const std = @import("std");
const expect = std.testing.expect;
const code = @import("../code/main.zig");

test "LookUpDefinition should return the correct definition for a valid opcode" {
    // Test for a valid opcode
    const op = code.Opcode.OpConstant;

    const def = code.LookUpDefinition(@intFromEnum(op));

    // Ensure the definition is not null
    try expect(def != null);

    // Check the details of the definition
    if (def) |d| {
        try expect(std.mem.eql(u8, d.Name, "OpConstant")); // Fixed field name (Name instead of name)
        try expect(d.OperandWidths.len == 1);
        try expect(d.OperandWidths[0] == 2);
    }
}

test "Make should encode OpConstant and its operand correctly" {
    const op = code.Opcode.OpConstant;
    const operands = [_]u32{65534};
    const expected = [_]u8{ @intFromEnum(op), 255, 254 };

    const instruction = try code.MakeInstruction(std.testing.allocator, op, &operands);
    defer std.testing.allocator.free(instruction);

    try expect(instruction.len == expected.len);

    for (instruction, 0..) |byte, i| {
        try expect(byte == expected[i]);
    }
}
