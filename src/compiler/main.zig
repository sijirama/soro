const std = @import("std");
const code = @import("../code/main.zig");
const ast = @import("../ast/ast.zig");
const object = @import("../object/object.zig");

const Bytecode = struct {
    Instructions: []code.byte,
    Constants: []object.Object,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Bytecode) void {
        self.allocator.free(self.Instructions);
        self.allocator.free(self.Constants);
    }
};

const Compiler = struct {
    instructions: std.ArrayList(code.byte), // array of instructions
    constantPool: std.ArrayList(object.Object), // array of constants
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) Compiler {
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

    fn bytecode(self: *Compiler) Bytecode {
        return Bytecode{
            .instructions = try self.instructions.toOwnedSlice(),
            .constants = try self.constantPool.toOwnedSlice(),
            .allocator = self.allocator,
        };
    }

    fn compile(_: *Compiler, _: ast.Program) void {}
};
