package main

import "core:container/queue"

Compiler :: struct {
	current_filepath: string, // Unused for now
	funcs:            map[string]^Ast_Function,
	line_starts:      [dynamic]int,
	scopes:           queue.Queue(Scope),
	global_scope:     Scope,
	loops:            queue.Queue(Loop),
	types:            map[string]^Type,
	errors:           [dynamic]Compiler_Error,
}

Compiler_Error :: struct {
	file:    string,
	span:    Span,
	message: string,
}

Scope :: struct {
	vars: map[string]Scope_Var,
}

Scope_Var :: struct {
	type_name: string,
	type:      ^Type,
	ref:       ValueRef,
}

Loop :: struct {
	break_block: BasicBlockRef,
}

compiler := Compiler{}

compiler_init :: proc() {
	setup_native_types(&compiler) // Initialize the native type pointers
	scope_push({}) // Push the root scope
}

setup_native_types :: proc(compiler: ^Compiler) {
	u8_t := new(Type)
	u8_t.kind = .U8
	compiler.types["u8"] = u8_t

	i8_t := new(Type)
	i8_t.kind = .Int8
	compiler.types["i8"] = i8_t

	i16_t := new(Type)
	i16_t.kind = .Int16
	compiler.types["i16"] = i16_t

	i32_t := new(Type)
	i32_t.kind = .Int32
	compiler.types["i32"] = i32_t

	bool_t := new(Type)
	bool_t.kind = .Bool
	compiler.types["bool"] = bool_t
}

scope_push :: proc(scope: Scope) {
	queue.push_front(&compiler.scopes, scope)
}

scope_pop :: proc() -> Scope {
	return queue.pop_front(&compiler.scopes)
}

scope_current :: proc() -> ^Scope {
	return queue.front_ptr(&compiler.scopes)
}

scope_top_level :: proc() -> bool {
	return queue.len(compiler.scopes) == 1
}
