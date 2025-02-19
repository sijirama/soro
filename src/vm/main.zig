const std = @import("std");
const code = @import("../code/main.zig");
const object = @import("../object/main.zig");
const compiler = @import("../compiler/main.zig");

const StackSize = 2048;

pub const VM = struct {
    constants: []object.Object,
    instructions: code.InstructionsType,
    stack: []object.Object,
    sp: usize, // Stack pointer (points to the next free slot)

    pub fn init(allocator: std.mem.Allocator, bytecode: *compiler.Bytecode) VM {
        return .{
            .constants = bytecode.Constants,
            .instructions = bytecode.Instructions,
            .stack = allocator.alloc(object.Object, StackSize) catch unreachable,
            .sp = 0,
        };
    }

    pub fn deinit(self: *VM, allocator: std.mem.Allocator) void {
        allocator.free(self.stack);
    }

    pub fn push(self: *VM, obj: object.Object) !void {
        if (self.sp >= StackSize) return error.StackOverflow;
        self.stack[self.sp] = obj;
        self.sp += 1;
    }

    pub fn stackTop(self: *VM) ?object.Object {
        if (self.sp == 0) return null;
        return self.stack[self.sp - 1];
    }

    pub fn run(self: *VM) !void {
        var ip: usize = 0; // Instruction pointer

        //std.debug.print("Bytecode: {any}\n", .{self.instructions});

        while (ip < self.instructions.len) {
            const op: code.Opcode = @enumFromInt(self.instructions[ip]);

            switch (op) { // Cast the opcode to its underlying u8 value
                code.Opcode.OpConstant => {

                    // Ensure there are enough bytes left for the operand
                    if (ip + 3 > self.instructions.len) {
                        return error.InvalidInstruction;
                    }

                    const constIndex = std.mem.readInt(u16, self.instructions[ip + 1 ..][0..2], .big);

                    ip += 3;

                    // Ensure the constant index is within bounds
                    if (constIndex >= self.constants.len) {
                        return error.InvalidConstantIndex;
                    }

                    try self.push(self.constants[constIndex]);
                },
            }
        }
    }
};
