const std = @import("std");
const testing = std.testing;
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const Type = @import("../type/types.zig").Type;
const TypetoString = @import("../type/types.zig").typeToString;
const ast = @import("../ast/ast.zig");

fn createToken(type_val: TokenType, value: []const u8, line: usize, column: usize, fileName: []const u8, fileDirectory: []const u8) Token {
    return Token{
        .type = type_val,
        .value = value,
        .line = line,
        .column = column,
        .fileName = fileName,
        .fileDirectory = fileDirectory,
    };
}

test "Identifier token literal" {
    const identifier = ast.Identifier{ .token = createToken(.IDENT, "myVariable", 1, 1, "test.zig", "/test/path"), .value = "myVariable" };

    try testing.expectEqualStrings("myVariable", identifier.tokenLiteral());
}

test "AbegStatement creation" {
    const allocator = testing.allocator;

    const int_expr = try allocator.create(ast.Expression);

    int_expr.* = .{ .integer_literal = ast.IntegerLiteral{ .token = createToken(.INTEGER, "5", 1, 1, "test.zig", "/test/path"), .value = 5 } };

    const abeg_stmt = ast.AbegStatement{ .token = createToken(.ABEG, "abeg", 1, 1, "test.zig", "/test/path"), .name = ast.Identifier{ .token = createToken(.IDENT, "x", 1, 1, "test.zig", "/test/path"), .value = "x" }, .value = int_expr, .is_locked = false, .is_inferred = false };

    try testing.expectEqualStrings("abeg", abeg_stmt.tokenLiteral());
    try testing.expect(!abeg_stmt.is_locked);
    try testing.expect(!abeg_stmt.is_inferred);

    defer allocator.destroy(int_expr);
}

test "Type Annotation in AbegStatement" {
    const allocator = testing.allocator;
    const int_expr = try allocator.create(ast.Expression);
    int_expr.* = .{ .integer_literal = ast.IntegerLiteral{ .token = createToken(.INTEGER, "42", 1, 1, "test.zig", "/test/path"), .value = 42 } };
    //const type_annotation = Type.fromTokenType(.INTEGER_TYPE);
    const abeg_stmt = ast.AbegStatement{ .token = createToken(.ABEG, "abeg", 1, 1, "test.zig", "/test/path"), .name = ast.Identifier{ .token = createToken(.IDENT, "age", 1, 1, "test.zig", "/test/path"), .value = "age" }, .value = int_expr, .type_annotation = Type.Int };
    try testing.expect(abeg_stmt.type_annotation != null);
    try testing.expectEqualStrings("int", TypetoString(abeg_stmt.type_annotation.?));
    defer allocator.destroy(int_expr);
}

test "Expression Union token literal" {
    const allocator = testing.allocator;

    // Integer Literal Expression
    var int_expr = try allocator.create(ast.Expression);
    int_expr.* = .{ .integer_literal = ast.IntegerLiteral{ .token = createToken(.INTEGER, "42", 1, 1, "test.zig", "/test/path"), .value = 42 } };
    try testing.expectEqualStrings("42", int_expr.tokenLiteral());

    // Identifier Expression
    var ident_expr = try allocator.create(ast.Expression);
    ident_expr.* = .{ .identifier = ast.Identifier{ .token = createToken(.IDENT, "myVar", 1, 1, "test.zig", "/test/path"), .value = "myVar" } };
    try testing.expectEqualStrings("myVar", ident_expr.tokenLiteral());

    defer allocator.destroy(int_expr);
    defer allocator.destroy(ident_expr);
}

test "Prefix Expression Creation" {
    const allocator = testing.allocator;

    const right_expr = try allocator.create(ast.Expression);
    right_expr.* = .{ .integer_literal = ast.IntegerLiteral{ .token = createToken(.INTEGER, "5", 1, 1, "test.zig", "/test/path"), .value = 5 } };

    const prefix_expr = ast.PrefixExpression{ .token = createToken(.MINUS, "-", 1, 1, "test.zig", "/test/path"), .operator = "-", .right = right_expr };

    try testing.expectEqualStrings("-", prefix_expr.tokenLiteral());
    defer allocator.destroy(right_expr);
}
