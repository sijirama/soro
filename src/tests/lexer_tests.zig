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
