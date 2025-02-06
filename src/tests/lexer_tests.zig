const std = @import("std");
const testing = std.testing;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const Lexer = @import("../lexer/main.zig").Lexer;
const LexerError = @import("../lexer/error.zig").LexerError;

// Helper function to create a lexer for testing
fn createTestLexer(allocator: std.mem.Allocator, input: []const u8) Lexer {
    return Lexer.init(allocator, input, "test.soro", ".");
}

// Any leaks will be reported
test "Lexer: memory leak check" {
    const testing_allocator = std.testing.allocator;
    var lexer = Lexer.init(testing_allocator, "\"hello\"", "test", ".");
    defer lexer.deinit();
}

// Test basic tokenization
test "Lexer: basic tokens" {
    const input = "+ \"hello\"";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    // Check the first token (PLUS)
    try testing.expectEqual(tokens[0].type, TokenType.PLUS);
    try testing.expectEqualStrings(tokens[0].value, "+");

    // Check the second token (STRING)
    try testing.expectEqual(tokens[1].type, TokenType.STRING);
    try testing.expectEqualStrings(tokens[1].value, "hello");
}

// Test whitespace skipping
test "Lexer: whitespace skipping" {
    const input = "  \t\n+";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(tokens.len, 2); // plus and eof

    // Check the token (PLUS)
    try testing.expectEqual(tokens[0].type, TokenType.PLUS);
    try testing.expectEqualStrings(tokens[0].value, "+");
}

// Test string tokenization with escape sequences
test "Lexer: string with escape sequences" {
    const input = "\"hello\nworld\"";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();
    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    // Check the token (STRING)
    try testing.expectEqual(tokens[0].type, TokenType.STRING);
    try testing.expectEqualStrings(tokens[0].value, "hello\nworld");
}

// Test EOF token
test "Lexer: EOF token" {
    const input = "";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    // Check the token (EOF)
    try testing.expectEqual(tokens[0].type, TokenType.EOF);
    try testing.expectEqualStrings(tokens[0].value, "");
}

test "Lexer: integer tokens" {
    const input = "123 0 - 456";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    try testing.expectEqual(tokens[0].type, TokenType.INTEGER);
    try testing.expectEqualStrings(tokens[0].value, "123");

    try testing.expectEqual(tokens[1].type, TokenType.INTEGER);
    try testing.expectEqualStrings(tokens[1].value, "0");

    try testing.expectEqual(tokens[2].type, TokenType.MINUS);
    try testing.expectEqualStrings(tokens[2].value, "-");

    try testing.expectEqual(tokens[3].type, TokenType.INTEGER);
    try testing.expectEqualStrings(tokens[3].value, "456");
}

test "Lexer: comments" {
    const input =
        \\// This is a single-line comment
        \\/* This is a
        \\   multi-line comment */
        \\42 // Another single-line comment
    ;
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    // Check the tokens
    try testing.expectEqual(tokens[0].type, TokenType.COMMENT);
    try testing.expectEqualStrings(tokens[0].value, " This is a single-line comment");

    try testing.expectEqual(tokens[1].type, TokenType.COMMENT);
    try testing.expectEqualStrings(tokens[1].value, " This is a\n   multi-line comment ");

    try testing.expectEqual(tokens[2].type, TokenType.INTEGER);
    try testing.expectEqualStrings(tokens[2].value, "42");

    try testing.expectEqual(tokens[3].type, TokenType.COMMENT);
    try testing.expectEqualStrings(tokens[3].value, " Another single-line comment");
}

