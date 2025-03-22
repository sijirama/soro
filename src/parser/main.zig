const std = @import("std");
const Lexer = @import("../lexer/main.zig").Lexer;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const Type = @import("../type/types.zig").Type;
const TypeKeywords = @import("../type/types.zig").TypeKeywords;
const ast = @import("../ast/ast.zig");
const ParserError = @import("./error.zig").ParserError;
const ParserErrorSeverity = @import("./error.zig").ErrorSeverity;
const ParserErrorType = @import("./error.zig").ParserErrorType;
const CreateParserError = @import("./error.zig").createError;

const Precedence = enum(u8) {
    LOWEST,
    EQUALS, // ==
    LESSGREATER, // > or <
    SUM, // +
    PRODUCT, // *
    PREFIX, // -X or !X
    CALL, // myFunction(X)
    INDEX, // array[index]
};

const PrefixParseFn = *const fn (p: *Parser) ?*ast.Expression;
const InfixParseFn = *const fn (p: *Parser, left: *ast.Expression) ?*ast.Expression;

pub const ParserConfig = struct {
    max_errors: usize = 25,
    stop_on_first_error: bool = false,
    recover_statements: bool = true,
    ignore_warnings: bool = false,
};

pub const Parser = struct {
    lexer: *Lexer,
    arena: std.heap.ArenaAllocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList(ParserError),

    config: ParserConfig = .{},
    error_count: usize = 0,
    has_fatal_error: bool = false,

    prefixParseFns: std.AutoHashMap(TokenType, PrefixParseFn),
    infixParseFns: std.AutoHashMap(TokenType, InfixParseFn),

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {
        const arena = std.heap.ArenaAllocator.init(allocator);

        // initialize the parser
        var parser = Parser{
            .lexer = lexer,

            .arena = arena,

            .current_token = undefined,
            .peek_token = undefined,

            .errors = std.ArrayList(ParserError).init(allocator), // use the parent allocator for errors

            .prefixParseFns = std.AutoHashMap(TokenType, PrefixParseFn).init(allocator), // Use the parent allocator for hash maps
            .infixParseFns = std.AutoHashMap(TokenType, InfixParseFn).init(allocator), // Use the parent allocator for hash maps

        };

        // register prefix functions
        parser.registerPrefix(TokenType.IDENT, Parser.parseIdentifier);
        parser.registerPrefix(TokenType.INTEGER, Parser.parseIntegerLiteral);
        parser.registerPrefix(TokenType.FLOAT, Parser.parseFloatLiteral);
        parser.registerPrefix(TokenType.STRING, Parser.parseStringLiteral);
        parser.registerPrefix(TokenType.TRUE, Parser.parseBooleanLiteral);
        parser.registerPrefix(TokenType.FALSE, Parser.parseBooleanLiteral);
        parser.registerPrefix(TokenType.MINUS, Parser.parsePrefixExpression);
        parser.registerPrefix(TokenType.BANG, Parser.parsePrefixExpression);
        parser.registerPrefix(TokenType.LPAREN, Parser.parseGroupedExpression);
        parser.registerPrefix(TokenType.ABI, Parser.parseIfExpression);
        parser.registerPrefix(TokenType.LBRACKET, Parser.parseArrayLiteral);

        // register infix functions
        parser.registerInfix(TokenType.PLUS, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.MINUS, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.SLASH, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.ASTERISK, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.EQUAL, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.NOT_EQUAL, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.LESS_THAN, Parser.parseInfixExpression);
        parser.registerInfix(TokenType.GREATER_THAN, Parser.parseInfixExpression);

        // Advance tokens to set current and peek
        parser.nextToken();
        parser.nextToken();

        // return the parser
        return parser;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Helper Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn deinit(self: *Parser) void {
        self.prefixParseFns.deinit();

        self.infixParseFns.deinit();

        self.errors.deinit();

        self.arena.deinit();
    }

    pub fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken() catch unreachable;
    }

    pub fn curTokenIs(self: *Parser, t: TokenType) bool {
        return self.current_token.type == t;
    }

    pub fn peekTokenIs(self: *Parser, t: TokenType) bool {
        return self.peek_token.type == t;
    }

    fn precedenceOf(_: *Parser, tokenType: TokenType) Precedence {
        return switch (tokenType) {
            .PLUS, .MINUS => .SUM,
            .ASTERISK, .SLASH => .PRODUCT,
            .EQUAL, .NOT_EQUAL => .EQUALS,
            .LESS_THAN, .GREATER_THAN => .LESSGREATER,
            .LPAREN => .CALL,
            .LBRACKET => .INDEX,
            else => .LOWEST,
        };
    }

    fn curPrecedence(self: *Parser) Precedence {
        return self.precedenceOf(self.current_token.type);
    }

    fn peekPrecedence(self: *Parser) Precedence {
        return self.precedenceOf(self.peek_token.type);
    }

    fn IntgerFromPrecedence(p: Precedence) u8 {
        return @intFromEnum(p);
    }

    pub fn skipInvalidStatement(self: *Parser) void {
        var depth: usize = 0;

        while (self.current_token.type != .EOF) {
            switch (self.current_token.type) {
                .SEMICOLON => {
                    if (depth == 0) {
                        self.nextToken(); // Consume the semicolon
                        break;
                    }
                },
                .LPAREN, .LBRACE => depth += 1,
                .RPAREN, .RBRACE => {
                    if (depth > 0) depth -= 1;
                    if (depth == 0) {
                        self.nextToken(); // Consume the closing delimiter
                        break;
                    }
                },
                .ABEG, .COMOT => if (depth == 0) break,
                else => {},
            }
            self.nextToken();
        }
    }

    pub fn expectPeek(self: *Parser, expected: TokenType) bool {

        // if the next token is as expected
        if (self.peek_token.type == expected) {
            self.nextToken(); // Advance to the next token
            return true;
        }

        self.addError(.UnexpectedToken, .Error, self.peek_token, expected, self.peek_token.type, null);

        return false;
    }

    pub fn registerPrefix(self: *Parser, tokenType: TokenType, func: PrefixParseFn) void {
        self.prefixParseFns.put(tokenType, func) catch unreachable;
    }

    pub fn registerInfix(self: *Parser, tokenType: TokenType, func: InfixParseFn) void {
        self.infixParseFns.put(tokenType, func) catch unreachable;
    }

    fn addError(
        self: *Parser,
        error_type: ParserErrorType,
        severity: ParserErrorSeverity,
        token: Token,
        expected: ?TokenType,
        found: ?TokenType,
        message: ?[]const u8,
    ) void {

        // Don't add warnings if they're ignored
        if (severity == .Warning and self.config.ignore_warnings) {
            return;
        }

        const err = CreateParserError(error_type, severity, token, expected, found, message);
        self.errors.append(err) catch return;

        if (severity != .Warning) {
            self.error_count += 1;
        }

        // Handle fatal errors or too many errors
        if (severity == .Fatal) {
            self.has_fatal_error = true;
        }

        if (self.error_count >= self.config.max_errors) {
            self.has_fatal_error = true;
            const max_errors_token = Token{
                .type = .ILLEGAL,
                .value = "too many errors",
                .line = token.line,
                .column = token.column,
                .fileName = token.fileName,
                .fileDirectory = token.fileDirectory,
            };
            self.errors.append(
                CreateParserError(.TooManyErrors, .Fatal, max_errors_token, null, null, "Parser don tire! Too many errors."),
            ) catch return;
        }

        // Stop immediately if configured to do so
        if (self.config.stop_on_first_error and severity != .Warning) {
            self.has_fatal_error = true;
        }
    }

    // Function to print all collected errors
    pub fn printErrors(self: *Parser) void {
        if (self.errors.items.len == 0) return;

        // Print header with total error count
        std.debug.print("\n=== Wahala Dey! Found {} error{s} ===\n\n", .{ self.errors.items.len, if (self.errors.items.len > 1) "s" else "" });

        // Print each error
        for (self.errors.items, 0..) |err, i| {
            if (err.format(self.arena.allocator())) |msg| {
                std.debug.print("{}. {s}\n", .{ i + 1, msg });
            } else |_| {
                std.debug.print("{}. Error formatting error message\n", .{i + 1});
            }
        }

        std.debug.print("\n=== End of Errors ===\n\n", .{});
    }

    //new method to check if parsing should continue
    fn shouldContinueParsing(self: *Parser) bool {
        return !self.has_fatal_error and self.error_count < self.config.max_errors;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Parsing Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseProgram(self: *Parser) !ast.Program {
        var program = ast.Program.init(self.arena.allocator());

        while (self.current_token.type != .EOF and self.shouldContinueParsing()) {
            if (self.parseStatement()) |statement| {
                try program.statements.append(statement);
            } else if (self.config.recover_statements) {
                self.skipInvalidStatement();
            } else {
                break;
            }

            // move to the next token
            self.nextToken();
        }

        // if (self.errors.items.len > 0) {
        //     self.printErrors();
        //     if (self.has_fatal_error) {
        //         return error.ParsingFailed;
        //     }
        // }

        return program;
    }

    pub fn parseStatement(self: *Parser) ?ast.Statement {
        return switch (self.current_token.type) {
            .ABEG => self.parseAbegStatement(),
            .COMOT => self.parseComotStatement(),
            else => {
                const stmt = self.parseExpressionStatement();
                if (stmt == null) {
                    self.skipInvalidStatement();
                }
                return stmt;
            },
        };
    }

    //WARN:we can't realy return null anywhere here
    //NOTE: there are 2 parse AbegStatement functions, refactor one to the most readable and leave,
    // they are both horrendous in terms of readability

    pub fn parseAbegStatement(self: *Parser) ?ast.Statement {
        // Create the AbegStatement node
        var stmt = ast.AbegStatement{
            .token = self.current_token,
            .name = undefined,
            .value = undefined,
            .type_annotation = null,
            .is_locked = false,
            .is_inferred = false,
        };

        // Check for 'lock' keyword
        if (self.peek_token.type == .LOCK) {
            stmt.is_locked = true;
            self.nextToken(); // Consume 'lock'
        }

        // Expect identifier after 'abeg' or 'abeg lock'
        if (!self.expectPeek(.IDENT)) {
            return null;
        }

        // Set the variable name
        stmt.name = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Check if next token is a colon for type inference
        if (self.peek_token.type == .COLON) {
            self.nextToken(); // Consume ':'
            // Now check for the '=' part of ':='
            if (self.peek_token.type == .ASSIGN) {
                self.nextToken(); // Consume '='
                stmt.is_inferred = true;
            } else {
                return null; // Error: expected '=' after ':'
            }
        } else if (self.peek_token.type == .TYPE) {
            // Handle explicit type case: abeg name string = value
            self.nextToken(); // Consume type identifier
            if (TypeKeywords.getType(self.current_token.value)) |type_annotation| {
                stmt.type_annotation = type_annotation;
            } else {
                self.addError(
                    .InvalidTypeAnnotation,
                    .Error,
                    self.current_token,
                    null,
                    null,
                    "Dis type no dey valid o",
                );
                return null;
            }

            // Expect '=' after type
            if (!self.expectPeek(.ASSIGN)) {
                return null;
            }
        } else {
            // Expect '=' for direct assignment
            if (!self.expectPeek(.ASSIGN)) {
                return null;
            }
        }

        // Parse the expression value
        self.nextToken(); // Move to the start of the expression
        if (self.parseExpression(.LOWEST)) |value_expr| {
            stmt.value = value_expr;
        } else {
            return null;
        }

        // Handle optional semicolon
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        } else {
            self.addError(.MissingSemicolon, .Warning, self.current_token, null, null, null);
        }

        return ast.Statement{ .abeg_statement = stmt };
    }

    pub fn parseComotStatement(self: *Parser) ?ast.Statement {
        const comot_token = self.current_token;

        self.nextToken();

        var stmt = ast.ComotStatement{
            .token = comot_token,
            .value = undefined,
        };

        //stmt.value = self.parseExpression(.LOWEST);
        const value_expr = self.parseExpression(.LOWEST) orelse {
            // Don't add another error - parseExpression already did
            return null;
        };

        stmt.value = value_expr;

        // Handle semicolon (warning)
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        } else {
            self.addError(.MissingSemicolon, .Warning, self.current_token, null, null, null);
        }

        return ast.Statement{ .comot_statement = stmt };
    }

    pub fn parseExpressionStatement(self: *Parser) ?ast.Statement {

        //
        const expr = self.parseExpression(.LOWEST) orelse {
            // No need to add error here - parseExpression already did
            return null;
        };

        //std.debug.print("Parsed expression: {any}\n", .{expr}); // Debug log

        const stmt = ast.ExpressionStatement{
            .token = self.current_token,
            .expression = expr,
        };

        // Handle semicolon as warning
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        } else {
            self.addError(.MissingSemicolon, .Warning, self.current_token, null, null, null);
        }

        return ast.Statement{ .expression_statement = stmt };
    }

    pub fn parseBlockStatement(self: *Parser) ?ast.Statement {
        const first_token = self.current_token;

        var block = ast.BlockStatement.init(self.arena.allocator(), first_token);

        self.nextToken(); // Move past the opening brace

        while (!self.curTokenIs(.RBRACE) and !self.curTokenIs(.EOF)) {
            if (self.parseStatement()) |statement| {
                block.statements.append(statement) catch {
                    self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish!");
                    return null;
                };
            } else {
                if (self.config.recover_statements) {
                    self.skipInvalidStatement();
                } else {
                    return null;
                }
            }
            self.nextToken();
        }

        if (self.curTokenIs(.EOF)) {
            std.debug.print("Reached EOF before closing brace\n", .{});
            self.addError(.MissingToken, .Error, first_token, null, null, "Missing closing brace");
            return null;
        }

        //std.debug.print("Finished parsing block statement with {d} statements\n", .{block.statements.items.len});
        return ast.Statement{ .block_statement = block };
    }

    pub fn parseExpression(self: *Parser, precedence: Precedence) ?*ast.Expression {

        //
        const prefixFn = self.prefixParseFns.get(self.current_token.type) orelse {
            self.addError(.NoPrefix, .Error, self.current_token, null, null, std.fmt.allocPrint(
                self.arena.allocator(),
                "I no sabi wetin to do with dis token: {s}",
                .{self.current_token.value},
            ) catch "unknown token");
            return null;
        };

        var leftExpr = prefixFn(self) orelse return null;

        while (self.peek_token.type != .SEMICOLON and
            !self.has_fatal_error and
            @intFromEnum(precedence) < @intFromEnum(self.peekPrecedence()))
        {
            const infixFn = self.infixParseFns.get(self.peek_token.type) orelse break;
            self.nextToken();
            leftExpr = infixFn(self, leftExpr) orelse return null;
        }

        //std.debug.print("Final expr {}", .{leftExpr});

        return leftExpr;
    }

    // Helper function to create a dummy expression
    fn createDummyExpression(self: *Parser) *ast.Expression {
        const dummy = self.arena.allocator().create(ast.Expression) catch unreachable;
        dummy.* = .{ .integer_literal = ast.IntegerLiteral{ .token = self.current_token, .value = 0 } };
        return dummy;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Prefix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseIdentifier(self: *Parser) ?*ast.Expression {
        const identifier = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Allocate memory for the Expression union
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create identifier");
            return null;
        };

        expr.* = .{ .identifier = identifier }; // Wrap the Identifier in an Expression

        return expr;
    }

    pub fn parseIntegerLiteral(self: *Parser) ?*ast.Expression {

        //
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create number");
            return null;
        };

        expr.* = ast.Expression{ .integer_literal = ast.IntegerLiteral{
            .token = self.current_token,
            .value = 0,
        } };

        // Try to parse the integer value
        const value = std.fmt.parseInt(i32, self.current_token.value, 10) catch {
            self.addError(.InvalidNumber, .Error, self.current_token, null, null, self.current_token.value);
            return null;
        };

        expr.integer_literal.value = value;

        return expr;
    }

    pub fn parseFloatLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create float");
            return null;
        };

        expr.* = ast.Expression{ .float_literal = ast.FloatLiteral{
            .token = self.current_token,
            .value = 0.0,
        } };

        const value = std.fmt.parseFloat(f64, self.current_token.value) catch {
            const msg = std.fmt.allocPrint(self.arena.allocator(), "Dis number '{s}' no be correct float o", .{self.current_token.value}) catch "Invalid float number";
            self.addError(.InvalidNumber, .Error, self.current_token, null, null, msg);
            return null;
        };

        expr.float_literal.value = value;

        return expr;
    }

    pub fn parseStringLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create string");
            return null;
        };

        expr.* = ast.Expression{ .string_literal = ast.StringLiteral{
            .value = self.current_token.value,
            .token = self.current_token,
        } };

        return expr;
    }

    pub fn parseBooleanLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create boolean");
            return null;
        };

        expr.* = ast.Expression{ .boolean_literal = ast.BooleanLiteral{
            .token = self.current_token,
            .value = self.curTokenIs(TokenType.TRUE),
        } };

        return expr;
    }

    pub fn parseGroupedExpression(self: *Parser) ?*ast.Expression {

        //
        const group_token = self.current_token;
        self.nextToken(); // Consume '('

        const expr = self.parseExpression(.LOWEST) orelse {
            // Don't add another error - parseExpression already did
            return null;
        };

        if (!self.expectPeek(.RPAREN)) {
            self.addError(.MissingRightParen, .Error, group_token, null, null, null);
            return null;
        }

        return expr;
    }

    pub fn parsePrefixExpression(self: *Parser) ?*ast.Expression {
        // Save the current token info before advancing
        const prefix_token = self.current_token;
        const operator = self.current_token.value;

        // Advance to the operand
        self.nextToken();

        // Parse the right-hand side first
        const right_expr = self.parseExpression(.PREFIX) orelse {
            return null;
        };

        // Now create and initialize the expression
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(
                .InvalidExpression,
                .Fatal,
                prefix_token,
                null,
                null,
                "Memory don finish! I no fit create expression",
            );
            return null;
        };

        expr.* = .{
            .prefix_expression = .{
                .token = prefix_token,
                .operator = operator,
                .right = right_expr,
            },
        };

        return expr;
    }

    pub fn parseIfExpression(self: *Parser) ?*ast.Expression {
        // Allocate memory for the Expression union
        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create if expression");
            return null;
        };

        const if_token = self.current_token; // Save 'abi' token

        // Expect opening parenthesis after 'abi'
        if (!self.expectPeek(.LPAREN)) {
            return null;
        }

        self.nextToken(); // Move to condition expression

        // Parse condition
        const condition = self.parseExpression(.LOWEST) orelse {
            return null;
        };

        // Expect closing parenthesis
        if (!self.expectPeek(.RPAREN)) {
            return null;
        }

        // Expect opening brace for consequence block
        if (!self.expectPeek(.LBRACE)) {
            return null;
        }

        // Parse consequence block
        const consequence_stmt = self.parseBlockStatement() orelse {
            return null;
        };

        const consequence = self.arena.allocator().create(ast.BlockStatement) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish!");
            return null;
        };

        // Convert consequence to BlockStatement
        consequence.* = switch (consequence_stmt) {
            .block_statement => |blk| blk,
            else => {
                self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
                return null;
            },
        };

        // Initialize the if expression without alternative first
        expr.* = .{
            .if_expression = .{
                .token = if_token,
                .condition = condition,
                .consequence = consequence,
                .alternative = null,
            },
        };

        // std.debug.print("\nBEFORE PARSING ALTERNATIVE\n", .{});
        // std.debug.print("\nCONDITION: {any}\n", .{expr.if_expression.condition});
        // std.debug.print("\nCONSEQUENCE: {any}\n", .{expr.if_expression.consequence.statements.items[0]});
        // std.debug.print("\nALTERNATIVE: {?}\n\n", .{expr.if_expression.alternative});

        // Parse optional else block
        if (self.peek_token.type == .NASO) {
            self.nextToken();
            if (!self.expectPeek(.LBRACE)) {
                return null;
            }
            if (self.parseBlockStatement()) |alternative_stmt| {
                const alternative = self.arena.allocator().create(ast.BlockStatement) catch {
                    self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish!");
                    return null;
                };
                alternative.* = switch (alternative_stmt) {
                    .block_statement => |blk| blk,
                    else => {
                        self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
                        return null;
                    },
                };
                expr.if_expression.alternative = alternative;
            } else {
                return null;
            }
        }

        return expr;
    }

    pub fn parseArrayLiteral(self: *Parser) ?*ast.Expression {
        const first_token = self.current_token;

        var array = ast.ArrayLiteral.init(self.arena.allocator(), first_token);

        array.elements = self.parseExpressionList(TokenType.RBRACKET);

        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create identifier");
            return null;
        };

        expr.* = .{ .array_literal = array }; // Wrap the Identifier in an Expression
        return expr;
    }

    pub fn parseExpressionList(self: *Parser, end: TokenType) std.ArrayList(*ast.Expression) {
        var exprList = std.ArrayList(*ast.Expression).init(self.arena.allocator());

        if (self.peekTokenIs(end)) {
            self.nextToken();
            return exprList;
        }

        self.nextToken();
        exprList.append(self.parseExpression(Precedence.LOWEST) orelse {
            return exprList;
        }) catch unreachable;

        while (self.peekTokenIs(TokenType.COMMA)) {
            self.nextToken();
            self.nextToken();

            exprList.append(self.parseExpression(Precedence.LOWEST) orelse {
                return exprList;
            }) catch unreachable;
        }

        _ = self.expectPeek(end);

        return exprList;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Infix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseInfixExpression(self: *Parser, left: *ast.Expression) ?*ast.Expression {

        // Allocate memory for the Expression union
        const infix_token = self.current_token;
        const precedence = self.curPrecedence();

        const expr = self.arena.allocator().create(ast.Expression) catch {
            self.addError(
                .InvalidExpression,
                .Fatal,
                infix_token,
                null,
                null,
                "Memory don finish! I no fit create expression",
            );
            return null;
        };

        // Initialize the InfixExpression and wrap it in the Expression union
        expr.* = .{
            .infix_expression = .{
                .token = self.current_token,
                .operator = self.current_token.value,
                .left = left,
                .right = undefined, // Will be set below
            },
        };

        // Advance to the next token (the right operand)
        self.nextToken();

        // Parse the right-hand side of the infix expression
        const right_expr = self.parseExpression(precedence) orelse {
            // Don't add another error - parseExpression already did
            return null;
        };

        expr.infix_expression.right = right_expr;

        return expr;
    }
};
