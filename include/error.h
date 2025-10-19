#ifndef ERROR_H
#define ERROR_H

#include <stdint.h>

typedef enum {
    LEXER_ERROR_NONE = 0,
    LEXER_ERROR_UNTERMINATED_STRING,
    LEXER_ERROR_INVALID_ESCAPE,
    LEXER_ERROR_UNTERMINATED_COMMENT,
    LEXER_ERROR_INVALID_CHAR,
} LexerErrorType;

// Print error message with context
void lexer_error_print(LexerErrorType error, uint32_t line, uint32_t column,
                       const char *input, const char *file_name);

#endif // ERROR_H
