#ifndef LEXER_H
#define LEXER_H

#include <stddef.h>
#include <stdint.h>

#include "token.h"

typedef struct {
    const char* input;
    size_t input_len;
    uint32_t position;
    uint32_t line;
    uint32_t column;
    char* file_name;
    char* file_directory;

    // Dynamic array for tokens
    Token** tokens;
    size_t token_count;
    size_t token_capacity;

    // Track string allocations for cleanup
    char** string_allocations;
    size_t string_count;
    size_t string_capacity;
} Lexer;

// Initialize lexer
Lexer* lexer_init(const char* input, const char* file_name, const char* file_directory);

// Free lexer and all associated memory
void lexer_free(Lexer* lexer);

// Tokenize entire input
Token** lexer_tokenize(Lexer* lexer, size_t* token_count);

// Get next token
Token* lexer_next_token(Lexer* lexer);

#endif  // LEXER_H
