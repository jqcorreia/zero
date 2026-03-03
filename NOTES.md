  ---
  Phase 1 — Lexer

  Add LBracket ([) and RBracket (]) tokens. Straightforward, same as the other single-char tokens.

  ---
  Phase 2 — Structured type expressions

  type_expr: string can't represent [4]i32. Replace it with a union:
  Type_Expr :: union {
      string,           // "i32", "f32", "MyStruct"
      Array_Type_Expr,  // [4]i32
  }
  Array_Type_Expr :: struct {
      size: int,
      elem: ^Type_Expr,
  }
  This touches Ast_Var_Decl, function params, ret_type_expr, and struct field declarations. The resolver then switches on the union instead of doing a plain resolve_symbol string lookup.

  ---
  Phase 3 — Parser

  Three new things to parse:
  - Type expressions: [4]i32 when parsing a type annotation
  - Array literals: [1, 2, 3] as an expression
  - Index expressions: arr[i] — needs to slot into the existing expression parser at the right precedence level (postfix, same as member access)

  ---
  Phase 4 — AST & Type system

  New expression nodes:
  - Expr_Array_Literal { elements: []^Expr }
  - Expr_Index { array: ^Expr, index: ^Expr }

  Type gains two new fields:
  elem_type:  ^Type
  array_size: int
  And a new Type_Kind value: .Array.

  ---
  Phase 5 — Resolver

  - Resolving Array_Type_Expr: look up the element type recursively, create an .Array type with elem_type and array_size
  - Expr_Index resolves to array.type.elem_type
  - Expr_Array_Literal resolves each element, infers the array type from context or the first element

  ---
  Phase 6 — Checker

  - Verify the index expression is an integer type
  - If the index is a compile-time literal, emit a compile-time bounds error
  - For runtime indices, the checker just validates types — the bounds check is emitted in codegen

  ---
  Phase 7 — Codegen

  - Type: ArrayType(elem_llvm_type, size)
  - Alloca: same as structs, allocate the whole array
  - Literal: GEP + store for each element
  - Index: two-index GEP — [0, i] because the array is behind a pointer
  - Bounds check: emit before every index operation:
  %oob = icmp uge i64 %i, <size>   ; unsigned: catches negatives too
  br i1 %oob, trap_bb, ok_bb
  trap_bb:
    call void @llvm.trap()
    unreachable
  ok_bb:
    ; GEP proceeds
  - @llvm.trap() is an LLVM intrinsic that lowers to a hardware trap — cleaner than calling abort and gives you a crash with a useful signal.

  ---
  Order of attack

  1. Lexer brackets
  2. Type_Expr union + parser for type annotations
  3. Resolver handles array types
  4. Expr_Index through the full pipeline (resolver → checker → codegen) without literals first
  5. Array literals
  6. Bounds check insertion in codegen

  The Type_Expr union change in phase 2 is the most invasive since it touches several structs and every place the resolver calls resolve_symbol on a type. Worth doing cleanly before moving on to the rest.


