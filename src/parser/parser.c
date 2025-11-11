
#include "../../include/parser/parser.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ===== Parser Lifecycle =====

Parser* parser_init(Token** tokens, size_t count, const char* filename) {
    Parser* parser = malloc(sizeof(Parser));
    parser->tokens = tokens;
    parser->current = 0;
    parser->token_count = count;
    parser->had_error = false;
    parser->panic_mode = false;
    parser->filename = filename;
    return parser;
}

void parser_free(Parser* parser) {
    free(parser);
}

// parse is at the end

// ===== Token Utilities =====

Token* peek(Parser* parser) {
    if(parser->current >= parser->token_count) {
        return parser->tokens[parser->token_count - 1];  // EOF
    }
    return parser->tokens[parser->current];
}

Token* peek_next(Parser* parser) {
    if(parser->current + 1 >= parser->token_count) {
        return parser->tokens[parser->token_count - 1];  // EOF
    }
    return parser->tokens[parser->current + 1];
}

Token* previous(Parser* parser) {
    return parser->tokens[parser->current - 1];
}

Token* advance(Parser* parser) {
    if(!is_at_end(parser)) {
        parser->current++;
    }
    return previous(parser);
}

bool check(Parser* parser, TokenType type) {
    if(is_at_end(parser))
        return false;
    return peek(parser)->type == type;
}

bool match(Parser* parser, TokenType type) {
    if(!check(parser, type))
        return false;
    advance(parser);
    return true;
}

Token* consume(Parser* parser, TokenType type, const char* message) {
    if(check(parser, type)) {
        return advance(parser);
    }
    parser_error_at_current(parser, message);
    return NULL;
}

bool is_at_end(Parser* parser) {
    return peek(parser)->type == TOKEN_EOF;
}

// ===== Error Handling =====

void parser_error(Parser* parser, const char* message) {
    if(parser->panic_mode)
        return;
    parser->panic_mode = true;
    parser->had_error = true;

    Token* token = previous(parser);
    fprintf(stderr, "[%s:%u] Error at '%s': %s\n", parser->filename, token->line, token->value,
            message);
}

void parser_error_at_current(Parser* parser, const char* message) {
    if(parser->panic_mode)
        return;
    parser->panic_mode = true;
    parser->had_error = true;

    Token* token = peek(parser);
    fprintf(stderr, "[%s:%u] Error at '%s': %s\n", parser->filename, token->line, token->value,
            message);
}

void synchronize(Parser* parser) {
    parser->panic_mode = false;

    while(!is_at_end(parser)) {
        if(previous(parser)->type == TOKEN_SEMICOLON)
            return;

        switch(peek(parser)->type) {
            case TOKEN_ABEG:   // let/var
            case TOKEN_WAKA:   // loop
            case TOKEN_ABI:    // if
            case TOKEN_COMOT:  // return
            case TOKEN_TYPE:   // type declaration
                return;
            default:
                break;
        }
        advance(parser);
    }
}

// ===== Pratt Parsing - Expressions =====

// Forward declarations

// Prefix parse functions
static Expr* parse_grouping(Parser* parser);  // ( expr )
static Expr* parse_literal(Parser* parser);   // 42, 3.14, "hello", true
static Expr* parse_variable(Parser* parser);  // identifier
static Expr* parse_unary(Parser* parser);     // -expr, !expr
static Expr* parse_array(Parser* parser);     // [1, 2, 3]

// Infix parse functions
static Expr* parse_binary(Parser* parser, Expr* left);  // left + right
static Expr* parse_call(Parser* parser, Expr* left);    // func(args)
static Expr* parse_index(Parser* parser, Expr* left);   // arr[index]
static Expr* parse_assign(Parser* parser, Expr* left);

