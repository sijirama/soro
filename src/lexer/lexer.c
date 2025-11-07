#define _POSIX_C_SOURCE 200809L
#include "../../include/lexer.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../include/error.h"

// Helper macros
#define INITIAL_TOKEN_CAPACITY 256
#define INITIAL_STRING_CAPACITY 64

// Helper functions (forward declarations)
static char current_char(Lexer* lexer);
static char peek_char(Lexer* lexer, size_t offset);
static void advance(Lexer* lexer, uint32_t count);
static void skip_whitespace(Lexer* lexer);
static int is_ident_char(char c);
static int is_digit(char c);

static Token* read_number(Lexer* lexer);
static Token* read_string(Lexer* lexer);
static Token* read_identifier(Lexer* lexer);
static Token* read_slash_or_comment(Lexer* lexer);
static Token* create_token(Lexer* lexer, TokenType type, const char* value);
static void add_string_allocation(Lexer* lexer, char* str);

Lexer* lexer_init(const char* input, const char* file_name, const char* file_directory) {
    Lexer* lexer = malloc(sizeof(Lexer));
    if(!lexer)
        return NULL;

    lexer->input = input;
    lexer->input_len = strlen(input);
    lexer->position = 0;
    lexer->line = 1;
    lexer->column = 1;
    lexer->file_name = file_name ? strdup(file_name) : strdup("unknown");
    lexer->file_directory = file_directory ? strdup(file_directory) : strdup(".");

    // Initialize token array
    lexer->token_capacity = INITIAL_TOKEN_CAPACITY;
    lexer->token_count = 0;
    lexer->tokens = malloc(sizeof(Token*) * lexer->token_capacity);

    // Initialize string allocation tracking
    lexer->string_capacity = INITIAL_STRING_CAPACITY;
    lexer->string_count = 0;
    lexer->string_allocations = malloc(sizeof(char*) * lexer->string_capacity);

    return lexer;
}

void lexer_free(Lexer* lexer) {
    if(!lexer)
        return;

    // Free all tokens
    for(size_t i = 0; i < lexer->token_count; i++) {
        token_free(lexer->tokens[i]);
    }
    free(lexer->tokens);

    // Free string allocations
    for(size_t i = 0; i < lexer->string_count; i++) {
        free(lexer->string_allocations[i]);
    }
    free(lexer->string_allocations);

    free(lexer->file_name);
    free(lexer->file_directory);
    free(lexer);
}

Token** lexer_tokenize(Lexer* lexer, size_t* token_count) {
    while(1) {
        Token* token = lexer_next_token(lexer);

        if(!token) {
            // Error occurred, but we still need to set token_count
            *token_count = lexer->token_count;
            return lexer->tokens;
        }

        // Add token to array
        if(lexer->token_count >= lexer->token_capacity) {
            lexer->token_capacity *= 2;
            lexer->tokens = realloc(lexer->tokens, sizeof(Token*) * lexer->token_capacity);
        }
        lexer->tokens[lexer->token_count++] = token;

        if(token->type == TOKEN_EOF) {
            break;
        }
    }

    *token_count = lexer->token_count;
    return lexer->tokens;
}

