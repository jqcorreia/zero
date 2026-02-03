package main

import "core:container/queue"
import "core:fmt"
import "core:strings"

resolve_var :: proc(name: string) -> ValueRef {
	local_var, local_var_ok := scope_current().vars[name]
	if local_var_ok {
		return local_var.ref
	} else {
		global_var, global_var_ok := compiler.global_scope.vars[name]
		if global_var_ok {
			return global_var.ref
		}
	}
	return nil
}

emit_stmt :: proc(s: ^Ast_Node, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	#partial switch &node in s.node {
	case Ast_Expr:
		emit_expr(node.expr, ctx, builder)
	case Ast_Assignment:
		emit_assigment(&node, ctx, builder, module)
	case Ast_Function:
		emit_function(&node, ctx, builder, module)
	case Ast_Return:
		emit_return(&node, ctx, builder, module)
	case Ast_If:
		emit_if(&node, ctx, builder, module)
	case Ast_For:
		emit_for_loop(&node, ctx, builder, module)
	case Ast_Break:
		emit_break(&node, ctx, builder, module)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_assigment :: proc(
	s: ^Ast_Assignment,
	ctx: ContextRef,
	builder: BuilderRef,
	module: ModuleRef,
) {
	data := s
	// Build local variables
	// If the variable exists, just emit a Store, otherwise emit Alloca + Store
	if !scope_top_level() {
		var, exists := scope_current().vars[data.name]
		ptr := var.ref
		if exists {
			BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
		} else {
			ptr = BuildAlloca(builder, Int32Type(), "")
			BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
			var.ref = ptr
			scope_current().vars[data.name] = var
		}
	} else {
		// Create global variables, only constant for now
		if _, ok := data.expr.(Expr_Int_Literal); ok {
			ptr := AddGlobal(module, Int32Type(), strings.clone_to_cstring(data.name))
			SetInitializer(
				ptr,
				ConstInt(Int32Type(), u64(data.expr.(Expr_Int_Literal).value), false),
			)
			compiler.global_scope.vars[data.name] = Scope_Var {
				ref = ptr,
			}
		} else {
			panic("Global variables need to be constants")
		}
	}
}

emit_function :: proc(s: ^Ast_Function, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	old_pos := GetInsertBlock(builder)

	data := s

	int32 := Int32TypeInContext(ctx)
	param_types: [dynamic]TypeRef

	fn_type: TypeRef
	ret_type_ref := s.ret_type == nil ? VoidTypeInContext(ctx) : Int32TypeInContext(ctx)

	if len(s.params) > 0 {
		for _ in data.params {
			append(&param_types, int32)
		}

		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), false)
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, false)

	}

	fn := AddFunction(module, strings.clone_to_cstring(data.name), fn_type)
	// By now the function must exist in state
	// Complete the information with TypeRef and ValueRef
	s.ty = fn_type
	s.fn = fn

	// Store function Ast node for further reference in calls
	compiler.funcs[s.name] = s

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(ctx, fn, "")
	PositionBuilderAtEnd(builder, entry)

	// Allocate vars
	scope := Scope{}
	scope_push(scope)
	for ast_param, i in data.params {
		param := GetParam(fn, u32(i))

		alloca := BuildAlloca(builder, int32, strings.clone_to_cstring(ast_param.name))
		BuildStore(builder, param, alloca)

		scope_current().vars[ast_param.name] = Scope_Var {
			ref = alloca,
		}
	}

	emit_block(data.body, ctx, builder, module)

	if s.ret_type == nil {
		BuildRetVoid(builder)
	}
	PositionBuilderAtEnd(builder, old_pos)
	DumpValue(fn)

	scope_pop()
}

emit_return :: proc(s: ^Ast_Return, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	data := s
	BuildRet(builder, emit_expr(data.expr, ctx, builder))
}

// This a hacked printf-type emission until we have proper external functions and string support
emit_print_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr := BuildGlobalStringPtr(builder, "%d\n", "")
	func := compiler.funcs[e.callee.(Expr_Variable).value]
	args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")

	return call
}

emit_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fn_name := e.callee.(Expr_Variable).value
	func, ok := compiler.funcs[e.callee.(Expr_Variable).value]

	if !ok {
		panic(fmt.tprintln("Function", fn_name, "not found"))
	}

	args: [dynamic]ValueRef
	for a in e.args {
		append(&args, emit_expr(a, ctx, builder))
	}

	if len(args) == 0 {
		return BuildCall2(builder, func.ty, func.fn, nil, 0, "")
	} else {
		return BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")
	}
}

