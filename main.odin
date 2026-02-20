package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"
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

	// Read file
	expr := os.read_entire_file(opt.file) or_else panic("No file found")

	// Lex
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
	generate(stmts)

	if ODIN_DEBUG {
		fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")
	}

	compiler_command := "cc"
	compiler_flags := "-o out calc.o" // Need to change all this 'out' and 'calc.o'
	linker_libs := strings.builder_make()

	for lib in compiler.external_linker_libs {
		fmt.sbprintf(&linker_libs, "-l%s ", lib)
	}
	build_command := fmt.tprintf(
		"%s %s %s",
		compiler_command,
		compiler_flags,
		strings.to_string(linker_libs),
	)
	fmt.println("Using final build command:", build_command)
	// Link and run
	when ODIN_OS == .Linux {
		if opt.command == "build" {
			posix.system(strings.clone_to_cstring(build_command))
			os.exit(0)
		}
		if opt.command == "run" {
			posix.system(strings.clone_to_cstring(build_command))
			posix.system("./out")
			os.exit(0)
		}
	} else {
		unimplemented("Only linux is supported for now. :-\\")
	}

	os.exit(0)
}
