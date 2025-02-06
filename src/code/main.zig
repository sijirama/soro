const std = @import("std");

/// A type alias for `u8` to represent a byte.
/// This makes the code more readable and semantically meaningful.
pub const byte = u8;

/// Represents a sequence of instructions as a slice of bytes.
/// Each instruction is encoded as one or more bytes.
pub const InstructionsType = []byte;

/// Represents the type of an opcode.
/// An opcode is a single byte that identifies the operation to be performed.
pub const OpcodeType = byte;

/// Defines the set of opcodes supported by the virtual machine or interpreter.
/// Each opcode is represented as a unique value of type `OpcodeType`.
pub const Opcode = enum(OpcodeType) {
    /// The `OpConstant` opcode is used to load a constant value onto the stack.
    /// It takes one operand, which is a 2-byte index into the constants pool.
    OpConstant,
};

/// Defines the metadata for an opcode, such as its name and operand widths.
/// This is used to decode and execute instructions correctly.
/// The human-readable name of the opcode (e.g., "OpConstant").
/// A slice of bytes representing the widths (in bytes) of each operand.
/// For example, `&[_]u8{2}` means the opcode has one operand that is 2 bytes wide.
const OpcodeDefinition = struct {
    Name: []const u8,
    OperandWidths: []const u8,
};

/// A map that associates each `Opcode` with its corresponding `OpcodeDefinition`.
/// This is used to look up metadata about an opcode at runtime.
pub const definitions = std.EnumMap(Opcode, OpcodeDefinition).init(.{
    .OpConstant = .{
        .Name = "OpConstant",
        .OperandWidths = &[_]u8{2}, // 1 operand, 2 bytes wide
    },
});

/// Looks up the definition of an opcode by its numeric value.
///
/// # Parameters
/// - `op`: The opcode value to look up, of type `OpcodeType`.
///
/// # Returns
/// - `?OpcodeDefinition`: The definition of the opcode if found, or `null` if the opcode is invalid.
pub fn LookUpDefinition(op: OpcodeType) ?OpcodeDefinition {
    return definitions.get(@enumFromInt(op));
}

/// Encodes an opcode and its operands into a byte sequence (instruction).
pub fn MakeInstruction(allocator: std.mem.Allocator, op: Opcode, operands: []const u32) ![]u8 {
    const def = definitions.get(op) orelse return error.InvalidOpcode;

    var instruction_len: usize = 1;

    for (def.OperandWidths) |width| {
        instruction_len += width;
    }

    var instruction = try allocator.alloc(u8, instruction_len);
    errdefer allocator.free(instruction);

    instruction[0] = @intFromEnum(op);

    var offset: usize = 1;

    for (operands, 0..) |operand, i| {
        const width = def.OperandWidths[i];
        switch (width) {
            2 => {
                std.mem.writeInt(u16, instruction[offset..][0..2], @intCast(operand), .big);
            },
            else => return error.UnsupportedOperandWidth,
        }
        offset += width;
    }

    return instruction;
}
