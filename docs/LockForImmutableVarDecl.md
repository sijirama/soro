# **Using `lock` as an Enhancer for Immutable Variables**  

In our language, **`abeg`** is used to declare mutable variables. To make a variable **immutable**, we enhance `abeg` with **`lock`**, ensuring its value **cannot be changed after assignment**.  

#### **Syntax:**  
```abeg
abeg lock variableName = value;
```

#### **Example Usage:**  
```abeg
abeg lock pi = 3.14;
abeg lock appName = "Chookeye";

pi = 3.1415;  // ❌ ERROR: Cannot modify a locked variable
appName = "NewApp";  // ❌ ERROR: Immutable variable
```

#### **Rules:**  
1. **Once a variable is declared with `abeg lock`, its value cannot be modified.**  
2. **Type inference still works:**  
   ```abeg
   abeg lock maxUsers := 100;  // maxUsers is inferred as an integer
   ```
3. **Can be used for constants, configuration values, etc.**  
4. **Attempting to reassign a `lock` variable should throw an error.**  

This keeps the syntax simple while allowing immutability when needed. 🚀  

What do you think?
