# Lang

Tag 0.0.1 is the tag that contains the initial, minimal lexer, parser, checker and codegen backend.  
It uses LLVM as the backend.

# TODO
- [ ] Do not need forward declaration with symbol table pass and LLVM function declaration  
- [ ] User defined types (i.e structs)  
- [ ] Bound checked strings  
- [ ] Bound checked arrays  

# Running
```
odin build .
./lang tests/basic.z
```
