const std = @import("std");
const Token = @import("../token/main.zig").Token;
const TokenType = @import("../token/main.zig").TokenType;
const LexerError = @import("./error.zig").LexerError;
const LexerErrorUtils = @import("./error.zig");

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

            '"' => {
                self.advancePosition(1); // INFO: Move past opening quote
                var string = std.ArrayList(u8).init(self.allocator);
                defer string.deinit();

                while (self.position < self.input.len) {
                    const currentChar = self.input[self.position];

                    // INFO: Check for closing quote
                    if (currentChar == '"') {
                        self.advancePosition(1); // Move past closing quote

                        // Create and append the token for the string
                        const tokenValue = try string.toOwnedSlice(); // Take ownership of memory
                        //errdefer self.allocator.free(tokenValue); // Free on error
                        const token = self.createToken(.STRING, tokenValue);
                        try self.stringAllocations.append(tokenValue);
                        return token; // Return the token, clean up `string` automatically via defer.
                    }

                    // Handle escape sequences
                    if (currentChar == '\\') {
                        self.advancePosition(1); // Skip the backslash

                        if (self.position >= self.input.len) {
                            return LexerError.InvalidString;
                        }

                        const escapedChar = self.input[self.position];
                        switch (escapedChar) {
                            'n' => try string.append('\n'), // Handle newline
                            't' => try string.append('\t'), // Handle tab
                            '\\', '"' => try string.append(escapedChar), // Handle backslash and quote
                            else => return LexerError.InvalidString,
                        }
                    } else {
                        try string.append(currentChar);
                    }

                    self.advancePosition(1); // Move to next character
                }

                return LexerError.UnterminatedString;
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
