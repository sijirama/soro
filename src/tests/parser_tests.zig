const std = @import("std");
const testing = std.testing;
const Lexer = @import("../lexer/main.zig").Lexer;
const Parser = @import("../parser/main.zig").Parser;
const ast = @import("../ast/ast.zig");
const Type = @import("../type/types.zig").Type;

test "Parser: Does the bitch compile" {
    const input =
        \\abeg age int = 50;
        \\abeg name := "Siji";
        \\abeg lock pi = 3.14;
        \\abeg lock is_valid := true;
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 4);
}

test "Parser: AbegStatement with integer literal" {
    const input = "abeg age = 5;";
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 1);

    const stmt = program.statements.items[0];
    try testing.expect(stmt == .abeg_statement);

    const abeg_stmt = stmt.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt.name.value, "age");
    try testing.expectEqual(abeg_stmt.is_locked, false);
    try testing.expectEqual(abeg_stmt.is_inferred, false);

    const expr = abeg_stmt.value.*;
    try testing.expect(expr == .integer_literal);
    try testing.expectEqual(expr.integer_literal.value, 5);
}

test "Parser: AbegStatement with boolean literal" {
    const input = "abeg is_true = true;";
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 1);

    const stmt = program.statements.items[0];
    try testing.expect(stmt == .abeg_statement);

    const abeg_stmt = stmt.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt.name.value, "is_true");
    try testing.expectEqual(abeg_stmt.is_locked, false);
    try testing.expectEqual(abeg_stmt.is_inferred, false);

    const expr = abeg_stmt.value.*;
    try testing.expect(expr == .boolean_literal);
    try testing.expectEqual(expr.boolean_literal.value, true);
}

test "Parser: ComotStatement with integer literal" {
    const input = "comot 42;";
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 1);

    const stmt = program.statements.items[0];
    try testing.expect(stmt == .comot_statement);

    const comot_stmt = stmt.comot_statement;
    const expr = comot_stmt.value.*;
    try testing.expect(expr == .integer_literal);
    try testing.expectEqual(expr.integer_literal.value, 42);
}

test "Parser: ExpressionStatement with infix expression" {
    const input = "5 + 5;";
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 1);

    const stmt = program.statements.items[0];
    try testing.expect(stmt == .expression_statement);

    const expr_stmt = stmt.expression_statement;
    const expr = expr_stmt.expression.*;
    try testing.expect(expr == .infix_expression);

    const infix_expr = expr.infix_expression;
    try testing.expectEqualStrings(infix_expr.operator, "+");

    const left = infix_expr.left.*;
    try testing.expect(left == .integer_literal);
    try testing.expectEqual(left.integer_literal.value, 5);

    const right = infix_expr.right.*;
    try testing.expect(right == .integer_literal);
    try testing.expectEqual(right.integer_literal.value, 5);
}

test "Parser: ExpressionStatement with prefix expression" {
    const input = "!true;";
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 1);

    const stmt = program.statements.items[0];
    try testing.expect(stmt == .expression_statement);

    const expr_stmt = stmt.expression_statement;
    const expr = expr_stmt.expression.*;
    try testing.expect(expr == .prefix_expression);

    const prefix_expr = expr.prefix_expression;
    try testing.expectEqualStrings(prefix_expr.operator, "!");

    const right = prefix_expr.right.*;
    try testing.expect(right == .boolean_literal);
    try testing.expectEqual(right.boolean_literal.value, true);
}

