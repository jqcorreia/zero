package main

import "core:container/queue"
import "core:fmt"
import "core:strings"

Generator :: struct {
	values:  map[^Symbol]ValueRef,
	types:   map[^Symbol]TypeRef,
	ctx:     ContextRef,
	builder: BuilderRef,
	module:  ModuleRef,
}

emit_stmt :: proc(gen: ^Generator, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		emit_expr(gen, node.expr, s.scope, s.span)
	case Ast_Assignment:
		emit_assigment(gen, &node, s.scope, s.span)
	case Ast_Function:
	case Ast_Return:
		emit_return(gen, &node, s.scope, s.span)
	case Ast_If:
		emit_if(gen, &node, s.scope, s.span)
	case Ast_For:
		emit_for_loop(gen, &node, s.scope, s.span)
	case Ast_Break:
		emit_break(gen, &node, s.scope, s.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_assigment :: proc(gen: ^Generator, s: ^Ast_Assignment, scope: ^Scope, span: Span) {
	// Build local variables
	// If the variable exists, just emit a Store, otherwise emit Alloca + Store
	is_global := scope.kind == .Global
	sym := s.symbol
	if sym == nil {
		fatal_span(span, "Symbol %s is not bound!", s.name)
	}
	if !is_global {
		ptr, exists := gen.values[sym]
		if exists {
			BuildStore(gen.builder, emit_expr(gen, s.expr, scope, span), ptr)
		} else {
			ptr = BuildAlloca(gen.builder, Int32Type(), "")
			gen.values[sym] = ptr
			BuildStore(gen.builder, emit_expr(gen, s.expr, scope, span), ptr)
		}
	} else {
		// Create global variables, only constant for now
		if _, ok := s.expr.(Expr_Int_Literal); ok {
			ptr := AddGlobal(gen.module, Int32Type(), strings.clone_to_cstring(s.name))
			SetInitializer(ptr, ConstInt(Int32Type(), u64(s.expr.(Expr_Int_Literal).value), false))
		} else {
			panic("Global variables need to be constants")
		}
	}
}

emit_function_decl :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {

}

emit_function :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	old_pos := GetInsertBlock(gen.builder)

	int32 := Int32TypeInContext(gen.ctx)
	param_types: [dynamic]TypeRef

	fn_type: TypeRef

	//TODO(quadrado): For now do this until we have proper function return types resolved
	ret_type_ref :=
		s.ret_type_expr == "" ? VoidTypeInContext(gen.ctx) : Int32TypeInContext(gen.ctx)

	if len(s.params) > 0 {
		for _ in s.params {
			append(&param_types, int32)
		}

		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), false)
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, false)

	}

	sym := s.symbol
	fn := AddFunction(gen.module, strings.clone_to_cstring(s.name), fn_type)
	// By now the function must exist in state
	// Complete the information with TypeRef and ValueRef
	gen.values[sym] = fn
	gen.types[sym] = fn_type

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(gen.ctx, fn, "")
	PositionBuilderAtEnd(gen.builder, entry)

	// Allocate vars
	scope := Scope{}
	scope_push(scope)
	for ast_param, i in s.params {
		param_sym := ast_param.symbol
		param := GetParam(fn, u32(i))

		alloca := BuildAlloca(gen.builder, int32, strings.clone_to_cstring(ast_param.name))
		BuildStore(gen.builder, param, alloca)
		gen.values[param_sym] = alloca
	}

	emit_block(gen, s.body)

	if s.symbol.type == nil {
		BuildRetVoid(gen.builder)
	}
	PositionBuilderAtEnd(gen.builder, old_pos)
	// DumpValue(fn)

	scope_pop()
}

emit_return :: proc(gen: ^Generator, s: ^Ast_Return, scope: ^Scope, span: Span) {
	data := s
	BuildRet(gen.builder, emit_expr(gen, data.expr, scope, span))
}

