package main

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:time"


main :: proc() {
	compiler_init()

	start_time := time.now()
	filename := "tests/basic.z"

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

	// Semantic and type checker
	checker := Checker{}
	check(&checker, stmts)

	// Code generation
	generate(stmts)

	if len(compiler.errors) > 0 {
		fmt.println("Compilation failed:")
		for error in compiler.errors {
			fmt.println(error.message)
		}
		os.exit(1)
	}

	if ODIN_DEBUG {
		fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")
	}

	// Link and run
	when ODIN_OS == .Linux {
		posix.system("cc -o calc calc.o")
		posix.system("./calc")
	} else {
		unimplemented("Only linux is supported for now. :-\\")
	}

	os.exit(0)
}