test "Parser: Mixed AbegStatements and Expressions" {
    const input =
        \\abeg x = 10;
        \\x + 5;
        \\abeg lock y := 20;
        \\y * 2;
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 4);

    // Test first statement: abeg x = 10;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "x");
    try testing.expectEqual(abeg_stmt1.type_annotation, null); // Inferred type
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, false);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .integer_literal);
    try testing.expectEqual(expr1.integer_literal.value, 10);

    // Test second statement: x + 5;
    const stmt2 = program.statements.items[1];
    try testing.expect(stmt2 == .expression_statement);

    const expr_stmt2 = stmt2.expression_statement;
    const expr2 = expr_stmt2.expression.*;
    try testing.expect(expr2 == .infix_expression);

    const infix_expr2 = expr2.infix_expression;
    try testing.expectEqualStrings(infix_expr2.operator, "+");

    const left2 = infix_expr2.left.*;
    try testing.expect(left2 == .identifier);
    try testing.expectEqualStrings(left2.identifier.value, "x");

    const right2 = infix_expr2.right.*;
    try testing.expect(right2 == .integer_literal);
    try testing.expectEqual(right2.integer_literal.value, 5);

    // Test third statement: abeg lock y := 20;
    const stmt3 = program.statements.items[2];
    try testing.expect(stmt3 == .abeg_statement);

    const abeg_stmt3 = stmt3.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt3.name.value, "y");
    try testing.expectEqual(abeg_stmt3.type_annotation, null); // Inferred type
    try testing.expectEqual(abeg_stmt3.is_locked, true);
    try testing.expectEqual(abeg_stmt3.is_inferred, true);

    const expr3 = abeg_stmt3.value.*;
    try testing.expect(expr3 == .integer_literal);
    try testing.expectEqual(expr3.integer_literal.value, 20);

    // Test fourth statement: y * 2;
    const stmt4 = program.statements.items[3];
    try testing.expect(stmt4 == .expression_statement);

    const expr_stmt4 = stmt4.expression_statement;
    const expr4 = expr_stmt4.expression.*;
    try testing.expect(expr4 == .infix_expression);

    const infix_expr4 = expr4.infix_expression;
    try testing.expectEqualStrings(infix_expr4.operator, "*");

    const left4 = infix_expr4.left.*;
    try testing.expect(left4 == .identifier);
    try testing.expectEqualStrings(left4.identifier.value, "y");

    const right4 = infix_expr4.right.*;
    try testing.expect(right4 == .integer_literal);
    try testing.expectEqual(right4.integer_literal.value, 2);
}

test "Parser: Literals - Integer, Boolean, String, and Float" {
    const input =
        \\abeg age = 42;
        \\abeg is_active = true;
        \\abeg name = "Siji";
        \\abeg pi = 3.14;
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 4);

    // Test first statement: abeg age = 42;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "age");
    try testing.expectEqual(abeg_stmt1.type_annotation, null);
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, false);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .integer_literal);
    try testing.expectEqual(expr1.integer_literal.value, 42);

    // Test second statement: abeg is_active = true;
    const stmt2 = program.statements.items[1];
    try testing.expect(stmt2 == .abeg_statement);

    const abeg_stmt2 = stmt2.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt2.name.value, "is_active");
    try testing.expectEqual(abeg_stmt2.type_annotation, null);
    try testing.expectEqual(abeg_stmt2.is_locked, false);
    try testing.expectEqual(abeg_stmt2.is_inferred, false);

    const expr2 = abeg_stmt2.value.*;
    try testing.expect(expr2 == .boolean_literal);
    try testing.expectEqual(expr2.boolean_literal.value, true);

    // Test third statement: abeg name = "Siji";
    const stmt3 = program.statements.items[2];
    try testing.expect(stmt3 == .abeg_statement);

    const abeg_stmt3 = stmt3.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt3.name.value, "name");
    try testing.expectEqual(abeg_stmt3.type_annotation, null);
    try testing.expectEqual(abeg_stmt3.is_locked, false);
    try testing.expectEqual(abeg_stmt3.is_inferred, false);

    const expr3 = abeg_stmt3.value.*;
    try testing.expect(expr3 == .string_literal);
    try testing.expectEqualStrings(expr3.string_literal.value, "Siji");

    // Test fourth statement: abeg pi = 3.14;
    const stmt4 = program.statements.items[3];
    try testing.expect(stmt4 == .abeg_statement);

    const abeg_stmt4 = stmt4.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt4.name.value, "pi");
    try testing.expectEqual(abeg_stmt4.type_annotation, null);
    try testing.expectEqual(abeg_stmt4.is_locked, false);
    try testing.expectEqual(abeg_stmt4.is_inferred, false);

    const expr4 = abeg_stmt4.value.*;
    try testing.expect(expr4 == .float_literal); // Assuming float_literal exists
    try testing.expectEqual(expr4.float_literal.value, 3.14);
}

