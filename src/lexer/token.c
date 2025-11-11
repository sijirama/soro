#define _POSIX_C_SOURCE 200809L

#include "../../include/token.h"

#include <stdlib.h>
#include <string.h>

static const char* token_type_strings[] = {
    [TOKEN_ILLEGAL] = "ILLEGAL",
    [TOKEN_EOF] = "EOF",
    [TOKEN_COMMENT] = "COMMENT",
    [TOKEN_IDENT] = "IDENT",
    [TOKEN_INTEGER] = "INTEGER",
    [TOKEN_FLOAT] = "FLOAT",
    [TOKEN_STRING] = "STRING",
    [TOKEN_ASSIGN] = "ASSIGN",
    [TOKEN_PLUS] = "PLUS",
    [TOKEN_MINUS] = "MINUS",
    [TOKEN_ASTERISK] = "ASTERISK",
    [TOKEN_SLASH] = "SLASH",
    [TOKEN_BANG] = "BANG",
    [TOKEN_EQUAL] = "EQUAL",
    [TOKEN_NOT_EQUAL] = "NOT_EQUAL",
    [TOKEN_LESS_THAN] = "LESS_THAN",
    [TOKEN_GREATER_THAN] = "GREATER_THAN",
    [TOKEN_COMMA] = "COMMA",
    [TOKEN_SEMICOLON] = "SEMICOLON",
    [TOKEN_COLON] = "COLON",
    [TOKEN_LPAREN] = "LPAREN",
    [TOKEN_RPAREN] = "RPAREN",
    [TOKEN_LBRACE] = "LBRACE",
    [TOKEN_RBRACE] = "RBRACE",
    [TOKEN_LBRACKET] = "LBRACKET",
    [TOKEN_RBRACKET] = "RBRACKET",
    [TOKEN_ABEG] = "ABEG",
    [TOKEN_OYA] = "OYA",
    [TOKEN_WAKA] = "WAKA",
    [TOKEN_COMOT] = "COMOT",
    [TOKEN_ABI] = "ABI",
    [TOKEN_NASO] = "NASO",
    [TOKEN_TRUE] = "TRUE",
    [TOKEN_FALSE] = "FALSE",
    [TOKEN_AND] = "AND",
    [TOKEN_OR] = "OR",
    [TOKEN_OR_ELSE] = "OR_ELSE",
    [TOKEN_TYPE] = "TYPE",
};

Token* token_create(TokenType type, const char* value, uint32_t line, uint32_t column,
                    const char* file_name, const char* file_directory) {
    // INFO: Always duplicate in token_create

    Token* token = malloc(sizeof(Token));
    if(!token)
        return NULL;

    token->type = type;
    token->value = strdup(value);  // Duplicate!
    token->line = line;
    token->column = column;
    token->file_name = strdup(file_name);            // Duplicate!
    token->file_directory = strdup(file_directory);  // Duplicate!
    return token;
}

void token_free(Token* token) {
    if(!token)
        return;

    free(token->value);
    free(token->file_name);
    free(token->file_directory);
    free(token);
}

const char* token_type_to_string(TokenType type) {
    if(type >= 0 && type < sizeof(token_type_strings) / sizeof(token_type_strings[0])) {
        return token_type_strings[type];
    }
    return "UNKNOWN";
}

TokenType token_lookup_keyword(const char* ident) {
    if(strcmp(ident, "abeg") == 0)
        return TOKEN_ABEG;
    if(strcmp(ident, "oya") == 0)
        return TOKEN_OYA;
    if(strcmp(ident, "waka") == 0)
        return TOKEN_WAKA;
    if(strcmp(ident, "comot") == 0)
        return TOKEN_COMOT;
    if(strcmp(ident, "abi") == 0)
        return TOKEN_ABI;
    if(strcmp(ident, "naso") == 0)
        return TOKEN_NASO;
    if(strcmp(ident, "true") == 0)
        return TOKEN_TRUE;
    if(strcmp(ident, "false") == 0)
        return TOKEN_FALSE;
    if(strcmp(ident, "and") == 0)
        return TOKEN_AND;
    if(strcmp(ident, "or") == 0)
        return TOKEN_OR;
    if(strcmp(ident, "orelse") == 0)
        return TOKEN_OR_ELSE;

    return TOKEN_IDENT;
}

int token_is_type_keyword(const char* ident) {
    return (strcmp(ident, "int") == 0 || strcmp(ident, "float") == 0 ||
            strcmp(ident, "string") == 0 || strcmp(ident, "bool") == 0 ||
            strcmp(ident, "void") == 0 || strcmp(ident, "any") == 0 ||
            strcmp(ident, "error") == 0 || strcmp(ident, "interface") == 0);
}
