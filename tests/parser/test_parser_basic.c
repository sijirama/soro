
#include <stdio.h>
#include <string.h>

#include "../../include/lexer.h"
#include "../../include/parser/parser.h"
#include "../../include/token.h"
#include "../utest.h"

UTEST(parser, simple_integer_literal) {
    const char* input = "42;";

    // Lex the input
    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    // Parse the tokens
    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    // Verify we got a valid AST
    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(NODE_PROGRAM, ast->type);
    ASSERT_EQ(1, ast->as.program.count);

    // Check the statement
    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_EXPR, stmt->type);

    // Check the expression
    Expr* expr = stmt->as.expr_stmt.expression;
    ASSERT_EQ(EXPR_LITERAL, expr->type);
    ASSERT_EQ(LITERAL_INT, expr->as.literal.type);
    ASSERT_EQ(42, expr->as.literal.value.int_val);

    // Cleanup
    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

UTEST(parser, simple_addition) {
    const char* input = "5 + 3;";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_EXPR, stmt->type);

    Expr* expr = stmt->as.expr_stmt.expression;
    ASSERT_EQ(EXPR_BINARY, expr->type);
    ASSERT_EQ(TOKEN_PLUS, expr->as.binary.op);

    // Check left side
    ASSERT_EQ(EXPR_LITERAL, expr->as.binary.left->type);
    ASSERT_EQ(5, expr->as.binary.left->as.literal.value.int_val);

    // Check right side
    ASSERT_EQ(EXPR_LITERAL, expr->as.binary.right->type);
    ASSERT_EQ(3, expr->as.binary.right->as.literal.value.int_val);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

UTEST(parser, variable_declaration) {
    const char* input = "abeg x: int = 42;";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_VAR_DECL, stmt->type);
    ASSERT_STREQ("x", stmt->as.var_decl.name);
    ASSERT_STREQ("int", stmt->as.var_decl.type_annotation);

    // Check initializer
    ASSERT_TRUE(stmt->as.var_decl.initializer != NULL);
    ASSERT_EQ(EXPR_LITERAL, stmt->as.var_decl.initializer->type);
    ASSERT_EQ(42, stmt->as.var_decl.initializer->as.literal.value.int_val);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 1. Unary Expression ===
UTEST(parser, unary_expression) {
    const char* input = "-42;";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_EXPR, stmt->type);

    Expr* expr = stmt->as.expr_stmt.expression;
    ASSERT_EQ(EXPR_UNARY, expr->type);
    ASSERT_EQ(TOKEN_MINUS, expr->as.unary.op);

    ASSERT_EQ(EXPR_LITERAL, expr->as.unary.right->type);
    ASSERT_EQ(42, expr->as.unary.right->as.literal.value.int_val);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 2. If Statement ===
UTEST(parser, simple_if_statement) {
    const char* input = "abi (true) { abeg x: int = 5; }";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_IF, stmt->type);

    Expr* cond = stmt->as.if_stmt.condition;
    ASSERT_EQ(EXPR_LITERAL, cond->type);
    ASSERT_EQ(LITERAL_BOOL, cond->as.literal.type);
    ASSERT_TRUE(cond->as.literal.value.bool_val);

    Stmt* then_branch = stmt->as.if_stmt.then_branch;
    ASSERT_EQ(STMT_BLOCK, then_branch->type);
    ASSERT_EQ(1, then_branch->as.block.count);

    Stmt* inner = then_branch->as.block.statements[0];
    ASSERT_EQ(STMT_VAR_DECL, inner->type);
    ASSERT_STREQ("x", inner->as.var_decl.name);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 3. If-Else Statement ===
UTEST(parser, if_else_statement) {
    const char* input = "abi (false) { abeg y: int = 1; } naso { abeg y: int = 2; }";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_IF, stmt->type);
    ASSERT_TRUE(stmt->as.if_stmt.else_branch != NULL);

    Stmt* else_branch = stmt->as.if_stmt.else_branch;
    ASSERT_EQ(STMT_BLOCK, else_branch->type);
    ASSERT_EQ(1, else_branch->as.block.count);

    Stmt* else_inner = else_branch->as.block.statements[0];
    ASSERT_EQ(STMT_VAR_DECL, else_inner->type);
    ASSERT_STREQ("y", else_inner->as.var_decl.name);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 4. While Loop ===
UTEST(parser, while_loop) {
    const char* input = "waka (x < 10) { x = x + 1; }";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_WHILE, stmt->type);

    Expr* cond = stmt->as.while_stmt.condition;
    ASSERT_EQ(EXPR_BINARY, cond->type);
    ASSERT_EQ(TOKEN_LESS_THAN, cond->as.binary.op);

    Stmt* body = stmt->as.while_stmt.body;
    ASSERT_EQ(STMT_BLOCK, body->type);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 5. Function Declaration ===
UTEST(parser, function_declaration) {
    const char* input = "oya add(a: int, b:int): int { comot a + b; }";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_FUNCTION_DECL, stmt->type);

    ASSERT_STREQ("add", stmt->as.function_decl.name);
    ASSERT_EQ(2, stmt->as.function_decl.param_count);
    ASSERT_STREQ("a", stmt->as.function_decl.param_names[0]);
    ASSERT_STREQ("b", stmt->as.function_decl.param_names[1]);
    ASSERT_STREQ("int", stmt->as.function_decl.param_types[0]);
    ASSERT_STREQ("int", stmt->as.function_decl.param_types[1]);

    ASSERT_STREQ("int", stmt->as.function_decl.return_type);
    ASSERT_EQ(STMT_BLOCK, stmt->as.function_decl.body->type);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 6. Array Literal ===
UTEST(parser, array_literal) {
    const char* input = "[1, 2, 3];";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_EXPR, stmt->type);

    Expr* expr = stmt->as.expr_stmt.expression;
    ASSERT_EQ(EXPR_ARRAY, expr->type);
    ASSERT_EQ(3, expr->as.array.count);

    ASSERT_EQ(1, expr->as.array.elements[0]->as.literal.value.int_val);
    ASSERT_EQ(2, expr->as.array.elements[1]->as.literal.value.int_val);
    ASSERT_EQ(3, expr->as.array.elements[2]->as.literal.value.int_val);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}

// === 7. Assignment Expression ===
UTEST(parser, assignment_expression) {
    const char* input = "x = 10;";

    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t token_count = 0;
    Token** tokens = lexer_tokenize(lexer, &token_count);

    Parser* parser = parser_init(tokens, token_count, "test.soro");
    ASTNode* ast = parse(parser);

    ASSERT_TRUE(ast != NULL);
    ASSERT_EQ(1, ast->as.program.count);

    Stmt* stmt = ast->as.program.statements[0];
    ASSERT_EQ(STMT_EXPR, stmt->type);

    Expr* expr = stmt->as.expr_stmt.expression;
    ASSERT_EQ(EXPR_ASSIGN, expr->type);
    ASSERT_STREQ("x", expr->as.assign.name);
    ASSERT_EQ(EXPR_LITERAL, expr->as.assign.value->type);
    ASSERT_EQ(10, expr->as.assign.value->as.literal.value.int_val);

    ast_free_node(ast);
    parser_free(parser);
    lexer_free(lexer);
}
