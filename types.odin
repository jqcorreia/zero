#+feature dynamic-literals

package main


ident_to_type :: proc(ident: string) -> ^Type {
	return compiler.types[ident]
}

ident_to_type_in_scope :: proc(node: ^Ast_Node, ident: string) -> ^Type {
	sym, ok := resolve_symbol(node.scope, ident)

	if !ok {
		error_span(node.span, "Unknown symbol: %s", sym.name)
		return nil
	}

	if sym.kind != .Type {
		error_span(node.span, "Unknown type: %s", sym.name)
		return nil
	}

	return sym.type
}

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	Undefined,
	Uint8,
	Int8,
	Int16,
	Int32,
	Uint32,
	Bool,
	Error,
}
