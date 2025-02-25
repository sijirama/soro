const std = @import("std");
const code = @import("../code/main.zig");
const object = @import("../object/main.zig");
const compiler = @import("../compiler/main.zig");

const StackSize = 2048;
const True = object.Object{ .Boolean = .{ .value = true } };
const False = object.Object{ .Boolean = .{ .value = false } };
const Null = object.Object{ .Null = {} };

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

    pub fn executeBangOperation(self: *VM) !void {
        const operator = self.pop() orelse return error.StackUnderflow;

        switch (operator) {
            .Boolean => |lit_value| {
                switch (lit_value.value) {
                    true => {
                        try self.push(False);
                    },
                    false => {
                        try self.push(True);
                    },
                }
            },
            .Null => {
                try self.push(True);
            },
            else => {
                try self.push(False);
            },
        }
    }

    pub fn executeMinusOperation(self: *VM) !void {
        const operand = self.pop() orelse return error.StackUnderflow;

        try switch (operand) { // omo i confuse too, which one is try switch
            .Integer => |lit_int| {
                try self.push(object.Object{ .Integer = .{ .value = -lit_int.value } });
            },
            else => error.UnsupportedType,
        };
    }

    fn nativeBoolToBooleanObject(input: bool) object.Object {
        if (input) {
            return True;
        }
        return False;
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
            .String => |left_str| {
                switch (right) {
                    .String => |right_str| {
                        const result = try self.executeStringBinaryOperation(left_str.value, right_str.value, op);
                        try self.push(result);
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

    fn executeStringBinaryOperation(self: *VM, left: []const u8, right: []const u8, op: InfixOperators) !object.Object {
        return switch (op) {
            .Add => {
                var list = std.ArrayList(u8).init(self.allocator);
                defer list.deinit(); // This will clean up the ArrayList if we encounter an error

                try list.appendSlice(left);
                try list.appendSlice(right);

                // toOwnedSlice() transfers ownership of the underlying memory to the caller
                // and resets the ArrayList to empty state
                return object.Object{ .String = .{ .value = try list.toOwnedSlice() } };
            },
            else => error.UnsupportedOperation,
        };
    }

    // Add these type-specific comparison functions
    fn compareValues(comptime T: type, a: T, b: T, op: code.Opcode) bool {
        return switch (op) {
            .OpEqual => a == b,
            .OpNotEqual => a != b,
            .OpGreaterThan => a > b,
            .OpLessThan => a < b,
            else => unreachable,
        };
    }

    fn compareStrings(a: []const u8, b: []const u8, op: code.Opcode) bool {
        return switch (op) {
            .OpEqual => std.mem.eql(u8, a, b),
            .OpNotEqual => !std.mem.eql(u8, a, b),
            .OpGreaterThan => a.len > b.len,
            .OpLessThan => a.len < b.len,
            else => unreachable,
        };
    }

    fn executeComparisonOperation(self: *VM, op: code.Opcode) !void {
        const right = self.pop() orelse return error.StackUnderflow;
        const left = self.pop() orelse return error.StackUnderflow;

        const result = switch (left) {
            .Integer => |left_int| switch (right) {
                .Integer => |right_int| compareValues(i64, left_int.value, right_int.value, op),
                .Float => |right_float| compareValues(f64, @floatFromInt(left_int.value), right_float.value, op),
                else => return error.TypeError,
            },
            .Float => |left_float| switch (right) {
                .Integer => |right_int| compareValues(f64, left_float.value, @floatFromInt(right_int.value), op),
                .Float => |right_float| compareValues(f64, left_float.value, right_float.value, op),
                else => return error.TypeError,
            },
            .String => |left_str| switch (right) {
                .String => |right_str| compareStrings(left_str.value, right_str.value, op),
                else => return error.TypeError,
            },
            .Boolean => |left_bool| switch (right) {
                .Boolean => |right_bool| if (op == .OpEqual) left_bool.value == right_bool.value else if (op == .OpNotEqual) left_bool.value != right_bool.value else return error.InvalidOperator,
                else => return error.TypeError,
            },
            else => return error.TypeError,
        };

        try self.push(nativeBoolToBooleanObject(result));
    }

    fn isTruthy(_: *VM, obj: object.Object) bool {
        return switch (obj) {
            .Boolean => obj.Boolean.value,
            .Null => false,
            .Integer => obj.Integer.value > 0,
            .Float => obj.Float.value > 0,
            .String => obj.String.value.len > 0,
            else => true,
        };
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
                .OpPop => {
                    _ = self.pop() orelse return error.StackEmpty;
                },

                .OpTrue => try self.push(True),
                .OpFalse => try self.push(False),

                .OpAdd => try self.executeBinaryOperation(.Add),
                .OpSub => try self.executeBinaryOperation(.Sub),
                .OpMul => try self.executeBinaryOperation(.Mul),
                .OpDiv => try self.executeBinaryOperation(.Div),

                .OpEqual => try self.executeComparisonOperation(op),
                .OpNotEqual => try self.executeComparisonOperation(op),
                .OpGreaterThan => try self.executeComparisonOperation(op),
                .OpLessThan => try self.executeComparisonOperation(op),
                .OpBang => try self.executeBangOperation(),
                .OpMinus => try self.executeMinusOperation(),
                .OpJump => {
                    const pos = std.mem.readInt(u16, self.instructions[ip..][0..2], .big);
                    ip += 2;
                    ip = pos;
                },

                .OpJumpNotTruthy => {
                    const pos = std.mem.readInt(u16, self.instructions[ip..][0..2], .big);
                    ip += 2;

                    const condition = self.pop() orelse return error.StackUnderflow;
                    if (!self.isTruthy(condition)) {
                        ip = pos;
                    }
                },
                .OpNull => {
                    try self.push(Null);
                },
            }
        }
    }
};