test "Lexer: Final Test" {

    // Note: Using \\ for line continuations in Zig multiline strings
    const input =
        \\abeg five int = 5;
        \\abeg ten = 10;
        \\oya add (x int, y int) : int {
        \\    comot x + y;
        \\}
        \\abeg result int = add (5, 10);
        \\!-/ or *5;
        \\5 < 10 > 5;
        \\if (5 < 10) {
        \\    comot true;
        \\} else {
        \\    comot false;
        \\}
        \\10 == 10;
        \\10 != 9;
        \\"foobar"
        \\"foo bar"
        \\5
        \\10
        \\[1, 2];
        \\{"foo": "bar"}
        \\abeg married bool = false;
        \\abeg grade float = 95.5;
        \\abeg name string = "John";
        \\abeg anyvalue any = 42;
        \\abeg err error = "oops";
        \\if (x < 5 and y > 10) {
        \\    comot true;
        \\}
        \\abeg result = x or y orelse 42;
        \\oya printName(name string) : void {
        \\    comot;
        \\}
        \\abeg stuff interface = {};
        \\abeg numbers = [1.5, 2.5, 3.5];
        \\//fuck everyone for realll
    ;

    const TestToken = struct {
        expected_type: TokenType,
        expected_literal: []const u8,
    };

    const test_tokens = [_]TestToken{

        //abeg five int = 5;
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "five" },
        .{ .expected_type = .TYPE, .expected_literal = "int" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // abeg ten = 10;
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "ten" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // function details
        .{ .expected_type = .OYA, .expected_literal = "oya" },
        .{ .expected_type = .IDENT, .expected_literal = "add" },
        .{ .expected_type = .LPAREN, .expected_literal = "(" },
        .{ .expected_type = .IDENT, .expected_literal = "x" },
        .{ .expected_type = .TYPE, .expected_literal = "int" },
        .{ .expected_type = .COMMA, .expected_literal = "," },
        .{ .expected_type = .IDENT, .expected_literal = "y" },
        .{ .expected_type = .TYPE, .expected_literal = "int" },
        .{ .expected_type = .RPAREN, .expected_literal = ")" },
        .{ .expected_type = .COLON, .expected_literal = ":" },
        .{ .expected_type = .TYPE, .expected_literal = "int" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .COMOT, .expected_literal = "comot" },
        .{ .expected_type = .IDENT, .expected_literal = "x" },
        .{ .expected_type = .PLUS, .expected_literal = "+" },
        .{ .expected_type = .IDENT, .expected_literal = "y" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },

        // abeg result int = add(5,10);
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "result" },
        .{ .expected_type = .TYPE, .expected_literal = "int" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .IDENT, .expected_literal = "add" },
        .{ .expected_type = .LPAREN, .expected_literal = "(" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .COMMA, .expected_literal = "," },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .RPAREN, .expected_literal = ")" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // bunch of tokens to test
        .{ .expected_type = .BANG, .expected_literal = "!" },
        .{ .expected_type = .MINUS, .expected_literal = "-" },
        .{ .expected_type = .SLASH, .expected_literal = "/" },
        .{ .expected_type = .OR, .expected_literal = "or" },
        .{ .expected_type = .ASTERISK, .expected_literal = "*" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .LESS_THAN, .expected_literal = "<" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .GREATER_THAN, .expected_literal = ">" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // if logic
        .{ .expected_type = .IF, .expected_literal = "if" },
        .{ .expected_type = .LPAREN, .expected_literal = "(" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .LESS_THAN, .expected_literal = "<" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .RPAREN, .expected_literal = ")" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .COMOT, .expected_literal = "comot" },
        .{ .expected_type = .TRUE, .expected_literal = "true" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },
        .{ .expected_type = .ELSE, .expected_literal = "else" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .COMOT, .expected_literal = "comot" },
        .{ .expected_type = .FALSE, .expected_literal = "false" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },

        // comparision logic
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .EQUAL, .expected_literal = "==" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .NOT_EQUAL, .expected_literal = "!=" },
        .{ .expected_type = .INTEGER, .expected_literal = "9" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // test strings
        .{ .expected_type = .STRING, .expected_literal = "foobar" },
        .{ .expected_type = .STRING, .expected_literal = "foo bar" },

        // test numbers
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },

        // arrays
        .{ .expected_type = .LBRACKET, .expected_literal = "[" },
        .{ .expected_type = .INTEGER, .expected_literal = "1" },
        .{ .expected_type = .COMMA, .expected_literal = "," },
        .{ .expected_type = .INTEGER, .expected_literal = "2" },
        .{ .expected_type = .RBRACKET, .expected_literal = "]" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // key value pairs
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .STRING, .expected_literal = "foo" },
        .{ .expected_type = .COLON, .expected_literal = ":" },
        .{ .expected_type = .STRING, .expected_literal = "bar" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },

        // abeg married bool = false;
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "married" },
        .{ .expected_type = .TYPE, .expected_literal = "bool" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .FALSE, .expected_literal = "false" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // New tokens for additional types
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "grade" },
        .{ .expected_type = .TYPE, .expected_literal = "float" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .FLOAT, .expected_literal = "95.5" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "name" },
        .{ .expected_type = .TYPE, .expected_literal = "string" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .STRING, .expected_literal = "John" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "anyvalue" },
        .{ .expected_type = .TYPE, .expected_literal = "any" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .INTEGER, .expected_literal = "42" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "err" },
        .{ .expected_type = .TYPE, .expected_literal = "error" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .STRING, .expected_literal = "oops" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // Testing logical operators
        .{ .expected_type = .IF, .expected_literal = "if" },
        .{ .expected_type = .LPAREN, .expected_literal = "(" },
        .{ .expected_type = .IDENT, .expected_literal = "x" },
        .{ .expected_type = .LESS_THAN, .expected_literal = "<" },
        .{ .expected_type = .INTEGER, .expected_literal = "5" },
        .{ .expected_type = .AND, .expected_literal = "and" },
        .{ .expected_type = .IDENT, .expected_literal = "y" },
        .{ .expected_type = .GREATER_THAN, .expected_literal = ">" },
        .{ .expected_type = .INTEGER, .expected_literal = "10" },
        .{ .expected_type = .RPAREN, .expected_literal = ")" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .COMOT, .expected_literal = "comot" },
        .{ .expected_type = .TRUE, .expected_literal = "true" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },

        // Testing or and or_else
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "result" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .IDENT, .expected_literal = "x" },
        .{ .expected_type = .OR, .expected_literal = "or" },
        .{ .expected_type = .IDENT, .expected_literal = "y" },
        .{ .expected_type = .OR_ELSE, .expected_literal = "orelse" },
        .{ .expected_type = .INTEGER, .expected_literal = "42" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // Testing void return type
        .{ .expected_type = .OYA, .expected_literal = "oya" },
        .{ .expected_type = .IDENT, .expected_literal = "printName" },
        .{ .expected_type = .LPAREN, .expected_literal = "(" },
        .{ .expected_type = .IDENT, .expected_literal = "name" },
        .{ .expected_type = .TYPE, .expected_literal = "string" },
        .{ .expected_type = .RPAREN, .expected_literal = ")" },
        .{ .expected_type = .COLON, .expected_literal = ":" },
        .{ .expected_type = .TYPE, .expected_literal = "void" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .COMOT, .expected_literal = "comot" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },

        // Testing interface type
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "stuff" },
        .{ .expected_type = .TYPE, .expected_literal = "interface" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .LBRACE, .expected_literal = "{" },
        .{ .expected_type = .RBRACE, .expected_literal = "}" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },

        // Testing float array
        .{ .expected_type = .ABEG, .expected_literal = "abeg" },
        .{ .expected_type = .IDENT, .expected_literal = "numbers" },
        .{ .expected_type = .ASSIGN, .expected_literal = "=" },
        .{ .expected_type = .LBRACKET, .expected_literal = "[" },
        .{ .expected_type = .FLOAT, .expected_literal = "1.5" },
        .{ .expected_type = .COMMA, .expected_literal = "," },
        .{ .expected_type = .FLOAT, .expected_literal = "2.5" },
        .{ .expected_type = .COMMA, .expected_literal = "," },
        .{ .expected_type = .FLOAT, .expected_literal = "3.5" },
        .{ .expected_type = .RBRACKET, .expected_literal = "]" },
        .{ .expected_type = .SEMICOLON, .expected_literal = ";" },
        .{ .expected_type = .COMMENT, .expected_literal = "fuck everyone for realll" },

        .{ .expected_type = .EOF, .expected_literal = "" },
    };

    const allocator = testing.allocator;
    var lexer = createTestLexer(allocator, input);
    defer lexer.deinit();
    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    for (test_tokens, 0..) |expected_token, i| {
        try testing.expectEqual(
            expected_token.expected_type,
            tokens[i].type,
        );
        try testing.expectEqualStrings(
            expected_token.expected_literal,
            tokens[i].value,
        );
    }
}
