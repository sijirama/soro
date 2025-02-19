const std = @import("std");
const testing = std.testing;
const code = @import("../code/main.zig");
const object = @import("../object/main.zig");
const compiler = @import("../compiler/main.zig");
const parser = @import("../parser/main.zig");
const lexer = @import("../lexer/main.zig");
const ast = @import("../ast/ast.zig");
const VM = @import("../vm/main.zig").VM;

const VmTestCase = struct {
    input: []const u8,
    expected: union(enum) {
        int: i64,
        float: f64,
        bool: bool,
        string: []const u8,
    },
};

fn testExpectedObject(expected: anytype, actual: object.Object) !void {
    switch (expected) {
        .int => |value| {
            const actualInt = actual.Integer;
            try testing.expectEqual(value, actualInt.value);
        },
        .float => |value| {
            const actualFloat = actual.Float;
            try testing.expectEqual(value, actualFloat.value);
        },
        .bool => |value| {
            const actualBool = actual.Boolean;
            try testing.expectEqual(value, actualBool.value);
        },
        .string => |value| {
            const actualString = actual.String;
            try testing.expectEqualStrings(value, actualString.value);
        },
    }
}

fn runVmTests(allocator: std.mem.Allocator, test_cases: []const VmTestCase) !void {
    for (test_cases) |test_case| {

        //
        var l = lexer.Lexer.init(allocator, test_case.input, "repl", "repl");
        var p = parser.Parser.init(allocator, &l);
        defer p.deinit();

        var program = try p.parseProgram();

        defer program.deinit();

        var comp = compiler.Compiler.init(allocator);
        defer comp.deinit();

        try comp.compile(program);
        const bytecode = try comp.bytecode();

        defer {
            bytecode.deinit();
            allocator.destroy(bytecode);
        }

        var vm = VM.init(allocator, bytecode);
        defer vm.deinit(allocator);

        try vm.run();
        const stackElem = vm.stackTop() orelse return error.StackEmpty;

        try testExpectedObject(test_case.expected, stackElem);
    }
}

test "integer arithmetic" {
    const test_cases = [_]VmTestCase{
        .{ .input = "1", .expected = .{ .int = 1 } },
        .{ .input = "2", .expected = .{ .int = 2 } },
        .{ .input = "1 + 2 + 3", .expected = .{ .int = 3 } }, // FIXME: This will fail until you implement addition
    };

    try runVmTests(std.testing.allocator, &test_cases);
}
