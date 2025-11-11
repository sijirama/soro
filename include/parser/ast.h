#ifndef AST_H
#define AST_H

#include <stddef.h>
#include <stdbool.h>

#include "../token.h"

// Forward declarations
typedef struct Expr Expr;
typedef struct Stmt Stmt;

// ===== Expression Types =====

typedef enum {
    EXPR_LITERAL,
    EXPR_VARIABLE,
    EXPR_BINARY,
    EXPR_UNARY,
    EXPR_CALL,
    EXPR_INDEX,
    EXPR_ARRAY,
    EXPR_ASSIGN
} ExprType;

// Literal value types
typedef enum { LITERAL_INT, LITERAL_FLOAT, LITERAL_STRING, LITERAL_BOOL } LiteralType;

typedef struct {
    LiteralType type;
    union {
        int int_val;
        double float_val;
        char* string_val;
        bool bool_val;
    } value;
} Literal;

typedef struct {
    char* name;
} Variable;

typedef struct {
    Expr* left;
    TokenType op;
    Expr* right;
} Binary;

typedef struct {
    TokenType op;
    Expr* right;
} Unary;

typedef struct {
    Expr* callee;
    Expr** args;
    size_t arg_count;
} Call;

typedef struct {
    Expr* object;
    Expr* index;
} Index;

typedef struct {
    Expr** elements;
    size_t count;
} Array;

typedef struct {
    char* name;
    Expr* value;
} Assign;

struct Expr {
    ExprType type;
    Token* token;  // For error reporting
    union {
        Literal literal;
        Variable variable;
        Binary binary;
        Unary unary;
        Call call;
        Index index;
        Array array;
        Assign assign;
    } as;
};

// ===== Statement Types =====

typedef enum {
    STMT_EXPR,
    STMT_VAR_DECL,
    STMT_FUNCTION_DECL,
    STMT_IF,
    STMT_WHILE,
    STMT_RETURN,
    STMT_BLOCK
} StmtType;

typedef struct {
    Expr* expression;
} ExprStmt;

typedef struct {
    char* name;
    char* type_annotation;  // optional
    Expr* initializer;      // optional
} VarDecl;

typedef struct {
    char* name;
    char** param_names;
    char** param_types;
    size_t param_count;
    char* return_type;
    Stmt* body;
} FunctionDecl;

typedef struct {
    Expr* condition;
    Stmt* then_branch;
    Stmt* else_branch;  // optional
} IfStmt;

typedef struct {
    Expr* condition;
    Stmt* body;
} WhileStmt;

typedef struct {
    Expr* value;  // optional
} ReturnStmt;

typedef struct {
    Stmt** statements;
    size_t count;
} Block;

struct Stmt {
    StmtType type;
    union {
        ExprStmt expr_stmt;
        VarDecl var_decl;
        FunctionDecl function_decl;
        IfStmt if_stmt;
        WhileStmt while_stmt;
        ReturnStmt return_stmt;
        Block block;
    } as;
};

// ===== Program (Root Node) =====

typedef enum { NODE_PROGRAM } ASTNodeType;

typedef struct {
    Stmt** statements;
    size_t count;
} Program;

typedef struct {
    ASTNodeType type;
    union {
        Program program;
    } as;
} ASTNode;

// ===== AST Utilities =====

void ast_free_expr(Expr* expr);
void ast_free_stmt(Stmt* stmt);
void ast_free_node(ASTNode* node);

// Printing for debugging
void ast_print_expr(Expr* expr, int indent);
void ast_print_stmt(Stmt* stmt, int indent);
void ast_print_node(ASTNode* node);

#endif
