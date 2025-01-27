const std = @import("std");

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
            std.debug.print("{s}\n", .{input});
        } else {
            break;
        }
    }
}

pub fn getComputerName(allocator: std.mem.Allocator) ![]const u8 {
    var buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&buffer);
    return try allocator.dupe(u8, hostname);
}

pub fn processInputSourceFile(file_path: []const u8) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    defer std.heap.page_allocator.free(buffer);

    _ = try file.readAll(buffer);
    std.debug.print("\n{s}\n", .{buffer});
}
