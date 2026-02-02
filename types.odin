#+feature dynamic-literals

package main


ident_to_type :: proc(ident: string) -> ^Type {
	return state.types[ident]
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

setup_native_types :: proc() {
	u8_t := new(Type)
	u8_t.kind = .U8
	state.types["u8"] = u8_t

	i8_t := new(Type)
	i8_t.kind = .Int8
	state.types["i8"] = i8_t

	i16_t := new(Type)
	i16_t.kind = .Int16
	state.types["i16"] = i16_t

	i32_t := new(Type)
	i32_t.kind = .Int32
	state.types["i32"] = i32_t

	bool_t := new(Type)
	bool_t.kind = .Bool
	state.types["bool"] = bool_t
}
