package main

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:time"

setup_runtime :: proc(ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
	// Printf
	i32 := Int32TypeInContext(ctx)
	i8 := Int8TypeInContext(ctx)
	i8p := PointerType(i8, 0)

	printf_ty := FunctionType(
		i32, // return type
		&i8p, // first arg: char *
		1,
		true, // variadic
	)

	printf_fn := AddFunction(module, "printf", printf_ty)

	compiler.funcs["print"] = Function {
		name   = "print",
		ty     = printf_ty,
		fn     = printf_fn,
		params = {Param{name = "val", type = &Type{kind = .Int32}}},
	}
}

main :: proc() {
	compiler_init()

	start_time := time.now()
	filename := "test4.z"

	if len(os.args) > 1 {
		filename = os.args[1]
	}

	// Lex
	expr := os.read_entire_file(filename) or_else panic("No file found")
	tokens := lex(string(expr))
	if ODIN_DEBUG {
		tokens_print(tokens)
	}

	// Parse
	parser := Parser {
		tokens = tokens,
	}
	stmts := parse_program(&parser)
	if ODIN_DEBUG {
		for stmt in stmts {
			statement_print(stmt)
		}
	}

	// Code generation
	generate(stmts)

	// DumpModule(module)
	fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")

	// Link and run
	when ODIN_OS == .Linux {
		posix.system("cc -o calc calc.o")
		posix.system("./calc")
	} else {
		unimplemented("Only linux is supported for now. :-\\")
	}
}
