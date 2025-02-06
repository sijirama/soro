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

    pub fn bytecode(self: *Compiler) !Bytecode {
        return Bytecode{
            .Instructions = try self.instructions.toOwnedSlice(),
            .Constants = try self.constantPool.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    pub fn compile(_: *Compiler, _: ast.Program) !void {}
};
