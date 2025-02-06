const std = @import("std");
const testing = std.testing;
const Keywords = @import("../token/main.zig").Keywords;
const BuiltinTypes = @import("../type/types.zig").TypeKeywords;

test "Keywords.getKeywordToken returns correct token types" {

    // Test existing keywords
    try testing.expectEqual(Keywords.getKeywordToken("abeg"), .ABEG);
    try testing.expectEqual(Keywords.getKeywordToken("lock"), .LOCK);
    try testing.expectEqual(Keywords.getKeywordToken("oya"), .OYA);
    try testing.expectEqual(Keywords.getKeywordToken("comot"), .COMOT);
    try testing.expectEqual(Keywords.getKeywordToken("true"), .TRUE);
    try testing.expectEqual(Keywords.getKeywordToken("false"), .FALSE);
    try testing.expectEqual(Keywords.getKeywordToken("if"), .IF);
    try testing.expectEqual(Keywords.getKeywordToken("else"), .ELSE);
    try testing.expectEqual(Keywords.getKeywordToken("and"), .AND);
    try testing.expectEqual(Keywords.getKeywordToken("or"), .OR);
    try testing.expectEqual(Keywords.getKeywordToken("orelse"), .OR_ELSE);

    // Test non-existent keywords
    try testing.expectEqual(Keywords.getKeywordToken("notakeyword"), null);
    try testing.expectEqual(Keywords.getKeywordToken(""), null);

    // Test case sensitivity
    try testing.expectEqual(Keywords.getKeywordToken("IF"), null);
    try testing.expectEqual(Keywords.getKeywordToken("True"), null);
}

test "BuiltinTypes.getBuiltinTypeToken returns correct token types" {
    // Test existing builtin types
    try testing.expectEqual(BuiltinTypes.getType("int"), .Int);
    try testing.expectEqual(BuiltinTypes.getType("string"), .String);
    try testing.expectEqual(BuiltinTypes.getType("bool"), .Bool);
    try testing.expectEqual(BuiltinTypes.getType("float"), .Float);
    try testing.expectEqual(BuiltinTypes.getType("interface"), .Interface);
    try testing.expectEqual(BuiltinTypes.getType("void"), .Void);
    try testing.expectEqual(BuiltinTypes.getType("any"), .Any);
    try testing.expectEqual(BuiltinTypes.getType("error"), .Error);

    // Test non-existent types
    try testing.expectEqual(BuiltinTypes.getType("notatype"), null);
    try testing.expectEqual(BuiltinTypes.getType(""), null);

    // Test case sensitivity
    try testing.expectEqual(BuiltinTypes.getType("INT"), null);
    try testing.expectEqual(BuiltinTypes.getType("String"), null);
}
