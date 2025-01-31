const std = @import("std");
const testing = std.testing;
const Lexer = @import("../lexer/main.zig").Lexer;
const Parser = @import("../parser/main.zig").Parser;
const ast = @import("../ast/ast.zig");

fn createTestLexer(allocator: std.mem.Allocator, input: []const u8) Lexer {
    return Lexer.init(allocator, input, "test.soro", ".");
}

test "Parser: prefix expressions" {
    const input = "-5; !true;";
    const allocator = std.testing.allocator;
    var lexer = createTestLexer(allocator, input);
    var parser = Parser.init(testing.allocator, &lexer);
    defer {
        parser.deinit(); // Deinitialize the parser
        lexer.deinit(); // Deinitialize the lexer
    }

    const program = try parser.parseProgram();

    try testing.expectEqual(program.statements.items.len, 2);

    // Test the first statement: -5
    const stmt1 = program.statements.items[0];
    try testing.expectEqual(stmt1, .expression_statement);
    const expr1 = stmt1.expression_statement.expression;
    try testing.expectEqual(expr1, .prefix_expression);
    try testing.expectEqualStrings(expr1.prefix_expression.operator, "-");
    try testing.expectEqual(expr1.prefix_expression.right, .integer_literal);
    try testing.expectEqual(expr1.prefix_expression.right.integer_literal.value, 5);

    // Test the second statement: !true
    const stmt2 = program.statements.items[1];
    try testing.expectEqual(stmt2, .expression_statement);
    const expr2 = stmt2.expression_statement.expression;
    try testing.expectEqual(expr2, .prefix_expression);
    try testing.expectEqualStrings(expr2.prefix_expression.operator, "!");
    try testing.expectEqual(expr2.prefix_expression.right, .boolean_literal);
    try testing.expectEqual(expr2.prefix_expression.right.boolean_literal.value, true);
}