Token* lexer_next_token(Lexer* lexer) {
    skip_whitespace(lexer);

    if(lexer->position >= lexer->input_len) {
        return create_token(lexer, TOKEN_EOF, "");
    }

    char ch = current_char(lexer);

    switch(ch) {
        case '+': {
            Token* tok = create_token(lexer, TOKEN_PLUS, "+");
            advance(lexer, 1);
            return tok;
        }
        case '-': {
            Token* tok = create_token(lexer, TOKEN_MINUS, "-");
            advance(lexer, 1);
            return tok;
        }
        case '*': {
            Token* tok = create_token(lexer, TOKEN_ASTERISK, "*");
            advance(lexer, 1);
            return tok;
        }
        case '/':
            return read_slash_or_comment(lexer);
        case ';': {
            Token* tok = create_token(lexer, TOKEN_SEMICOLON, ";");
            advance(lexer, 1);
            return tok;
        }
        case ':': {
            Token* tok = create_token(lexer, TOKEN_COLON, ":");
            advance(lexer, 1);
            return tok;
        }
        case ',': {
            Token* tok = create_token(lexer, TOKEN_COMMA, ",");
            advance(lexer, 1);
            return tok;
        }
        case '(': {
            Token* tok = create_token(lexer, TOKEN_LPAREN, "(");
            advance(lexer, 1);
            return tok;
        }
        case ')': {
            Token* tok = create_token(lexer, TOKEN_RPAREN, ")");
            advance(lexer, 1);
            return tok;
        }
        case '{': {
            Token* tok = create_token(lexer, TOKEN_LBRACE, "{");
            advance(lexer, 1);
            return tok;
        }
        case '}': {
            Token* tok = create_token(lexer, TOKEN_RBRACE, "}");
            advance(lexer, 1);
            return tok;
        }
        case '[': {
            Token* tok = create_token(lexer, TOKEN_LBRACKET, "[");
            advance(lexer, 1);
            return tok;
        }
        case ']': {
            Token* tok = create_token(lexer, TOKEN_RBRACKET, "]");
            advance(lexer, 1);
            return tok;
        }
        case '<': {
            Token* tok = create_token(lexer, TOKEN_LESS_THAN, "<");
            advance(lexer, 1);
            return tok;
        }
        case '>': {
            Token* tok = create_token(lexer, TOKEN_GREATER_THAN, ">");
            advance(lexer, 1);
            return tok;
        }
        case '=':
            if(peek_char(lexer, 1) == '=') {
                Token* tok = create_token(lexer, TOKEN_EQUAL, "==");
                advance(lexer, 2);
                return tok;
            } else {
                Token* tok = create_token(lexer, TOKEN_ASSIGN, "=");
                advance(lexer, 1);
                return tok;
            }
        case '!':
            if(peek_char(lexer, 1) == '=') {
                Token* tok = create_token(lexer, TOKEN_NOT_EQUAL, "!=");
                advance(lexer, 2);
                return tok;
            } else {
                Token* tok = create_token(lexer, TOKEN_BANG, "!");
                advance(lexer, 1);
                return tok;
            }
        case '"':
        case '\'':
            return read_string(lexer);
        case '0' ... '9':
            return read_number(lexer);
        default:
            if(isalpha(ch) || ch == '_') {
                return read_identifier(lexer);
            }
            {
                char buf[2] = {ch, '\0'};
                Token* tok = create_token(lexer, TOKEN_ILLEGAL, buf);
                advance(lexer, 1);
                return tok;
            }
    }
}

// Helper function implementations

static char current_char(Lexer* lexer) {
    if(lexer->position >= lexer->input_len) {
        return '\0';
    }
    return lexer->input[lexer->position];
}

static char peek_char(Lexer* lexer, size_t offset) {
    size_t pos = lexer->position + offset;
    if(pos >= lexer->input_len) {
        return '\0';
    }
    return lexer->input[pos];
}

static void advance(Lexer* lexer, uint32_t count) {
    for(uint32_t i = 0; i < count && lexer->position < lexer->input_len; i++) {
        if(lexer->input[lexer->position] == '\n') {
            lexer->line++;
            lexer->column = 1;
        } else {
            lexer->column++;
        }
        lexer->position++;
    }
}

static void skip_whitespace(Lexer* lexer) {
    while(lexer->position < lexer->input_len) {
        char ch = current_char(lexer);
        if(ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
            advance(lexer, 1);
        } else {
            break;
        }
    }
}

static int is_ident_char(char c) {
    return isalnum(c) || c == '_';
}

static int is_digit(char c) {
    return c >= '0' && c <= '9';
}

static Token* read_number(Lexer* lexer) {
    size_t start = lexer->position;
    uint32_t start_line = lexer->line;
    uint32_t start_column = lexer->column;
    int has_decimal = 0;

    // Read integer part
    while(is_digit(current_char(lexer))) {
        advance(lexer, 1);
    }

    // Check for decimal point
    if(current_char(lexer) == '.' && is_digit(peek_char(lexer, 1))) {
        has_decimal = 1;
        advance(lexer, 1);  // consume '.'

        // Read decimal part
        while(is_digit(current_char(lexer))) {
            advance(lexer, 1);
        }
    }

    size_t len = lexer->position - start;
    char* num_str = strndup(lexer->input + start, len);
    add_string_allocation(lexer, num_str);

    Token* token = token_create(has_decimal ? TOKEN_FLOAT : TOKEN_INTEGER, num_str, start_line,
                                start_column, lexer->file_name, lexer->file_directory);
    free(num_str);
    return token;
}

