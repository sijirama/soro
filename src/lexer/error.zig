const std = @import("std");

pub const LexerError = error{ InvalidString, UnterminatedString, UnterminatedComment } || std.mem.Allocator.Error;

// Define ANSI color codes
const Color = struct {
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const cyan = "\x1b[36m";
    const reset = "\x1b[0m";
    const bold = "\x1b[1m";
};

pub fn handleLexerError(err: LexerError, line: u32, column: u32, input: []const u8, allocator: std.mem.Allocator) !void {
    std.debug.print("\n{s}Wahala: {s}", .{ Color.red, Color.reset });
    switch (err) {
        LexerError.InvalidString => {
            std.debug.print("{s}Na wrong format you put for string for line {d}, column {d}{s}\n", .{ Color.red, line, column, Color.reset });
        },
        LexerError.UnterminatedString => {
            std.debug.print("{s}You never close your string quote for line {d}, column {d}{s}\n", .{ Color.red, line, column, Color.reset });
        },
        else => {
            std.debug.print("{s}Something don scatter for line {d}, column {d} wey we never see before{s}\n", .{ Color.red, line, column, Color.reset });
            return err;
        },
    }

    // Extract and print the line where the error occurred
    if (try getErrorLine(input, line)) |errorLine| {
        std.debug.print("{s}\n", .{errorLine});

        // Create the marker line with the arrow
        const marker = try createMarkerLine(errorLine.len, column, allocator);
        defer allocator.free(marker);

        std.debug.print("{s}\n", .{marker});
    }
}

fn getErrorLine(input: []const u8, targetLine: u32) !?[]const u8 {
    var current_line: u32 = 1;
    var start: usize = 0;

    // Find the start of the target line
    for (input, 0..) |c, i| {
        if (current_line == targetLine) {
            start = i;
            break;
        }
        if (c == '\n') current_line += 1;
    }

    // If we didn't find the target line, return null
    if (current_line != targetLine) return null;

    // Find the end of the line
    var end = start;
    while (end < input.len and input[end] != '\n') : (end += 1) {}

    return input[start..end];
}

fn createMarkerLine(lineLength: usize, column: u32, allocator: std.mem.Allocator) ![]u8 {
    var marker = try allocator.alloc(u8, lineLength);
    @memset(marker, ' ');

    // Calculate where to place the arrow
    const arrowPos = @min(column -| 1, lineLength -| 1);
    marker[arrowPos] = '^';

    return marker;
}
