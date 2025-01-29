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

    // keywords
    OYA, // function
    TRUE, // true
    FALSE, // false
    ABEG, // variable decralation
    COMOT, // return from function
    IF,
    ELSE,
};

//WARN: comptimestringmap has been moved
// and idk where it is in the std,
// but i found this structture called static stringmap
// and copied it form the std tests

const KVType = struct { []const u8, TokenType };
const ComtimeMap = std.StaticStringMap(TokenType);

const keywordsSlice: []const KVType = &.{
    .{ "abeg", .ABEG },
    .{ "oya", .OYA },
    .{ "comot", .COMOT },
    .{ "true", .TRUE },
    .{ "false", .FALSE },
};

pub const Keywords = struct {
    const keywords = ComtimeMap.initComptime(keywordsSlice);

    pub fn getKeywordToken(ident: []const u8) ?TokenType {
        return keywords.get(ident);
    }
};
