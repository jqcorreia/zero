#+feature dynamic-literals

package main

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	Undefined,
	Error,
	Void,
	Bool,
	Uint8,
	Int8,
	Int16,
	Int32,
	Uint32,
	String,
}

create_primitive_types :: proc(scope: ^Scope) {
	void := new(Type)
	void.kind = .Void
	scope.symbols[""] = make_symbol(.Type, void)

	u8_t := new(Type)
	u8_t.kind = .Uint8
	scope.symbols["u8"] = make_symbol(.Type, u8_t)

	i32_t := new(Type)
	i32_t.kind = .Int32
	scope.symbols["i32"] = make_symbol(.Type, i32_t)

	u32_t := new(Type)
	u32_t.kind = .Uint32
	scope.symbols["u32"] = make_symbol(.Type, u32_t)

	string_t := new(Type)
	string_t.kind = .String
	scope.symbols["str"] = make_symbol(.Type, string_t)
}
