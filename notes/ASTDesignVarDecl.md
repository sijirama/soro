# **AST Design for Variable Declarations in Zig (For Your Language)**  
Since we're using `abeg` for **mutable variables** and `abeg lock` for **immutable ones**, we need an **AST structure** that properly represents:  
1. **Mutable variable declarations**  
2. **Immutable variable declarations (`lock` modifier)**  
3. **Type inference (`:=`)**  
4. **Explicit type assignments (`=` with type specified)**  

---

### **AST Node Structure for Variable Declarations**
#### **Zig Representation**
```zig
const std = @import("std");

pub const VarDecl = struct {
    name: []const u8,     // Variable name
    type: ?Type,          // Optional explicit type
    value: Expr,          // Expression assigned to the variable
    is_locked: bool,      // True if `lock` is used (immutable)
    is_inferred: bool,    // True if `:=` is used (type inference)

    pub fn format(self: VarDecl, writer: anytype) !void {
        try writer.print("VarDecl(name: {s}, type: {}, value: {}, is_locked: {}, is_inferred: {})\n",
            .{ self.name, self.type, self.value, self.is_locked, self.is_inferred });
    }
};
```
---

### **Example AST Construction**
For the following script:  
```abeg
abeg age int = 50;
abeg name := "Siji";
abeg lock pi = 3.14;
```

The AST representation would be:  
```zig
const age_decl = VarDecl{
    .name = "age",
    .type = Type.int,
    .value = Expr.IntLiteral(50),
    .is_locked = false,
    .is_inferred = false,
};

const name_decl = VarDecl{
    .name = "name",
    .type = null,  // Inferred type
    .value = Expr.StringLiteral("Siji"),
    .is_locked = false,
    .is_inferred = true,
};

const pi_decl = VarDecl{
    .name = "pi",
    .type = null,  // Inferred type
    .value = Expr.FloatLiteral(3.14),
    .is_locked = true, // Immutable
    .is_inferred = false, // Explicit assignment
};
```
---

### **Parsing Logic in Zig**
When parsing `abeg` statements:  
1. **Detect `lock`** → Set `.is_locked = true`  
2. **Detect `:=`** → Set `.is_inferred = true`, `.type = null`  
3. **Detect `=`** → Check if a type is provided, otherwise infer  

---

### **Key Features of This AST Design**
- Supports **mutable & immutable variables**  
- Differentiates between **inferred (`:=`) vs explicit (`=`) types**  
- Keeps the **syntax simple** while allowing flexibility  
- Allows easy **type checking and validation**  

Would this structure fit your language’s needs? 🚀
