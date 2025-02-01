const std = @import("std");
const Token = @import("../token/main.zig").Token;
const Type = @import("../token/main.zig").Type;

//Root node of the ast
pub const Program = struct {
    statements: std.ArrayList(Statement),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Program {
        return Program{ .statements = std.ArrayList(Statement).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *Program) void {
        self.statements.deinit();
    }

    pub fn tokenLiteral(self: Program) []const u8 {
        if (self.statements.items.len > 0) {
            return self.statements.items[0].tokenLiteral();
        } else {
            return "";
        }
    }
};

// Expanded Expression Union to support more types
pub const Expression = union(enum) {
    identifier: Identifier,

    integer_literal: IntegerLiteral,
    boolean_literal: BooleanLiteral,
    string_literal: StringLiteral,

    prefix_expression: PrefixExpression,
    infix_expression: InfixExpression,

    pub fn tokenLiteral(self: Expression) []const u8 {
        return switch (self) {
            .identifier => |id| id.tokenLiteral(),
            .integer_literal => |lit| lit.tokenLiteral(),
            .boolean_literal => |lit| lit.tokenLiteral(),
            .string_literal => |lit| lit.tokenLiteral(),
            .prefix_expression => |expr| expr.tokenLiteral(),
            .infix_expression => |expr| expr.tokenLiteral(),
        };
    }
};

pub const Statement = union(enum) {
    abeg_statement: AbegStatement,
    comot_statement: ComotStatement,
    expression_statement: ExpressionStatement,

    pub fn tokenLiteral(self: Statement) []const u8 {
        return switch (self) {
            .abeg_statement => |stmt| stmt.tokenLiteral(),
            .comot_statement => |stmt| stmt.tokenLiteral(),
            .expression_statement => |stmt| stmt.tokenLiteral(),
        };
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    pub fn tokenLiteral(self: Identifier) []const u8 {
        return self.token.value;
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,

    pub fn tokenLiteral(self: IntegerLiteral) []const u8 {
        return self.token.value;
    }
};

pub const StringLiteral = struct {
    token: Token,
    value: []const u8,

    pub fn tokenLiteral(self: StringLiteral) []const u8 {
        return self.token.value;
    }
};

pub const BooleanLiteral = struct {
    token: Token,
    value: bool,

    pub fn tokenLiteral(self: BooleanLiteral) []const u8 {
        return self.token.value;
    }
};

pub const PrefixExpression = struct {
    token: Token, // The prefix token, e.g., '!' or '-'
    operator: []const u8,
    right: *Expression,

    pub fn tokenLiteral(self: PrefixExpression) []const u8 {
        return self.token.value;
    }
};

pub const InfixExpression = struct {
    token: Token, // The operator token
    left: *Expression,
    operator: []const u8,
    right: *Expression,

    pub fn tokenLiteral(self: InfixExpression) []const u8 {
        return self.token.value;
    }
};

// basically your let statemtnt for vardecl in other languages
pub const AbegStatement = struct {
    token: Token,
    name: Identifier,
    value: *Expression,
    type_annotation: ?Type = null,
    is_locked: bool = false,
    is_inferred: bool = false,

    pub fn tokenLiteral(self: AbegStatement) []const u8 {
        return self.token.value;
    }
};

// return statemtnt is other languages
pub const ComotStatement = struct {
    token: Token,
    value: *Expression,

    pub fn tokenLiteral(self: ComotStatement) []const u8 {
        return self.token.value;
    }
};

pub const ExpressionStatement = struct {
    token: Token, // The first token of the expression
    expression: *Expression,

    pub fn tokenLiteral(self: ExpressionStatement) []const u8 {
        return self.token.value;
    }
};
