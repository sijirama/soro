
#include "../../include/error.h"

#include <stdio.h>

void lexer_error_print(LexerErrorType error, uint32_t line, uint32_t column, const char* input,
                       const char* file_name) {
    fprintf(stderr, "\033[1;31mLexer Error\033[0m in %s at line %u, column %u:\n",
            file_name ? file_name : "unknown", line, column);

    switch(error) {
        case LEXER_ERROR_UNTERMINATED_STRING:
            fprintf(stderr, "  Unterminated string literal\n");
            break;
        case LEXER_ERROR_INVALID_ESCAPE:
            fprintf(stderr, "  Invalid escape sequence in string\n");
            break;
        case LEXER_ERROR_UNTERMINATED_COMMENT:
            fprintf(stderr, "  Unterminated multi-line comment\n");
            break;
        case LEXER_ERROR_INVALID_CHAR:
            fprintf(stderr, "  Invalid character\n");
            break;
        default:
            fprintf(stderr, "  Unknown error\n");
            break;
    }

    // Show the line with error (simplified)
    if(input) {
        // Find start of line
        const char* line_start = input;
        uint32_t current_line = 1;

        while(current_line < line && *line_start) {
            if(*line_start == '\n') {
                current_line++;
            }
            line_start++;
        }

        // Find end of line
        const char* line_end = line_start;
        while(*line_end && *line_end != '\n') {
            line_end++;
        }

        // Print the line
        fprintf(stderr, "\n  %.*s\n", (int)(line_end - line_start), line_start);

        // Print error indicator
        fprintf(stderr, "  ");
        for(uint32_t i = 1; i < column; i++) {
            fprintf(stderr, " ");
        }
        fprintf(stderr, "\033[1;31m^\033[0m\n");
    }
}
