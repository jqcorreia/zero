package main

import "core:container/queue"
import "core:fmt"
import "core:strings"

Generator :: struct {
	values:          map[^Symbol]ValueRef,
	types:           map[^Symbol]TypeRef,
	ctx:             ContextRef,
	builder:         BuilderRef,
	module:          ModuleRef,
	primitive_types: map[^Type]TypeRef,
}

emit_stmt :: proc(gen: ^Generator, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Expr:
		emit_value(gen, data.expr, node.scope, node.span)
	case Ast_Var_Assign:
		emit_assigment(gen, &data, node.scope, node.span)
	case Ast_Var_Decl:
		emit_var_decl(gen, &data, node.scope, node.span)
	case Ast_Struct_Decl:
		emit_struct_body(gen, &data, node.scope, node.span)
	case Ast_Function:
		if !data.external {
			emit_function_body(gen, &data, node.scope, node.span)
		}
	case Ast_Block:
	// Do nothing
	case Ast_Import:
	// Do nothing
	case Ast_Return:
		emit_return(gen, &data, node.scope, node.span)
	case Ast_If:
		emit_if(gen, &data, node.scope, node.span)
	case Ast_For:
		emit_for_loop(gen, &data, node.scope, node.span)
	case Ast_Break:
		emit_break(gen, &data, node.scope, node.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", node))
	}
}
emit_into :: proc(gen: ^Generator, expr: ^Expr, dest: ValueRef, scope: ^Scope, span: Span) {
	#partial switch e in expr.data {
	case Expr_Struct_Literal:
		sym, _ := resolve_symbol(scope, e.type_expr)
		struct_llvm_type := gen.primitive_types[sym.type]

		for field in sym.type.fields {
			field_ptr := BuildStructGEP2(gen.builder, struct_llvm_type, dest, u32(field.index), "")
			field_val := emit_value(gen, e.args[field.name], scope, span)
			BuildStore(gen.builder, field_val, field_ptr)
		}
	}
}

emit_address :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	#partial switch e in expr.data {
	case Expr_Struct_Literal:
		sym, _ := resolve_symbol(scope, e.type_expr)
		struct_llvm_type := gen.primitive_types[sym.type]
		fmt.println(sym)
		ptr := BuildAlloca(gen.builder, struct_llvm_type, "")

		for field in sym.type.fields {
			field_ptr := BuildStructGEP2(gen.builder, struct_llvm_type, ptr, u32(field.index), "")
			BuildStore(gen.builder, emit_value(gen, e.args[field.name], scope, span), field_ptr)
		}
		return ptr

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok {
			fatal_span(span, "Symbol not found on expr emit: %s", e.value)
		}
		var := gen.values[sym]

		return var

	case Expr_Member:
		base_ptr := emit_address(gen, e.base, scope, span)
		base_type := gen.primitive_types[e.base.type]
		field_index := 0
		for f in e.base.type.fields {
			if f.name == e.member {
				field_index = f.index
				break
			}
		}
		return BuildStructGEP2(gen.builder, base_type, base_ptr, u32(field_index), "")
	}

	unimplemented(fmt.tprintf("Not addressable expression %v", expr))
}

