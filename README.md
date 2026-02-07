# Lang

Procedural language with basics done right. Straightforward, correct and if possible with some syntatic sugar on top.

Already done:
- Lexing
- Parsing / AST construction (straightforward Pratt parser)
- Basic Checker (semantic and basic types)
- Integers and Boolean support
- Comments (surprisingly hard to implement well actually)
- User functions
- Recursion
- Unconditional For loop with break and continue
- Single file, single module
- Hardcoded `printf` import from libc
- LLVM codegen (planning to abstract the backend, but one fight at a time)

Potentially this README can look a lot different in a couple of months if this becomes a serious project.

# TODO
- [ ] Do not need forward declaration with symbol table pass and LLVM function declaration  
- [ ] User defined types (i.e structs)  
- [ ] Bound checked arrays  
- [ ] Bound checked strings  

# Try it
```
odin build .
./lang tests/basic.z 
```
