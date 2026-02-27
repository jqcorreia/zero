#+feature dynamic-literals

package main

import "core:fmt"

Type :: struct {
	kind:            Type_Kind,
	compiled:        Compiled_Type,
	signed:          bool, // not sure if this is the best place or I should have a kind union a be done with it
	numeric_integer: bool,
	numeric_float:   bool,
	fields:          [dynamic]Struct_Field,
}

Struct_Field :: struct {
	name:  string,
	type:  ^Type,
	index: int,
}


Compiled_Type :: union {
	TypeRef,
}

Type_Kind :: enum {
	Undefined,
	Error,
	Void,
	Bool,
	Untyped_Int,
	Uint8,
	Uint16,
	Uint64,
	Uint32,
	Int8,
	Int16,
	Int32,
	Int64,
	String,
	Struct,
}

create_type :: proc(
	kind: Type_Kind,
	type_name: string,
	scope: ^Scope,
	signed := false,
	numeric_integer := false,
	numeric_float := false,
) {
	t := new(Type)
	t.kind = kind
	t.numeric_integer = numeric_integer
	t.signed = signed
	scope.symbols[type_name] = make_symbol(.Type, t)
}

create_primitive_types :: proc(scope: ^Scope) {
	// NOTE: I don't know if void to be equivalent to empty type_expr is a good idea
	create_type(.Void, "", scope)
	create_type(.Bool, "bool", scope)

	create_type(.Untyped_Int, "untyped_int", scope)
	create_type(.Uint8, "u8", scope, numeric_integer = true)
	create_type(.Uint16, "u16", scope, numeric_integer = true)
	create_type(.Uint32, "u32", scope, numeric_integer = true)
	create_type(.Uint64, "u64", scope, numeric_integer = true)
	create_type(.Int8, "i8", scope, signed = true, numeric_integer = true)
	create_type(.Int16, "i16", scope, signed = true, numeric_integer = true)
	create_type(.Int32, "i32", scope, signed = true, numeric_integer = true)
	create_type(.Int64, "i64", scope, signed = true, numeric_integer = true)

	create_type(.String, "str", scope)
}

type_coercion :: proc(from: ^Type, to: ^Type, scope: ^Scope) -> ^Type {
	fmt.println("$$$$", from, to)
	if from.kind == to.kind {
		return from
	}

	if from.kind == .Untyped_Int && to.numeric_integer {
		return to
	}

	if to.kind == .Untyped_Int && from.numeric_integer {
		return from
	}

	if to.kind == .Untyped_Int && from.kind == .Untyped_Int {
		sym, _ := resolve_symbol(scope, "i64")
		return sym.type
	}

	return nil
}
