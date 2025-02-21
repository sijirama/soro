const std = @import("std");
const testing = std.testing;
const code = @import("../code/main.zig");
const object = @import("../object/main.zig");
const PrintObject = @import("../object/utils.zig").printObject;
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
        const stackElem = vm.LastPoppedStackElem() orelse return error.StackEmpty;

        try testExpectedObject(test_case.expected, stackElem);
    }
}

test "integer arithmetic" {
    const test_cases = [_]VmTestCase{
        // Basic literals
        .{ .input = "1", .expected = .{ .int = 1 } },
        .{ .input = "2", .expected = .{ .int = 2 } },

        // Addition
        .{ .input = "2 + 1", .expected = .{ .int = 3 } },
        .{ .input = "1 + 2 + 3", .expected = .{ .int = 6 } },
        .{ .input = "10 + 20 + 30", .expected = .{ .int = 60 } },

        // Subtraction
        .{ .input = "5 - 3", .expected = .{ .int = 2 } },
        .{ .input = "10 - 2 - 3", .expected = .{ .int = 5 } },
        .{ .input = "100 - 50 - 25", .expected = .{ .int = 25 } },

        // Multiplication
        .{ .input = "2 * 3", .expected = .{ .int = 6 } },
        .{ .input = "4 * 5 * 2", .expected = .{ .int = 40 } },
        .{ .input = "10 * 0", .expected = .{ .int = 0 } },

        // Division
        .{ .input = "6 / 3", .expected = .{ .int = 2 } },
        .{ .input = "10 / 2 / 5", .expected = .{ .int = 1 } },
        .{ .input = "100 / 10 / 2", .expected = .{ .int = 5 } },

        // Mixed operations
        .{ .input = "2 + 3 * 4", .expected = .{ .int = 14 } },
        .{ .input = "(2 + 3) * 4", .expected = .{ .int = 20 } },
        .{ .input = "10 - 2 * 3", .expected = .{ .int = 4 } },
        .{ .input = "(10 - 2) * 3", .expected = .{ .int = 24 } },
        .{ .input = "20 / 4 + 3", .expected = .{ .int = 8 } },
        .{ .input = "20 / (4 + 1)", .expected = .{ .int = 4 } },

        // Edge cases
        .{ .input = "0 + 0", .expected = .{ .int = 0 } },
        .{ .input = "0 * 100", .expected = .{ .int = 0 } },
        .{ .input = "10 / 1", .expected = .{ .int = 10 } },
        .{ .input = "10 - 10", .expected = .{ .int = 0 } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "float arithmetic" {
    const test_cases = [_]VmTestCase{
        // Basic literals
        .{ .input = "1.0", .expected = .{ .float = 1.0 } },
        .{ .input = "2.5", .expected = .{ .float = 2.5 } },

        // Addition
        .{ .input = "2.5 + 1.5", .expected = .{ .float = 4.0 } },
        .{ .input = "1.2 + 2.3 + 3.4", .expected = .{ .float = 6.9 } },
        .{ .input = "10.5 + 20.5 + 30.5", .expected = .{ .float = 61.5 } },

        // Subtraction
        .{ .input = "5.5 - 3.2", .expected = .{ .float = 2.3 } },
        .{ .input = "10.0 - 2.5 - 3.5", .expected = .{ .float = 4.0 } },
        .{ .input = "100.0 - 50.5 - 25.5", .expected = .{ .float = 24.0 } },

        // Multiplication
        .{ .input = "2.5 * 3.0", .expected = .{ .float = 7.5 } },
        .{ .input = "4.0 * 5.0 * 2.0", .expected = .{ .float = 40.0 } },
        .{ .input = "10.0 * 0.0", .expected = .{ .float = 0.0 } },

        // Division
        .{ .input = "6.0 / 3.0", .expected = .{ .float = 2.0 } },
        .{ .input = "10.0 / 2.0 / 5.0", .expected = .{ .float = 1.0 } },
        .{ .input = "100.0 / 10.0 / 2.0", .expected = .{ .float = 5.0 } },

        // Mixed operations
        .{ .input = "2.0 + 3.0 * 4.0", .expected = .{ .float = 14.0 } },
        .{ .input = "(2.0 + 3.0) * 4.0", .expected = .{ .float = 20.0 } },
        .{ .input = "10.0 - 2.0 * 3.0", .expected = .{ .float = 4.0 } },
        .{ .input = "(10.0 - 2.0) * 3.0", .expected = .{ .float = 24.0 } },
        .{ .input = "20.0 / 4.0 + 3.0", .expected = .{ .float = 8.0 } },
        .{ .input = "20.0 / (4.0 + 1.0)", .expected = .{ .float = 4.0 } },

        // Edge cases
        .{ .input = "0.0 + 0.0", .expected = .{ .float = 0.0 } },
        .{ .input = "0.0 * 100.0", .expected = .{ .float = 0.0 } },
        .{ .input = "10.0 / 1.0", .expected = .{ .float = 10.0 } },
        .{ .input = "10.0 - 10.0", .expected = .{ .float = 0.0 } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "VM: boolean expressions" {
    const test_cases = [_]VmTestCase{
        // Boolean literals
        .{ .input = "true", .expected = .{ .bool = true } },
        .{ .input = "false", .expected = .{ .bool = false } },

        // Negation
        // .{ .input = "!true", .expected = .{ .boolean = false } },
        // .{ .input = "!false", .expected = .{ .boolean = true } },

        // Equality comparisons
        //.{ .input = "true == true", .expected = .{ .boolean = true } },
        //.{ .input = "true == false", .expected = .{ .boolean = false } },
        //.{ .input = "false == false", .expected = .{ .boolean = true } },
        //.{ .input = "false == true", .expected = .{ .boolean = false } },

        // Inequality comparisons
        // .{ .input = "true != true", .expected = .{ .boolean = false } },
        // .{ .input = "true != false", .expected = .{ .boolean = true } },
        // .{ .input = "false != false", .expected = .{ .boolean = false } },
        // .{ .input = "false != true", .expected = .{ .boolean = true } },

        // Logical AND
        // .{ .input = "true && true", .expected = .{ .boolean = true } },
        // .{ .input = "true && false", .expected = .{ .boolean = false } },
        // .{ .input = "false && true", .expected = .{ .boolean = false } },
        // .{ .input = "false && false", .expected = .{ .boolean = false } },

        // Logical OR
        // .{ .input = "true || true", .expected = .{ .boolean = true } },
        // .{ .input = "true || false", .expected = .{ .boolean = true } },
        // .{ .input = "false || true", .expected = .{ .boolean = true } },
        // .{ .input = "false || false", .expected = .{ .boolean = false } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}
