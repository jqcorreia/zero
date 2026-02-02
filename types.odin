#+feature dynamic-literals

package main


ident_to_type :: proc(ident: string) -> ^Type {
	return compiler.types[ident]
}

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	U8,
	Int8,
	Int16,
	Int32,
	Bool,
}
