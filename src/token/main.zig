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
    EOF,
    ERROR,
    ILLEGAL,

    STRING,
    INT,
    FLOAT,

    SEMICOLON, // ;
    COLON, // :
    LPAREN, // (
    RPAREN, // )
    LBRACE, // {
    RBRACE, // }
    LBRACKET, // [
    RBRACKET, // ]
    COMMA, // ,

    PLUS, // +
    MINUS, // -
};
