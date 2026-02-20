# Lang

Procedural language with basics done right. Straightforward, correct and if possible with some syntatic sugar on top.
Aims to be explicit but to not sacrifice all the creature comforts of a modern language.

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
- [x] Do not need forward declaration with symbol table pass and LLVM function declaration  
- [x] Basic type system
- [x] Basic External functions system and cleanup the printf mess
- [x] Implement a really dumb variadic marker
- [ ] Check types for function calls. right now is a mess.
- [ ] Make sure that the available types are synched with the primtive types in codegen 
- [ ] User defined types (i.e structs)  
- [ ] Bound checked arrays  
- [ ] Bound checked strings  
- [ ] Make `external` blocks it's own AST node kind

# Try it
```
odin build .
./lang run tests/basic.z 
```
