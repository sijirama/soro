//TODO: what i have to do here
// - basic type checking
// - more defined ast types

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
    allocator: std.mem.Allocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList(ParserError),

    config: ParserConfig = .{},
    error_count: usize = 0,
    has_fatal_error: bool = false,

    prefixParseFns: std.AutoHashMap(TokenType, PrefixParseFn),
    infixParseFns: std.AutoHashMap(TokenType, InfixParseFn),

    allocated_expressions: std.ArrayList(*ast.Expression),
    allocated_block_statements: std.ArrayList(*ast.BlockStatement),

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {

        // initialize the parser
        var parser = Parser{
            .lexer = lexer,

            .current_token = undefined,
            .peek_token = undefined,

            .allocator = allocator,

            .errors = std.ArrayList(ParserError).init(allocator),

            .prefixParseFns = std.AutoHashMap(TokenType, PrefixParseFn).init(allocator),
            .infixParseFns = std.AutoHashMap(TokenType, InfixParseFn).init(allocator),

            .allocated_expressions = std.ArrayList(*ast.Expression).init(allocator),
            .allocated_block_statements = std.ArrayList(*ast.BlockStatement).init(allocator),
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

        // Free all expressions
        for (self.allocated_expressions.items) |expr| {
            self.allocator.destroy(expr);
        }
        self.allocated_expressions.deinit();

        // Free all block statements
        for (self.allocated_block_statements.items) |block| {
            block.deinit();
            self.allocator.destroy(block);
        }
        self.allocated_block_statements.deinit(); // deinit the block statements array

        self.errors.deinit();
        self.prefixParseFns.deinit();
        self.infixParseFns.deinit();
    }

    pub fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken() catch unreachable;
    }

    pub fn curTokenIs(self: *Parser, t: TokenType) bool {
        return self.current_token.type == t;
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
            if (err.format(self.allocator)) |msg| {
                std.debug.print("{}. {s}\n", .{ i + 1, msg });
                self.allocator.free(msg);
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
        var program = ast.Program.init(self.allocator);

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

    /// Deprecated, left here for idek bro, why is this actually still here, i'm lowkey just chilling
    pub fn parseOldAbegStatement(self: *Parser) ?ast.Statement {

        // Create the AbegStatement node
        var stmt = ast.AbegStatement{
            .token = self.current_token, // The 'abeg' token
            .name = undefined, // Will be set below
            .value = undefined, // Will be set below
            .type_annotation = null, // Default to no type annotation TODO:
            .is_locked = false, // Default to mutable
            .is_inferred = false, // Default to explicit type
        };

        // Check if the variable is immutable (e.g., 'abeg lock')
        if (self.peek_token.type == .LOCK) {
            stmt.is_locked = true;
            self.nextToken(); // Consume 'lock'
        }

        // Expect an identifier after 'abeg' or 'abeg lock'
        if (!self.expectPeek(.IDENT)) {
            return null;
        }

        // Parse the identifier (variable name)
        stmt.name = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Check if the next token is a type (e.g., 'string', 'int')
        // Handle type annotation or type inference
        if (self.peek_token.type != .COLON and self.peek_token.type != .ASSIGN) {
            self.nextToken();

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
        }

        // Check for type inference (e.g., ':=')
        if (self.peek_token.type == .COLON) {
            self.nextToken(); // Consume ':'
            if (self.peek_token.type == .ASSIGN) {
                stmt.is_inferred = true;
                self.nextToken(); // Consume '='
            } else {
                // Handle type annotation (e.g., 'abeg x: int = 5;')
                if (!self.expectPeek(.IDENT)) {
                    return null; // Error: Missing type identifier
                }
                //stmt.type_annotation = self.current_token.value; // Set the type annotation TODO:
                self.nextToken(); // Consume the type identifier //WARN: check this out

                // Expect an assignment operator '='
                if (!self.expectPeek(.ASSIGN)) {
                    return null; // Error: Missing '='
                }
            }
        } else {
            // Expect an assignment operator '='
            if (!self.expectPeek(.ASSIGN)) {
                return null; // Error: Missing '='
            }
        }

        // Advance to the next token (the value)
        self.nextToken();

        // Parse the expression on the right-hand side of the assignment
        const value_expr = self.parseExpression(.LOWEST) orelse {
            // Don't add another error here - parseExpression will have added one
            return null;
        };
        stmt.value = value_expr;

        // Expect a semicolon at the end of the statement
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        } else {
            self.addError(.MissingSemicolon, .Warning, self.current_token, null, null, null);
        }

        const result = ast.Statement{ .abeg_statement = stmt };

        return result;
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

        //TODO:
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

    // parse block statement, this usually consists of a set of statements but is not the program itself which is the same form
    // pub fn parseBlockStatement(self: *Parser) ?ast.Statement {
    //     const first_token = self.current_token;
    //
    //     var block = ast.BlockStatement.init(self.allocator);
    //     block.token = first_token;
    //
    //     self.nextToken(); // Move past the opening brace
    //
    //     block.statements = std.ArrayList(ast.Statement).init(block.allocator);
    //
    //     while (!self.curTokenIs(.RBRACE) and !self.curTokenIs(.EOF)) {
    //         if (self.parseStatement()) |statement| {
    //             block.statements.append(statement) catch {
    //                 self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish!");
    //                 block.deinit(); // Clean up if append fails
    //                 return null;
    //             };
    //         }
    //         self.nextToken();
    //     }
    //
    //     return ast.Statement{ .block_statement = block };
    // }

    pub fn parseBlockStatement(self: *Parser) ?ast.Statement {
        const first_token = self.current_token;
        //std.debug.print("Parsing block statement starting with token: {s}\n", .{first_token.value});

        var block = ast.BlockStatement.init(self.allocator);
        block.token = first_token;

        self.nextToken(); // Move past the opening brace

        while (!self.curTokenIs(.RBRACE) and !self.curTokenIs(.EOF)) {
            //std.debug.print("Current token in block: {s}\n", .{self.current_token.value});

            if (self.parseStatement()) |statement| {
                //std.debug.print("Parsed statement: {any}\n", .{statement});
                block.statements.append(statement) catch {
                    self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish!");
                    block.deinit(); // Clean up if append fails
                    return null;
                };
            } else {
                std.debug.print("Skipping invalid statement\n", .{});
                self.skipInvalidStatement(); // Skip invalid statements
            }
            self.nextToken();
        }

        if (self.curTokenIs(.EOF)) {
            std.debug.print("Reached EOF before closing brace\n", .{});
            self.addError(.MissingToken, .Error, first_token, null, null, "Missing closing brace");
            return null;
        }

        self.allocated_block_statements.append(&block) catch {
            return null;
        };

        std.debug.print("Finished parsing block statement with {d} statements\n", .{block.statements.items.len});
        return ast.Statement{ .block_statement = block };
    }

    pub fn parseExpression(self: *Parser, precedence: Precedence) ?*ast.Expression {

        //
        const prefixFn = self.prefixParseFns.get(self.current_token.type) orelse {
            self.addError(.NoPrefix, .Error, self.current_token, null, null, std.fmt.allocPrint(
                self.allocator,
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
        const dummy = self.allocator.create(ast.Expression) catch unreachable;
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
        const expr = self.allocator.create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create identifier");
            return null;
        };

        expr.* = .{ .identifier = identifier }; // Wrap the Identifier in an Expression

        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit track identifier");
            return null;
        };

        return expr;
    }

    pub fn parseIntegerLiteral(self: *Parser) ?*ast.Expression {

        //
        const expr = self.allocator.create(ast.Expression) catch {
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

        // Track the allocated expression
        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit track number");
            return null;
        };

        // Return the allocated pointer
        return expr;
    }

    pub fn parseFloatLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.allocator.create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create float");
            return null;
        };

        expr.* = ast.Expression{ .float_literal = ast.FloatLiteral{
            .token = self.current_token,
            .value = 0.0,
        } };

        const value = std.fmt.parseFloat(f64, self.current_token.value) catch {
            const msg = std.fmt.allocPrint(self.allocator, "Dis number '{s}' no be correct float o", .{self.current_token.value}) catch "Invalid float number";
            self.addError(.InvalidNumber, .Error, self.current_token, null, null, msg);
            return null;
        };

        expr.float_literal.value = value;

        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit track float");
            return null;
        };

        return expr;
    }

    pub fn parseStringLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.allocator.create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create string");
            return null;
        };

        expr.* = ast.Expression{ .string_literal = ast.StringLiteral{
            .value = self.current_token.value,
            .token = self.current_token,
        } };

        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit track string");
            return null;
        };

        return expr;
    }

    pub fn parseBooleanLiteral(self: *Parser) ?*ast.Expression {
        const expr = self.allocator.create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create boolean");
            return null;
        };

        expr.* = ast.Expression{ .boolean_literal = ast.BooleanLiteral{
            .token = self.current_token,
            .value = self.curTokenIs(TokenType.TRUE),
        } };

        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit track boolean");
            return null;
        };

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
        const expr = self.allocator.create(ast.Expression) catch {
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

        // Track for cleanup
        self.allocated_expressions.append(expr) catch {
            self.addError(
                .InvalidExpression,
                .Fatal,
                prefix_token,
                null,
                null,
                "Memory don finish! I no fit track expression",
            );
            return null;
        };

        return expr;
    }

    pub fn parseIfExpression(self: *Parser) ?*ast.Expression {
        //std.debug.print("Parsing if expression starting with token: {s}\n", .{self.current_token.value});

        const expr = self.allocator.create(ast.Expression) catch {
            self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create if expression");
            return null;
        };

        const if_token = self.current_token; // Save 'abi' token

        // Expect opening parenthesis after 'abi'
        if (!self.expectPeek(.LPAREN)) {
            std.debug.print("Missing opening parenthesis after 'abi'\n", .{});
            return null;
        }

        self.nextToken(); // Move to condition expression

        // Parse condition
        //std.debug.print("Parsing condition expression\n", .{});
        const condition = self.parseExpression(.LOWEST) orelse {
            std.debug.print("Failed to parse condition expression\n", .{});
            return null;
        };

        // Expect closing parenthesis
        if (!self.expectPeek(.RPAREN)) {
            std.debug.print("Missing closing parenthesis after condition\n", .{});
            return null;
        }

        // Expect opening brace for consequence block
        if (!self.expectPeek(.LBRACE)) {
            std.debug.print("Missing opening brace for consequence block\n", .{});
            return null;
        }

        // Parse consequence block
        //std.debug.print("Parsing consequence block\n", .{});
        const consequence = if (self.parseBlockStatement()) |stmt| blk: {
            if (stmt == .block_statement) {
                break :blk &stmt.block_statement;
            } else {
                self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
                return null;
            }
        } else {
            std.debug.print("Failed to parse consequence block\n", .{});
            return null;
        };

        // Parse optional else block
        var alternative: ?*ast.BlockStatement = null;
        if (self.peek_token.type == .NASO) {
            std.debug.print("Parsing naso (else) block\n", .{});
            self.nextToken(); // Consume 'naso'

            if (!self.expectPeek(.LBRACE)) {
                std.debug.print("Missing opening brace for naso block\n", .{});
                return null;
            }

            // Parse else block
            if (self.parseBlockStatement()) |*stmt| {
                if (stmt.* == .block_statement) {
                    alternative = @constCast(&stmt.block_statement);
                } else {
                    self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
                    return null;
                }
            } else {
                std.debug.print("Failed to parse naso block\n", .{});
                return null;
            }
        }

        // std.debug.print("\nCONSEQUENCE: {any}\n", .{consequence});
        // std.debug.print("\nALTERNATIVE: {any}\n", .{alternative});

        // Create and return the if expression
        expr.* = .{
            .if_expression = .{
                .token = if_token,
                .condition = condition,
                .consequence = @constCast(consequence),
                .alternative = alternative,
            },
        };

        // Track the allocated expression
        self.allocated_expressions.append(expr) catch {
            self.addError(.InvalidExpression, .Fatal, if_token, null, null, "Memory don finish! I no fit track if expression");
            return null;
        };

        std.debug.print("Successfully parsed if expression\n", .{});
        return expr;
    }

    // pub fn parseIfExpression(self: *Parser) ?*ast.Expression {
    //
    //     // Allocate memory for the Expression union
    //     const expr = self.allocator.create(ast.Expression) catch {
    //         self.addError(.InvalidExpression, .Fatal, self.current_token, null, null, "Memory don finish! I no fit create if expression");
    //         return null;
    //     };
    //
    //     const if_token = self.current_token; // Save 'abi' token
    //
    //     // Expect opening parenthesis after 'abi'
    //     if (!self.expectPeek(.LPAREN)) {
    //         return null;
    //     }
    //
    //     self.nextToken(); // Move to condition expression
    //
    //     // Parse condition
    //     const condition = self.parseExpression(.LOWEST) orelse {
    //         return null;
    //     };
    //
    //     // Expect closing parenthesis
    //     if (!self.expectPeek(.RPAREN)) {
    //         return null;
    //     }
    //
    //     // Expect opening brace for consequence block
    //     if (!self.expectPeek(.LBRACE)) {
    //         return null;
    //     }
    //
    //     // Parse consequence block
    //     const consequence = if (self.parseBlockStatement()) |stmt| blk: {
    //         if (stmt == .block_statement) {
    //             break :blk &stmt.block_statement;
    //         } else {
    //             self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
    //             return null;
    //         }
    //     } else return null;
    //
    //     // Parse optional else block
    //     var alternative: ?*ast.BlockStatement = null;
    //     if (self.peek_token.type == .NASO) {
    //         self.nextToken(); // Consume 'naso'
    //
    //         if (!self.expectPeek(.LBRACE)) {
    //             return null;
    //         }
    //
    //         // Parse else block
    //         if (self.parseBlockStatement()) |*stmt| {
    //             if (stmt.* == .block_statement) {
    //                 alternative = @constCast(&stmt.block_statement);
    //             } else {
    //                 self.addError(.InvalidExpression, .Error, self.current_token, null, null, "Expected block statement");
    //                 return null;
    //             }
    //         } else return null;
    //     }
    //
    //     // Create and return the if expression
    //     expr.* = .{
    //         .if_expression = .{
    //             .token = if_token,
    //             .condition = condition,
    //             .consequence = @constCast(consequence),
    //             .alternative = alternative,
    //         },
    //     };
    //
    //     // Track the allocated expression
    //     self.allocated_expressions.append(expr) catch {
    //         self.addError(.InvalidExpression, .Fatal, if_token, null, null, "Memory don finish! I no fit track if expression");
    //         return null;
    //     };
    //
    //     return expr;
    // }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Infix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseInfixExpression(self: *Parser, left: *ast.Expression) ?*ast.Expression {

        // Allocate memory for the Expression union
        const infix_token = self.current_token;
        const precedence = self.curPrecedence();

        const expr = self.allocator.create(ast.Expression) catch {
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

        self.allocated_expressions.append(expr) catch {
            self.addError(
                .InvalidExpression,
                .Fatal,
                infix_token,
                null,
                null,
                "Memory don finish! I no fit track expression",
            );
            return null;
        };

        // Return the parsed expression
        return expr;
    }
};