test "Parser: Mixed Literals in Expressions" {
    const input =
        \\abeg result := (42 + 3.14) * true;
        \\abeg str_concat = "Hello, " + "World!";
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 2);

    // Test first statement: abeg result = (42 + 3.14) * true;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "result");
    try testing.expectEqual(abeg_stmt1.type_annotation, null);
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, true);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .infix_expression);

    const infix_expr1 = expr1.infix_expression;
    try testing.expectEqualStrings(infix_expr1.operator, "*");

    const left1 = infix_expr1.left.*;
    try testing.expect(left1 == .infix_expression);

    const nested_infix = left1.infix_expression;
    try testing.expectEqualStrings(nested_infix.operator, "+");

    const nested_left = nested_infix.left.*;
    try testing.expect(nested_left == .integer_literal);
    try testing.expectEqual(nested_left.integer_literal.value, 42);

    const nested_right = nested_infix.right.*;
    try testing.expect(nested_right == .float_literal);
    try testing.expectEqual(nested_right.float_literal.value, 3.14);

    const right1 = infix_expr1.right.*;
    try testing.expect(right1 == .boolean_literal);
    try testing.expectEqual(right1.boolean_literal.value, true);

    // Test second statement: abeg str_concat = "Hello, " + "World!";
    const stmt2 = program.statements.items[1];
    try testing.expect(stmt2 == .abeg_statement);

    const abeg_stmt2 = stmt2.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt2.name.value, "str_concat");
    try testing.expectEqual(abeg_stmt2.type_annotation, null);
    try testing.expectEqual(abeg_stmt2.is_locked, false);
    try testing.expectEqual(abeg_stmt2.is_inferred, false);

    const expr2 = abeg_stmt2.value.*;
    try testing.expect(expr2 == .infix_expression);

    const infix_expr2 = expr2.infix_expression;
    try testing.expectEqualStrings(infix_expr2.operator, "+");

    const left2 = infix_expr2.left.*;
    try testing.expect(left2 == .string_literal);
    try testing.expectEqualStrings(left2.string_literal.value, "Hello, ");

    const right2 = infix_expr2.right.*;
    try testing.expect(right2 == .string_literal);
    try testing.expectEqualStrings(right2.string_literal.value, "World!");
}

test "Parser: Abeg Declaration with Types " {
    const input =
        \\abeg age int = 50;
        \\abeg lock name string = "Siji";
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    // Test first statement: abeg age int = 50;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "age");
    try testing.expectEqual(abeg_stmt1.type_annotation, Type.Int);
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, false);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .integer_literal);
    try testing.expectEqual(expr1.integer_literal.value, 50);

    // Test second statement: abeg name := "Siji";
    const stmt2 = program.statements.items[1];
    try testing.expect(stmt2 == .abeg_statement);

    const abeg_stmt2 = stmt2.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt2.name.value, "name");
    try testing.expectEqual(abeg_stmt2.type_annotation, Type.String); // Inferred type
    try testing.expectEqual(abeg_stmt2.is_locked, true);

    const expr2 = abeg_stmt2.value.*;
    try testing.expect(expr2 == .string_literal);
    try testing.expectEqualStrings(expr2.string_literal.value, "Siji");
}

