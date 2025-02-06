const std = @import("std");

// Define the types supported by the language
pub const Type = enum {
    Int,
    Float,
    Bool,
    String,
    Interface,
    Void,
    Any,
    Error,
    Unknown, // For inferred or unknown types
};

// Convert a type to a string for error messages
pub fn typeToString(type_: Type) []const u8 {
    return switch (type_) {
        .Int => "int",
        .Float => "float",
        .Bool => "bool",
        .String => "string",
        .Interface => "interface",
        .Void => "void",
        .Any => "any",
        .Error => "error",
        .Unknown => "unknown",
    };
}

const BuiltinKVType = struct { []const u8, Type };
const BuiltinTypeMap = std.StaticStringMap(Type);

const typeKeywords: []const BuiltinKVType = &.{
    .{ "int", .Int },
    .{ "float", .Float },
    .{ "bool", .Bool },
    .{ "string", .String },
    .{ "interface", .Interface },
    .{ "void", .Void },
    .{ "any", .Any },
    .{ "error", .Error },
    .{ "unknown", .Unknown },
};

//INFO: generally for the lexer to map strings to the int type
pub const TypeKeywords = struct {
    const builtinTypes = BuiltinTypeMap.initComptime(typeKeywords);
    pub fn getType(ident: []const u8) ?Type {
        return builtinTypes.get(ident);
    }
};
