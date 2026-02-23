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
- [x] User defined types (i.e structs)  
- [ ] Struct field accessor
- [x] Implement support for arbitrary "_" character in numbers (e.g for thousands separator)
- [ ] Check types for function calls. right now is a mess.
- [ ] Make sure that the available types are synched with the primtive types in codegen 
- [ ] Arrays with bound checked access  
- [ ] Proper string with bound check and not null-terminated  
- [ ] Make `external` blocks it's own AST node kind
- [ ] Make sure that lexer is UTF-8 compliant
- [ ] Implement float support

# Try it
```
odin build .
./lang run tests/basic.z 
```

# Dependencies
- `linux` at least until we know properly what we are doing
- `cc` as the C compiler that does the linking in the end
- `raylib` in order to run the raylib example in `tests/raylib.z`
