
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
