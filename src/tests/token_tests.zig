const std = @import("std");
const testing = std.testing;
const Keywords = @import("../token/main.zig").Keywords;
const BuiltinTypes = @import("../token/main.zig").BuiltinTypes;

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
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("int"), .INTEGER_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("string"), .STRING_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("bool"), .BOOL_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("float"), .FLOAT_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("interface"), .INTERFACE_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("void"), .VOID_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("any"), .ANY_TYPE);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("error"), .ERROR_TYPE);

    // Test non-existent types
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("notatype"), null);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken(""), null);

    // Test case sensitivity
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("INT"), null);
    try testing.expectEqual(BuiltinTypes.getBuiltinTypeToken("String"), null);
}


