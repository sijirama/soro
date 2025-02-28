pub const astTests = @import("./tests/ast_tests.zig");
pub const codeTests = @import("./tests/code_tests.zig");
pub const compilerTests = @import("./tests/compiler_test.zig");
pub const symbolTreeTests = @import("./tests/symbol_table_tests.zig");
pub const lexerTests = @import("./tests/lexer_tests.zig");
pub const parserTests = @import("./tests/parser_tests.zig");
pub const tokenTests = @import("./tests/token_tests.zig");
pub const vmTests = @import("./tests/vm_tests.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
