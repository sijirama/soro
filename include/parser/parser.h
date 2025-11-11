#ifndef PARSER_H
#define PARSER_H

#include <stdbool.h>

#include "ast.h"

// Precedence levels for Pratt parsing
typedef enum {
    PREC_NONE,
    PREC_ASSIGNMENT,  // =
    PREC_OR,          // or, orelse
    PREC_AND,         // and
    PREC_EQUALITY,    // == !=
    PREC_COMPARISON,  // < >
    PREC_TERM,        // + -
    PREC_FACTOR,      // * /
    PREC_UNARY,       // ! -
    PREC_CALL,        // . () []
    PREC_PRIMARY
} Precedence;

// Function pointer types for Pratt parsing
typedef Expr* (*PrefixParseFn)(struct Parser* parser);
typedef Expr* (*InfixParseFn)(struct Parser* parser, Expr* left);

typedef struct {
    PrefixParseFn prefix;
    InfixParseFn infix;
    Precedence precedence;
} ParseRule;

typedef struct Parser {
    Token** tokens;
    size_t current;
    size_t token_count;

    // Error handling
    bool had_error;
    bool panic_mode;

    // For error messages
    const char* filename;
} Parser;

// ===== Parser Lifecycle =====
Parser* parser_init(Token** tokens, size_t count, const char* filename);
void parser_free(Parser* parser);
ASTNode* parse(Parser* parser);

// ===== Token Utilities =====
Token* peek(Parser* parser);
Token* peek_next(Parser* parser);
Token* previous(Parser* parser);
Token* advance(Parser* parser);
bool check(Parser* parser, TokenType type);
bool match(Parser* parser, TokenType type);
Token* consume(Parser* parser, TokenType type, const char* message);
bool is_at_end(Parser* parser);

// ===== Error Handling =====
void parser_error(Parser* parser, const char* message);
void parser_error_at_current(Parser* parser, const char* message);
void synchronize(Parser* parser);

// ===== Recursive Descent - Statements =====
Stmt* parse_statement(Parser* parser);
Stmt* parse_declaration(Parser* parser);
Stmt* parse_var_declaration(Parser* parser);  // abeg x = 5
Stmt* parse_if_statement(Parser* parser);      // abi (cond) { }
Stmt* parse_while_statement(Parser* parser);   // waka (cond) { }
Stmt* parse_function_declaration(Parser* parser); // oya name(params) { }
Stmt* parse_return_statement(Parser* parser);  // comot expr
Stmt* parse_block_statement(Parser* parser);   // { stmts }
Stmt* parse_expression_statement(Parser* parser);

// ===== Pratt Parsing - Expressions =====
Expr* parse_expression(Parser* parser);
Expr* parse_precedence(Parser* parser, Precedence precedence);

// Prefix parse functions
Expr* parse_grouping(Parser* parser);  // ( expr )
Expr* parse_literal(Parser* parser);   // 42, 3.14, "hello", true
Expr* parse_variable(Parser* parser);  // identifier
Expr* parse_unary(Parser* parser);     // -expr, !expr
Expr* parse_array(Parser* parser);     // [1, 2, 3]

// Infix parse functions
Expr* parse_binary(Parser* parser, Expr* left);  // left + right
Expr* parse_call(Parser* parser, Expr* left);    // func(args)
Expr* parse_index(Parser* parser, Expr* left);   // arr[index]

// Helper
ParseRule* get_rule(TokenType type);

#endif
