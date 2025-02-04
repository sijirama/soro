const std = @import("std");
const Ast = @import("../ast/ast.zig"); // Assuming you have an AST module

pub const ObjectType = enum {
    INTEGER,
    BOOLEAN,
    NULL,
    STRING,
    ARRAY,
    HASH,
    FUNCTION,
    ERROR,
    RETURN_VALUE,
};

pub const Object = union(ObjectType) {
    INTEGER: Integer,
    BOOLEAN: Boolean,
    NULL: Null,
    STRING: String,
    ARRAY: Array,
    FUNCTION: Function,
    ERROR: Error,
    RETURN_VALUE: ReturnValue,

    pub fn type(self: Object) ObjectType {
        return @as(ObjectType, self);
    }

    pub fn inspect(self: Object) []const u8 {
        return switch (self) {
            .INTEGER => |i| std.fmt.allocPrint(allocator, "{}", .{i.value}) catch unreachable,
            .BOOLEAN => |b| std.fmt.allocPrint(allocator, "{}", .{b.value}) catch unreachable,
            .NULL => "null",
            .STRING => |s| s.value,
            .ARRAY => |a| blk: {
                var parts = std.ArrayList([]const u8).init(allocator);
                defer parts.deinit();
                for (a.elements) |elem| {
                    parts.append(elem.inspect()) catch unreachable;
                }
                break :blk std.fmt.allocPrint(allocator, "[{}]", .{parts.items}) catch unreachable;
            },
            // Add more type-specific inspections
            else => "unimplemented",
        };
    }
};

pub const Integer = struct {
    value: i64,

    pub fn init(value: i64) Integer {
        return Integer{ .value = value };
    }
};

pub const Boolean = struct {
    value: bool,

    pub fn init(value: bool) Boolean {
        return Boolean{ .value = value };
    }
};

pub const Null = struct {
    pub fn init() Null {
        return Null{};
    }
};

pub const String = struct {
    value: []const u8,

    pub fn init(value: []const u8) String {
        return String{ .value = value };
    }
};

pub const Array = struct {
    elements: []Object,

    pub fn init(elements: []Object) Array {
        return Array{ .elements = elements };
    }
};

pub const Function = struct {
    parameters: []Ast.Identifier,
    body: *Ast.BlockStatement,
    env: *Environment, // You'll need to define this

    pub fn init(parameters: []Ast.Identifier, body: *Ast.BlockStatement, env: *Environment) Function {
        return Function{
            .parameters = parameters,
            .body = body,
            .env = env,
        };
    }
};

pub const Error = struct {
    message: []const u8,

    pub fn init(message: []const u8) Error {
        return Error{ .message = message };
    }
};

pub const ReturnValue = struct {
    value: Object,

    pub fn init(value: Object) ReturnValue {
        return ReturnValue{ .value = value };
    }
};

// Hashable trait for hash map support
pub const Hashable = struct {
    pub fn hash(self: Object) u64 {
        return switch (self) {
            .INTEGER => |i| @intCast(u64, i.value),
            .BOOLEAN => |b| if (b.value) 1 else 0,
            .STRING => |s| std.hash.Fnv1a_64.hash(s.value),
            else => 0, // Not hashable
        };
    }
};
