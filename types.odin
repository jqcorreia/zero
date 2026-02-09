#+feature dynamic-literals

package main


ident_to_type :: proc(ident: string) -> ^Type {
	return compiler.types[ident]
}

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	Undefined,
	U8,
	Int8,
	Int16,
	Int32,
	Uint32,
	Bool,
}

type_check_expr :: proc(expr: ^Expr, span: Span) -> ^Type {
	#partial switch e in expr {
	case Expr_Binary:
		left := type_check_expr(e.left, span)
		right := type_check_expr(e.right, span)

		if left != right {
			return nil
		} else {
			return left
		}
	case Expr_Int_Literal:
		return e.type
	case Expr_Variable:
		return scope_current().vars[e.value].type
	case Expr_Call:
		func := compiler.funcs[e.callee.(Expr_Variable).value]
		return func.ret_type
	}
	return nil
}