// Parse rule table - maps token types to parsing functions
ParseRule rules[] = {
    [TOKEN_LPAREN] = {parse_grouping, parse_call, PREC_CALL},
    [TOKEN_RPAREN] = {NULL, NULL, PREC_NONE},
    [TOKEN_LBRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_RBRACE] = {NULL, NULL, PREC_NONE},
    [TOKEN_LBRACKET] = {parse_array, parse_index, PREC_CALL},
    [TOKEN_RBRACKET] = {NULL, NULL, PREC_NONE},
    [TOKEN_COMMA] = {NULL, NULL, PREC_NONE},
    [TOKEN_SEMICOLON] = {NULL, NULL, PREC_NONE},
    [TOKEN_COLON] = {NULL, NULL, PREC_NONE},

    // Operators
    [TOKEN_PLUS] = {NULL, parse_binary, PREC_TERM},
    [TOKEN_MINUS] = {parse_unary, parse_binary, PREC_TERM},
    [TOKEN_ASTERISK] = {NULL, parse_binary, PREC_FACTOR},
    [TOKEN_SLASH] = {NULL, parse_binary, PREC_FACTOR},
    [TOKEN_BANG] = {parse_unary, NULL, PREC_NONE},
    [TOKEN_ASSIGN] = {NULL, parse_assign, PREC_ASSIGNMENT},
    [TOKEN_EQUAL] = {NULL, parse_binary, PREC_EQUALITY},
    [TOKEN_NOT_EQUAL] = {NULL, parse_binary, PREC_EQUALITY},
    [TOKEN_LESS_THAN] = {NULL, parse_binary, PREC_COMPARISON},
    [TOKEN_GREATER_THAN] = {NULL, parse_binary, PREC_COMPARISON},

    // Literals
    [TOKEN_INTEGER] = {parse_literal, NULL, PREC_NONE},
    [TOKEN_FLOAT] = {parse_literal, NULL, PREC_NONE},
    [TOKEN_STRING] = {parse_literal, NULL, PREC_NONE},
    [TOKEN_TRUE] = {parse_literal, NULL, PREC_NONE},
    [TOKEN_FALSE] = {parse_literal, NULL, PREC_NONE},

    // Keywords
    [TOKEN_AND] = {NULL, parse_binary, PREC_AND},
    [TOKEN_OR] = {NULL, parse_binary, PREC_OR},
    [TOKEN_OR_ELSE] = {NULL, parse_binary, PREC_OR},

    // Identifier
    [TOKEN_IDENT] = {parse_variable, NULL, PREC_NONE},

    [TOKEN_EOF] = {NULL, NULL, PREC_NONE},
};

ParseRule* get_rule(TokenType type) {
    return &rules[type];
}

Expr* parse_expression(Parser* parser) {
    return parse_precedence(parser, PREC_ASSIGNMENT);
}

Expr* parse_precedence(Parser* parser, Precedence precedence) {
    advance(parser);

    ParseRule* rule = get_rule(previous(parser)->type);
    PrefixParseFn prefix = rule->prefix;

    if(prefix == NULL) {
        parser_error(parser, "Expected expression");
        return NULL;
    }

    Expr* left = prefix(parser);

    while(precedence <= get_rule(peek(parser)->type)->precedence) {
        advance(parser);
        InfixParseFn infix = get_rule(previous(parser)->type)->infix;
        left = infix(parser, left);
    }

    return left;
}

// ===== Prefix Parse Functions =====

static Expr* parse_grouping(Parser* parser) {
    Expr* expr = parse_expression(parser);
    consume(parser, TOKEN_RPAREN, "Expected ')' after expression");
    return expr;
}

static Expr* parse_literal(Parser* parser) {
    Token* token = previous(parser);

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_LITERAL;
    expr->token = token;

    switch(token->type) {
        case TOKEN_INTEGER:
            expr->as.literal.type = LITERAL_INT;
            expr->as.literal.value.int_val = atoi(token->value);
            break;
        case TOKEN_FLOAT:
            expr->as.literal.type = LITERAL_FLOAT;
            expr->as.literal.value.float_val = atof(token->value);
            break;
        case TOKEN_STRING:
            expr->as.literal.type = LITERAL_STRING;
            expr->as.literal.value.string_val = strdup(token->value);
            break;
        case TOKEN_TRUE:
            expr->as.literal.type = LITERAL_BOOL;
            expr->as.literal.value.bool_val = true;
            break;
        case TOKEN_FALSE:
            expr->as.literal.type = LITERAL_BOOL;
            expr->as.literal.value.bool_val = false;
            break;
        default:
            parser_error(parser, "Unknown literal type");
            free(expr);
            return NULL;
    }

    return expr;
}

