const std = @import("std");
const testing = std.testing;
const code = @import("../code/main.zig");
const object = @import("../object/main.zig");
const compiler = @import("../compiler/main.zig");
const parser = @import("../parser/main.zig");
const lexer = @import("../lexer/main.zig");
const ast = @import("../ast/ast.zig");

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

fn parse(input: []const u8, allocator: std.mem.Allocator) !ast.Program {
    var l = lexer.Lexer.init(allocator, input, "repl", "repl");
    var p = parser.Parser.init(allocator, &l);
    defer p.deinit();
    return p.parseProgram();
}

fn testInstructions(allocator: std.mem.Allocator, expected: []const []const u8, actual: []const u8) !void {
    var total_length: usize = 0;
    for (expected) |ins| {
        total_length += ins.len;
    }

    // Concatenate expected instructions
    var expected_concatenated = try allocator.alloc(u8, total_length);
    defer allocator.free(expected_concatenated);

    var offset: usize = 0;
    for (expected) |ins| {
        @memcpy(expected_concatenated[offset..][0..ins.len], ins);
        offset += ins.len;
    }

    // Get instruction strings and handle their memory
    const actual_str = try code.instructionsToString(actual, allocator);
    defer allocator.free(actual_str);
    const expected_str = try code.instructionsToString(expected_concatenated, allocator);
    defer allocator.free(expected_str);

    // Now print the strings
    // std.debug.print("\nInstruction String (Expected):\n{s}\n", .{expected_str});
    // std.debug.print("\nInstruction String (Actual):\n{s}\n", .{actual_str});

    if (total_length != actual.len) {

        // Convert both to readable format for comparison
        std.debug.print(
            \\
            \\wrong instructions length
            \\want:
            \\{s}
            \\got:
            \\{s}
            \\
            \\Raw bytes:
            \\want: {any}
            \\got:  {any}
            \\
        , .{
            expected_str,
            actual_str,
            std.fmt.fmtSliceHexUpper(expected_concatenated),
            std.fmt.fmtSliceHexUpper(actual),
        });
        return error.InstructionLengthMismatch;
    }

    // Check byte by byte
    for (expected_concatenated, 0..) |b, i| {
        if (actual[i] != b) {
            const expected_str2 = try code.instructionsToString(expected_concatenated, allocator);
            defer allocator.free(expected_str);
            const actual_str2 = try code.instructionsToString(actual, allocator);
            defer allocator.free(actual_str);

            std.debug.print(
                \\
                \\wrong instruction at position {d}
                \\want:
                \\{s}
                \\got:
                \\{s}
                \\
                \\Raw bytes:
                \\want: {any}
                \\got:  {any}
                \\
            , .{
                i,
                expected_str2,
                actual_str2,
                std.fmt.fmtSliceHexUpper(expected_concatenated),
                std.fmt.fmtSliceHexUpper(actual),
            });
            return error.InstructionMismatch;
        }
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

        try testInstructions(allocator, test_case.expected_instructions, bytecode.Instructions);
        try testConstants(test_case.expected_constants, bytecode.Constants);
    }
}

test "Compiler: integer arithmetic" {
    const allocator = testing.allocator;

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

    // Free the test case instructions
    defer for (test_cases) |test_case| {
        for (test_case.expected_instructions) |instruction| {
            allocator.free(instruction);
        }
    };

    try runCompilerTests(allocator, &test_cases);
}

// Add this to your test file:
test "Compiler: instructions to string" {
    const allocator = std.testing.allocator;

    // Create test instructions
    const ins1 = try code.MakeInstruction(allocator, .OpConstant, &[_]u32{1});
    defer allocator.free(ins1);
    const ins2 = try code.MakeInstruction(allocator, .OpConstant, &[_]u32{2});
    defer allocator.free(ins2);
    const ins3 = try code.MakeInstruction(allocator, .OpConstant, &[_]u32{65535});
    defer allocator.free(ins3);

    // Concatenate instructions
    const total_len = ins1.len + ins2.len + ins3.len;
    var concatted = try allocator.alloc(u8, total_len);
    defer allocator.free(concatted);

    @memcpy(concatted[0..ins1.len], ins1);
    @memcpy(concatted[ins1.len..][0..ins2.len], ins2);
    @memcpy(concatted[ins1.len + ins2.len ..][0..ins3.len], ins3);

    // Generate string representation
    const result = try code.instructionsToString(concatted, allocator);
    defer allocator.free(result);

    const expected =
        \\0000 OpConstant 1
        \\0003 OpConstant 2
        \\0006 OpConstant 65535
        \\
    ;

    try std.testing.expectEqualStrings(expected, result);
}
