#include <stdio.h>
#include <string.h>

#include "../../include/lexer.h"
#include "../../include/token.h"
#include "../utest.h"

UTEST(lexer_basic, empty_input) {
    Lexer* lexer = lexer_init("", "test.soro", ".");
    ASSERT_TRUE(lexer != NULL);

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(1, count);
    ASSERT_EQ(TOKEN_EOF, tokens[0]->type);
    ASSERT_STREQ("", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_basic, single_plus) {
    Lexer* lexer = lexer_init("+", "test.soro", ".");
    ASSERT_TRUE(lexer != NULL);

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);  // PLUS + EOF
    ASSERT_EQ(TOKEN_PLUS, tokens[0]->type);
    ASSERT_STREQ("+", tokens[0]->value);
    ASSERT_EQ(TOKEN_EOF, tokens[1]->type);

    lexer_free(lexer);
}

UTEST(lexer_basic, whitespace_skipping) {
    Lexer* lexer = lexer_init("  \t\n+", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);
    ASSERT_EQ(TOKEN_PLUS, tokens[0]->type);
    ASSERT_STREQ("+", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_basic, operators) {
    const char* input = "+ - * / ! = == != < >";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(11, count);  // 10 operators + EOF

    ASSERT_EQ(TOKEN_PLUS, tokens[0]->type);
    ASSERT_EQ(TOKEN_MINUS, tokens[1]->type);
    ASSERT_EQ(TOKEN_ASTERISK, tokens[2]->type);
    ASSERT_EQ(TOKEN_SLASH, tokens[3]->type);
    ASSERT_EQ(TOKEN_BANG, tokens[4]->type);
    ASSERT_EQ(TOKEN_ASSIGN, tokens[5]->type);
    ASSERT_EQ(TOKEN_EQUAL, tokens[6]->type);
    ASSERT_EQ(TOKEN_NOT_EQUAL, tokens[7]->type);
    ASSERT_EQ(TOKEN_LESS_THAN, tokens[8]->type);
    ASSERT_EQ(TOKEN_GREATER_THAN, tokens[9]->type);

    lexer_free(lexer);
}

UTEST(lexer_basic, delimiters) {
    const char* input = "( ) { } [ ] , ; :";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(10, count);  // 9 delimiters + EOF

    ASSERT_EQ(TOKEN_LPAREN, tokens[0]->type);
    ASSERT_EQ(TOKEN_RPAREN, tokens[1]->type);
    ASSERT_EQ(TOKEN_LBRACE, tokens[2]->type);
    ASSERT_EQ(TOKEN_RBRACE, tokens[3]->type);
    ASSERT_EQ(TOKEN_LBRACKET, tokens[4]->type);
    ASSERT_EQ(TOKEN_RBRACKET, tokens[5]->type);
    ASSERT_EQ(TOKEN_COMMA, tokens[6]->type);
    ASSERT_EQ(TOKEN_SEMICOLON, tokens[7]->type);
    ASSERT_EQ(TOKEN_COLON, tokens[8]->type);

    lexer_free(lexer);
}

UTEST(lexer_basic, keywords) {
    const char* input = "abeg oya comot abi naso true false and or orelse";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(11, count);  // 9 keywords + EOF

    ASSERT_EQ(TOKEN_ABEG, tokens[0]->type);
    ASSERT_STREQ("abeg", tokens[0]->value);

    ASSERT_EQ(TOKEN_OYA, tokens[1]->type);
    ASSERT_STREQ("oya", tokens[1]->value);

    ASSERT_EQ(TOKEN_COMOT, tokens[2]->type);
    ASSERT_STREQ("comot", tokens[2]->value);

    ASSERT_EQ(TOKEN_ABI, tokens[3]->type);
    ASSERT_STREQ("abi", tokens[3]->value);

    ASSERT_EQ(TOKEN_NASO, tokens[4]->type);
    ASSERT_STREQ("naso", tokens[4]->value);

    ASSERT_EQ(TOKEN_TRUE, tokens[5]->type);
    ASSERT_EQ(TOKEN_FALSE, tokens[6]->type);
    ASSERT_EQ(TOKEN_AND, tokens[7]->type);
    ASSERT_EQ(TOKEN_OR, tokens[8]->type);
    ASSERT_EQ(TOKEN_OR_ELSE, tokens[9]->type);

    lexer_free(lexer);
}

UTEST(lexer_basic, type_keywords) {
    const char* input = "int float string bool void any error interface";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(9, count);  // 8 types + EOF

    for(size_t i = 0; i < 8; i++) {
        ASSERT_EQ(TOKEN_TYPE, tokens[i]->type);
    }

    ASSERT_STREQ("int", tokens[0]->value);
    ASSERT_STREQ("float", tokens[1]->value);
    ASSERT_STREQ("string", tokens[2]->value);
    ASSERT_STREQ("bool", tokens[3]->value);

    lexer_free(lexer);
}

UTEST(lexer_basic, identifiers) {
    const char* input = "x y foo bar_baz _private test123";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(7, count);  // 5 identifiers + EOF

    for(size_t i = 0; i < 5; i++) {
        ASSERT_EQ(TOKEN_IDENT, tokens[i]->type);
    }

    ASSERT_STREQ("x", tokens[0]->value);
    ASSERT_STREQ("y", tokens[1]->value);
    ASSERT_STREQ("foo", tokens[2]->value);
    ASSERT_STREQ("bar_baz", tokens[3]->value);
    ASSERT_STREQ("_private", tokens[4]->value);

    lexer_free(lexer);
}

UTEST(lexer_basic, line_tracking) {
    const char* input = "abeg\nx\n+";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(1, tokens[0]->line);  // abeg on line 1
    ASSERT_EQ(2, tokens[1]->line);  // x on line 2
    ASSERT_EQ(3, tokens[2]->line);  // + on line 3

    lexer_free(lexer);
}

//-----------------------------------------------------------------------------------------

UTEST(lexer_numbers, single_integer) {
    Lexer* lexer = lexer_init("42", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);  // INTEGER + EOF
    ASSERT_EQ(TOKEN_INTEGER, tokens[0]->type);
    ASSERT_STREQ("42", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, multiple_integers) {
    const char* input = "123 0 456";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(4, count);  // 3 integers + EOF

    ASSERT_EQ(TOKEN_INTEGER, tokens[0]->type);
    ASSERT_STREQ("123", tokens[0]->value);

    ASSERT_EQ(TOKEN_INTEGER, tokens[1]->type);
    ASSERT_STREQ("0", tokens[1]->value);

    ASSERT_EQ(TOKEN_INTEGER, tokens[2]->type);
    ASSERT_STREQ("456", tokens[2]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, single_float) {
    Lexer* lexer = lexer_init("3.14", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);  // FLOAT + EOF
    ASSERT_EQ(TOKEN_FLOAT, tokens[0]->type);
    ASSERT_STREQ("3.14", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, multiple_floats) {
    const char* input = "1.5 2.5 3.5";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(4, count);  // 3 floats + EOF

    ASSERT_EQ(TOKEN_FLOAT, tokens[0]->type);
    ASSERT_STREQ("1.5", tokens[0]->value);

    ASSERT_EQ(TOKEN_FLOAT, tokens[1]->type);
    ASSERT_STREQ("2.5", tokens[1]->value);

    ASSERT_EQ(TOKEN_FLOAT, tokens[2]->type);
    ASSERT_STREQ("3.5", tokens[2]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, float_precision) {
    Lexer* lexer = lexer_init("95.5", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_FLOAT, tokens[0]->type);
    ASSERT_STREQ("95.5", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, integer_with_operators) {
    const char* input = "5 + 10";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(4, count);  // 5 PLUS 10 EOF

    ASSERT_EQ(TOKEN_INTEGER, tokens[0]->type);
    ASSERT_STREQ("5", tokens[0]->value);

    ASSERT_EQ(TOKEN_PLUS, tokens[1]->type);

    ASSERT_EQ(TOKEN_INTEGER, tokens[2]->type);
    ASSERT_STREQ("10", tokens[2]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, negative_number) {
    const char* input = "- 456";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_MINUS, tokens[0]->type);
    ASSERT_EQ(TOKEN_INTEGER, tokens[1]->type);
    ASSERT_STREQ("456", tokens[1]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, array_of_numbers) {
    const char* input = "[1, 2]";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(6, count);  // [ 1 , 2 ] EOF

    ASSERT_EQ(TOKEN_LBRACKET, tokens[0]->type);
    ASSERT_EQ(TOKEN_INTEGER, tokens[1]->type);
    ASSERT_STREQ("1", tokens[1]->value);
    ASSERT_EQ(TOKEN_COMMA, tokens[2]->type);
    ASSERT_EQ(TOKEN_INTEGER, tokens[3]->type);
    ASSERT_STREQ("2", tokens[3]->value);
    ASSERT_EQ(TOKEN_RBRACKET, tokens[4]->type);

    lexer_free(lexer);
}

UTEST(lexer_numbers, multi_dimensional_array) {
    const char* input = "[[1, 2], [3, 4]]";
    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(14, count);

    int i = 0;
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);  // [
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);  // [
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);     // 1
    ASSERT_STREQ("1", tokens[i++]->value);
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);  // ,
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);  // 2
    ASSERT_STREQ("2", tokens[i++]->value);
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);  // ]
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);     // ,
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);  // [
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);     // 3
    ASSERT_STREQ("3", tokens[i++]->value);
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);  // ,
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);  // 4
    ASSERT_STREQ("4", tokens[i++]->value);
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);  // ]
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);  // ]

    lexer_free(lexer);
}

