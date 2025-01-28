const std = @import("std");
const Lexer = @import("lexer/main.zig").Lexer;
const LexerUtils = @import("lexer/utils.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        try processInputSourceFile(args[1]);
    } else {
        try replStart();
    }
}

pub fn replStart() !void {
    const allocator = std.heap.page_allocator;
    const username = try getComputerName(allocator);
    defer allocator.free(username);

    std.debug.print("Welcome to soro, {s}!\n", .{username});
    std.debug.print("How far? Wetin you wan do today?\n", .{});

    var buffer: [256]u8 = undefined;
    while (true) {
        std.debug.print(">> ", .{});
        if (try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {
            var lexer = Lexer.init(allocator, input, "repl", "repl");
            defer lexer.deinit();

            const tokens = try lexer.tokenize();
            defer allocator.free(tokens);

            const output = try LexerUtils.tokensToString(allocator, tokens);
            defer allocator.free(output);

            std.debug.print("\n{s}\n", .{output});
        } else {
            break;
        }
    }
}

pub fn processInputSourceFile(file_path: []const u8) !void {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const absolute_path = try std.fs.cwd().realpathAlloc(allocator, file_path);
    defer allocator.free(absolute_path);

    const dir_path = std.fs.path.dirname(absolute_path) orelse ".";
    const file_name = std.fs.path.basename(absolute_path);

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    defer std.heap.page_allocator.free(buffer);

    _ = try file.readAll(buffer);

    var lexer = Lexer.init(allocator, buffer, file_name, dir_path);
    defer lexer.deinit();

    const tokens = try lexer.tokenize();
    defer allocator.free(tokens);

    const output = try LexerUtils.tokensToString(allocator, tokens);
    defer allocator.free(output);

    std.debug.print("\n{s}\n", .{output});
}

pub fn getComputerName(allocator: std.mem.Allocator) ![]const u8 {
    var buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&buffer);
    return try allocator.dupe(u8, hostname);
}
