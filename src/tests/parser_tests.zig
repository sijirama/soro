const std = @import("std");
const testing = std.testing;
const Lexer = @import("../lexer/main.zig").Lexer;
const Parser = @import("../parser/main.zig").Parser;
const ast = @import("../ast/ast.zig");

fn createTestLexer(allocator: std.mem.Allocator, input: []const u8) Lexer {
    return Lexer.init(allocator, input, "test.soro", ".");
}

fn parseInput(allocator: std.mem.Allocator, input: []const u8) !ast.Program {
    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    var parser = Parser.init(allocator, &lexer);
    defer {
        parser.deinit();
        lexer.deinit();
    }

    return try parser.parseProgram();
}

// test "Parser: prefix expressions 2" {
//     const input = "-5;";
//     const allocator = std.testing.allocator;
//
//     var program = try parseInput(allocator, input);
//     defer program.deinit();
//
//     try testing.expectEqual(program.statements.items.len, 1);
//     std.debug.print("{s}", .{program.statements.items[0].tokenLiteral()});
//     std.debug.print("\n There are {} statements", .{program.statements.items.len});
//     std.debug.print("{s}", .{program.statements.items[0].expression_statement.expression.tokenLiteral()});
// }
