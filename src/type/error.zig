const std = @import("std");

// Custom error types for the type checker
pub const TypeError = error{
    TypeMismatch,
    UndefinedVariable,
    InvalidOperation,
    UnknownType,
};

// Error formatter for Nigerian Pidgin-inspired messages
pub fn formatTypeError(err: TypeError, writer: anytype) !void {
    switch (err) {
        error.TypeMismatch => try writer.print("Omo! This thing no match o. You mix two different types wey no fit work together.", .{}),
        error.UndefinedVariable => try writer.print("Abeg, which variable be this? I no see am for where I dey look o.", .{}),
        error.InvalidOperation => try writer.print("Wetin you wan do no make sense. You no fit do this kind operation.", .{}),
        error.UnknownType => try writer.print("I no sabi this type o. Wetin be this one?", .{}),
    }
}

// Helper function to print errors
pub fn printTypeError(err: TypeError) void {
    std.debug.print("Type Error: ", .{});
    formatTypeError(err, std.io.getStdErr().writer()) catch {};
    std.debug.print("\n", .{});
}
