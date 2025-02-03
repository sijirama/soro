const std = @import("std");
const Lexer = @import("lexer/main.zig").Lexer;
const LexerUtils = @import("lexer/utils.zig");
const Parser = @import("parser/main.zig").Parser;

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
    std.debug.print("How far? Wetin you wan do today?\n\n", .{});

    var buffer: [256]u8 = undefined;
    while (true) {
        std.debug.print(">> ", .{});
        if (try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {

            // start compilation
            var lexer = Lexer.init(allocator, input, "repl", "repl");
            defer lexer.deinit();

            var parser = Parser.init(allocator, &lexer);

            defer {
                if (parser.errors.items.len > 0) {
                    std.debug.print("\nREPL: Total of {} parser errors\n", .{parser.errors.items.len});
                    parser.printErrors();
                }
                parser.deinit();
            }

            var program = try parser.parseProgram();
            defer program.deinit();

            if (parser.errors.items.len == 0) {
                std.debug.print("\nREPL: Total of {d} statements\n", .{program.statements.items.len});
                if (program.statements.items.len > 0) {
                    std.debug.print("\nREPL: {}\n", .{program.statements.items[0]});
                }
            }
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

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    if (parser.errors.items.len > 0) {
        parser.printErrors();
    }

    var program = try parser.parseProgram();
    defer program.deinit();

    std.debug.print("\n{s}\n", .{output});
}

pub fn getComputerName(allocator: std.mem.Allocator) ![]const u8 {
    var buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&buffer);
    return try allocator.dupe(u8, hostname);
}
