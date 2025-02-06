const std = @import("std");
const ast = @import("../ast/ast.zig");
const code = @import("../code/main.zig");

pub const ObjectType = enum {
    Integer,
    Float,
    Boolean,
    Null,
    ReturnValue,
    Error,
    String,
    // Builtin,
    // Array,
    // Hash,
    //Function,
    //CompiledFunction,

    pub fn toString(self: ObjectType) []const u8 {
        return switch (self) {
            .Integer => "INTEGER",
            .Float => "FLOAT",
            .Boolean => "BOOLEAN",
            .Null => "NULL",
            .ReturnValue => "RETURN_VALUE",
            .Error => "ERROR",
            .String => "STRING",
            //.Builtin => "BUILTIN",
            //.Array => "ARRAY",
            //.Hash => "HASH",
            // .Function => "FUNCTION",
            // .CompiledFunction => "COMPILED_FUNCTION",
        };
    }
};

pub const Object = union(ObjectType) {
    Integer: Integer,
    Float: Float,
    Boolean: Boolean,
    Null: void,
    ReturnValue: ReturnValue,
    Error: Error,
    String: String,
    // Builtin: Builtin,
    // Array: Array,
    // Hash: Hash,
    //Function: Function,
    //CompiledFunction: CompiledFunction,
};

pub const Integer = struct {
    value: i64,
    is_immutable: bool = false,

    pub fn objectType(self: Integer) []const u8 {
        _ = self;
        return ObjectType.Integer.toString();
    }

    pub fn inspect(self: Integer) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{}",
            .{self.value},
        ) catch "error formatting integer";
    }

    pub fn formatWithMetadata(self: Integer) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{s}{}",
            .{ if (self.is_immutable) "const " else "", self.value },
        ) catch "error formatting integer";
    }
};

pub const Float = struct {
    value: f64,
    is_immutable: bool = false,

    pub fn objectType(self: Float) []const u8 {
        _ = self;
        return ObjectType.Float.toString();
    }

    pub fn inspect(self: Float) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{}",
            .{self.value},
        ) catch "error formatting float";
    }

    pub fn formatWithMetadata(self: Float) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{s}{}",
            .{ if (self.is_immutable) "const " else "", self.value },
        ) catch "error formatting float";
    }
};

pub const Boolean = struct {
    value: bool,
    is_immutable: bool = false,

    pub fn objectType(self: Boolean) []const u8 {
        _ = self;
        return ObjectType.Boolean.toString();
    }

    pub fn inspect(self: Boolean) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{}",
            .{self.value},
        ) catch "error formatting boolean";
    }

    pub fn formatWithMetadata(self: Boolean) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{s}{}",
            .{ if (self.is_immutable) "const " else "", self.value },
        ) catch "error formatting boolean";
    }

    pub fn hashKey(self: Boolean) HashKey {
        return .{
            .type = .Boolean,
            .value = if (self.value) 1 else 0,
        };
    }
};

pub const String = struct {
    value: []const u8,
    is_immutable: bool = false,

    pub fn objectType(self: String) []const u8 {
        _ = self;
        return ObjectType.String.toString();
    }

    pub fn inspect(self: String) []const u8 {
        return self.value;
    }

    pub fn formatWithMetadata(self: String) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "{s}\"{s}\"",
            .{ if (self.is_immutable) "const " else "", self.value },
        ) catch "error formatting string";
    }

    pub fn hashKey(self: String) HashKey {
        var hasher = std.hash.Fnv1a_64.init();
        hasher.update(self.value);
        return .{
            .type = .String,
            .value = hasher.final(),
        };
    }
};

pub const ReturnValue = struct {
    value: *const Object,

    pub fn objectType(self: ReturnValue) []const u8 {
        _ = self;
        return ObjectType.ReturnValue.toString();
    }

    pub fn inspect(self: ReturnValue) []const u8 {
        return switch (self.value) {
            inline else => |v| v.inspect(),
        };
    }

    pub fn formatWithMetadata(self: ReturnValue) []const u8 {
        return self.inspect();
    }
};

pub const Error = struct {
    message: []const u8,

    pub fn objectType(self: Error) []const u8 {
        _ = self;
        return ObjectType.Error.toString();
    }

    pub fn inspect(self: Error) []const u8 {
        return self.message;
    }

    pub fn formatWithMetadata(self: Error) []const u8 {
        return std.fmt.allocPrint(
            std.heap.page_allocator,
            "ERROR: {s}",
            .{self.message},
        ) catch "error formatting error";
    }
};

pub const BuiltinFunction = *const fn (args: []const Object) Object;

pub const Builtin = struct {
    func: BuiltinFunction,

    pub fn objectType(self: Builtin) []const u8 {
        _ = self;
        return ObjectType.Builtin.toString();
    }

    pub fn inspect(self: Builtin) []const u8 {
        _ = self;
        return "builtin function";
    }

    pub fn formatWithMetadata(self: Builtin) []const u8 {
        return self.inspect();
    }
};