// --------------------------------------------------------------------------------------------

UTEST(lexer_strings, simple_double_quote) {
    Lexer* lexer = lexer_init("\"hello\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);  // STRING + EOF
    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("hello", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, simple_single_quote) {
    Lexer* lexer = lexer_init("'hello'", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(2, count);
    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("hello", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, string_with_spaces) {
    Lexer* lexer = lexer_init("\"foo bar\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("foo bar", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, multiple_strings) {
    const char* input = "\"foobar\" \"foo bar\"";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(3, count);  // 2 strings + EOF

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("foobar", tokens[0]->value);

    ASSERT_EQ(TOKEN_STRING, tokens[1]->type);
    ASSERT_STREQ("foo bar", tokens[1]->value);

    lexer_free(lexer);
}

UTEST(lexer_numbers, mixed_numbers_strings_array) {
    const char* input = "[[1, \"hello\", 3.14], [\"world\", 42]]";
    Lexer* lexer = lexer_init(input, "test.soro", ".");
    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(16, count);

    int i = 0;

    // Outer [
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);

    // Inner [
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);

    // 1
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);
    ASSERT_STREQ("1", tokens[i++]->value);

    // ,
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);

    // "hello"
    ASSERT_EQ(TOKEN_STRING, tokens[i]->type);
    ASSERT_STREQ("hello", tokens[i++]->value);

    // ,
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);

    // 3.14
    ASSERT_EQ(TOKEN_FLOAT, tokens[i]->type);
    ASSERT_STREQ("3.14", tokens[i++]->value);

    // ]
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);

    // ,
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);

    // Inner [
    ASSERT_EQ(TOKEN_LBRACKET, tokens[i++]->type);

    // "world"
    ASSERT_EQ(TOKEN_STRING, tokens[i]->type);
    ASSERT_STREQ("world", tokens[i++]->value);

    // ,
    ASSERT_EQ(TOKEN_COMMA, tokens[i++]->type);

    // 42
    ASSERT_EQ(TOKEN_INTEGER, tokens[i]->type);
    ASSERT_STREQ("42", tokens[i++]->value);

    // ]
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);

    // Outer ]
    ASSERT_EQ(TOKEN_RBRACKET, tokens[i++]->type);

    // EOF (assuming your lexer includes it)
    ASSERT_EQ(TOKEN_EOF, tokens[i++]->type);

    lexer_free(lexer);
}

