#ifndef PARSER_H
#define PARSER_H

#include <stdbool.h>
#include <stddef.h>

#include "../lexer.h"

typedef enum {
    NODE_INTEGER,
    NODE_FLOAT,
    NODE_STRING,
    NODE_ARRAY,
} NodeKind;

typedef struct Node {
    NodeKind kind;
    char* value;           
    struct Node** children;
    size_t child_count;

    // Source location (for errors)
    size_t line;
    size_t col;
} Node;

typedef struct {
    Token** tokens;
    size_t count;
    size_t pos;
    const char* filename;
} Parser;

Parser parser_init(Token** tokens, size_t count, const char* filename);
Node* parse_root(Parser* p);  // expects top-level array
void node_free(Node* n);

typedef struct {
    const char* msg;
    size_t line, col;
    const char* filename;
} ParseError;

extern ParseError* g_parse_errors;
extern size_t      g_parse_error_count;

void parse_error_add(const char* msg, size_t line, size_t col);

#endif
