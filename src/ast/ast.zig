const std = @import("std");
const Token = @import("../token/main.zig").Token;
const Type = @import("../type/types.zig").Type;

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
    float_literal: FloatLiteral, // Add this
    boolean_literal: BooleanLiteral,
    string_literal: StringLiteral,

    prefix_expression: PrefixExpression,
    infix_expression: InfixExpression,

    if_expression: IfExpression,

    pub fn tokenLiteral(self: Expression) []const u8 {
        return switch (self) {
            .identifier => |id| id.tokenLiteral(),
            .integer_literal => |lit| lit.tokenLiteral(),
            .float_literal => |lit| lit.tokenLiteral(),
            .boolean_literal => |lit| lit.tokenLiteral(),
            .string_literal => |lit| lit.tokenLiteral(),
            .prefix_expression => |expr| expr.tokenLiteral(),
            .infix_expression => |expr| expr.tokenLiteral(),
            .if_expression => |expr| expr.tokenLiteral(),
        };
    }
};

pub const Statement = union(enum) {
    abeg_statement: AbegStatement,
    comot_statement: ComotStatement,
    expression_statement: ExpressionStatement,
    block_statement: BlockStatement,

    pub fn tokenLiteral(self: Statement) []const u8 {
        return switch (self) {
            .abeg_statement => |stmt| stmt.tokenLiteral(),
            .comot_statement => |stmt| stmt.tokenLiteral(),
            .expression_statement => |stmt| stmt.tokenLiteral(),
            .block_statement => |stmt| stmt.tokenLiteral(),
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

pub const FloatLiteral = struct {
    token: Token,
    value: f64,

    pub fn tokenLiteral(self: FloatLiteral) []const u8 {
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

pub const BlockStatement = struct {
    token: Token,
    statements: std.ArrayList(Statement),
    //allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, token: Token) BlockStatement {
        return .{
            .token = token,
            .statements = std.ArrayList(Statement).init(allocator),
            //.allocator = allocator,
        };
    }

    pub fn tokenLiteral(self: BlockStatement) []const u8 {
        return self.token.value;
    }

    // pub fn deinit(self: *BlockStatement) void {
    //     std.debug.print("Deinitializing BlockStatement with {} statements\n", .{self.statements.items.len});
    //
    //     // First deinit any nested statements
    //     for (self.statements.items) |*stmt| {
    //         switch (stmt.*) {
    //             .block_statement => |*block| {
    //                 std.debug.print("Deinitializing nested BlockStatement\n", .{});
    //                 block.deinit();
    //             },
    //             .expression_statement => |expr| {
    //                 std.debug.print("Deinitializing ExpressionStatement\n", .{});
    //                 // Handle expression cleanup if needed
    //                 switch (expr.expression.*) {
    //                     .if_expression => |*if_expr| {
    //                         std.debug.print("Deinitializing IfExpression inside ExpressionStatement\n", .{});
    //                         if_expr.consequence.deinit();
    //                         if (if_expr.alternative) |alternative| {
    //                             alternative.deinit();
    //                         }
    //                     },
    //                     else => {
    //                         std.debug.print("Skipping expression cleanup for type: {}\n", .{expr.expression.*});
    //                     },
    //                 }
    //             },
    //             .abeg_statement => |_| {
    //                 std.debug.print("Deinitializing AbegStatement\n", .{});
    //             },
    //             .comot_statement => |_| {
    //                 std.debug.print("Deinitializing ComotStatement\n", .{});
    //             },
    //         }
    //     }
    //     self.statements.deinit();
    //     std.debug.print("Finished deinitializing BlockStatement\n", .{});
    // }
};

pub const IfExpression = struct {
    token: Token, // The 'if' token
    condition: *Expression,
    consequence: *BlockStatement,
    alternative: ?*BlockStatement, // Optional else block

    pub fn tokenLiteral(self: IfExpression) []const u8 {
        return self.token.value;
    }

    pub fn deinit(_: *IfExpression, _: std.mem.Allocator) void {
        std.debug.print("Deinitializing IfExpression\n", .{});

        // Do not free condition, consequence, or alternative here.
        // They are already tracked in allocated_expressions and will be freed by the parser.

        // // Free the condition expression
        // std.debug.print("Deinitializing condition expression\n", .{});
        // allocator.destroy(self.condition);
        //
        // // Free the consequence block
        // std.debug.print("Deinitializing consequence block\n", .{});
        // self.consequence.deinit();
        // allocator.destroy(self.consequence);
        //
        // // Free the alternative block if it exists
        // if (self.alternative) |alt| {
        //     std.debug.print("Deinitializing alternative block\n", .{});
        //     alt.deinit();
        //     allocator.destroy(alt);
        // }

        std.debug.print("Finished deinitializing IfExpression\n", .{});
    }
};