UTEST(lexer_strings, escape_newline) {
    Lexer* lexer = lexer_init("\"hello\\nworld\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("hello\nworld", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, escape_tab) {
    Lexer* lexer = lexer_init("\"hello\\tworld\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("hello\tworld", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, escape_backslash) {
    Lexer* lexer = lexer_init("\"hello\\\\world\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("hello\\world", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, escape_quotes) {
    Lexer* lexer = lexer_init("\"He said \\\"hello\\\"\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("He said \"hello\"", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, empty_string) {
    Lexer* lexer = lexer_init("\"\"", "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(TOKEN_STRING, tokens[0]->type);
    ASSERT_STREQ("", tokens[0]->value);

    lexer_free(lexer);
}

UTEST(lexer_strings, string_in_assignment) {
    const char* input = "abeg name string = \"John\"";
    Lexer* lexer = lexer_init(input, "test.soro", ".");

    size_t count = 0;
    Token** tokens = lexer_tokenize(lexer, &count);

    ASSERT_EQ(6, count);  // abeg name string = "John" EOF

    ASSERT_EQ(TOKEN_ABEG, tokens[0]->type);
    ASSERT_EQ(TOKEN_IDENT, tokens[1]->type);
    ASSERT_STREQ("name", tokens[1]->value);
    ASSERT_EQ(TOKEN_TYPE, tokens[2]->type);
    ASSERT_STREQ("string", tokens[2]->value);
    ASSERT_EQ(TOKEN_ASSIGN, tokens[3]->type);
    ASSERT_EQ(TOKEN_STRING, tokens[4]->type);
    ASSERT_STREQ("John", tokens[4]->value);

    lexer_free(lexer);
}
