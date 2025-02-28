const std = @import("std");
const code = @import("../code/main.zig");
const ast = @import("../ast/ast.zig");
const object = @import("../object/main.zig");
const symbol = @import("./symbol_table.zig");
//const CompilerError = @import("./error.zig").CompilerErrorType;

pub const CompilerErrorType = error{
    UnsupportedExpression,
    UnknownNodeType,
    MakeInstructionsFailed,
    SymbolTableDefinition,
    SymbolTableLookUp,
};

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

const EmittedInstruction = struct {
    OpCode: ?code.Opcode = null,
    Position: ?usize = null,
};

pub const Compiler = struct {
    instructions: std.ArrayList(code.byte), // array of instructions
    constantPool: std.ArrayList(object.Object), // array of constants
    allocator: std.mem.Allocator,

    lastInstruction: EmittedInstruction,
    previousInstruction: EmittedInstruction,

    symbolTable: symbol.SymbolTable,

    owns_constants: bool,

    pub fn init(allocator: std.mem.Allocator) Compiler {
        const compiler = Compiler{
            .allocator = allocator,
            .constantPool = std.ArrayList(object.Object).init(allocator),
            .instructions = std.ArrayList(code.byte).init(allocator),
            .lastInstruction = EmittedInstruction{},
            .previousInstruction = EmittedInstruction{},
            .symbolTable = symbol.SymbolTable.init(allocator),
            .owns_constants = true,
        };
        return compiler;
    }

    pub fn deinitOld(self: *Compiler) void {
        self.instructions.deinit();
        self.constantPool.deinit();
        self.symbolTable.deinit();
    }

    pub fn deinit(self: *Compiler) void {
        self.instructions.deinit();

        // Only deinit these if we own them (not in initWithState case)
        if (self.owns_constants) {
            self.constantPool.deinit();
            self.symbolTable.deinit();
        }
    }

    // New initialization method that preserves state
    pub fn initWithState(
        allocator: std.mem.Allocator,
        symbolTable: symbol.SymbolTable,
        constants: std.ArrayList(object.Object),
    ) Compiler {
        return Compiler{
            .allocator = allocator,
            .constantPool = constants,
            .instructions = std.ArrayList(code.byte).init(allocator),
            .lastInstruction = EmittedInstruction{},
            .previousInstruction = EmittedInstruction{},
            .symbolTable = symbolTable,
            .owns_constants = false,
        };
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
    fn addConstant(self: *Compiler, obj: object.Object) CompilerErrorType!usize {
        self.constantPool.append(obj) catch unreachable;
        return self.constantPool.items.len - 1;
    }

    fn setLastInstruction(self: *Compiler, op: code.Opcode, pos: usize) void {
        const prev = self.lastInstruction;
        const last = EmittedInstruction{
            .OpCode = op,
            .Position = pos,
        };

        self.previousInstruction = prev;
        self.lastInstruction = last;
    }

    fn lastInstructionIsPop(self: *Compiler) bool {
        return self.lastInstruction.OpCode == code.Opcode.OpPop;
    }

    fn replaceInstruction(self: *Compiler, pos: usize, newInstruction: []const code.byte) void {
        // Ensure the new instructions fit within the existing instructions array
        if (pos + newInstruction.len > self.instructions.items.len) {
            @panic("New instructions exceed the bounds of the existing instructions array");
        }

        for (newInstruction, 0..) |byte, i| {
            self.instructions.items[pos + i] = byte;
        }
    }

    pub fn changeOperand(self: *Compiler, opPos: usize, operand: usize) void {
        const op: code.Opcode = @enumFromInt(self.instructions.items[opPos]);

        const ope: u32 = @intCast(operand);

        const newInstruction = code.MakeInstruction(self.allocator, op, &[_]u32{ope}) catch unreachable;
        defer self.allocator.free(newInstruction); // Free the temporary instruction

        self.replaceInstruction(opPos, newInstruction);
    }

    fn removeLastPop(self: *Compiler) void {
        if (self.instructions.items.len == 0) return;

        if (self.lastInstruction.Position) |pos| {
            self.instructions.shrinkRetainingCapacity(pos);
        }

        self.lastInstruction = self.previousInstruction;
    }

    /// emit: Creates and emits an instruction, returning its position
    fn emit(self: *Compiler, op: code.Opcode, operands: []const u32) CompilerErrorType!usize {
        const instruction = code.MakeInstruction(self.allocator, op, operands) catch unreachable;
        defer self.allocator.free(instruction); // Free the temporary instruction

        const pos = self.instructions.items.len;
        self.instructions.appendSlice(instruction) catch unreachable;

        self.setLastInstruction(op, pos);

        return pos;
    }

    pub fn compile(self: *Compiler, node: anytype) CompilerErrorType!void {
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
                        // TODO: constant declarations should watch out
                        const value = stmt.value.*;
                        try self.compile(value);
                        const symb = self.symbolTable.define(stmt.name.value, symbol.GLOBAL_SCOPE) catch {
                            return CompilerErrorType.SymbolTableDefinition;
                        };
                        _ = try self.emit(code.Opcode.OpSetGlobal, &[_]u32{@intCast(symb.Index)});
                    },
                    .comot_statement => |stmt| {
                        const value = stmt.value.*;
                        try self.compile(value);
                    },
                    .block_statement => |block| {
                        for (block.statements.items) |stmt| {
                            try self.compile(stmt);
                        }
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
                    .string_literal => |lit| {
                        const constant = object.Object{ .String = .{ .value = lit.value } };
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
                    .identifier => |ident| {
                        const symb = self.symbolTable.lookup(ident.value);
                        if (symb) |sym| {
                            _ = try self.emit(code.Opcode.OpGetGlobal, &[_]u32{@intCast(sym.Index)});
                        } else {
                            return CompilerErrorType.SymbolTableLookUp;
                        }
                    },
                    .infix_expression => |expr| {
                        const left = expr.left.*;
                        const right = expr.right.*;
                        try self.compile(left);
                        try self.compile(right);

                        // i know this is sad, but i can't switch overstrings in zig
                        //which is crazy so this was the next thing, abeg no vex
                        // i should definitely use a switch case here, wtf

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
                        if (std.mem.eql(u8, expr.operator, ">")) {
                            _ = try self.emit(.OpGreaterThan, &[_]u32{});
                        }
                        if (std.mem.eql(u8, expr.operator, "<")) {
                            _ = try self.emit(.OpLessThan, &[_]u32{});
                        }

                        if (std.mem.eql(u8, expr.operator, "==")) {
                            _ = try self.emit(.OpEqual, &[_]u32{});
                        }
                        if (std.mem.eql(u8, expr.operator, "!=")) {
                            _ = try self.emit(.OpNotEqual, &[_]u32{});
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
                        if (std.mem.eql(u8, expr.operator, "-")) {
                            _ = try self.emit(.OpMinus, &[_]u32{});
                        }

                        if (std.mem.eql(u8, expr.operator, "!")) {
                            _ = try self.emit(.OpBang, &[_]u32{});
                        }
                    },
                    .if_expression => |expr| {
                        const condition = expr.condition.*;
                        try self.compile(condition);

                        // Emit an `OpJumpNotTruthy` with a bogus value
                        const jumNotTruthyPos = try self.emit(.OpJumpNotTruthy, &[_]u32{999});

                        // compile the consequence
                        const consequence = expr.consequence.*;
                        const statement = ast.Statement{ .block_statement = consequence };
                        try self.compile(statement);

                        // remove that nasty OpPop
                        if (self.lastInstructionIsPop()) {
                            self.removeLastPop();
                        }

                        var afterConsequencePos: ?usize = null;

                        const jumpPos = try self.emit(.OpJump, &[_]u32{999});
                        afterConsequencePos = self.instructions.items.len;
                        self.changeOperand(jumNotTruthyPos, afterConsequencePos.?);

                        if (expr.alternative == null) {
                            _ = try self.emit(.OpNull, &[_]u32{});
                        } else {
                            const alternative = expr.alternative.?.*;
                            const altStatement = ast.Statement{ .block_statement = alternative };
                            try self.compile(altStatement);

                            if (self.lastInstructionIsPop()) {
                                self.removeLastPop();
                            }
                        }

                        const afterAlternativePos = self.instructions.items.len;
                        self.changeOperand(jumpPos, afterAlternativePos);
                    },

                    // else => {
                    //     return CompilerErrorType.UnsupportedExpression;
                    // },
                }
            },
            else => {
                return CompilerErrorType.UnknownNodeType;
            },
        }
    }
};
