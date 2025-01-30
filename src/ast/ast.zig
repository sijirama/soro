const Node = struct {
    toString: fn (*const anyopaque, []u8) []const u8,
};

const Expression = struct {
    node: Node, // Embed the Node interface
};

const Statement = struct {
    node: Node, // Embed the Node interface
};