emit_value :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	int32 := Int32TypeInContext(gen.ctx)
	#partial switch e in expr.data {
	case Expr_Int_Literal:
		fmt.println("$$$$$$$$$$$", expr, expr.type, span_to_location(span))
		type := gen.primitive_types[expr.type]
		return ConstInt(type, u64(e.value), false)
	case Expr_String_Literal:
		return BuildGlobalStringPtr(gen.builder, strings.clone_to_cstring(e.value), "")
	case Expr_Struct_Literal:
		addr := emit_address(gen, expr, scope, span)
		sym, _ := resolve_symbol(scope, e.type_expr)
		return BuildLoad2(gen.builder, gen.primitive_types[sym.type], addr, "")
	case Expr_Member:
		ptr := emit_address(gen, expr, scope, span)
		return BuildLoad2(gen.builder, gen.primitive_types[expr.type], ptr, "")
	case Expr_Call:
		return emit_call(gen, e, scope, span)
	case Expr_Variable:
		ptr := emit_address(gen, expr, scope, span)
		sym, _ := resolve_symbol(scope, e.value)
		return BuildLoad2(gen.builder, gen.primitive_types[sym.type], ptr, "")
	case Expr_Unary:
		#partial switch e.op {
		case .Minus:
			return BuildSub(
				gen.builder,
				ConstInt(int32, 0, false),
				emit_value(gen, e.expr, scope, span),
				"subzero",
			)
		}

	case Expr_Binary:
		#partial switch e.op {
		case .Plus:
			return BuildAdd(
				gen.builder,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"add",
			)
		case .Minus:
			return BuildSub(
				gen.builder,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"sub",
			)
		case .Star:
			return BuildMul(
				gen.builder,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"mul",
			)
		case .Slash:
			return BuildSDiv(
				gen.builder,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"div",
			)
		case .DoubleEqual:
			return BuildICmp(
				gen.builder,
				.IntEQ,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"gt",
			)
		case .NotEqual:
			return BuildICmp(
				gen.builder,
				.IntNE,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"gt",
			)
		case .Greater:
			left_type := e.left.type
			right_type := e.right.type
			return BuildICmp(
				gen.builder,
				left_type.signed || right_type.signed ? .IntSGT : .IntUGT,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"gt",
			)
		case .Lesser:
			left_type := e.left.type
			right_type := e.right.type
			return BuildICmp(
				gen.builder,
				left_type.signed || right_type.signed ? .IntSLT : .IntULT,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"lt",
			)
		case .GreaterOrEqual:
			left_type := e.left.type
			right_type := e.right.type
			return BuildICmp(
				gen.builder,
				left_type.signed || right_type.signed ? .IntSGE : .IntUGE,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"gte",
			)
		case .LesserOrEqual:
			left_type := e.left.type
			right_type := e.right.type
			return BuildICmp(
				gen.builder,
				left_type.signed || right_type.signed ? .IntSLE : .IntULE,
				emit_value(gen, e.left, scope, span),
				emit_value(gen, e.right, scope, span),
				"lte",
			)
		}
	}
	unimplemented(fmt.tprintf("Expression %v emit not implemented", expr))
}

emit_assigment :: proc(gen: ^Generator, s: ^Ast_Var_Assign, scope: ^Scope, span: Span) {
	ptr := emit_address(gen, s.lhs, scope, span)
	BuildStore(gen.builder, emit_value(gen, s.expr, scope, span), ptr)
}

emit_var_decl :: proc(gen: ^Generator, s: ^Ast_Var_Decl, scope: ^Scope, span: Span) {
	// Build local variables
	// If the variable exists, just emit a Store, otherwise emit Alloca + Store
	is_global := scope.kind == .Global
	sym := s.symbol
	if sym == nil {
		fatal_span(span, "Symbol %s is not bound!", s.name)
	}
	if !is_global {
		ptr, exists := gen.values[sym]

		if exists do fatal_span(span, "Variable aliasing detected. Fatal error for now")

		compiler_type := gen.primitive_types[sym.type]
		ptr = BuildAlloca(gen.builder, compiler_type, "")
		gen.values[sym] = ptr
		if s.expr != nil {
			if sym.type.kind == .Struct {
				emit_into(gen, s.expr, ptr, scope, span)

			} else {
				BuildStore(gen.builder, emit_value(gen, s.expr, scope, span), ptr)
			}
		}
	} else {
		// Create global variables, only constant for now
		if _, ok := s.expr.data.(Expr_Int_Literal); ok {
			ptr := AddGlobal(gen.module, Int32Type(), strings.clone_to_cstring(s.name))
			SetInitializer(
				ptr,
				ConstInt(Int32Type(), u64(s.expr.data.(Expr_Int_Literal).value), false),
			)
		} else {
			panic("Global variables need to be constants")
		}
	}
}

emit_memcpy :: proc(gen: ^Generator, s: ^Ast_Var_Decl, scope: ^Scope, span: Span) {
	// NOTE: THis is incomplete but saved for future reference!!

	// data_layout := GetModuleDataLayout(gen.module)

	// align := ABIAlignmentOfType(data_layout, compiler_type)
	// size := ABISizeOfType(data_layout, compiler_type)
	// i64_size := ConstInt(Int64Type(), size, false)
	// addr := emit_address(gen, s.expr, scope, span)
	// BuildMemCpy(gen.builder, ptr, align, addr, align, i64_size)
}

emit_function_decl :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	param_types: [dynamic]TypeRef

	fn_type: TypeRef

	//NOTE(quadrado): This must change so a function can return more than primitive types
	ret_type_ref := gen.primitive_types[s.symbol.type]

	if len(s.params) > 0 {
		variadic := false
		for param in s.params {
			if param.variadic_marker {
				variadic = true
			} else {
				append(&param_types, gen.primitive_types[param.symbol.type])
			}
		}
		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), i32(variadic))
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, false)

	}

	sym := s.symbol
	fn := AddFunction(gen.module, strings.clone_to_cstring(s.name), fn_type)

	gen.values[sym] = fn
	gen.types[sym] = fn_type
}

emit_struct_decl :: proc(gen: ^Generator, s: ^Ast_Struct_Decl, scope: ^Scope, span: Span) {
	llvm_type := StructCreateNamed(gen.ctx, strings.clone_to_cstring(s.name))
	sym := s.symbol
	gen.primitive_types[sym.type] = llvm_type
}

