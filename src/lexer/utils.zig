const std = @import("std");
const Token = @import("../token/main.zig").Token;
const TokenUtils = @import("../token/utils.zig");

// Standalone function to convert tokens to string
pub fn tokensToString(allocator: std.mem.Allocator, tokens: []const Token) ![]const u8 {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const writer = output.writer();
    for (tokens) |token| {
        // Get the formatted string
        const tokenStr = try TokenUtils.tokenToDetailedStringFormat(token, allocator);
        defer allocator.free(tokenStr);

        try writer.print("{s}\n", .{tokenStr});
    }

    return try output.toOwnedSlice();
}
