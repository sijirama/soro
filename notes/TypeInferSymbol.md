
# Type infer with ( := ) inside functions like golang

Since your language is a **scripting language**, it likely executes statements sequentially, rather than requiring a `main` function like Go. However, keeping `:=` **only inside functions** still makes sense if you want to maintain Go's scoping rules.  

### How This Would Work in Your Language  
- **Global variables require explicit types**  
  ```abeg
  abeg age int = 50;  // ✅ Allowed at the top level
  abeg name string = "Siji";  // ✅ Allowed
  ```
- **Type inference (`:=`) only inside functions**  
  ```abeg
  func foo() {
      abeg age := 50;  // ✅ Allowed inside functions
      abeg name := "Siji";  // ✅ Allowed, inferred as string
  }
  ```
- **Type inference (`:=`) NOT allowed at the global scope**  
  ```abeg
  abeg age := 50;  // ❌ ERROR: Type inference not allowed globally
  ```

---

### Why This Approach Works for a Scripting Language  
Even though your language doesn't have a `main` function, it still likely has **global scope vs. function scope**. By enforcing explicit types at the global level:  
1. **Avoids unexpected type inference issues in global variables**  
2. **Encourages clearer, more predictable global state**  
3. **Still allows dynamic, flexible code inside functions**  
