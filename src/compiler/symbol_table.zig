const std = @import("std");

pub const SYMBOL_SCOPE = []const u8;
pub const GLOBAL_SCOPE: SYMBOL_SCOPE = "GLOBAL";

pub const Symbol = struct {
    Name: []const u8,
    Scope: SYMBOL_SCOPE,
    Index: usize,
    IsConstant: ?bool,
};

pub const SymbolTable = struct {
    store: std.StringHashMap(Symbol),
    num_definitions: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return SymbolTable{
            .store = std.StringHashMap(Symbol).init(allocator),
            .num_definitions = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SymbolTable) void {
        self.store.deinit();
    }

    pub fn lookup(self: *SymbolTable, name: []const u8) ?Symbol {
        return self.store.get(name);
    }

    pub fn define(self: *SymbolTable, name: []const u8, scope: SYMBOL_SCOPE) !Symbol {
        const symbol = Symbol{
            .Name = name,
            .Scope = scope,
            .Index = self.num_definitions,
            .IsConstant = null,
        };

        try self.store.put(name, symbol);
        self.num_definitions += 1;

        return symbol;
    }

    pub fn defineConst(self: *SymbolTable, name: []const u8, scope: SYMBOL_SCOPE) !Symbol {
        const symbol = Symbol{
            .Name = name,
            .Scope = scope,
            .Index = self.num_definitions,
            .IsConstant = true,
        };

        try self.store.put(name, symbol);
        self.num_definitions += 1;

        return symbol;
    }
};
