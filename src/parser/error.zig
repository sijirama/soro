// error.zig
const std = @import("std");
const TokenType = @import("../token/main.zig").TokenType;
const Token = @import("../token/main.zig").Token;

pub const ErrorSeverity = enum {
    Warning, // Can continue parsing
    Error, // Should try to recover
    Fatal, // Must stop parsing
};

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
    TooManyErrors,
};

pub const ParserError = struct {
    error_type: ParserErrorType,
    severity: ErrorSeverity,
    line: usize,
    column: usize,
    fileName: []const u8,
    fileDirectory: []const u8,
    expected: ?TokenType = null,
    found: ?TokenType = null,
    message: ?[]const u8 = null,

    pub fn format(self: ParserError, allocator: std.mem.Allocator) ![]const u8 {

        // severity prefix
        const severity_prefix = switch (self.severity) {
            .Warning => "WARNING: ",
            .Error => "ERROR: ",
            .Fatal => "FATAL ERROR: ",
        };

        //create the file location string
        const file_loc = try std.fmt.allocPrint(
            allocator,
            "for file '{s}' inside '{s}' [line {}, column {}]",
            .{ self.fileName, self.fileDirectory, self.line, self.column },
        );

        defer allocator.free(file_loc);

        return switch (self.error_type) {

            //format that bitch for me
            .UnexpectedToken => std.fmt.allocPrint(
                allocator,
                "{s}Abeg, I dey find {any} but I see {any} instead {s}",
                .{ severity_prefix, self.expected.?, self.found.?, file_loc },
            ),

            .NoPrefix => std.fmt.allocPrint(
                allocator,
                "{s}My Oga, I no sabi wetin to do with '{s}' {s}",
                .{ severity_prefix, self.message.?, file_loc },
            ),

            .InvalidNumber => std.fmt.allocPrint(
                allocator,
                "{s}Omo, dis number '{s}' no make sense o {s}",
                .{ severity_prefix, self.message.?, file_loc },
            ),

            .MissingToken => std.fmt.allocPrint(
                allocator,
                "{s}Abeg, where de {any}? I no see am {s}",
                .{ severity_prefix, self.expected.?, file_loc },
            ),

            .MissingSemicolon => std.fmt.allocPrint(
                allocator,
                "{s}Chaii, you forget semicolon ';' {s}",
                .{ severity_prefix, file_loc },
            ),

            .MissingRightParen => std.fmt.allocPrint(
                allocator,
                "{s}Abeg close your bracket ')' nau {s}",
                .{ severity_prefix, file_loc },
            ),

            .InvalidExpression => std.fmt.allocPrint(
                allocator,
                "{s}Wetin be dis expression? E no make sense: {s} {s}",
                .{ severity_prefix, self.message.?, file_loc },
            ),
            .TooManyErrors => std.fmt.allocPrint(
                allocator,
                "{s}Chai! Too many wahala dey this code o! I no fit continue {s}",
                .{ severity_prefix, file_loc },
            ),

            else => if (self.message) |msg|
                std.fmt.allocPrint(
                    allocator,
                    "Wahala dey o! {s} {s}",
                    .{ msg, file_loc },
                )
            else
                std.fmt.allocPrint(
                    allocator,
                    "Something no dey work well: {any} {s}",
                    .{ self.error_type, file_loc },
                ),
        };
    }
};

pub fn createError(
    error_type: ParserErrorType,
    severity: ErrorSeverity,
    token: Token,
    expected: ?TokenType,
    found: ?TokenType,
    message: ?[]const u8,
) ParserError {
    return ParserError{
        .error_type = error_type,
        .severity = severity,
        .line = token.line,
        .column = token.column,
        .fileName = token.fileName,
        .fileDirectory = token.fileDirectory,
        .expected = expected,
        .found = found,
        .message = message,
    };
}