emit_struct_body :: proc(gen: ^Generator, s: ^Ast_Struct_Decl, scope: ^Scope, span: Span) {
	sym := s.symbol
	llvm_type := gen.primitive_types[sym.type]

	field_types: [dynamic]TypeRef

	for field in sym.type.fields {
		append(&field_types, gen.primitive_types[field.type])
	}

	StructSetBody(llvm_type, raw_data(field_types), u32(len(field_types)), false)
	AddGlobal(gen.module, llvm_type, "dummy_struct_use")
}

emit_function_body :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	int32 := Int32TypeInContext(gen.ctx)

	sym := s.symbol
	fn := gen.values[sym]

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(gen.ctx, fn, "")

	old_pos := GetInsertBlock(gen.builder)
	PositionBuilderAtEnd(gen.builder, entry)

	for ast_param, i in s.params {
		param_sym := ast_param.symbol
		param := GetParam(fn, u32(i))

		alloca := BuildAlloca(gen.builder, int32, strings.clone_to_cstring(ast_param.name))
		BuildStore(gen.builder, param, alloca)
		gen.values[param_sym] = alloca
	}

	emit_block(gen, s.body)

	/*
	If function return type is Void and not terminated yet (a explicit return, 
    which is a valid expression), terminate with a RetVoid
    NOTE(quadrado): Using the "terminated" field in the Ast is not good but GetBasicBlockTerminator 
    always returns a value and not nil as expected of a non-terminated block.
    */
	if s.symbol.type.kind == .Void && !s.body.terminated {
		BuildRetVoid(gen.builder)
	}

	PositionBuilderAtEnd(gen.builder, old_pos)
	// DumpValue(fn)
}

emit_return :: proc(gen: ^Generator, s: ^Ast_Return, scope: ^Scope, span: Span) {
	data := s
	if data.expr != nil {
		BuildRet(gen.builder, emit_value(gen, data.expr, scope, span))
	} else {
		BuildRetVoid(gen.builder)
	}
}


emit_call :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	fn_name := e.callee.data.(Expr_Variable).value

	args: [dynamic]ValueRef
	for a in e.args {
		append(&args, emit_value(gen, a, scope, span))
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


emit_block :: proc(gen: ^Generator, block: ^Ast_Block) {
	for bst in block.statements {
		emit_stmt(gen, bst)
		if _, ok := bst.data.(Ast_Return); ok {
			block.terminated = true
		}
	}
}

emit_if :: proc(gen: ^Generator, s: ^Ast_If, scope: ^Scope, span: Span) {
	if_stmt := s
	cond_val := emit_value(gen, if_stmt.cond, scope, span)

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

setup_codegen :: proc(gen: ^Generator) {
	// Primitive types
	for _, sym in global_scope.symbols {
		if sym.kind == .Type {
			#partial switch sym.type.kind {
			case .Void:
				gen.primitive_types[sym.type] = VoidTypeInContext(gen.ctx)
			case .Bool:
				gen.primitive_types[sym.type] = Int1TypeInContext(gen.ctx)
			case .Uint8:
				gen.primitive_types[sym.type] = Int8TypeInContext(gen.ctx)
			case .Int8:
				gen.primitive_types[sym.type] = Int8TypeInContext(gen.ctx)
			case .Uint32:
				gen.primitive_types[sym.type] = Int32TypeInContext(gen.ctx)
			case .Int32:
				gen.primitive_types[sym.type] = Int32TypeInContext(gen.ctx)
			case .Uint64:
				gen.primitive_types[sym.type] = Int64TypeInContext(gen.ctx)
			case .Int64:
				gen.primitive_types[sym.type] = Int64TypeInContext(gen.ctx)
			case .String:
				gen.primitive_types[sym.type] = PointerTypeInContext(gen.ctx, 0)
			}
		}
	}
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

	emit_struct_decls := proc(node: ^Ast_Node, userdata: rawptr = nil) {
		if snode, ok := node.data.(Ast_Struct_Decl); ok {
			gen := cast(^Generator)userdata
			emit_struct_decl(gen, &snode, node.scope, node.span)
		}
	}
	emit_function_decls := proc(node: ^Ast_Node, userdata: rawptr = nil) {
		if fnode, ok := node.data.(Ast_Function); ok {
			gen := cast(^Generator)userdata
			emit_function_decl(gen, &fnode, node.scope, node.span)
		}
	}

	// Emit first things first
	// - Structs
	// - Functions
	traverse_block(stmts, emit_struct_decls, &generator)
	traverse_block(stmts, emit_function_decls, &generator)

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
