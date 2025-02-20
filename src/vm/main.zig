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

    pub fn pop(self: *VM) ?object.Object {
        if (self.sp == 0) return null;
        const o = self.stack[self.sp - 1];
        self.sp -= 1;
        return o;
    }

    pub fn stackTop(self: *VM) ?object.Object {
        if (self.sp == 0) return null;
        return self.stack[self.sp - 1];
    }

    fn getInteger(obj: object.Object) !i64 {
        return switch (obj) {
            .Integer => |i| i.value,
            else => error.TypeError,
        };
    }

    const Operator = enum { Add };

    fn executeBinaryOperation(self: *VM, op: Operator) !void {
        // Pop values first to ensure we have them before modifying the stack
        const right = self.pop() orelse return error.StackUnderflow;
        const left = self.pop() orelse return error.StackUnderflow;

        // Get integer values, return TypeError if not integers
        const right_val = try getInteger(right);
        const left_val = try getInteger(left);

        // Perform the operation
        const result = switch (op) {
            .Add => left_val + right_val,
        };

        // Push the result
        try self.push(object.Object{ .Integer = .{ .value = result } });
    }

    pub fn run(self: *VM) !void {
        //std.debug.print("Bytecode: {any}\n", .{self.instructions});

        var ip: usize = 0; // Instruction pointer

        while (ip < self.instructions.len) {
            const op: code.Opcode = @enumFromInt(self.instructions[ip]);
            ip += 1; // Increment ip after reading the opcode

            switch (op) {
                .OpConstant => {
                    const constIndex = std.mem.readInt(u16, self.instructions[ip..][0..2], .big);
                    ip += 2;
                    if (constIndex >= self.constants.len) {
                        return error.InvalidConstantIndex;
                    }
                    try self.push(self.constants[constIndex]);
                },

                .OpAdd => try self.executeBinaryOperation(.Add),
            }
        }
    }
};
