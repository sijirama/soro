const std = @import("std");
const Token = @import("./main.zig").Token;

pub fn tokenToDetailedStringFormat(token: Token, allocator: std.mem.Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "Token(type: {any}, value: {s}, line: {d}, column: {d}, file: {s}, dir: {s})", .{ token.type, token.value, token.line, token.column, token.fileName, token.fileDirectory });
}
