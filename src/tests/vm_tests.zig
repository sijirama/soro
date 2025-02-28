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
        null: void,
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
        .null => |value| {
            const actualNull = actual.Null;
            try testing.expectEqual(value, actualNull);
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
        .{ .input = "!true", .expected = .{ .bool = false } },
        .{ .input = "!!true", .expected = .{ .bool = true } },
        .{ .input = "!false", .expected = .{ .bool = true } },
        .{ .input = "!!false", .expected = .{ .bool = false } },

        // Equality comparisons
        .{ .input = "true == true", .expected = .{ .bool = true } },
        .{ .input = "true == false", .expected = .{ .bool = false } },
        .{ .input = "false == false", .expected = .{ .bool = true } },
        .{ .input = "false == true", .expected = .{ .bool = false } },

        // Inequality comparisons
        .{ .input = "true != true", .expected = .{ .bool = false } },
        .{ .input = "true != false", .expected = .{ .bool = true } },
        .{ .input = "false != false", .expected = .{ .bool = false } },
        .{ .input = "false != true", .expected = .{ .bool = true } },

        // Logical AND
        // .{ .input = "true && true", .expected = .{ .bool = true } },
        // .{ .input = "true && false", .expected = .{ .bool = false } },
        // .{ .input = "false && true", .expected = .{ .bool = false } },
        // .{ .input = "false && false", .expected = .{ .bool = false } },

        // Logical OR
        // .{ .input = "true || true", .expected = .{ .bool = true } },
        // .{ .input = "true || false", .expected = .{ .bool = true } },
        // .{ .input = "false || true", .expected = .{ .bool = true } },
        // .{ .input = "false || false", .expected = .{ .bool = false } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "VM: string operations" {
    const test_cases = [_]VmTestCase{
        // String literals
        //.{ .input = "\"hello\"", .expected = .{ .string = "hello" } },
        //.{ .input = "'abc' > 'ab'", .expected = .{ .bool = true } },
        //.{ .input = "\"\"", .expected = .{ .string = "" } },

        // String concatenation
        //.{ .input = "\"hello\" + \" world\"", .expected = .{ .string = "hello world" } },
        //.{ .input = "\"a\" + \"b\" + \"c\"", .expected = .{ .string = "abc" } },
        //.{ .input = "\"\" + \"test\"", .expected = .{ .string = "test" } },
        //.{ .input = "\"test\" + \"\"", .expected = .{ .string = "test" } },
        //.{ .input = "\"hello\" + \" \" + \"world\"", .expected = .{ .string = "hello world" } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "VM: comparison operations" {
    const test_cases = [_]VmTestCase{
        // Integer comparisons
        .{ .input = "1 < 2", .expected = .{ .bool = true } },
        .{ .input = "2 < 1", .expected = .{ .bool = false } },
        .{ .input = "1 > 2", .expected = .{ .bool = false } },
        .{ .input = "2 > 1", .expected = .{ .bool = true } },
        .{ .input = "1 == 1", .expected = .{ .bool = true } },
        .{ .input = "1 != 1", .expected = .{ .bool = false } },
        .{ .input = "1 == 2", .expected = .{ .bool = false } },
        .{ .input = "1 != 2", .expected = .{ .bool = true } },

        // Float comparisons
        .{ .input = "1.5 < 2.0", .expected = .{ .bool = true } },
        .{ .input = "2.0 < 1.5", .expected = .{ .bool = false } },
        .{ .input = "1.5 > 2.0", .expected = .{ .bool = false } },
        .{ .input = "2.0 > 1.5", .expected = .{ .bool = true } },
        .{ .input = "1.5 == 1.5", .expected = .{ .bool = true } },
        .{ .input = "1.5 != 1.5", .expected = .{ .bool = false } },
        .{ .input = "1.5 == 2.0", .expected = .{ .bool = false } },
        .{ .input = "1.5 != 2.0", .expected = .{ .bool = true } },

        // Mixed number type comparisons
        .{ .input = "1 < 2.5", .expected = .{ .bool = true } },
        .{ .input = "2.5 < 1", .expected = .{ .bool = false } },
        .{ .input = "1 > 2.5", .expected = .{ .bool = false } },
        .{ .input = "2.5 > 1", .expected = .{ .bool = true } },
        .{ .input = "1 == 1.0", .expected = .{ .bool = true } },
        .{ .input = "1 != 1.0", .expected = .{ .bool = false } },
        .{ .input = "1 == 2.0", .expected = .{ .bool = false } },
        .{ .input = "1 != 2.0", .expected = .{ .bool = true } },

        // String comparisons (based on length)
        // .{ .input = "\"abc\" > \"ab\"", .expected = .{ .bool = true } },
        // .{ .input = "\"ab\" < \"abc\"", .expected = .{ .bool = true } },
        // .{ .input = "\"abc\" == \"abc\"", .expected = .{ .bool = true } },
        // .{ .input = "\"abc\" != \"def\"", .expected = .{ .bool = true } },
        // .{ .input = "\"\" == \"\"", .expected = .{ .bool = true } },
        // .{ .input = "\"\" < \"a\"", .expected = .{ .bool = true } },

        // Boolean comparisons
        .{ .input = "true == true", .expected = .{ .bool = true } },
        .{ .input = "false == false", .expected = .{ .bool = true } },
        .{ .input = "true != false", .expected = .{ .bool = true } },
        .{ .input = "false != true", .expected = .{ .bool = true } },
        .{ .input = "true == false", .expected = .{ .bool = false } },
        .{ .input = "false == true", .expected = .{ .bool = false } },

        // Complex expressions
        .{ .input = "(1 < 2) == true", .expected = .{ .bool = true } },
        .{ .input = "(1 > 2) == false", .expected = .{ .bool = true } },
        .{ .input = "(1 == 1) == true", .expected = .{ .bool = true } },
        .{ .input = "(1 != 1) == false", .expected = .{ .bool = true } },
        .{ .input = "(2.5 > 1) == true", .expected = .{ .bool = true } },
        //.{ .input = "(\"abc\" > \"ab\") == true", .expected = .{ .bool = true } },

        // Chained comparisons
        .{ .input = "1 < 2 == true", .expected = .{ .bool = true } },
        .{ .input = "1.5 < 2.0 == true", .expected = .{ .bool = true } },
        //.{ .input = "\"hello\" == \"hello\" == true", .expected = .{ .bool = true } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "Interger Prefix Operations" {
    const test_cases = [_]VmTestCase{
        // Basic literals
        .{ .input = "!1", .expected = .{ .bool = false } },
        .{ .input = "!!1", .expected = .{ .bool = true } },

        .{ .input = "-1", .expected = .{ .int = -1 } },
        .{ .input = "-2", .expected = .{ .int = -2 } },
        .{ .input = "-50 + 100 + -50", .expected = .{ .int = 0 } },
        .{ .input = "(5 + 10 * 2 + 15 / 3) * 2 + -10", .expected = .{ .int = 50 } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "Conditionals" {
    const test_cases = [_]VmTestCase{
        // Basic literals
        .{ .input = "abi (true) {10}", .expected = .{ .int = 10 } },
        .{ .input = "abi ((abi (false) { 10 })) { 10 } naso { 20 }", .expected = .{ .int = 20 } },
        .{ .input = "abi (false) {10}", .expected = .null },
        .{ .input = "abi (0) {10}", .expected = .null },
        .{ .input = "abi (5) {10}", .expected = .{ .int = 10 } },
        .{ .input = "abi (1 > 2) {10}", .expected = .null },
        .{ .input = "!(abi (false) { 5; })", .expected = .{ .bool = true } },
        .{ .input = "abi (true) { 10 } naso { 20 }", .expected = .{ .int = 10 } },
        .{ .input = "abi (false) { 10 } naso { 20 }", .expected = .{ .int = 20 } },
        .{ .input = "abi (1) { 10 } naso { 20 }", .expected = .{ .int = 10 } },
        .{ .input = "abi (1 < 2) { 10 } naso { 20 }", .expected = .{ .int = 10 } },
        .{ .input = "abi (1 > 2) { 10 } naso { 20 }", .expected = .{ .int = 20 } },
        //.{ .input = "abi( \'siji\' ){40}naso{30}", .expected = .{ .int = 40 } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}

test "Gloabal Let Statements" {
    const test_cases = [_]VmTestCase{
        .{ .input = "abeg one = 1; one", .expected = .{ .int = 1 } },
        .{ .input = "abeg one = 1 ; abeg two = 2; one + two", .expected = .{ .int = 3 } },
        .{ .input = "abeg one = 1; abeg two = one + one ; one + two", .expected = .{ .int = 3 } },
    };

    try runVmTests(std.testing.allocator, &test_cases);
}