pub const Array = struct {
    elements: []*const Object,
    is_immutable: bool = false,

    pub fn objectType(self: Array) []const u8 {
        _ = self;
        return ObjectType.Array.toString();
    }

    pub fn inspect(self: Array) []const u8 {
        var result = std.ArrayList(u8).init(std.heap.page_allocator);
        result.appendSlice("[") catch return "error formatting array";
        for (self.elements, 0..) |elem, i| {
            if (i > 0) {
                result.appendSlice(", ") catch return "error formatting array";
            }
            const elem_str = switch (elem) {
                inline else => |e| e.inspect(),
            };
            result.appendSlice(elem_str) catch return "error formatting array";
        }
        result.appendSlice("]") catch return "error formatting array";
        return result.items;
    }

    pub fn formatWithMetadata(self: Array) []const u8 {
        var result = std.ArrayList(u8).init(std.heap.page_allocator);
        if (self.is_immutable) {
            result.appendSlice("const ") catch return "error formatting array";
        }
        result.appendSlice(self.inspect()) catch return "error formatting array";
        return result.items;
    }
};

pub const HashKey = struct {
    type: ObjectType,
    value: u64,
};

pub const HashPair = struct {
    key: *const Object,
    value: *const Object,
};

pub const Hash = struct {
    pairs: std.AutoHashMap(HashKey, HashPair),
    is_immutable: bool = false,

    pub fn objectType(self: Hash) []const u8 {
        _ = self;
        return ObjectType.Hash.toString();
    }

    pub fn inspect(self: Hash) []const u8 {
        var result = std.ArrayList(u8).init(std.heap.page_allocator);
        result.appendSlice("{") catch return "error formatting hash";
        var first = true;
        var it = self.pairs.iterator();
        while (it.next()) |entry| {
            if (!first) {
                result.appendSlice(", ") catch return "error formatting hash";
            }
            first = false;
            const key_str = switch (entry.value.key) {
                inline else => |k| k.inspect(),
            };
            const value_str = switch (entry.value.value) {
                inline else => |v| v.inspect(),
            };
            result.writer().print("{s}: {s}", .{ key_str, value_str }) catch return "error formatting hash";
        }
        result.appendSlice("}") catch return "error formatting hash";
        return result.items;
    }

    pub fn formatWithMetadata(self: Hash) []const u8 {
        var result = std.ArrayList(u8).init(std.heap.page_allocator);
        if (self.is_immutable) {
            result.appendSlice("const ") catch return "error formatting hash";
        }
        result.appendSlice(self.inspect()) catch return "error formatting hash";
        return result.items;
    }
};

// pub const Function = struct {
//     parameters: []const *ast.Identifier,
//     body: *ast.BlockStatement,
//     env: *Environment,
//     is_immutable: bool = false,
//
//     pub fn objectType(self: Function) []const u8 {
//         _ = self;
//         return ObjectType.Function.toString();
//     }
//
//     pub fn inspect(self: Function) []const u8 {
//         var result = std.ArrayList(u8).init(std.heap.page_allocator);
//         result.appendSlice("fn(") catch return "error formatting function";
//         for (self.parameters, 0..) |param, i| {
//             if (i > 0) {
//                 result.appendSlice(", ") catch return "error formatting function";
//             }
//             result.appendSlice(param.toString()) catch return "error formatting function";
//         }
//         result.appendSlice(") {\n") catch return "error formatting function";
//         result.appendSlice(self.body.toString()) catch return "error formatting function";
//         result.appendSlice("\n}") catch return "error formatting function";
//         return result.items;
//     }
//
//     pub fn formatWithMetadata(self: Function) []const u8 {
//         var result = std.ArrayList(u8).init(std.heap.page_allocator);
//         if (self.is_immutable) {
//             result.appendSlice("const ") catch return "error formatting function";
//         }
//         result.appendSlice(self.inspect()) catch return "error formatting function";
//         return result.items;
//     }
// };

// pub const CompiledFunction = struct {
//     instructions: code.InstructionsType,
//     num_locals: usize,
//     num_parameters: usize,
//
//     pub fn objectType(self: CompiledFunction) []const u8 {
//         _ = self;
//         return ObjectType.CompiledFunction.toString();
//     }
//
//     pub fn inspect(self: CompiledFunction) []const u8 {
//         return std.fmt.allocPrint(
//             std.heap.page_allocator,
//             "{*}",
//             .{&self},
//         ) catch "error formatting compiled function";
//     }
//
//     pub fn formatWithMetadata(self: CompiledFunction) []const u8 {
//         return std.fmt.allocPrint(
//             std.heap.page_allocator,
//             "CompiledFunction[{*}]",
//             .{&self},
//         ) catch "error formatting compiled function";
//     }
// };