test "Parser: Multiple AbegStatements with variety" {
    const input =
        \\abeg age int = 50;
        \\abeg name := "Siji";
        \\abeg lock pi = 3.14;
        \\abeg lock is_valid := true;
    ;
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    try testing.expectEqual(program.statements.items.len, 4);

    // Test first statement: abeg age int = 50;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "age");
    try testing.expectEqual(abeg_stmt1.type_annotation, Type.Int); // Assuming Type.int exists
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, false);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .integer_literal);
    try testing.expectEqual(expr1.integer_literal.value, 50);

    // Test second statement: abeg name := "Siji";
    const stmt2 = program.statements.items[1];
    try testing.expect(stmt2 == .abeg_statement);

    const abeg_stmt2 = stmt2.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt2.name.value, "name");
    try testing.expectEqual(abeg_stmt2.type_annotation, null); // Inferred type
    try testing.expectEqual(abeg_stmt2.is_locked, false);
    try testing.expectEqual(abeg_stmt2.is_inferred, true);

    const expr2 = abeg_stmt2.value.*;
    try testing.expect(expr2 == .string_literal);
    try testing.expectEqualStrings(expr2.string_literal.value, "Siji");

    // Test third statement: abeg lock pi = 3.14;
    const stmt3 = program.statements.items[2];
    try testing.expect(stmt3 == .abeg_statement);

    const abeg_stmt3 = stmt3.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt3.name.value, "pi");
    try testing.expectEqual(abeg_stmt3.type_annotation, null); // Inferred type
    try testing.expectEqual(abeg_stmt3.is_locked, true);
    try testing.expectEqual(abeg_stmt3.is_inferred, false);

    const expr3 = abeg_stmt3.value.*;
    try testing.expect(expr3 == .float_literal); // Assuming float_literal exists
    //try testing.expectEqual(expr3.float_literal.value, 3.14);

    // Test fourth statement: abeg lock is_valid := true;
    const stmt4 = program.statements.items[3];
    try testing.expect(stmt4 == .abeg_statement);

    const abeg_stmt4 = stmt4.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt4.name.value, "is_valid");
    try testing.expectEqual(abeg_stmt4.type_annotation, null); // Inferred type
    try testing.expectEqual(abeg_stmt4.is_locked, true);
    try testing.expectEqual(abeg_stmt4.is_inferred, true);

    const expr4 = abeg_stmt4.value.*;
    try testing.expect(expr4 == .boolean_literal);
    try testing.expectEqual(expr4.boolean_literal.value, true);
}

test "Parser: Crazy Literals - Negative, Large Numbers, and Escaped Strings" {
    const input =
        \\abeg negative = -42;
        \\abeg escaped_str = "Hello\\nWorld\\t!";
        //\\abeg large_num = 1234567890123456789;
    ;

    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator, input, "test.soro", ".");
    defer lexer.deinit();

    var parser = Parser.init(allocator, &lexer);
    defer parser.deinit();

    var program = try parser.parseProgram();
    defer program.deinit();

    // try testing.expectEqual(program.statements.items.len, 3);

    // Test first statement: abeg negative = -42;
    const stmt1 = program.statements.items[0];
    try testing.expect(stmt1 == .abeg_statement);

    const abeg_stmt1 = stmt1.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt1.name.value, "negative");
    try testing.expectEqual(abeg_stmt1.type_annotation, null);
    try testing.expectEqual(abeg_stmt1.is_locked, false);
    try testing.expectEqual(abeg_stmt1.is_inferred, false);

    const expr1 = abeg_stmt1.value.*;
    try testing.expect(expr1 == .prefix_expression);

    //Test second statement: abeg escaped_str = "Hello\\nWorld\\t!";
    const stmt3 = program.statements.items[1];
    try testing.expect(stmt3 == .abeg_statement);

    const abeg_stmt3 = stmt3.abeg_statement;
    try testing.expectEqualStrings(abeg_stmt3.name.value, "escaped_str");
    try testing.expectEqual(abeg_stmt3.type_annotation, null);
    try testing.expectEqual(abeg_stmt3.is_locked, false);
    try testing.expectEqual(abeg_stmt3.is_inferred, false);

    const expr3 = abeg_stmt3.value.*;
    try testing.expect(expr3 == .string_literal);
    try testing.expectEqualStrings(expr3.string_literal.value, "Hello\\nWorld\\t!");

    // // Test second statement: abeg large_num = 1234567890123456789;
    // const stmt2 = program.statements.items[1];
    // try testing.expect(stmt2 == .abeg_statement);
    //
    // const abeg_stmt2 = stmt2.abeg_statement;
    // try testing.expectEqualStrings(abeg_stmt2.name.value, "large_num");
    // try testing.expectEqual(abeg_stmt2.type_annotation, null);
    // try testing.expectEqual(abeg_stmt2.is_locked, false);
    // try testing.expectEqual(abeg_stmt2.is_inferred, false);
    //
    // const expr2 = abeg_stmt2.value.*;
    // try testing.expect(expr2 == .integer_literal);
    // try testing.expectEqual(expr2.integer_literal.value, 1234567890123456789);
}