static Token* read_string(Lexer* lexer) {
    char quote = current_char(lexer);
    uint32_t start_line = lexer->line;
    uint32_t start_column = lexer->column;

    advance(lexer, 1);  // Skip opening quote

    char* buffer = malloc(256);
    size_t capacity = 256;
    size_t len = 0;

    while(lexer->position < lexer->input_len) {
        char ch = current_char(lexer);

        if(ch == quote) {
            advance(lexer, 1);  // Skip closing quote
            buffer[len] = '\0';
            add_string_allocation(lexer, buffer);

            Token* token = token_create(TOKEN_STRING, buffer, start_line, start_column,
                                        lexer->file_name, lexer->file_directory);
            return token;
        }

        if(ch == '\\') {
            advance(lexer, 1);
            if(lexer->position >= lexer->input_len) {
                free(buffer);
                lexer_error_print(LEXER_ERROR_INVALID_ESCAPE, lexer->line, lexer->column,
                                  lexer->input, lexer->file_name);
                return NULL;
            }

            char escaped = current_char(lexer);
            switch(escaped) {
                case 'n':
                    ch = '\n';
                    break;
                case 't':
                    ch = '\t';
                    break;
                case 'r':
                    ch = '\r';
                    break;
                case '\\':
                    ch = '\\';
                    break;
                case '"':
                    ch = '"';
                    break;
                case '\'':
                    ch = '\'';
                    break;
                default:
                    free(buffer);
                    lexer_error_print(LEXER_ERROR_INVALID_ESCAPE, lexer->line, lexer->column,
                                      lexer->input, lexer->file_name);
                    return NULL;
            }
        }

        if(len >= capacity - 1) {
            capacity *= 2;
            buffer = realloc(buffer, capacity);
        }

        buffer[len++] = ch;
        advance(lexer, 1);
    }

    free(buffer);
    lexer_error_print(LEXER_ERROR_UNTERMINATED_STRING, lexer->line, lexer->column, lexer->input,
                      lexer->file_name);
    return NULL;
}

static Token* read_identifier(Lexer* lexer) {
    size_t start = lexer->position;
    uint32_t start_line = lexer->line;
    uint32_t start_column = lexer->column;

    while(is_ident_char(current_char(lexer))) {
        advance(lexer, 1);
    }

    size_t len = lexer->position - start;
    char* ident = strndup(lexer->input + start, len);

    // Check if it's a keyword
    TokenType type = token_lookup_keyword(ident);

    // Check if it's a type keyword
    if(type == TOKEN_IDENT && token_is_type_keyword(ident)) {
        type = TOKEN_TYPE;
    }

    Token* token = token_create(type, ident, start_line, start_column, lexer->file_name,
                                lexer->file_directory);
    free(ident);

    return token;
}

static Token* read_slash_or_comment(Lexer* lexer) {
    uint32_t start_line = lexer->line;
    uint32_t start_column = lexer->column;

    // Single-line comment
    if(peek_char(lexer, 1) == '/') {
        advance(lexer, 2);  // consume '//'
        size_t comment_start = lexer->position;

        while(current_char(lexer) != '\n' && lexer->position < lexer->input_len) {
            advance(lexer, 1);
        }

        size_t len = lexer->position - comment_start;
        char* comment = strndup(lexer->input + comment_start, len);
        add_string_allocation(lexer, comment);

        Token* token = token_create(TOKEN_COMMENT, comment, start_line, start_column,
                                    lexer->file_name, lexer->file_directory);
        return token;
    }

    // Multi-line comment
    if(peek_char(lexer, 1) == '*') {
        advance(lexer, 2);  // consume '/*'
        size_t comment_start = lexer->position;

        while(lexer->position < lexer->input_len) {
            if(current_char(lexer) == '*' && peek_char(lexer, 1) == '/') {
                size_t len = lexer->position - comment_start;
                char* comment = strndup(lexer->input + comment_start, len);
                add_string_allocation(lexer, comment);

                advance(lexer, 2);  // consume '*/'

                Token* token = token_create(TOKEN_COMMENT, comment, start_line, start_column,
                                            lexer->file_name, lexer->file_directory);
                return token;
            }
            advance(lexer, 1);
        }

        lexer_error_print(LEXER_ERROR_UNTERMINATED_COMMENT, lexer->line, lexer->column,
                          lexer->input, lexer->file_name);
        return NULL;
    }

    // Standalone '/'
    Token* tok = create_token(lexer, TOKEN_SLASH, "/");
    advance(lexer, 1);
    return tok;
}

static Token* create_token(Lexer* lexer, TokenType type, const char* value) {
    return token_create(type, value, lexer->line, lexer->column, lexer->file_name,
                        lexer->file_directory);
}

static void add_string_allocation(Lexer* lexer, char* str) {
    if(lexer->string_count >= lexer->string_capacity) {
        lexer->string_capacity *= 2;
        lexer->string_allocations =
            realloc(lexer->string_allocations, sizeof(char*) * lexer->string_capacity);
    }
    lexer->string_allocations[lexer->string_count++] = str;
}
