#ifndef TOKEN_H
#define TOKEN_H

#include <stdint.h>

typedef enum {
    // Special tokens
    TOKEN_ILLEGAL,
    TOKEN_EOF,
    TOKEN_COMMENT,

    // Identifiers and literals
    TOKEN_IDENT,
    TOKEN_INTEGER,
    TOKEN_FLOAT,
    TOKEN_STRING,

    // Operators
    TOKEN_ASSIGN,    // =
    TOKEN_PLUS,      // +
    TOKEN_MINUS,     // -
    TOKEN_ASTERISK,  // *
    TOKEN_SLASH,     // /
    TOKEN_BANG,      // !

    // Comparison
    TOKEN_EQUAL,         // ==
    TOKEN_NOT_EQUAL,     // !=
    TOKEN_LESS_THAN,     //
    TOKEN_GREATER_THAN,  // >

    // Delimiters
    TOKEN_COMMA,      // ,
    TOKEN_SEMICOLON,  // ;
    TOKEN_COLON,      // :
    TOKEN_LPAREN,     // (
    TOKEN_RPAREN,     // )
    TOKEN_LBRACE,     // {
    TOKEN_RBRACE,     // }
    TOKEN_LBRACKET,   // [
    TOKEN_RBRACKET,   // ]

    // Keywords (Pidgin English)
    TOKEN_ABEG,   // let/var
    TOKEN_OYA,    // function
    TOKEN_WAKA,   // function
    TOKEN_COMOT,  // return
    TOKEN_ABI,    // if
    TOKEN_NASO,   // else
    TOKEN_TRUE,
    TOKEN_FALSE,
    TOKEN_AND,
    TOKEN_OR,
    TOKEN_OR_ELSE,  // orelse

    // Type keywords
    TOKEN_TYPE,  // int, float, string, bool, etc.
} TokenType;

typedef struct {
    TokenType type;
    char* value;
    uint32_t line;
    uint32_t column;
    char* file_name;
    char* file_directory;
} Token;

// Create a new token
Token* token_create(TokenType type, const char* value, uint32_t line, uint32_t column,
                    const char* file_name, const char* file_directory);

// Free a token
void token_free(Token* token);

// Get string representation of token type
const char* token_type_to_string(TokenType type);

// Check if identifier is a keyword, return token type or TOKEN_IDENT
TokenType token_lookup_keyword(const char* ident);

// Check if identifier is a type keyword
int token_is_type_keyword(const char* ident);

#endif  // TOKEN_H
