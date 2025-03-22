const std = @import("std");
const Object = @import("./main.zig").Object;

pub fn printObject(obj: Object) void {
    switch (obj) {
        .Integer => |int| std.debug.print("{d}", .{int.value}),
        .Float => |float| std.debug.print("{d}", .{float.value}),
        .Boolean => |boolean| std.debug.print("{}", .{boolean.value}),
        .Null => std.debug.print("null", .{}),
        .ReturnValue => |ret| printObject(ret.value.*),
        .Error => |err| std.debug.print("ERROR: {s}", .{err.message}),
        .String => |str| std.debug.print("{s}", .{str.value}),
        .Array => |array| {
            std.debug.print("[ ", .{});
            for (array.elements) |value| {
                std.debug.print(" {any} ", .{value});
            }
            std.debug.print(" ]", .{});
        },
    }
    std.debug.print("\n", .{});
}
