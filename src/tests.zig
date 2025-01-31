pub const lexerTests = @import("./tests/lexer_tests.zig");
pub const tokenTests = @import("./tests/token_tests.zig");
pub const astTests = @import("./tests/ast_tests.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
