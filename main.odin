package main

import "core:fmt"

main :: proc() {
	expr := "12 + 34 + 35"
	tokens := lex(expr)

	parser := Parser {
		tokens = tokens,
	}
	// fmt.println(Binary{left = &Number{value = 100}, right = &Number{value = 200}})
	pexpr := parse_expression(&parser)
	fmt.println(pexpr)
	// print_expr(&pexpr)

	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	int32 := Int32TypeInContext(ctx)
	fn_type := FunctionType(int32, nil, 0, 0)

	main_f := AddFunction(module, "main", fn_type)

	entry := AppendBasicBlockInContext(ctx, main_f, "entry")

	PositionBuilderAtEnd(builder, entry)
	BuildRet(builder, ConstInt(int32, 42, 0))

	InitializeX86Target()
	InitializeX86AsmPrinter()
	InitializeX86TargetInfo()

	triple := GetDefaultTargetTriple()

	target: TargetRef

	error: cstring
	if GetTargetFromTriple(triple, &target, &error) > 0 {
		fmt.println(triple, string(error))
		return
	}
	SetTarget(module, triple)

	fmt.println(target, triple)
	tm := CreateTargetMachine(
		target,
		triple,
		"generic",
		"",
		.CodeGenLevelDefault,
		.RelocDefault,
		.CodeModelDefault,
	)

	SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error)
}
