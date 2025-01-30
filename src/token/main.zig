const std = @import("std");

pub const Token = struct {
    type: TokenType,
    value: []const u8,
    line: usize,
    column: usize,
    fileName: []const u8,
    fileDirectory: []const u8,
};

pub const TokenType = enum {
    ILLEGAL,
    EOF,
    ERROR,

    IDENT,
    STRING,
    INTEGER,
    FLOAT,

    ASSIGN, // =
    PLUS, // +
    MINUS, // -
    BANG, // !
    ASTERISK, // *
    SLASH, // /
    GREATER_THAN, // >
    LESS_THAN, // <

    COMMA, // ,
    COLON, // :
    SEMICOLON, // ;
    LPAREN, // (
    RPAREN, // )
    LBRACE, // {
    RBRACE, // }
    LBRACKET, // [
    RBRACKET, // ]

    EQUAL, // ==
    NOT_EQUAL, // !=

    // builtin types
    INTEGER_TYPE,
    STRING_TYPE,
    BOOL_TYPE,
    FLOAT_TYPE,
    INTERFACE_TYPE,
    VOID_TYPE,
    ANY_TYPE,
    ERROR_TYPE,

    // keywords
    ABEG, // variable decralation
    LOCK, // make declarations immutable e.g abeg lock name := "sijibomi"
    OYA, // function
    COMOT, // return from function
    TRUE, // true
    FALSE, // false
    IF,
    ELSE,
    AND, // instead of && which i absolutely hate even more
    OR, // instead of || which i hate with mylife
    OR_ELSE, // dubbing zigs orelse for inline conditionals
};

//WARN: comptimestringmap has been moved
// and idk where it is in the std,
// but i found this structture called static stringmap
// and copied it form the std tests

const KVType = struct { []const u8, TokenType };
const ComtimeMap = std.StaticStringMap(TokenType);

const keywordsSlice: []const KVType = &.{
    .{ "abeg", .ABEG },
    .{ "lock", .LOCK },
    .{ "oya", .OYA },
    .{ "comot", .COMOT },
    .{ "true", .TRUE },
    .{ "false", .FALSE },
    .{ "if", .IF },
    .{ "else", .ELSE },
    .{ "and", .AND },
    .{ "or", .OR },
    .{ "orelse", .OR_ELSE },
};

pub const Keywords = struct {
    const keywords = ComtimeMap.initComptime(keywordsSlice);

    pub fn getKeywordToken(ident: []const u8) ?TokenType {
        return keywords.get(ident);
    }
};

const BuiltinKVType = struct { []const u8, TokenType };
const BuiltinTypeMap = std.StaticStringMap(TokenType);

const builtinTypesSlice: []const BuiltinKVType = &.{
    .{ "int", .INTEGER_TYPE },
    .{ "string", .STRING_TYPE },
    .{ "bool", .BOOL_TYPE },
    .{ "float", .FLOAT_TYPE },
    .{ "interface", .INTERFACE_TYPE },
    .{ "void", .VOID_TYPE },
    .{ "any", .ANY_TYPE },
    .{ "error", .ERROR_TYPE },
};

pub const BuiltinTypes = struct {
    const builtinTypes = BuiltinTypeMap.initComptime(builtinTypesSlice);

    pub fn getBuiltinTypeToken(ident: []const u8) ?TokenType {
        return builtinTypes.get(ident);
    }
};
