#+feature dynamic-literals

package main

native_types: map[string]Type_Kind = {
	"i32" = .Int32,
}

ident_to_native_type_kind :: proc(ident: string) -> Type_Kind {
	return native_types[ident]
}

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	Int32,
	Bool,
}
