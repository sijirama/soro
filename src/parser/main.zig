//TODO: what i have to do here
// - fix and change the errors to ParserErrors and use token locations
// - basic type checking
// - more defined ast types

const std = @import("std");
const Lexer = @import("../lexer/main.zig").Lexer;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const Type = @import("../token/main.zig").Type;
const ast = @import("../ast/ast.zig");
const ParserError = @import("./error.zig").ParserError;
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

const PrefixParseFn = *const fn (p: *Parser) *ast.Expression;
const InfixParseFn = *const fn (p: *Parser, left: *ast.Expression) *ast.Expression;

pub const Parser = struct {
    lexer: *Lexer,
    allocator: std.mem.Allocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList(ParserError), // TODO: change this to ParserError

    prefixParseFns: std.AutoHashMap(TokenType, PrefixParseFn),
    infixParseFns: std.AutoHashMap(TokenType, InfixParseFn),
    allocated_expressions: std.ArrayList(*ast.Expression),

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
        for (self.allocated_expressions.items) |expr| {
            self.allocator.destroy(expr); // Free memory
        }
        self.allocated_expressions.deinit();
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
        while (self.current_token.type != .SEMICOLON and self.current_token.type != .EOF) {
            self.nextToken();
        }
        if (self.current_token.type == .SEMICOLON) {
            self.nextToken(); // Consume ';'
        }
    }

    pub fn expectPeek(self: *Parser, expected: TokenType) bool {
        if (self.peek_token.type == expected) {
            self.nextToken(); // Advance to the next token
            return true;
        } else {
            // const error_msg = std.fmt.allocPrint(self.allocator, "Expected next token to be {any}, got {any} instead", .{ expected, self.peek_token.type }) catch return false;
            // self.errors.append(error_msg) catch return false;

            self.errors.append(.{
                .error_type = .UnexpectedToken,
                .line = self.peek_token.line,
                .column = self.peek_token.column,
                .expected = expected,
                .fileName = self.peek_token.fileName,
                .fileDirectory = self.peek_token.fileDirectory,
                .found = self.peek_token.type,
            }) catch return false;

            return false;
        }
    }

    pub fn registerPrefix(self: *Parser, tokenType: TokenType, func: PrefixParseFn) void {
        self.prefixParseFns.put(tokenType, func) catch unreachable;
    }

    pub fn registerInfix(self: *Parser, tokenType: TokenType, func: InfixParseFn) void {
        self.infixParseFns.put(tokenType, func) catch unreachable;
    }

    fn addError(self: *Parser, error_type: ParserErrorType, token: Token, expected: ?TokenType, found: ?TokenType, message: ?[]const u8) void {
        self.errors.append(CreateParserError(error_type, token, expected, found, message)) catch unreachable;
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

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Parsing Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseProgram(self: *Parser) !ast.Program {
        var program = ast.Program.init(self.allocator);

        while (self.current_token.type != .EOF) {
            if (self.parseStatement()) |statement| {
                try program.statements.append(statement);
            }
            self.nextToken();
        }

        // if (self.errors.items.len > 0) {
        //     self.printErrors();
        //     return program;
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

    pub fn parseAbegStatement(self: *Parser) ?ast.Statement {
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
            self.addError(.MissingToken, self.current_token, .IDENT, self.peek_token.type, "Expected identifier after 'abeg'");
            return null;
        }

        // Parse the identifier (variable name)
        stmt.name = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Check if the next token is a type (e.g., 'string', 'int')
        if (self.peek_token.type != .COLON and self.peek_token.type != .ASSIGN) {
            // The next token might be a type identifier
            self.nextToken(); // Consume the type identifier

            // Convert the token type to a Type
            if (Type.fromTokenType(self.current_token.type)) |type_annotation| {
                stmt.type_annotation = type_annotation;
            } else {
                // Error: Invalid type
                self.addError(.InvalidTypeAnnotation, self.current_token, null, null, "Invalid type annotation");
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
                self.nextToken(); // Consume the type identifier

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
        if (self.parseExpression(.LOWEST)) |expr| {
            stmt.value = expr;
        } else {
            return null; // Avoid returning a broken statement
        }

        // Expect a semicolon at the end of the statement
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken(); // Consume the semicolon
        }

        const result = ast.Statement{ .abeg_statement = stmt };

        return result;
    }

    pub fn parseComotStatement(self: *Parser) ?ast.Statement {
        var stmt = ast.ComotStatement{
            .token = self.current_token,
            .value = undefined,
        };

        self.nextToken();

        //stmt.value = self.parseExpression(.LOWEST);
        if (self.parseExpression(.LOWEST)) |expr| {
            stmt.value = expr;
        } else {
            return null; // Avoid returning a broken statement
        }

        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        }

        return ast.Statement{ .comot_statement = stmt };
    }

    pub fn parseExpressionStatement(self: *Parser) ?ast.Statement {
        const expr = self.parseExpression(.LOWEST) orelse {
            //std.debug.print("Error: Failed to parse expression at line from expr stmt {}\n", .{self.current_token.line});
            const parseError = CreateParserError(.InvalidExpression, self.current_token, null, null, "Failed to parse expression");
            self.errors.append(parseError) catch return null;

            std.debug.print("\ntotal of {} parse errors from parseExprStmt", .{self.errors.items.len});

            return null;
        };

        const stmt = ast.ExpressionStatement{
            .token = self.current_token,
            .expression = expr,
        };

        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken();
        }

        return ast.Statement{ .expression_statement = stmt };
    }

    pub fn parseExpression(self: *Parser, precedence: Precedence) ?*ast.Expression {
        const prefixFn = self.prefixParseFns.get(self.current_token.type) orelse {
            self.errors.append(.{
                .error_type = .NoPrefix,
                .line = self.current_token.line,
                .column = self.current_token.column,
                .fileName = self.current_token.fileName,
                .fileDirectory = self.current_token.fileDirectory,
                .message = self.current_token.value,
            }) catch return null;

            return null; // Return null instead of dummy
        };

        var leftExpr = prefixFn(self);
        // if (leftExpr == null) {
        //     self.addError(.InvalidExpression, self.current_token, null, null, "Failed to parse prefix expression");
        //     return null;
        // }

        while (self.peek_token.type != .SEMICOLON and
            @intFromEnum(precedence) < @intFromEnum(self.peekPrecedence()))
        {
            const infixFn = self.infixParseFns.get(self.peek_token.type) orelse break;
            self.nextToken();
            leftExpr = infixFn(self, leftExpr);
            // if (leftExpr == null) {
            //     self.addError(.InvalidExpression, self.current_token, null, null, "Failed to parse infix expression");
            //     return null;
            // }
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

    pub fn parseIdentifier(self: *Parser) *ast.Expression {
        const identifier = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Allocate memory for the Expression union
        const expr = self.allocator.create(ast.Expression) catch unreachable;
        expr.* = .{ .identifier = identifier }; // Wrap the Identifier in an Expression

        self.allocated_expressions.append(expr) catch unreachable;

        return expr;
    }

    pub fn parseIntegerLiteral(self: *Parser) *ast.Expression {
        // Allocate memory for the Expression
        const expr = self.allocator.create(ast.Expression) catch unreachable;

        expr.* = ast.Expression{ .integer_literal = ast.IntegerLiteral{
            .token = self.current_token,
            .value = 0,
        } };

        // Try to parse the integer value
        const value = std.fmt.parseInt(i32, self.current_token.value, 10) catch {
            self.errors.append(.{
                .error_type = .InvalidNumber,
                .line = self.current_token.line,
                .column = self.current_token.column,
                .fileName = self.current_token.fileName,
                .fileDirectory = self.current_token.fileDirectory,
                .message = self.current_token.value,
            }) catch return self.createDummyExpression();

            return self.createDummyExpression();
        };

        expr.integer_literal.value = value;

        // Track the allocated expression
        self.allocated_expressions.append(expr) catch unreachable;

        // Return the allocated pointer
        return expr;
    }

    pub fn parseFloatLiteral(self: *Parser) *ast.Expression {
        // Allocate memory for the Expression
        const expr = self.allocator.create(ast.Expression) catch unreachable;

        expr.* = ast.Expression{ .float_literal = ast.FloatLiteral{
            .token = self.current_token,
            .value = 0.0,
        } };

        // Try to parse the float value
        const value = std.fmt.parseFloat(f64, self.current_token.value) catch {
            self.errors.append(.{
                .error_type = .InvalidNumber,
                .line = self.current_token.line,
                .column = self.current_token.column,
                .fileName = self.current_token.fileName,
                .fileDirectory = self.current_token.fileDirectory,
                .message = std.fmt.allocPrint(self.allocator, "Dis number '{s}' no be correct float o", .{self.current_token.value}) catch return self.createDummyExpression(),
            }) catch return self.createDummyExpression();

            return self.createDummyExpression();
        };

        expr.float_literal.value = value;

        // Track the allocated expression
        self.allocated_expressions.append(expr) catch unreachable;

        // Return the allocated pointer
        return expr;
    }

    pub fn parseStringLiteral(self: *Parser) *ast.Expression {
        const expr = self.allocator.create(ast.Expression) catch unreachable;
        expr.* = ast.Expression{ .string_literal = ast.StringLiteral{
            .value = self.current_token.value,
            .token = self.current_token,
        } };
        self.allocated_expressions.append(expr) catch unreachable;
        return expr;
    }

    pub fn parseBooleanLiteral(self: *Parser) *ast.Expression {
        const expr = self.allocator.create(ast.Expression) catch unreachable;
        expr.* = ast.Expression{ .boolean_literal = ast.BooleanLiteral{
            .token = self.current_token,
            .value = self.curTokenIs(TokenType.TRUE),
        } };
        self.allocated_expressions.append(expr) catch unreachable;
        return expr;
    }

    pub fn parseGroupedExpression(self: *Parser) *ast.Expression {
        self.nextToken(); // Consume '('

        const expr = self.parseExpression(.LOWEST) orelse {
            self.errors.append(.{
                .error_type = .InvalidExpression,
                .line = self.current_token.line,
                .column = self.current_token.column,
                .fileName = self.current_token.fileName,
                .fileDirectory = self.current_token.fileDirectory,
                .message = "Wetin you put inside bracket no clear",
            }) catch return self.createDummyExpression();

            return self.createDummyExpression();
        };

        if (!self.expectPeek(.RPAREN)) {
            //self.errors.append("Error: Missing \')\'") catch return self.createDummyExpression();

            self.errors.append(.{
                .error_type = .MissingRightParen,
                .line = self.current_token.line,
                .column = self.current_token.column,
                .fileName = self.current_token.fileName,
                .fileDirectory = self.current_token.fileDirectory,
            }) catch return self.createDummyExpression();

            return self.createDummyExpression(); //TODO: Error: Missing ')'
        }
        return expr;
    }

    pub fn parsePrefixExpression(self: *Parser) *ast.Expression {
        // Save the current token info before advancing
        const prefix_token = self.current_token;
        const operator = self.current_token.value;

        // Advance to the operand
        self.nextToken();

        // Parse the right-hand side first
        const right_expr = self.parseExpression(.PREFIX) orelse {
            self.errors.append(CreateParserError(.InvalidPrefixOperator, prefix_token, null, null, "I no fit parse wetin dey right side of dis operator")) catch return self.createDummyExpression();
            return self.createDummyExpression();
        };

        // Now create and initialize the expression
        const expr = self.allocator.create(ast.Expression) catch unreachable;
        expr.* = .{
            .prefix_expression = .{
                .token = prefix_token,
                .operator = operator,
                .right = right_expr,
            },
        };

        // Track for cleanup
        self.allocated_expressions.append(expr) catch unreachable;

        return expr;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Infix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseInfixExpression(self: *Parser, left: *ast.Expression) *ast.Expression {
        // Allocate memory for the Expression union
        const infix_token = self.current_token;
        const expr = self.allocator.create(ast.Expression) catch unreachable;

        // Initialize the InfixExpression and wrap it in the Expression union
        expr.* = .{
            .infix_expression = .{
                .token = self.current_token,
                .operator = self.current_token.value,
                .left = left,
                .right = undefined, // Will be set below
            },
        };

        // Get the precedence for this infix operation
        const precedence = self.curPrecedence();

        // Advance to the next token (the right operand)
        self.nextToken();

        // Parse the right-hand side of the infix expression
        const right_expr = self.parseExpression(precedence) orelse {
            self.errors.append(CreateParserError(.InvalidInfixOperator, infix_token, null, null, "I no fit parse wetin dey right side of dis operator")) catch return self.createDummyExpression();
            return self.createDummyExpression();
        };

        expr.infix_expression.right = right_expr;

        self.allocated_expressions.append(expr) catch unreachable;

        // Return the parsed expression
        return expr;
    }
};
