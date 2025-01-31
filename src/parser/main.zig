const std = @import("std");
const Lexer = @import("../lexer/main.zig").Lexer;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const ast = @import("../ast/ast.zig");

const PrefixParseFn = *const fn (p: *Parser) ast.Expression;
const InfixParseFn = *const fn (p: *Parser, left: ast.Expression) ast.Expression;

pub const Parser = struct {
    lexer: *Lexer,
    allocator: std.mem.Allocator,

    current_token: Token,
    peek_token: Token,

    errors: std.ArrayList([]const u8), // TODO: change this to ParserError

    prefixParseFns: std.AutoHashMap(TokenType, *const fn (p: *Parser) ast.Expression),
    infixParseFns: std.AutoHashMap(TokenType, *const fn (p: *Parser, left: ast.Expression) ast.Expression),

    pub fn init(allocator: std.mem.Allocator, lexer: *Lexer) Parser {

        // initialize the parser
        var parser = Parser{
            .lexer = lexer,
            .current_token = undefined,
            .peek_token = undefined,
            .allocator = allocator,
            .errors = std.ArrayList([]const u8).init(allocator),

            // .prefixParseFns = std.AutoHashMap(TokenType, *const fn (p: *Parser) ast.Expression).init(allocator),
            // .infixParseFns = std.AutoHashMap(TokenType, *const fn (p: *Parser, left: ast.Expression) ast.Expression).init(allocator),

            .prefixParseFns = std.AutoHashMap(TokenType, PrefixParseFn).init(allocator),
            .infixParseFns = std.AutoHashMap(TokenType, InfixParseFn).init(allocator),
        };

        // register prefix functions
        parser.registerPrefix(TokenType.IDENT, parser.parseIdentifier());
        parser.registerPrefix(TokenType.INTEGER, parser.parseIntegerLiteral());
        parser.registerPrefix(TokenType.STRING, parser.parseStringLiteral());
        parser.registerPrefix(TokenType.TRUE, parser.parseBooleanLiteral());
        parser.registerPrefix(TokenType.FALSE, parser.parseBooleanLiteral());

        // register infix functions

        // Advance tokens to set current and peek
        parser.nextToken();
        parser.nextToken();

        // return the parser
        return parser;
    }

    pub fn deinit(self: *Parser) void {
        self.errors.deinit();

        // any dynamically allocated statements or expressions e.g
        // for (self.program.statements.items) |*stmt| {
        // }
    }

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

    pub fn nextToken(self: *Parser) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
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

    pub fn parseStatement(self: *Parser) ?ast.Statement {
        return switch (self.current_token.type) {
            .ABEG => self.parseAbegStatement(),
            .COMOT => self.parseReturnStatement(),
            else => self.parseExpressionStatement(),
        };
    }

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Prefix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

    pub fn parseIdentifier(self: *Parser) *ast.Expression {
        return &ast.Identifier{ .token = self.current_token, .value = self.current_token.value };
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

    //-------------------------------------------------------------------------------------------------------------------------------------------------------
    // Infix Functions
    //-------------------------------------------------------------------------------------------------------------------------------------------------------

};
