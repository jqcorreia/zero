#+feature dynamic-literals

package main

Type :: struct {
	kind:     Type_Kind,
	compiled: Compiled_Type,
	signed:   bool, // not sure if this is the best place or I should have a kind union a be done with it
}


Compiled_Type :: union {
	TypeRef,
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
	u8_t.signed = false
	scope.symbols["u8"] = make_symbol(.Type, u8_t)

	i32_t := new(Type)
	i32_t.kind = .Int32
	i32_t.signed = true
	scope.symbols["i32"] = make_symbol(.Type, i32_t)

	u32_t := new(Type)
	u32_t.kind = .Uint32
	u32_t.signed = false
	scope.symbols["u32"] = make_symbol(.Type, u32_t)

	string_t := new(Type)
	string_t.kind = .String
	scope.symbols["str"] = make_symbol(.Type, string_t)
}
