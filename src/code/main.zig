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
    OpPop,

    // binary operations
    OpAdd,
    OpSub,
    OpMul,
    OpDiv,

    OpEqual,
    OpNotEqual,
    OpGreaterThan,
    OpLessThan,

    // unary operations
    OpMinus,
    OpBang,

    // booleans
    OpTrue,
    OpFalse,

    // jump
    OpJumpNotTruthy,
    OpJump,

    OpNull,

    // bindings bitch
    OpGetGlobal,
    OpSetGlobal,

    OpArray,
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

    // 1 operand, 2 bytes wide
    .OpConstant = .{ .Name = "OpConstant", .OperandWidths = &[_]u8{2} },

    .OpPop = .{ .Name = "OpPop", .OperandWidths = &[_]u8{} },

    .OpAdd = .{ .Name = "OpAdd", .OperandWidths = &[_]u8{} },
    .OpSub = .{ .Name = "OpSub", .OperandWidths = &[_]u8{} },
    .OpMul = .{ .Name = "OpMul", .OperandWidths = &[_]u8{} },
    .OpDiv = .{ .Name = "OpDiv", .OperandWidths = &[_]u8{} },

    .OpEqual = .{ .Name = "OpEqual", .OperandWidths = &[_]u8{} },
    .OpNotEqual = .{ .Name = "OpNotEqual", .OperandWidths = &[_]u8{} },

    .OpGreaterThan = .{ .Name = "OpGreaterThan", .OperandWidths = &[_]u8{} },
    .OpLessThan = .{ .Name = "OpLessThan", .OperandWidths = &[_]u8{} },

    .OpMinus = .{ .Name = "OpMinus", .OperandWidths = &[_]u8{} },
    .OpBang = .{ .Name = "OpBang", .OperandWidths = &[_]u8{} },

    .OpTrue = .{ .Name = "OpTrue", .OperandWidths = &[_]u8{} },
    .OpFalse = .{ .Name = "OpFalse", .OperandWidths = &[_]u8{} },

    // 1 operand, 2 bytes wide
    .OpJumpNotTruthy = .{ .Name = "OpJumpNotTruthy", .OperandWidths = &[_]u8{2} },
    .OpJump = .{ .Name = "OpJump", .OperandWidths = &[_]u8{2} },

    .OpNull = .{ .Name = "OpNull", .OperandWidths = &[_]u8{} },

    // bindings biatchhhhhhh
    .OpGetGlobal = .{ .Name = "OpGetGlobal", .OperandWidths = &[_]u8{2} },
    .OpSetGlobal = .{ .Name = "OpSetGlobal", .OperandWidths = &[_]u8{2} },

    .OpArray = .{ .Name = "OpArray", .OperandWidths = &[_]u8{2} },
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

/// Create a string representation of Instructions
pub fn instructionsToString(instructions: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    var i: usize = 0;
    while (i < instructions.len) {
        const op = instructions[i];
        const def = LookUpDefinition(op) orelse {
            try std.fmt.format(buffer.writer(), "ERROR: unknown opcode {d}\n", .{op});
            i += 1;
            continue;
        };

        const operands = try readOperands(def, instructions[i + 1 ..], allocator);
        defer allocator.free(operands);

        try std.fmt.format(buffer.writer(), "{:0>4} {s}", .{ i, def.Name });

        // Print operands
        for (operands) |operand| {
            try std.fmt.format(buffer.writer(), " {d}", .{operand});
        }
        try buffer.append('\n');

        i += 1;
        for (def.OperandWidths) |width| {
            i += width;
        }
    }

    return buffer.toOwnedSlice();
}

/// Read operands from a bytecode instruction
pub fn readOperands(def: OpcodeDefinition, ins: []const u8, allocator: std.mem.Allocator) ![]u32 {
    var operands = try allocator.alloc(u32, def.OperandWidths.len);
    errdefer allocator.free(operands);

    var offset: usize = 0;
    for (def.OperandWidths, 0..) |width, i| {
        switch (width) {
            2 => {
                operands[i] = @as(u32, std.mem.readInt(u16, ins[offset..][0..2], .big));
                offset += 2;
            },
            else => return error.UnsupportedOperandWidth,
        }
    }

    return operands;
}
