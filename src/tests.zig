pub const lexerTests = @import("./tests/lexer_tests.zig");
pub const tokenTests = @import("./tests/token_tests.zig");
pub const astTests = @import("./tests/ast_tests.zig");
pub const parserTests = @import("./tests/parser_tests.zig");
pub const codeTests = @import("./tests/code_tests.zig");
//pub const compilerTests = @import("./tests/compiler_test.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