static Expr* parse_variable(Parser* parser) {
    Token* name = previous(parser);

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_VARIABLE;
    expr->token = name;
    expr->as.variable.name = strdup(name->value);

    return expr;
}

static Expr* parse_unary(Parser* parser) {
    Token* op = previous(parser);
    Expr* right = parse_precedence(parser, PREC_UNARY);

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_UNARY;
    expr->token = op;
    expr->as.unary.op = op->type;
    expr->as.unary.right = right;

    return expr;
}

static Expr* parse_array(Parser* parser) {
    // [1, 2, 3]
    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_ARRAY;
    expr->token = previous(parser);
    expr->as.array.elements = NULL;
    expr->as.array.count = 0;

    if(!check(parser, TOKEN_RBRACKET)) {
        size_t capacity = 8;
        expr->as.array.elements = malloc(sizeof(Expr*) * capacity);

        do {
            if(expr->as.array.count >= capacity) {
                capacity *= 2;
                expr->as.array.elements =
                    realloc(expr->as.array.elements, sizeof(Expr*) * capacity);
            }
            expr->as.array.elements[expr->as.array.count++] = parse_expression(parser);
        } while(match(parser, TOKEN_COMMA));
    }

    consume(parser, TOKEN_RBRACKET, "Expected ']' after array elements");
    return expr;
}

// ===== Infix Parse Functions =====

static Expr* parse_binary(Parser* parser, Expr* left) {
    Token* op = previous(parser);
    ParseRule* rule = get_rule(op->type);

    // Parse right side with higher precedence (left-associative)
    Expr* right = parse_precedence(parser, (Precedence)(rule->precedence + 1));

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_BINARY;
    expr->token = op;
    expr->as.binary.left = left;
    expr->as.binary.op = op->type;
    expr->as.binary.right = right;

    return expr;
}

static Expr* parse_call(Parser* parser, Expr* left) {
    // func(arg1, arg2)
    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_CALL;
    expr->token = previous(parser);
    expr->as.call.callee = left;
    expr->as.call.args = NULL;
    expr->as.call.arg_count = 0;

    if(!check(parser, TOKEN_RPAREN)) {
        size_t capacity = 8;
        expr->as.call.args = malloc(sizeof(Expr*) * capacity);

        do {
            if(expr->as.call.arg_count >= capacity) {
                capacity *= 2;
                expr->as.call.args = realloc(expr->as.call.args, sizeof(Expr*) * capacity);
            }
            expr->as.call.args[expr->as.call.arg_count++] = parse_expression(parser);
        } while(match(parser, TOKEN_COMMA));
    }

    consume(parser, TOKEN_RPAREN, "Expected ')' after arguments");
    return expr;
}

static Expr* parse_index(Parser* parser, Expr* left) {
    // arr[index]
    Expr* index = parse_expression(parser);
    consume(parser, TOKEN_RBRACKET, "Expected ']' after index");

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_INDEX;
    expr->token = previous(parser);
    expr->as.index.object = left;
    expr->as.index.index = index;

    return expr;
}

static Expr* parse_assign(Parser* parser, Expr* left) {
    Token* equals = previous(parser);

    // Check if left side is a valid assignment target
    if(left->type != EXPR_VARIABLE) {
        parser_error(parser, "Invalid assignment target");
        return left;
    }

    // Right-associative: parse with same precedence
    Expr* value = parse_precedence(parser, PREC_ASSIGNMENT);

    Expr* expr = malloc(sizeof(Expr));
    expr->type = EXPR_ASSIGN;
    expr->token = equals;
    expr->as.assign.name = strdup(left->as.variable.name);
    expr->as.assign.value = value;

    // Free the old variable expression since we don't need it
    free(left->as.variable.name);
    free(left);

    return expr;
}

