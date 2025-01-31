const std = @import("std");
const Lexer = @import("../lexer/main.zig").Lexer;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const ast = @import("../ast/ast.zig");

const PrefixParseFn = *const fn (p: *Parser) *ast.Expression;
const InfixParseFn = *const fn (p: *Parser, left: *ast.Expression) *ast.Expression;

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

pub const Parser = struct {
    lexer: *Lexer,
    allocator: std.mem.Allocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList([]const u8), // TODO: change this to ParserError

    prefixParseFns: std.AutoHashMap(TokenType, PrefixParseFn),
    infixParseFns: std.AutoHashMap(TokenType, InfixParseFn),

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {

        // initialize the parser
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .peek_token = undefined,
            .allocator = allocator,
            .errors = std.ArrayList([]const u8).init(allocator),

            .prefixParseFns = std.AutoHashMap(TokenType, PrefixParseFn).init(allocator),
            .infixParseFns = std.AutoHashMap(TokenType, InfixParseFn).init(allocator),
        };

        // register prefix functions
        parser.registerPrefix(TokenType.IDENT, parser.parseIdentifier);
        parser.registerPrefix(TokenType.INTEGER, parser.parseIntegerLiteral);
        parser.registerPrefix(TokenType.STRING, parser.parseStringLiteral);
        parser.registerPrefix(TokenType.TRUE, parser.parseBooleanLiteral);
        parser.registerPrefix(TokenType.FALSE, parser.parseBooleanLiteral);
        parser.registerPrefix(TokenType.MINUS, parser.parsePrefixExpression);
        parser.registerPrefix(TokenType.BANG, parser.parsePrefixExpression);
        parser.registerPrefix(TokenType.LPAREN, parser.parseGroupedExpression);

        // register infix functions
        parser.registerInfix(TokenType.PLUS, parser.parseInfixExpression);
        parser.registerInfix(TokenType.MINUS, parser.parseInfixExpression);
        parser.registerInfix(TokenType.SLASH, parser.parseInfixExpression);
        parser.registerInfix(TokenType.ASTERISK, parser.parseInfixExpression);
        parser.registerInfix(TokenType.EQUAL, parser.parseInfixExpression);
        parser.registerInfix(TokenType.NOT_EQUAL, parser.parseInfixExpression);
        parser.registerInfix(TokenType.LESS_THAN, parser.parseInfixExpression);
        parser.registerInfix(TokenType.GREATER_THAN, parser.parseInfixExpression);

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
        self.errors.deinit();

        // any dynamically allocated statements or expressions e.g
        // for (self.program.statements.items) |*stmt| {
        // }
    }

    pub fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken() catch unreachable;
    }

    pub fn curTokenIs(self: *Parser, t: TokenType) bool {
        return self.curToken.Type == t;
    }

    pub fn registerPrefix(self: *Parser, tokenType: TokenType, func: PrefixParseFn) void {
        self.prefixParseFns[tokenType] = func;
    }

    pub fn registerInfix(self: *Parser, tokenType: TokenType, func: PrefixParseFn) void {
        self.infixParseFns[tokenType] = func;
    }

    fn precedenceOf(tokenType: TokenType) Precedence {
        return switch (tokenType) {
            .PLUS, .MINUS => .SUM,
            .ASTERISK, .SLASH => .PRODUCT,
            .EQ, .NOT_EQ => .EQUALS,
            .LT, .GT => .LESSGREATER,
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
            self.errors.append(try std.fmt.allocPrint(self.allocator, "Expected next token to be {}, got {} instead", .{ expected, self.peek_token.type }) catch return false);
            return false;
        }
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

    pub fn parseAbegStatement(self: *Parser) ?ast.Statement {
        // Create the AbegStatement node
        var stmt = ast.AbegStatement{
            .token = self.current_token, // The 'abeg' token
            .name = undefined, // Will be set below
            .value = undefined, // Will be set below
            .type_annotation = null, // Default to no type annotation
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
            return null; // Error: Missing identifier
        }

        // Parse the identifier (variable name)
        stmt.name = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

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
                stmt.type_annotation = self.current_token.value; // Set the type annotation
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
        stmt.value = self.parseExpression(.LOWEST);

        // Expect a semicolon at the end of the statement
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken(); // Consume the semicolon
        }

        return stmt;
    }

    pub fn parseComotStatement(self: *Parser) ?ast.Statement {
        // Create the ComotStatement node
        var stmt = &ast.ComotStatement{
            .token = self.current_token, // The 'comot' token
            .value = undefined, // Will be set below
        };

        // Advance to the next token (the return value)
        self.nextToken();

        // Parse the return value expression
        stmt.value = self.parseExpression(.LOWEST);

        // Expect a semicolon at the end of the statement
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken(); // Consume the semicolon
        }

        return stmt;
    }

    pub fn parseExpressionStatement(self: *Parser) ?ast.Statement {
        // Create the ExpressionStatement node
        var stmt = &ast.ExpressionStatement{
            .token = self.current_token, // The first token of the expression
            .expression = undefined, // Will be set below
        };

        // Parse the expression
        stmt.expression = self.parseExpression(.LOWEST);

        // Optionally consume a semicolon (if present)
        if (self.peek_token.type == .SEMICOLON) {
            self.nextToken(); // Consume the semicolon
        }

        return stmt;
    }

    pub fn parseExpression(self: *Parser, precedence: Precedence) *ast.Expression {
        // Get the prefix parsing function for the current token type
        const prefixFn = self.prefixParseFns.get(self.current_token.type) orelse {
            // No prefix function found for this token type
            self.errors.append(std.fmt.allocPrint(self.allocator, "No prefix parse function for {}", .{self.current_token.type}) catch return null);
            return null;
        };

        // Parse the left-hand side of the expression
        var leftExpr = prefixFn(self);

        // Continue parsing while the next token has higher precedence
        while (self.peek_token.type != .SEMICOLON and precedence < self.peekPrecedence()) {
            // Get the infix parsing function for the next token type
            const infixFn = self.infixParseFns.get(self.peek_token.type) orelse {
                // No infix function found for this token type
                return leftExpr;
            };

            // Advance to the next token
            self.nextToken();

            // Parse the right-hand side of the expression
            leftExpr = infixFn(self, leftExpr);
        }

        return leftExpr;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Prefix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    // pub fn parseIdentifier(self: *Parser) *ast.Expression {
    //     return &ast.Identifier{ .token = self.current_token, .value = self.current_token.value };
    // }

    pub fn parseIdentifier(self: *Parser) *ast.Expression {
        const identifier = ast.Identifier{
            .token = self.current_token,
            .value = self.current_token.value,
        };

        // Allocate memory for the Expression union
        const expr = self.allocator.create(ast.Expression) catch unreachable;
        expr.* = .{ .identifier = identifier }; // Wrap the Identifier in an Expression

        return expr;
    }

    pub fn parseIntegerLiteral(self: *Parser) *ast.Expression {
        var lit = &ast.IntegerLiteral{ .token = self.current_token };
        const value = std.fmt.parseInt(i32, self.current_token.value, 10) catch |err| {

            // TODO: change to the proper error message format
            const error_msg = std.fmt.allocPrint(self.allocator, "Error: Failed to parse integer '{}'. Reason: {}\n", .{ self.current_token.value, err }) catch return null;
            self.errors.append(error_msg) catch return null;

            return null;
        };

        lit.value = value;
        return lit;
    }

    pub fn parseStringLiteral(self: *Parser) *ast.Expression {
        return &ast.StringLiteral{ .value = self.current_token.value, .token = self.current_token };
    }

    pub fn parseBooleanLiteral(self: *Parser) *ast.Expression {
        return &ast.BooleanLiteral{ .value = self.current_token.value, .token = self.curTokenIs(TokenType.TRUE) };
    }

    pub fn parseGroupedExpression(self: *Parser) *ast.Expression {
        self.nextToken(); // Consume '('
        const expr = self.parseExpression(.LOWEST);
        if (!self.expectPeek(.RPAREN)) {
            return null; // Error: Missing ')'
        }
        return expr;
    }

    pub fn parsePrefixExpression(self: *Parser) *ast.Expression {
        // Create a PrefixExpression node
        const expr = &ast.PrefixExpression{
            .token = self.current_token, // The prefix token (e.g., '-', '!')
            .operator = self.current_token.value, // The operator (e.g., "-", "!")
            .right = undefined, // Will be set below
        };

        // Advance to the next token (the operand)
        self.nextToken();

        // Parse the right-hand side of the prefix expression
        // Use the lowest precedence to ensure the entire expression is parsed
        expr.right = self.parseExpression(.LOWEST);

        // Return the parsed expression
        return expr;
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Infix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseInfixExpression(self: *Parser, left: ast.Expression) *ast.Expression {
        const expr = &ast.InfixExpression{
            .token = self.current_token,
            .operator = self.current_token.value,
            .left = left,
            .right = undefined, // Will be set below
        };

        const precedence = self.curPrecedence();
        self.nextToken();
        expr.right = self.parseExpression(precedence);

        return expr;
    }
};
