package main

import "core:container/queue"

Compiler :: struct {
	current_filepath:     string, // Unused for now
	line_starts:          [dynamic]int,
	scopes:               queue.Queue(Scope),
	global_scope:         Scope,
	loops:                queue.Queue(Loop),
	types:                map[string]^Type,
	errors:               [dynamic]Compiler_Error,
	external_linker_libs: [dynamic]string,
}

Compiler_Error :: struct {
	file:    string,
	span:    Span,
	message: string,
}

Loop :: struct {
	break_block: BasicBlockRef,
}

compiler := Compiler{}

compiler_init :: proc() {
	setup_native_types(&compiler) // Initialize the native type pointers
}

setup_native_types :: proc(compiler: ^Compiler) {
	u8_t := new(Type)
	u8_t.kind = .Uint8
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

	i64_t := new(Type)
	i64_t.kind = .Int64
	compiler.types["i64"] = i64_t

	u32_t := new(Type)
	u32_t.kind = .Uint32
	compiler.types["u32"] = u32_t

	u64_t := new(Type)
	u64_t.kind = .Uint64
	compiler.types["i64"] = u64_t

	bool_t := new(Type)
	bool_t.kind = .Bool
	compiler.types["bool"] = bool_t
}
