const std = @import("std");
const Lexer = @import("lexer/main.zig").Lexer;
const LexerUtils = @import("lexer/utils.zig");
const Parser = @import("parser/main.zig").Parser;
const compiler = @import("compiler/main.zig");
const VM = @import("vm/main.zig").VM;
const PrintObject = @import("object/utils.zig").printObject;
const symbol = @import("compiler/symbol_table.zig");
const object = @import("object/main.zig");

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

pub fn getComputerName(allocator: std.mem.Allocator) ![]const u8 {
    var buffer: [std.posix.HOST_NAME_MAX]u8 = undefined;
    const hostname = try std.posix.gethostname(&buffer);
    return try allocator.dupe(u8, hostname);
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

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    var comp = compiler.Compiler.init(allocator);
    defer comp.deinit();

    try comp.compile(program);
    const bytecode = try comp.bytecode();

    defer {
        bytecode.deinit();
        allocator.destroy(bytecode);
    }

    var vm = VM.init(allocator, bytecode);
    defer vm.deinit(allocator);

    try vm.run();
    const stackElem = vm.LastPoppedStackElem() orelse return error.StackEmpty;

    PrintObject(stackElem);
}

pub fn replStart() !void {
    const allocator = std.heap.page_allocator;
    const username = try getComputerName(allocator);
    defer allocator.free(username);

    std.debug.print("Welcome to soro, {s}!\n", .{username});
    std.debug.print("How far? Wetin you wan do today?\n\n", .{});

    // Initialize persistent state
    var symbolTable = symbol.SymbolTable.init(allocator);
    defer symbolTable.deinit();

    // Create persistent constants pool
    var constantPool = std.ArrayList(object.Object).init(allocator);
    defer constantPool.deinit();

    // Create persistent globals
    var globals = std.ArrayList(object.Object).init(allocator);
    defer globals.deinit();

    var buffer: [256]u8 = undefined;
    while (true) {
        std.debug.print(">> ", .{});
        if (try std.io.getStdIn().reader().readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {

            // start compilation
            var lexer = Lexer.init(allocator, input, "repl", "repl");
            defer lexer.deinit();

            var parser = Parser.init(allocator, &lexer);
            defer parser.deinit();

            var program = try parser.parseProgram();
            defer program.deinit();

            var comp = compiler.Compiler.initWithState(allocator, symbolTable, constantPool);

            //don't deinit the shared resources
            //defer comp.deinit();
            defer {
                // Just deinit the instructions
                comp.instructions.deinit();
            }

            try comp.compile(program);
            const bytecode = try comp.bytecode();

            defer {
                bytecode.deinit();
                allocator.destroy(bytecode);
            }

            // Update our constant pool with any new constants from this compilation
            constantPool = comp.constantPool;

            var vm = VM.initWithGlobals(allocator, bytecode, globals);

            //defer vm.deinit(allocator);
            defer {
                // Just free the stack, not the globals
                allocator.free(vm.stack);
            }

            try vm.run();

            // Update our globals with any new globals from this VM execution
            globals = vm.globals;

            const stackElem = vm.LastPoppedStackElem() orelse return error.StackEmpty;

            std.debug.print("\n\n GLOBALS: .{any} \n\n", .{globals});
            std.debug.print("GLOBALS LENGTH: .{any} \n\n", .{globals.items.len});
            std.debug.print("CONSTANTS: .{any} \n\n", .{constantPool});
            std.debug.print("CONSTANTS LENGTH: .{any} \n\n", .{constantPool.items.len});

            PrintObject(stackElem);
        } else {
            break;
        }
    }
}