// ===== Recursive Descent - Statements =====

Stmt* parse_statement(Parser* parser) {
    if(match(parser, TOKEN_ABI)) {
        return parse_if_statement(parser);
    }
    if(match(parser, TOKEN_WAKA)) {
        return parse_while_statement(parser);
    }
    if(match(parser, TOKEN_COMOT)) {
        return parse_return_statement(parser);
    }
    if(match(parser, TOKEN_LBRACE)) {
        return parse_block_statement(parser);
    }

    return parse_expression_statement(parser);
}

Stmt* parse_declaration(Parser* parser) {
    if(match(parser, TOKEN_ABEG)) {
        return parse_var_declaration(parser);
    }
    if(match(parser, TOKEN_OYA)) {
        return parse_function_declaration(parser);
    }

    return parse_statement(parser);
}

Stmt* parse_var_declaration(Parser* parser) {
    // abeg x = 5;
    // abeg x: int = 5;

    Token* name = consume(parser, TOKEN_IDENT, "Expected variable name");
    if(!name)
        return NULL;

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_VAR_DECL;
    stmt->as.var_decl.name = strdup(name->value);
    stmt->as.var_decl.type_annotation = NULL;
    stmt->as.var_decl.initializer = NULL;

    // Optional type annotation: abeg x: int
    if(match(parser, TOKEN_COLON)) {
        Token* type = consume(parser, TOKEN_TYPE, "Expected type after ':'");
        if(type) {
            stmt->as.var_decl.type_annotation = strdup(type->value);
        }
    }

    // Optional initializer: = expr
    if(match(parser, TOKEN_ASSIGN)) {
        stmt->as.var_decl.initializer = parse_expression(parser);
    }

    consume(parser, TOKEN_SEMICOLON, "Expected ';' after variable declaration");
    return stmt;
}

Stmt* parse_function_declaration(Parser* parser) {
    // oya greet(name: string, age: int): void { ... }

    Token* name = consume(parser, TOKEN_IDENT, "Expected function name after 'oya'");
    if(!name)
        return NULL;

    consume(parser, TOKEN_LPAREN, "Expected '(' after function name");

    // Parse parameters
    size_t param_capacity = 4;
    char** param_names = malloc(sizeof(char*) * param_capacity);
    char** param_types = malloc(sizeof(char*) * param_capacity);
    size_t param_count = 0;

    if(!check(parser, TOKEN_RPAREN)) {
        do {
            if(param_count >= param_capacity) {
                param_capacity *= 2;
                param_names = realloc(param_names, sizeof(char*) * param_capacity);
                param_types = realloc(param_types, sizeof(char*) * param_capacity);
            }

            Token* param_name = consume(parser, TOKEN_IDENT, "Expected parameter name");
            if(!param_name)
                break;

            consume(parser, TOKEN_COLON, "Expected ':' after parameter name");
            Token* param_type = consume(parser, TOKEN_TYPE, "Expected parameter type");
            if(!param_type)
                break;

            param_names[param_count] = strdup(param_name->value);
            param_types[param_count] = strdup(param_type->value);
            param_count++;

        } while(match(parser, TOKEN_COMMA));
    }

    consume(parser, TOKEN_RPAREN, "Expected ')' after parameters");

    // Optional return type
    char* return_type = NULL;
    if(match(parser, TOKEN_COLON)) {
        Token* ret = consume(parser, TOKEN_TYPE, "Expected return type");
        if(ret) {
            return_type = strdup(ret->value);
        }
    }

    // Parse body
    Stmt* body = parse_block_statement(parser);

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_FUNCTION_DECL;
    stmt->as.function_decl.name = strdup(name->value);
    stmt->as.function_decl.param_names = param_names;
    stmt->as.function_decl.param_types = param_types;
    stmt->as.function_decl.param_count = param_count;
    stmt->as.function_decl.return_type = return_type;
    stmt->as.function_decl.body = body;

    return stmt;
}

