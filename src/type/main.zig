const std = @import("std");

const TypesFile = @import("./types.zig");
const Type = TypesFile.Type;

const ErrorFile = @import("./error.zig");
const TypeError = ErrorFile.TypeError;
const printTypeError = ErrorFile.printTypeError;

const ast = @import("../ast/ast.zig");
const Program = ast.Program;
const Expression = ast.Expression;
const Statement = ast.Statement;
const AbegStatement = ast.AbegStatement;
const InfixExpression = ast.InfixExpression;

pub const TypeChecker = struct {
    symbol_table: SymbolTable,
    allocator: std.mem.Allocator,
    errors: std.ArrayList(TypeError),

    pub fn init(allocator: std.mem.Allocator) TypeChecker {
        return .{
            .symbol_table = SymbolTable.init(allocator),
            .allocator = allocator,
            .errors = std.ArrayList(TypeError).init(allocator),
        };
    }

    pub fn deinit(self: *TypeChecker) void {
        self.symbol_table.deinit();
        self.errors.deinit();
    }

    // Main type-checking method
    pub fn check(self: *TypeChecker, program: *Program) !void {
        for (program.statements.items) |*statement| {
            self.checkStatement(statement) catch |err| {
                self.errors.append(err) catch {};
                // Decide whether to continue or stop on the first error
                // For now, we'll continue checking
            };
        }

        // Print all errors at the end
        if (self.errors.items.len > 0) {
            std.debug.print("\nType Checker don catch {d} error(s):\n", .{self.errors.items.len});
            for (self.errors.items) |err| {
                printTypeError(err);
            }
            //return error.TypeCheckFailed; TODO::
        }
    }

    // Check a single statement
    fn checkStatement(self: *TypeChecker, statement: *Statement) !void {
        switch (statement.*) {
            .abeg_statement => |*abeg| try self.checkAbegStatement(abeg),
            .expression_statement => |*expr_stmt| try self.checkExpression(expr_stmt.expression),
            else => {}, // Handle other statement types as needed
        }
    }

    // Check an AbegStatement (variable declaration)
    fn checkAbegStatement(self: *TypeChecker, abeg: *AbegStatement) !void {
        const inferred_type = try self.checkExpression(abeg.value);

        if (abeg.type_annotation) |annotated_type| {
            // If there's a type annotation, ensure it matches the inferred type
            if (inferred_type != annotated_type) {
                printTypeError(error.TypeMismatch);
                return error.TypeMismatch;
            }
        } else if (abeg.is_inferred) {
            // If the type is inferred, use the inferred type
            abeg.type_annotation = inferred_type;
        }

        // Add the variable to the symbol table
        try self.symbol_table.put(abeg.name.value, abeg.type_annotation orelse inferred_type);
    }

    // Check an expression and return its type
    fn checkExpression(self: *TypeChecker, expression: *Expression) !Type {
        return switch (expression.*) {
            .integer_literal => Type.Int,
            .float_literal => Type.Float,
            .boolean_literal => Type.Bool,
            .string_literal => Type.String,
            .identifier => |id| self.symbol_table.get(id.value) orelse {
                printTypeError(error.UndefinedVariable);
                return error.UndefinedVariable;
            },
            .infix_expression => |*infix| try self.checkInfixExpression(infix),
            else => {
                printTypeError(error.UnknownType);
                return error.UnknownType;
            },
        };
    }

    // Check an infix expression and return its type
    fn checkInfixExpression(self: *TypeChecker, infix: *InfixExpression) !Type {
        const left_type = try self.checkExpression(infix.left);
        const right_type = try self.checkExpression(infix.right);

        if (left_type != right_type) {
            printTypeError(error.TypeMismatch);
            return error.TypeMismatch;
        }

        return left_type; // The type of the infix expression is the same as its operands
    }
};

// A symbol table to track variable and function types
pub const SymbolTable = struct {
    table: std.StringHashMap(Type),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .table = std.StringHashMap(Type).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        self.table.deinit();
    }

    // Add a variable or function to the symbol table
    pub fn put(self: *SymbolTable, name: []const u8, type_: Type) !void {
        try self.table.put(name, type_);
    }

    // Look up the type of a variable or function
    pub fn get(self: *SymbolTable, name: []const u8) ?Type {
        return self.table.get(name);
    }
};
