pub const lexerTests = @import("./tests/lexer_tests.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