Stmt* parse_if_statement(Parser* parser) {
    // abi (condition) { ... } naso { ... }

    consume(parser, TOKEN_LPAREN, "Expected '(' after 'abi'");
    Expr* condition = parse_expression(parser);
    consume(parser, TOKEN_RPAREN, "Expected ')' after condition");

    Stmt* then_branch = parse_statement(parser);
    Stmt* else_branch = NULL;

    if(match(parser, TOKEN_NASO)) {  // naso = else
        else_branch = parse_statement(parser);
    }

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_IF;
    stmt->as.if_stmt.condition = condition;
    stmt->as.if_stmt.then_branch = then_branch;
    stmt->as.if_stmt.else_branch = else_branch;

    return stmt;
}

Stmt* parse_while_statement(Parser* parser) {
    // oya (condition) { ... }

    consume(parser, TOKEN_LPAREN, "Expected '(' after 'oya'");
    Expr* condition = parse_expression(parser);
    consume(parser, TOKEN_RPAREN, "Expected ')' after condition");

    Stmt* body = parse_statement(parser);

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_WHILE;
    stmt->as.while_stmt.condition = condition;
    stmt->as.while_stmt.body = body;

    return stmt;
}

Stmt* parse_return_statement(Parser* parser) {
    // comot; or comot expr;

    Expr* value = NULL;
    if(!check(parser, TOKEN_SEMICOLON)) {
        value = parse_expression(parser);
    }

    consume(parser, TOKEN_SEMICOLON, "Expected ';' after return statement");

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_RETURN;
    stmt->as.return_stmt.value = value;

    return stmt;
}

Stmt* parse_block_statement(Parser* parser) {
    // { stmt1; stmt2; ... }

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_BLOCK;
    stmt->as.block.statements = NULL;
    stmt->as.block.count = 0;

    size_t capacity = 8;
    stmt->as.block.statements = malloc(sizeof(Stmt*) * capacity);

    while(!check(parser, TOKEN_RBRACE) && !is_at_end(parser)) {
        if(stmt->as.block.count >= capacity) {
            capacity *= 2;
            stmt->as.block.statements =
                realloc(stmt->as.block.statements, sizeof(Stmt*) * capacity);
        }
        stmt->as.block.statements[stmt->as.block.count++] = parse_declaration(parser);
    }

    consume(parser, TOKEN_RBRACE, "Expected '}' after block");
    return stmt;
}

Stmt* parse_expression_statement(Parser* parser) {
    Expr* expr = parse_expression(parser);
    consume(parser, TOKEN_SEMICOLON, "Expected ';' after expression");

    Stmt* stmt = malloc(sizeof(Stmt));
    stmt->type = STMT_EXPR;
    stmt->as.expr_stmt.expression = expr;

    return stmt;
}

// ===== Main Parse Entry Point =====

ASTNode* parse(Parser* parser) {
    ASTNode* root = malloc(sizeof(ASTNode));
    root->type = NODE_PROGRAM;
    root->as.program.statements = NULL;
    root->as.program.count = 0;

    size_t capacity = 16;
    root->as.program.statements = malloc(sizeof(Stmt*) * capacity);

    while(!is_at_end(parser)) {
        if(root->as.program.count >= capacity) {
            capacity *= 2;
            root->as.program.statements =
                realloc(root->as.program.statements, sizeof(Stmt*) * capacity);
        }

        Stmt* stmt = parse_declaration(parser);
        if(stmt) {
            root->as.program.statements[root->as.program.count++] = stmt;
        }

        if(parser->panic_mode) {
            synchronize(parser);
        }
    }

    return parser->had_error ? NULL : root;
}
