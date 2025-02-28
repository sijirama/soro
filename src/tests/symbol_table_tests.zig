const std = @import("std");
const testing = std.testing;
const symbol_tree = @import("../compiler/symbol_table.zig");

test "define symbols" {
    // Expected symbols
    const expected_a = symbol_tree.Symbol{
        .Name = "a",
        .Scope = symbol_tree.GLOBAL_SCOPE,
        .Index = 0,
        .IsConstant = null,
    };
    const expected_b = symbol_tree.Symbol{
        .Name = "b",
        .Scope = symbol_tree.GLOBAL_SCOPE,
        .Index = 1,
        .IsConstant = null,
    };

    // Initialize symbol table
    var symbol_table = symbol_tree.SymbolTable.init(testing.allocator);
    defer symbol_table.deinit();

    // Define symbol 'a'
    const a = try symbol_table.define("a", symbol_tree.GLOBAL_SCOPE);
    try testing.expectEqualStrings(expected_a.Name, a.Name);
    try testing.expectEqualStrings(expected_a.Scope, a.Scope);
    try testing.expectEqual(expected_a.Index, a.Index);

    // Define symbol 'b'
    const b = try symbol_table.define("b", symbol_tree.GLOBAL_SCOPE);
    try testing.expectEqualStrings(expected_b.Name, b.Name);
    try testing.expectEqualStrings(expected_b.Scope, b.Scope);
    try testing.expectEqual(expected_b.Index, b.Index);
}

test "resolve global symbols" {
    // Initialize symbol table
    var symbol_table = symbol_tree.SymbolTable.init(testing.allocator);
    defer symbol_table.deinit();

    // Define symbols
    const defined_a = try symbol_table.define("a", symbol_tree.GLOBAL_SCOPE);
    const defined_b = try symbol_table.define("b", symbol_tree.GLOBAL_SCOPE);

    // Expected symbols to resolve
    const expected = [_]symbol_tree.Symbol{
        defined_a,
        defined_b,
    };

    // Test resolving each symbol
    for (expected) |expected_sym| {
        if (symbol_table.lookup(expected_sym.Name)) |resolved_sym| {
            try testing.expectEqualStrings(expected_sym.Name, resolved_sym.Name);
            try testing.expectEqualStrings(expected_sym.Scope, resolved_sym.Scope);
            try testing.expectEqual(expected_sym.Index, resolved_sym.Index);
        } else {
            std.debug.print("Name '{s}' not resolvable\n", .{expected_sym.Name});
            return error.SymbolNotResolved;
        }
    }
}

test "define constant symbols" {
    // Initialize symbol table
    var symbol_table = symbol_tree.SymbolTable.init(testing.allocator);
    defer symbol_table.deinit();

    // Define regular and constant symbols
    const regular_var = try symbol_table.define("regular_var", symbol_tree.GLOBAL_SCOPE);
    const const_var = try symbol_table.defineConst("CONST_VAR", symbol_tree.GLOBAL_SCOPE);

    // Check regular variable
    try testing.expectEqualStrings("regular_var", regular_var.Name);
    try testing.expectEqualStrings(symbol_tree.GLOBAL_SCOPE, regular_var.Scope);
    try testing.expectEqual(@as(usize, 0), regular_var.Index);
    try testing.expectEqual(null, regular_var.IsConstant);

    // Check constant variable
    try testing.expectEqualStrings("CONST_VAR", const_var.Name);
    try testing.expectEqualStrings(symbol_tree.GLOBAL_SCOPE, const_var.Scope);
    try testing.expectEqual(@as(usize, 1), const_var.Index);
    try testing.expectEqual(true, const_var.IsConstant);

    // Verify lookup works for both
    if (symbol_table.lookup("regular_var")) |resolved_var| {
        try testing.expectEqual(null, resolved_var.IsConstant);
    } else {
        return error.SymbolNotResolved;
    }

    if (symbol_table.lookup("CONST_VAR")) |resolved_const| {
        try testing.expectEqual(true, resolved_const.IsConstant);
    } else {
        return error.SymbolNotResolved;
    }
}
