// error.zig
const std = @import("std");
const TokenType = @import("../token/main.zig").TokenType;
const Token = @import("../token/main.zig").Token;

pub const ParserErrorType = enum {
    UnexpectedToken,
    MissingToken,
    InvalidExpression,
    InvalidNumber,
    InvalidIdentifier,
    InvalidPrefixOperator,
    InvalidInfixOperator,
    InvalidTypeAnnotation,
    MissingSemicolon,
    MissingRightParen,
    NoPrefix,
};

pub const ParserError = struct {
    error_type: ParserErrorType,
    line: usize,
    column: usize,
    fileName: []const u8,
    fileDirectory: []const u8,
    expected: ?TokenType = null,
    found: ?TokenType = null,
    message: ?[]const u8 = null,

    pub fn format(self: ParserError, allocator: std.mem.Allocator) ![]const u8 {
        // First create the file location string
        const file_loc = try std.fmt.allocPrint(allocator, "for file '{s}' inside '{s}' [line {}, column {}]", .{ self.fileName, self.fileDirectory, self.line, self.column });
        defer allocator.free(file_loc);

        return switch (self.error_type) {

            //format that bitch for me
            .UnexpectedToken => std.fmt.allocPrint(allocator, "Abeg, I dey find {any} but I see {any} instead {s}", .{ self.expected.?, self.found.?, file_loc }),

            .NoPrefix => std.fmt.allocPrint(allocator, "My brother/sister, I no sabi wetin to do with '{s}' {s}", .{ self.message.?, file_loc }),

            .InvalidNumber => std.fmt.allocPrint(allocator, "Omo, dis number '{s}' no make sense o {s}", .{ self.message.?, file_loc }),

            .MissingToken => std.fmt.allocPrint(allocator, "Abeg, where de {any}? I no see am {s}", .{ self.expected.?, file_loc }),

            .MissingSemicolon => std.fmt.allocPrint(allocator, "Chaii, you forget semicolon ';' {s}", .{file_loc}),

            .MissingRightParen => std.fmt.allocPrint(allocator, "Abeg close your bracket ')' nau {s}", .{file_loc}),

            .InvalidExpression => std.fmt.allocPrint(allocator, "Wetin be dis expression? E no make sense: {s} {s}", .{ self.message.?, file_loc }),

            else => if (self.message) |msg|
                std.fmt.allocPrint(allocator, "Wahala dey o! {s} {s}", .{ msg, file_loc })
            else
                std.fmt.allocPrint(allocator, "Something no dey work well: {any} {s}", .{ self.error_type, file_loc }),
        };
    }
};

pub fn createError(
    error_type: ParserErrorType,
    token: Token,
    expected: ?TokenType,
    found: ?TokenType,
    message: ?[]const u8,
) ParserError {
    return ParserError{
        .error_type = error_type,
        .line = token.line,
        .column = token.column,
        .fileName = token.fileName,
        .fileDirectory = token.fileDirectory,
        .expected = expected,
        .found = found,
        .message = message,
    };
}
