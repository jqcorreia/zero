 This is a classic ambiguity that every language with both struct literals and block-opening { has to solve. There are a few real approaches:

  ---
  Option A — Context flag on parse_expression (minimal change)

  Add a parameter allow_struct_literal: bool = true to parse_expression. In the identifier nud, only check for { when the flag is true. Call it with false from parse_if and parse_for.

  parse_expression :: proc(p: ^Parser, min_lbp: int = 0, allow_struct_literal: bool = true) -> ^Expr {
      ...
      case .Identifier:
          if allow_struct_literal && current(p).kind == .LBrace {
              left = parse_struct_literal(...)
          } else {
              left = expr_ident(...)
          }

  No syntax change for the user. This is essentially what Go does at the parser level.

  ---
  Option B — Change struct literal syntax (Zig-style)

  Use .{ field = val } instead of Type{ field = val }. The type is inferred from context.

  x := Color.{ r = 255, g = 0, b = 0 }

  Since .{ is an unambiguous two-token sequence that never appears in a condition, the problem disappears entirely. Cleaner language design but a syntax breaking change.

  ---
  Option C — Require parentheses in conditions (C-style)

  if (x < y) {

  Simple parser fix — remove the { check from the identifier nud entirely and only handle struct literals where they're explicitly expected. But it changes the feel of the language.

  ---
  Recommendation

  Option A is the fastest fix with zero syntax impact. Option B is the better long-term language design — it also solves the ambiguity of what type a struct literal is when the name precedes it, which becomes relevant when you add type
  inference. Zig chose it for exactly these reasons.

❯ I've just checked Odin and there the following happens: If you have a named struct literal in an if there's a syntax error *unless* you wrap it in parenthesis. I want to implement the same thing.

● That's Option A then, just slightly reframed — instead of a flag called allow_struct_literal, it's more accurately described as parentheses reset the context. In Odin, wrapping in () makes struct literals valid again because
  parse_expression is called fresh inside the parentheses group.

  The way it works:

  - parse_if and parse_for call parse_expression with allow_struct_literal = false
  - In the identifier nud, only try { if allow_struct_literal is true
  - In the ( nud (grouped expression), recurse with allow_struct_literal = true — this is the key, parentheses "reset" the flag

  case .LParen:
      left = parse_expression(p, 0, true)  // reset — struct literals allowed inside ()
      expect(p, .RParen)

  So if (MyStruct{ x = 1 }) { would parse fine because the inner call gets true, but if MyStruct{ x = 1 } { would not — the { after the identifier would be ignored and MyStruct parsed as a plain variable, then { would be consumed by
  parse_block as the body opener.

  Want me to make the changes?

