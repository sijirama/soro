```zig
const std = @import("std");

const AstNode = struct {
    type: NodeType,
    // Other fields like expression, operands, etc.
};

const SymbolTable = std.StringHashMap(Type);

const Type = enum {
    Int,
    Float,
    Bool,
    String,
    Unknown,
};

fn typeCheck(ast: *AstNode, symbolTable: *SymbolTable) void {
    switch (ast.type) {
        .VariableDeclaration => {
            const varName = ast.name;
            const varType = inferType(ast.expression, symbolTable);
            symbolTable.put(varName, varType) catch unreachable;
        },
        .BinaryExpression => {
            const leftType = inferType(ast.left, symbolTable);
            const rightType = inferType(ast.right, symbolTable);
            if (leftType != rightType) {
                std.debug.print("Type error: mismatched types in binary expression\n", .{});
            }
        },
        // Handle other node types...
    }
}

fn inferType(ast: *AstNode, symbolTable: *SymbolTable) Type {
    switch (ast.type) {
        .NumberLiteral => return Type.Int,
        .VariableReference => {
            const varName = ast.name;
            return symbolTable.get(varName) orelse {
                std.debug.print("Error: undefined variable '{s}'\n", .{varName});
                return Type.Unknown;
            };
        },
        // Handle other cases...
    }
}

```