// This a hacked printf-type emission until we have proper external functions and string support
emit_print_call :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	fmt_ptr := BuildGlobalStringPtr(gen.builder, "%d\n", "")
	args := []ValueRef{fmt_ptr, emit_expr(gen, e.args[0], scope, span)}

	ty := gen.types[printf_sym]
	fn := gen.values[printf_sym]

	call := BuildCall2(gen.builder, ty, fn, &args[0], u32(len(args)), "")

	return call
}

emit_call :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	fn_name := e.callee.(Expr_Variable).value

	args: [dynamic]ValueRef
	for a in e.args {
		append(&args, emit_expr(gen, a, scope, span))
	}

	sym, ok := resolve_symbol(scope, fn_name)
	if !ok {
		fatal_span(span, "Unresolved function %s in function call", fn_name)
	}
	sym_type := gen.types[sym]
	sym_value := gen.values[sym]
	if sym_type == nil || sym_value == nil {
		fmt.println(sym_type, sym_value)
	}
	if len(args) == 0 {
		return BuildCall2(gen.builder, sym_type, sym_value, nil, 0, "")
	} else {
		return BuildCall2(gen.builder, sym_type, sym_value, &args[0], u32(len(args)), "")
	}
}

emit_expr :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	int32 := Int32TypeInContext(gen.ctx)
	#partial switch e in expr {
	case Expr_Int_Literal:
		return ConstInt(int32, u64(e.value), false)
	case Expr_Call:
		data := e
		if data.callee.(Expr_Variable).value == "print" {
			return emit_print_call(gen, e, scope, span)
		} else {
			return emit_call(gen, e, scope, span)
		}
	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok {
			fatal_span(span, "Symbol not found on expr emit: %s", e.value)
		}
		var := gen.values[sym]

		return BuildLoad2(gen.builder, int32, var, "")
	case Expr_Binary:
		#partial switch e.op {
		case .Plus:
			return BuildAdd(
				gen.builder,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"add",
			)
		case .Minus:
			return BuildSub(
				gen.builder,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"sub",
			)
		case .Star:
			return BuildMul(
				gen.builder,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"mul",
			)
		case .Slash:
			return BuildSDiv(
				gen.builder,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"div",
			)
		case .DoubleEqual:
			return BuildICmp(
				gen.builder,
				.IntEQ,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"gt",
			)
		case .Greater:
			return BuildICmp(
				gen.builder,
				.IntUGT,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"gt",
			)
		case .Lesser:
			return BuildICmp(
				gen.builder,
				.IntULT,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"lt",
			)
		case .GreaterOrEqual:
			return BuildICmp(
				gen.builder,
				.IntUGE,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"gte",
			)
		case .LesserOrEqual:
			return BuildICmp(
				gen.builder,
				.IntULE,
				emit_expr(gen, e.left, scope, span),
				emit_expr(gen, e.right, scope, span),
				"lte",
			)
		}
	}
	unreachable()
}

emit_block :: proc(gen: ^Generator, block: ^Ast_Block) {
	for bst in block.statements {
		emit_stmt(gen, bst)
		if _, ok := bst.node.(Ast_Return); ok {
			block.terminated = true
		}
	}
}

