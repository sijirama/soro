const std = @import("std");
const code = @import("../code/main.zig");
const ast = @import("../ast/ast.zig");
const object = @import("../object/main.zig");

pub const Bytecode = struct {
    Instructions: []code.byte,
    Constants: []object.Object,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Bytecode) void {
        if (self.Instructions.len > 0) {
            self.allocator.free(self.Instructions);
        }
        if (self.Constants.len > 0) {
            self.allocator.free(self.Constants);
        }
    }
};

pub const Compiler = struct {
    instructions: std.ArrayList(code.byte), // array of instructions
    constantPool: std.ArrayList(object.Object), // array of constants
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Compiler {
        const compiler = Compiler{
            .allocator = allocator,
            .constantPool = std.ArrayList(object.Object).init(allocator),
            .instructions = std.ArrayList(code.byte).init(allocator),
        };
        return compiler;
    }

    pub fn deinit(self: *Compiler) void {
        self.instructions.deinit();
        self.constantPool.deinit();
    }

    pub fn bytecode(self: *Compiler) !*Bytecode {
        const bytecode_ptr = try self.allocator.create(Bytecode);
        errdefer self.allocator.destroy(bytecode_ptr);

        const instructions_copy = try self.allocator.alloc(code.byte, self.instructions.items.len);
        errdefer self.allocator.free(instructions_copy);
        @memcpy(instructions_copy, self.instructions.items);

        const constants_copy = try self.allocator.alloc(object.Object, self.constantPool.items.len);
        errdefer self.allocator.free(constants_copy);
        @memcpy(constants_copy, self.constantPool.items);

        bytecode_ptr.* = Bytecode{
            .Instructions = instructions_copy,
            .Constants = constants_copy,
            .allocator = self.allocator,
        };
        return bytecode_ptr;
    }

    /// addConstant: Adds a constant to the pool and returns its index
    fn addConstant(self: *Compiler, obj: object.Object) !usize {
        try self.constantPool.append(obj);
        return self.constantPool.items.len - 1;
    }

    /// emit: Creates and emits an instruction, returning its position
    fn emit(self: *Compiler, op: code.Opcode, operands: []const u32) !usize {
        const instruction = try code.MakeInstruction(self.allocator, op, operands);
        defer self.allocator.free(instruction); // Free the temporary instruction

        const pos = self.instructions.items.len;
        try self.instructions.appendSlice(instruction);
        return pos;
    }

    pub fn compile(self: *Compiler, node: anytype) !void {
        switch (@TypeOf(node)) {
            ast.Program => {
                for (node.statements.items) |stmt| {
                    try self.compile(stmt);
                }
            },
            ast.Statement => {
                switch (node) {
                    .expression_statement => |stmt| {
                        const expr = stmt.expression.*;
                        try self.compile(expr);
                        _ = try self.emit(.OpPop, &[_]u32{});
                    },
                    .abeg_statement => |stmt| {
                        const value = stmt.value.*;
                        try self.compile(value);
                    },
                    .comot_statement => |stmt| {
                        const value = stmt.value.*;
                        try self.compile(value);
                    },
                }
            },
            ast.Expression => {
                switch (node) {
                    .integer_literal => |lit| {
                        const constant = object.Object{ .Integer = .{ .value = lit.value } };
                        const const_index = try self.addConstant(constant);
                        _ = try self.emit(code.Opcode.OpConstant, &[_]u32{@intCast(const_index)});
                    },
                    .float_literal => |lit| {
                        const constant = object.Object{ .Float = .{ .value = lit.value } };
                        const const_index = try self.addConstant(constant);
                        _ = try self.emit(code.Opcode.OpConstant, &[_]u32{@intCast(const_index)});
                    },

                    .boolean_literal => |lit| {
                        const constant = object.Object{ .Boolean = .{ .value = lit.value } };
                        if (constant.Boolean.value) {
                            _ = try self.emit(.OpTrue, &[_]u32{});
                        } else {
                            _ = try self.emit(.OpFalse, &[_]u32{});
                        }
                    },

                    .infix_expression => |expr| {
                        const left = expr.left.*;
                        const right = expr.right.*;
                        try self.compile(left);
                        try self.compile(right);

                        // i know this is sad, but i can't switch overstrings in zig
                        //which is crazy so this was the next thing, abeg no vex

                        if (std.mem.eql(u8, expr.operator, "+")) {
                            _ = try self.emit(.OpAdd, &[_]u32{});
                        }
                        if (std.mem.eql(u8, expr.operator, "-")) {
                            _ = try self.emit(.OpSub, &[_]u32{});
                        }
                        if (std.mem.eql(u8, expr.operator, "*")) {
                            _ = try self.emit(.OpMul, &[_]u32{});
                        }
                        if (std.mem.eql(u8, expr.operator, "/")) {
                            _ = try self.emit(.OpDiv, &[_]u32{});
                        }

                        //omo the other ones i never do like
                        // or
                        // and
                        // no forget abeg
                    },
                    .prefix_expression => |expr| {
                        const right = expr.right.*;
                        try self.compile(right);
                        // Emit the prefix operation opcode here (e.g., OpNegate, OpNot, etc.)
                    },
                    else => {
                        // Handle other expression types as needed
                        return error.UnsupportedExpression;
                    },
                }
            },
            else => {
                return error.UnknownNodeType;
            },
        }
    }
};
