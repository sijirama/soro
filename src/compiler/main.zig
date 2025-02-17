const std = @import("std");
const code = @import("../code/main.zig");
const ast = @import("../ast/ast.zig");
const object = @import("../object/main.zig");

pub const Bytecode = struct {
    Instructions: []code.byte,
    Constants: []object.Object,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Bytecode) void {
        self.allocator.free(self.Instructions);
        self.allocator.free(self.Constants);
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
        bytecode_ptr.* = Bytecode{
            .Instructions = try self.instructions.toOwnedSlice(),
            .Constants = try self.constantPool.toOwnedSlice(),
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
        const pos = self.instructions.items.len;
        try self.instructions.appendSlice(instruction);
        self.allocator.free(instruction); // Free the temporary instruction
        return pos;
    }

    pub fn compile(self: *Compiler, node: anytype) !void {
        std.debug.print("Compiling node of type: {}\n", .{@TypeOf(node)});
        switch (@TypeOf(node)) {
            ast.Program => {
                for (node.statements.items) |stmt| {
                    try self.compile(stmt);
                }
            },
            ast.Statement => {
                switch (node) {
                    .expression_statement => |stmt| {
                        std.debug.print("Compiling expression statement: {any}\n", .{stmt}); // Debug log
                        std.debug.print("Expression pointer: {*}\n", .{stmt.expression}); // Debug log
                        const expr = stmt.expression.*;
                        try self.compile(expr);
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
                    .infix_expression => |expr| {
                        const left = expr.left.*;
                        const right = expr.right.*;
                        try self.compile(left);
                        try self.compile(right);
                        // Emit the infix operation opcode here (e.g., OpAdd, OpSub, etc.)
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