emit_expr :: proc(expr: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	#partial switch e in expr {
	case Expr_Int_Literal:
		return ConstInt(int32, u64(e.value), false)
	case Expr_Call:
		data := e
		if data.callee.(Expr_Variable).value == "print" {
			return emit_print_call(e, ctx, builder)
		} else {
			return emit_call(e, ctx, builder)
		}
	case Expr_Variable:
		var := resolve_var(e.value)
		if var == nil {
			panic(fmt.tprintf("Variable '%s' is not declared", e.value))
		}
		return BuildLoad2(builder, int32, var, "")
	case Expr_Binary:
		#partial switch e.op {
		case .Plus:
			return BuildAdd(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"add",
			)
		case .Minus:
			return BuildSub(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"sub",
			)
		case .Star:
			return BuildMul(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"mul",
			)
		case .Slash:
			return BuildSDiv(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"div",
			)
		case .DoubleEqual:
			return BuildICmp(
				builder,
				.IntEQ,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gt",
			)
		case .Greater:
			return BuildICmp(
				builder,
				.IntUGT,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gt",
			)
		case .Lesser:
			return BuildICmp(
				builder,
				.IntULT,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"lt",
			)
		case .GreaterOrEqual:
			return BuildICmp(
				builder,
				.IntUGE,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gte",
			)
		case .LesserOrEqual:
			return BuildICmp(
				builder,
				.IntULE,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"lte",
			)
		}
	}
	unreachable()
}

emit_block :: proc(block: ^Ast_Block, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	for bst in block.statements {
		emit_stmt(bst, ctx, builder, module)
		if _, ok := bst.node.(Ast_Return); ok {
			block.terminated = true
		}
	}
}

emit_if :: proc(s: ^Ast_If, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	if_stmt := s
	cond_val := emit_expr(if_stmt.cond, ctx, builder)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)

	// If the expression eval result is a i1 (one bit integer) then use it directly
	// Otherwise emit a comparison to zero and the cond_bool
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, false)
		cond_bool = BuildICmp(builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(builder))

	then_bb := AppendBasicBlock(function, "then")
	merge_bb := AppendBasicBlock(function, "ifcont")

	else_bb: BasicBlockRef
	if if_stmt.else_block != nil {
		else_bb = AppendBasicBlock(function, "else")
		BuildCondBr(builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(builder, cond_bool, then_bb, merge_bb)
	}

	PositionBuilderAtEnd(builder, then_bb)
	emit_block(if_stmt.then_block, ctx, builder, module)

	bb := GetInsertBlock(builder)
	if GetBasicBlockTerminator(bb) == nil {
		BuildBr(builder, merge_bb)
	}

	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(builder, else_bb)
		emit_block(if_stmt.else_block, ctx, builder, module)

		bb = GetInsertBlock(builder)
		if GetBasicBlockTerminator(bb) == nil {
			BuildBr(builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(builder, merge_bb)
}

emit_for_loop :: proc(s: ^Ast_For, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	for_stmt := s
	function := GetBasicBlockParent(GetInsertBlock(builder))

	loop_bb := AppendBasicBlock(function, "loop")
	after_bb := AppendBasicBlock(function, "after")

	BuildBr(builder, loop_bb)
	queue.push_front(&compiler.loops, Loop{break_block = after_bb})
	PositionBuilderAtEnd(builder, loop_bb)
	emit_block(for_stmt.body, ctx, builder, module)

	if GetBasicBlockTerminator(GetInsertBlock(builder)) == nil {
		BuildBr(builder, loop_bb)
	}

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(builder, after_bb)
}

emit_break :: proc(s: ^Ast_Break, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	if queue.len(compiler.loops) == 0 {
		panic("Breaking outside of a loop")
	}
	loop := queue.front(&compiler.loops)

	BuildBr(builder, loop.break_block)

	// Move builder away from terminated block
	fn := GetBasicBlockParent(GetInsertBlock(builder))
	dead := AppendBasicBlock(fn, "after_break")
	PositionBuilderAtEnd(builder, dead)
}

// This function mainly setup a print() function that will be linked to libc printf() with a only s
// Calls to this will be exceptionally emited in emit_print_call() for now
// Also do some house keeping before running codegen
setup_codegen :: proc(ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
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

	ast_function := new(Ast_Function)
	ast_function.name = "print"
	ast_function.ty = printf_ty
	ast_function.fn = printf_fn
	// ast.params = {Param{name = "val", type = &Type{kind = .Int32}}}

	compiler.funcs["print"] = ast_function

	// Clear compiler scopes in order to have a fresh start when generating
	// NOTE: I'm not sure that having this is needed in the codegen phase
	// if is is then it should be a separate thing from the one used in the checker
	queue.clear(&compiler.scopes)
	scope_push(Scope{})
}

generate :: proc(stmts: []^Ast_Node) {
	// int32 := Int32TypeInContext(ctx)
	// fn_type := FunctionType(int32, nil, 0, 0)

	// main_f := AddFunction(module, "main", fn_type)

	// entry := AppendBasicBlockInContext(ctx, main_f, "")
	// PositionBuilderAtEnd(builder, entry)

	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	setup_codegen(ctx, module, builder)

	for stmt in stmts {
		emit_stmt(stmt, ctx, builder, module)
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

	fmt.println(target, triple)
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
