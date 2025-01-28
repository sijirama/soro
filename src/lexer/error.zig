const std = @import("std");

pub const LexerError = error{ InvalidString, UnterminatedString } || std.mem.Allocator.Error;

pub fn handleLexerError(err: LexerError, line: u32, column: u32, input: []const u8, allocator: std.mem.Allocator) !void {
    // Print the error message
    switch (err) {
        LexerError.InvalidString => {
            std.debug.print("Error: Invalid string escape sequence at line {d}, column {d}\n", .{ line, column });
        },
        LexerError.UnterminatedString => {
            std.debug.print("Error: Unterminated string literal at line {d}, column {d}\n", .{ line, column });
        },
        else => {
            std.debug.print("Unknown lexer error at line {d}, column {d}\n", .{ line, column });
            return err;
        },
    }

    // Extract the line where the error occurred
    const lineStart = getLineStart(input, line);
    const lineEnd = getLineEnd(input, line);

    // Print the line of input
    const lineSlice = lineStart[0..lineEnd.len];
    std.debug.print("{s}\n", .{lineSlice});

    // Construct the marker
    const markerLength = lineSlice.len;
    const marker = try allocator.alloc(u8, markerLength);
    defer allocator.free(marker);

    // Initialize the marker with spaces
    for (marker) |*m| {
        m.* = ' ';
    }

    // Place the `^` at the correct column
    if (column - 1 < markerLength) {
        marker[column - 1] = '^';
    }

    // Print the marker
    std.debug.print("{s}\n", .{marker});
}

// Helper function to get the start of the line
fn getLineStart(input: []const u8, line: u32) []const u8 {
    var currentLine: usize = 1;
    var position: usize = 0;
    while (currentLine < line and position < input.len) {
        if (input[position] == '\n') {
            currentLine += 1;
        }
        position += 1;
    }
    return input[position..];
}

// Helper function to get the end of the line
fn getLineEnd(input: []const u8, line: u32) []const u8 {
    var currentLine: usize = 1;
    var position: usize = 0;
    while (currentLine < line and position < input.len) {
        if (input[position] == '\n') {
            currentLine += 1;
        }
        position += 1;
    }
    var endPosition: usize = position;
    while (endPosition < input.len and input[endPosition] != '\n') {
        endPosition += 1;
    }
    return input[position..endPosition];
}