emit_if :: proc(gen: ^Generator, s: ^Ast_If, scope: ^Scope, span: Span) {
	if_stmt := s
	cond_val := emit_expr(gen, if_stmt.cond, scope, span)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)

	// If the expression eval result is a i1 (one bit integer) then use it directly
	// Otherwise emit a comparison to zero and the cond_bool
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, false)
		cond_bool = BuildICmp(gen.builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	then_bb := AppendBasicBlock(function, "then")
	merge_bb := AppendBasicBlock(function, "ifcont")

	else_bb: BasicBlockRef
	if if_stmt.else_block != nil {
		else_bb = AppendBasicBlock(function, "else")
		BuildCondBr(gen.builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(gen.builder, cond_bool, then_bb, merge_bb)
	}

	PositionBuilderAtEnd(gen.builder, then_bb)
	emit_block(gen, if_stmt.then_block)

	bb := GetInsertBlock(gen.builder)
	if GetBasicBlockTerminator(bb) == nil {
		BuildBr(gen.builder, merge_bb)
	}

	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(gen.builder, else_bb)
		emit_block(gen, if_stmt.else_block)

		bb = GetInsertBlock(gen.builder)
		if GetBasicBlockTerminator(bb) == nil {
			BuildBr(gen.builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(gen.builder, merge_bb)
}

emit_for_loop :: proc(gen: ^Generator, s: ^Ast_For, scope: ^Scope, span: Span) {
	for_stmt := s
	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	loop_bb := AppendBasicBlock(function, "loop")
	after_bb := AppendBasicBlock(function, "after")

	BuildBr(gen.builder, loop_bb)
	queue.push_front(&compiler.loops, Loop{break_block = after_bb})
	PositionBuilderAtEnd(gen.builder, loop_bb)
	emit_block(gen, for_stmt.body)

	if GetBasicBlockTerminator(GetInsertBlock(gen.builder)) == nil {
		BuildBr(gen.builder, loop_bb)
	}

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(gen.builder, after_bb)
}

emit_break :: proc(gen: ^Generator, s: ^Ast_Break, scope: ^Scope, span: Span) {
	loop := queue.front(&compiler.loops)

	BuildBr(gen.builder, loop.break_block)

	// Move gen.builder away from terminated block
	fn := GetBasicBlockParent(GetInsertBlock(gen.builder))
	dead := AppendBasicBlock(fn, "after_break")
	PositionBuilderAtEnd(gen.builder, dead)
}

printf_sym: ^Symbol

// This function mainly setup a print() function that will be linked to libc printf() with a only s
// Calls to this will be exceptionally emited in emit_print_call() for now
// Also do some house keeping before running codegen
setup_codegen :: proc(gen: ^Generator) {
	// Printf
	i32 := Int32TypeInContext(gen.ctx)
	i8 := Int8TypeInContext(gen.ctx)
	i8p := PointerType(i8, 0)

	printf_ty := FunctionType(
		i32, // return type
		&i8p, // first arg: char *
		1,
		true, // variadic
	)

	printf_fn := AddFunction(gen.module, "printf", printf_ty)

	sym := make_symbol(.Function)
	sym.scope = global_scope
	sym.type = global_scope.symbols["i32"].type
	sym.name = "print"

	printf_sym = sym

	gen.values[sym] = printf_fn
	gen.types[sym] = printf_ty
}

generate :: proc(stmts: []^Ast_Node) {
	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	generator := Generator {
		ctx     = ctx,
		module  = module,
		builder = builder,
	}
	setup_codegen(&generator)

	emit_function_decls := proc(node: ^Ast_Node, userdata: rawptr = nil) {
		if fnode, ok := node.node.(Ast_Function); ok {
			fmt.println("should generate function")
			gen := cast(^Generator)userdata
			emit_function(gen, &fnode, node.scope, node.span)
		}
	}

	for stmt in stmts {
		traverse_ast(stmt, emit_function_decls, &generator)
	}

	for stmt in stmts {
		emit_stmt(&generator, stmt)
	}

	when ODIN_DEBUG {
		DumpModule(module)
	}
	InitializeX86Target()
	InitializeX86TargetInfo()
	InitializeX86TargetMC()
	InitializeX86AsmPrinter()

	triple := GetDefaultTargetTriple()

	target: TargetRef

	error: cstring
	if GetTargetFromTriple(triple, &target, &error) > 0 {
		fmt.println(triple, string(error))
		return
	}
	SetTarget(module, triple)

	tm := CreateTargetMachine(
		target,
		triple,
		"generic",
		"",
		.CodeGenLevelDefault,
		.RelocPIC,
		.CodeModelDefault,
	)

	SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	if VerifyModule(module, .AbortProcessAction, &error) > 0 {
		fmt.println(error)
	}
	if TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error) > 0 {
		fmt.println(error)
	}
}
