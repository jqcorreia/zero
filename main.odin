package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:time"

Options :: struct {
	command: string `args:"pos=0,required"`,
	file:    os.Handle `args:"pos=1,required,file=r,required"`,
}

main :: proc() {
	opt: Options

	flags.parse_or_exit(&opt, os.args, .Unix)

	compiler_init()

	start_time := time.now()
	// filename := "tests/basic.z"

	// if len(os.args) > 1 {
	// 	filename = os.args[1]
	// }

	// Lex
	expr := os.read_entire_file(opt.file) or_else panic("No file found")
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

	// Compilation errors should appear before codegen phase
	if len(compiler.errors) > 0 {
		fmt.printf("Compilation failed with %d errors:\n", len(compiler.errors))
		for error in compiler.errors {
			fmt.println(error.message)
		}
		os.exit(1)
	}
	if opt.command == "check" {
		os.exit(0)
	}

	// Code generation
	// generate(stmts)

	if ODIN_DEBUG {
		fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")
	}

	// Link and run
	when ODIN_OS == .Linux {
		if opt.command == "build" {
			posix.system("cc -o calc calc.o")
			os.exit(0)
		}
		if opt.command == "run" {
			posix.system("cc -o calc calc.o")
			posix.system("./calc")
			os.exit(0)
		}
	} else {
		unimplemented("Only linux is supported for now. :-\\")
	}

	os.exit(0)
}
