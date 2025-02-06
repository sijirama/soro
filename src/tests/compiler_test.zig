const std = @import("std");
const testing = std.testing;
const code = @import("../code/main.zig");
const object = @import("../object/object.zig");
const compiler = @import("../compiler/main.zig");
const parser = @import("../parser/main.zig");
const lexer = @import("../lexer/main.zig");

const CompilerTestCase = struct {
    input: []const u8,
    expected_constants: []const ExpectedConstant,
    expected_instructions: []const []const u8,
};

const ExpectedConstant = union(enum) {
    integer: i64,
    float: f64,
    boolean: bool,
    string: []const u8,
};

fn parse(input: []const u8, allocator: std.mem.Allocator) !parser.ast.Program {
    var l = lexer.Lexer.init(input);
    var p = try parser.Parser.init(&l, allocator);
    defer p.deinit();
    return p.parseProgram();
}

fn testInstructions(
    expected: []const []const u8,
    actual: []const u8,
) !void {
    var total_length: usize = 0;
    for (expected) |ins| {
        total_length += ins.len;
    }

    if (total_length != actual.len) {
        std.debug.print("\nwrong instructions length.\nwant={d}\ngot ={d}\n", .{
            total_length,
            actual.len,
        });
        return error.InstructionLengthMismatch;
    }

    var offset: usize = 0;
    for (expected) |ins| {
        for (ins, 0..) |b, i| {
            if (actual[offset + i] != b) {
                std.debug.print("\nwrong instruction at {d}.\nwant={d}\ngot ={d}\n", .{
                    offset + i,
                    b,
                    actual[offset + i],
                });
                return error.InstructionMismatch;
            }
        }
        offset += ins.len;
    }
}

fn testConstants(
    expected: []const ExpectedConstant,
    actual: []const object.Object,
) !void {
    if (expected.len != actual.len) {
        return error.ConstantLengthMismatch;
    }

    for (expected, actual) |exp, act| {
        switch (exp) {
            .integer => |int_val| {
                switch (act) {
                    .Integer => |obj| {
                        try testing.expectEqual(int_val, obj.value);
                    },
                    else => return error.WrongConstantType,
                }
            },
            .float => |float_val| {
                switch (act) {
                    .Float => |obj| {
                        try testing.expectEqual(float_val, obj.value);
                    },
                    else => return error.WrongConstantType,
                }
            },
            .boolean => |bool_val| {
                switch (act) {
                    .Boolean => |obj| {
                        try testing.expectEqual(bool_val, obj.value);
                    },
                    else => return error.WrongConstantType,
                }
            },
            .string => |str_val| {
                switch (act) {
                    .String => |obj| {
                        try testing.expectEqualStrings(str_val, obj.value);
                    },
                    else => return error.WrongConstantType,
                }
            },
        }
    }
}

fn runCompilerTests(allocator: std.mem.Allocator, test_cases: []const CompilerTestCase) !void {
    for (test_cases) |test_case| {
        var program = try parse(test_case.input, allocator);
        defer program.deinit();

        var comp = compiler.Compiler.init(allocator);
        defer comp.deinit();

        try comp.compile(program);

        var bytecode = try comp.bytecode();
        defer bytecode.deinit();

        try testInstructions(test_case.expected_instructions, bytecode.instructions);
        try testConstants(test_case.expected_constants, bytecode.constants);
    }
}

test "integer arithmetic" {
    const allocator = testing.allocator;

    // Helper to create instructions
    const make = code.MakeInstruction;

    const test_cases = [_]CompilerTestCase{
        .{
            .input = "1 + 2",
            .expected_constants = &[_]ExpectedConstant{
                .{ .integer = 1 },
                .{ .integer = 2 },
            },
            .expected_instructions = &[_][]const u8{
                try make(allocator, .OpConstant, &[_]u32{0}),
                try make(allocator, .OpConstant, &[_]u32{1}),
            },
        },
    };

    try runCompilerTests(allocator, &test_cases);
}
