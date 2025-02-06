const std = @import("std");
const Token = @import("../token/main.zig").Token;
const Keywords = @import("../token/main.zig").Keywords;
const TokenType = @import("../token/main.zig").TokenType;
const LexerError = @import("./error.zig").LexerError;
const LexerErrorUtils = @import("./error.zig");
const TypeKeywords = @import("../type/types.zig").TypeKeywords;

pub const Lexer = struct {
    input: []const u8,
    position: u32,
    line: u32,
    column: u32,
    fileName: []const u8,
    fileDirectory: []const u8,
    allocator: std.mem.Allocator,
    stringAllocations: std.ArrayList([]const u8), // Add this

    // Constructor for the lexer
    pub fn init(allocator: std.mem.Allocator, input: []const u8, fileName: []const u8, fileDirectory: []const u8) Lexer {
        return Lexer{
            .input = input,
            .position = 0,
            .line = 1, // Start at line 1
            .column = 1, // Start at column 1
            .fileName = fileName,
            .fileDirectory = fileDirectory,
            .allocator = allocator,
            .stringAllocations = std.ArrayList([]const u8).init(allocator),
        };
    }

    // New method to collect all tokens
    pub fn tokenize(self: *Lexer) ![]Token {
        var tokens = std.ArrayList(Token).init(self.allocator);
        defer tokens.deinit();

        while (true) {
            const token = self.nextToken() catch |err| {
                try LexerErrorUtils.handleLexerError(err, self.line, self.column, self.input, self.allocator);

                // Return a token list with an error token
                const errorToken = self.createToken(.ERROR, "Error occurred");
                try tokens.append(errorToken);
                break;
            };

            try tokens.append(token);

            if (token.type == .EOF) {
                break;
            }
        }

        return try tokens.toOwnedSlice();
    }

    // Example of a method that would read the next token
    pub fn nextToken(self: *Lexer) !Token {

        // Skip whitespace while tracking position
        self.skipWhitespace();

        // Check current character and create appropriate token
        if (self.position >= self.input.len) {
            return self.createToken(.EOF, "");
        }

        const ch = self.input[self.position];

        switch (ch) {
            '+' => {
                const token = self.createToken(.PLUS, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '-' => {
                const token = self.createToken(.MINUS, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },

            ';' => {
                const token = self.createToken(.SEMICOLON, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            ':' => {
                const token = self.createToken(.COLON, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },

            '(' => {
                const token = self.createToken(.LPAREN, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            ')' => {
                const token = self.createToken(.RPAREN, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '{' => {
                const token = self.createToken(.LBRACE, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '}' => {
                const token = self.createToken(.RBRACE, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '[' => {
                const token = self.createToken(.LBRACKET, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            ']' => {
                const token = self.createToken(.RBRACKET, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            ',' => {
                const token = self.createToken(.COMMA, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },

            '*' => {
                const token = self.createToken(.ASTERISK, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },

            '/' => return self.readSlashOrComment(),

            '<' => {
                const token = self.createToken(.LESS_THAN, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '>' => {
                const token = self.createToken(.GREATER_THAN, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
            '=' => {
                if (self.peekNextChar() == '=') {
                    const token = self.createToken(.EQUAL, self.input[self.position .. self.position + 2]);
                    self.advancePosition(2);
                    return token;
                } else {
                    const token = self.createToken(.ASSIGN, self.input[self.position .. self.position + 1]);
                    self.advancePosition(1);
                    return token;
                }
            },
            '!' => {
                if (self.peekNextChar() == '=') {
                    const token = self.createToken(.NOT_EQUAL, self.input[self.position .. self.position + 2]);
                    self.advancePosition(2);
                    return token;
                } else {
                    const token = self.createToken(.BANG, self.input[self.position .. self.position + 1]);
                    self.advancePosition(1);
                    return token;
                }
            },

            '"' => return self.readString(),

            '0'...'9' => return self.readNumber(),

            'a'...'z', 'A'...'Z', '_' => {
                const start = self.position;
                while (self.position < self.input.len and isIdentChar(self.input[self.position])) {
                    self.advancePosition(1);
                }
                const ident = self.input[start..self.position];

                // Check if it's a keyword
                if (Keywords.getKeywordToken(ident)) |tokenType| {
                    return self.createToken(tokenType, ident);
                }

                // Check if it's a type keyword
                if (TypeKeywords.getType(ident)) |_| {
                    return self.createToken(.TYPE, ident); // Treat type keywords as TYPE
                }

                return self.createToken(.IDENT, ident);
            },

            else => {
                const token = self.createToken(.ILLEGAL, self.input[self.position .. self.position + 1]);
                self.advancePosition(1);
                return token;
            },
        }
    }

    // Helper method to create a new token with all properties
    pub fn createToken(self: *Lexer, tokenType: TokenType, value: []const u8) Token {
        return Token{
            .type = tokenType,
            .value = value,
            .line = self.line,
            .column = self.column,
            .fileName = self.fileName,
            .fileDirectory = self.fileDirectory,
        };
    }

    fn peekNextChar(self: *Lexer) ?u8 {
        if (self.position + 1 >= self.input.len) return null;
        return self.input[self.position + 1];
    }

    fn peekNextChars(self: *Lexer, offset: usize) ?u8 {
        if (self.position + offset >= self.input.len) {
            return null;
        }
        return self.input[self.position + offset];
    }

    fn isIdentChar(ch: u8) bool {
        return (ch >= 'a' and ch <= 'z') or
            (ch >= 'A' and ch <= 'Z') or
            (ch >= '0' and ch <= '9') or
            ch == '_';
    }

    fn readNumber(self: *Lexer) !Token {
        const start = self.position;
        var hasDecimal = false;

        // Read integer part
        while (self.position < self.input.len and isDigit(self.input[self.position])) {
            self.advancePosition(1);
        }

        // Check for decimal point
        if (self.position < self.input.len and self.input[self.position] == '.') {
            // Look ahead to ensure there's a digit after the decimal
            if (self.position + 1 < self.input.len and isDigit(self.input[self.position + 1])) {
                hasDecimal = true;
                self.advancePosition(1); // consume the decimal point

                // Read decimal part
                while (self.position < self.input.len and isDigit(self.input[self.position])) {
                    self.advancePosition(1);
                }
            }
        }

        const numberStr = self.input[start..self.position];
        return self.createToken(if (hasDecimal) .FLOAT else .INTEGER, numberStr);
    }

    fn readString(self: *Lexer) !Token {
        self.advancePosition(1); // Skip opening quote
        var string = std.ArrayList(u8).init(self.allocator);
        defer string.deinit();

        while (self.position < self.input.len) {
            const ch = self.input[self.position];

            if (ch == '"') {
                self.advancePosition(1); // Skip closing quote
                const tokenValue = try string.toOwnedSlice();
                try self.stringAllocations.append(tokenValue);
                return self.createToken(.STRING, tokenValue);
            }

            if (ch == '\\') {
                try self.handleEscapeSequence(&string);
            } else {
                try string.append(ch);
                self.advancePosition(1);
            }
        }

        return LexerError.UnterminatedString;
    }

    fn readSlashOrComment(self: *Lexer) !Token {
        const start = self.position;

        // Single-line comment
        if (self.peekNextChar() == '/') {
            self.advancePosition(1); // Consume the second '/'
            while (self.position < self.input.len and self.input[self.position] != '\n') {
                self.advancePosition(1); // Consume until end of line
            }
            // Include the last character before the newline
            const value = self.input[start + 2 .. self.position];
            return self.createToken(.COMMENT, value);
        }

        // Multi-line comment
        if (self.peekNextChar() == '*') {
            self.advancePosition(1); // Consume the '*'
            while (self.position < self.input.len) {
                if (self.input[self.position] == '*' and self.peekNextChar() == '/') {
                    self.advancePosition(2); // Consume '*/'
                    const value = self.input[start + 2 .. self.position - 2];
                    return self.createToken(.COMMENT, value);
                }
                self.advancePosition(1); // Consume characters until '*/' is found
            }
            return error.UnterminatedComment;
        }

        // Standalone '/'
        self.advancePosition(1); // Consume the '/'
        return self.createToken(.SLASH, self.input[start..self.position]);
    }

    fn handleEscapeSequence(self: *Lexer, string: *std.ArrayList(u8)) !void {
        self.advancePosition(1); // Skip backslash

        if (self.position >= self.input.len) {
            return LexerError.InvalidString;
        }

        const escapedChar = self.input[self.position];
        const mappedChar: u8 = switch (escapedChar) {
            'n' => '\n',
            't' => '\t',
            'r' => '\r',
            '\\', '"' => escapedChar,
            else => return LexerError.InvalidString,
        };

        try string.append(mappedChar);
        self.advancePosition(1);
    }

    fn isDigit(ch: u8) bool {
        return ch >= '0' and ch <= '9';
    }

    // Helper to track line and column numbers
    pub fn advancePosition(self: *Lexer, chars: u32) void {
        var i: u32 = 0;
        while (i < chars) : (i += 1) {
            if (self.position < self.input.len) {
                if (self.input[self.position] == '\n') {
                    self.line += 1;
                    self.column = 1; // Reset column to 1 after a newline
                } else {
                    self.column += 1;
                }
                self.position += 1;
            }
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.position < self.input.len) {
            const ch = self.input[self.position];
            if (ch == ' ' or ch == '\t' or ch == '\n' or ch == '\r') {
                self.advancePosition(1); // Use advancePosition to track line and column
            } else {
                break;
            }
        }
    }

    pub fn deinit(self: *Lexer) void {
        // Free all string allocations
        for (self.stringAllocations.items) |str| {
            self.allocator.free(str);
        }
        self.stringAllocations.deinit();
    }
};
