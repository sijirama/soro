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
    allocator: std.mem.Allocator, // Add this line

    pub fn init(allocator: std.mem.Allocator, bytecode: *compiler.Bytecode) VM {
        return .{
            .constants = bytecode.Constants,
            .instructions = bytecode.Instructions,
            .stack = allocator.alloc(object.Object, StackSize) catch unreachable,
            .sp = 0,
            .allocator = allocator, // Add this line
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

    pub fn LastPoppedStackElem(self: *VM) ?object.Object {
        return self.stack[self.sp];
    }

    fn getInteger(obj: object.Object) !i64 {
        return switch (obj) {
            .Integer => |i| i.value,
            else => error.TypeError,
        };
    }

    fn executeBinaryOperation(self: *VM, op: InfixOperators) !void {
        const right = self.pop() orelse return error.StackUnderflow;
        const left = self.pop() orelse return error.StackUnderflow;

        switch (left) {
            .Integer => |left_int| {
                switch (right) {
                    .Integer => |right_int| {
                        const result = try executeIntegerBinaryOperation(left_int.value, right_int.value, op);
                        try self.push(object.Object{ .Integer = .{ .value = result } });
                    },
                    .Float => |right_float| {
                        const result = try executeFloatBinaryOperation(@floatFromInt(left_int.value), right_float.value, op);
                        try self.push(object.Object{ .Float = .{ .value = result } });
                    },
                    else => return error.TypeError,
                }
            },
            .Float => |left_float| {
                switch (right) {
                    .Integer => |right_int| {
                        const result = try executeFloatBinaryOperation(left_float.value, @floatFromInt(right_int.value), op);
                        try self.push(object.Object{ .Float = .{ .value = result } });
                    },
                    .Float => |right_float| {
                        const result = try executeFloatBinaryOperation(left_float.value, right_float.value, op);
                        try self.push(object.Object{ .Float = .{ .value = result } });
                    },
                    else => return error.TypeError,
                }
            },
            else => return error.TypeError,
        }
    }

    const InfixOperators = enum { Add, Sub, Mul, Div };

    fn executeIntegerBinaryOperation(left: i64, right: i64, op: InfixOperators) !i64 {
        return switch (op) {
            .Add => left + right,
            .Sub => left - right,
            .Mul => left * right,
            .Div => @divExact(left, right),
        };
    }

    fn executeFloatBinaryOperation(left: f64, right: f64, op: InfixOperators) !f64 {
        return switch (op) {
            .Add => left + right,
            .Sub => left - right,
            .Mul => left * right,
            .Div => left / right,
        };
    }

    //NOTE: omo the issues here was that there's no way i know to concatenate this strings without allocating data and where to deallocate it was very tricky,
    //i'll come back to it, for now you can't append strings

    // fn executeStringBinaryOperation(allocator: std.mem.Allocator, left: []const u8, right: []const u8, op: InfixOperators) ![]const u8 {
    //     return switch (op) {
    //         .Add => {
    //             // Allocate a new slice to hold the concatenated result
    //             const result = try allocator.alloc(u8, left.len + right.len);
    //             // Copy the left string into the result
    //             @memcpy(result[0..left.len], left);
    //             // Copy the right string into the result
    //             @memcpy(result[left.len..], right);
    //             return result;
    //         },
    //         else => return error.UnsupportedOperation,
    //     };
    // }
    //
    // fn executeStringBinaryOperation2(left: []const u8, right: []const u8, op: InfixOperators) ![]const u8 {
    //     return switch (op) {
    //         .Add => left ++ right,
    //         else => return error.UnsupportedOperation,
    //     };
    // }

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
                .OpPop => {
                    _ = self.pop() orelse return error.StackEmpty;
                },
                .OpAdd => try self.executeBinaryOperation(.Add),
                .OpSub => try self.executeBinaryOperation(.Sub),
                .OpMul => try self.executeBinaryOperation(.Mul),
                .OpDiv => try self.executeBinaryOperation(.Div),
            }
        }
    }
};
