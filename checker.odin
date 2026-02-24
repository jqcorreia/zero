package main

import "core:fmt"

Checker :: struct {}

check_stmt :: proc(c: ^Checker, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Expr:
		check_expr(c, data.expr, node.scope, node.span)
	case Ast_Var_Decl:
	case Ast_Var_Assign:
		check_assigment(c, &data, node.scope, node.span)
	case Ast_Function:
		check_function(c, &data, node.scope, node.span)
	case Ast_Struct_Decl:
	case Ast_Return:
		check_return(c, &data, node.scope, node.span)
	case Ast_If:
		check_if(c, &data, node.span)
	case Ast_For:
		check_for_loop(c, &data, node.span)
	case Ast_Break:
		check_break(c, &data, node.scope, node.span)
	case Ast_Block:
	case Ast_Import:
		check_import(c, &data, node.scope, node.span)
	// Do nothing here
	case:
		unimplemented(fmt.tprint("Unimplement check", node))
	}
}


check_assigment :: proc(c: ^Checker, s: ^Ast_Var_Assign, scope: ^Scope, span: Span) {
	var, ok := resolve_symbol(scope, s.name)
	if ok {
		if var.type != s.expr.type {
			error_span(span, "Cannot assign %v to %v", s.expr.type.kind, var.type.kind)
		}
	} else {
		error_span(span, "symbol %s not found", s.name)
	}
}

check_function :: proc(c: ^Checker, s: ^Ast_Function, scope: ^Scope, span: Span) {
	// for p in s.params {
	// }
	if !s.external {
		check_block(c, s.body, span)
	}
}

check_return :: proc(c: ^Checker, s: ^Ast_Return, scope: ^Scope, span: Span) {
	sc := scope
	inside_function := false
	for {
		if sc.kind == .Function {
			inside_function = true
			break
		}
		if sc.parent == nil do break
		sc = sc.parent
	}

	if !inside_function {
		error_span(span, "Return statement outside of function")
	}
}

check_call :: proc(c: ^Checker, e: Expr_Call, span: Span) {

}

check_expr :: proc(c: ^Checker, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	#partial switch e in expr.data {
	case Expr_Binary:
		left := check_expr(c, e.left, scope, span)
		right := check_expr(c, e.right, scope, span)

		if left != right {
			error_span(
				span,
				"Operation '%s' cannot be done on different types: %s vs %s",
				e.op,
				left.kind,
				right.kind,
			)
			return nil
		} else {
			return left
		}
	case Expr_Int_Literal:
		return expr.type
	}

	// case Expr_Variable:
	// 	sym, _ := resolve_symbol(scope, e.value)
	// 	return sym.type

	// case Expr_Call:
	// 	func_name := e.callee.(Expr_Variable).value
	// 	sym, ok := resolve_symbol(scope, func_name)
	// 	if !ok {
	// 		error_span(span, "Function '%s' not found", func_name)
	// 		return nil
	// 	}
	// 	return sym.type
	// }
	return nil
}

check_block :: proc(c: ^Checker, block: ^Ast_Block, span: Span) {
	for node in block.statements {
		check_stmt(c, node)
	}
}

check_if :: proc(c: ^Checker, s: ^Ast_If, span: Span) {
	check_block(c, s.then_block, span)
	if s.else_block != nil {
		check_block(c, s.else_block, span)
	}
}

check_for_loop :: proc(c: ^Checker, s: ^Ast_For, span: Span) {
	check_block(c, s.body, span)
}

check_break :: proc(c: ^Checker, s: ^Ast_Break, scope: ^Scope, span: Span) {
	sc := scope
	inside_loop := false
	for {
		if sc.kind == .Loop {
			inside_loop = true
			break
		}
		if sc.parent == nil do break
		sc = sc.parent
	}

	if !inside_loop {
		error_span(span, "Break statement outside of loop")
	}
}

check_import :: proc(c: ^Checker, node: ^Ast_Import, scope: ^Scope, span: Span) {
	if scope.kind != .Global {
		error_span(span, "Import statemens must be at top-level")
	}
}

global_scope: ^Scope

check :: proc(c: ^Checker, nodes: []^Ast_Node) {
	global_scope = create_global_scope()
	for node in nodes {
		bind_scopes(node, global_scope)
	}

	for node in nodes {
		resolve_types(c, node)
	}

	// Debug traverse to make sure that no symbol in untyped
	check_resolved_symbols := proc(node: ^Ast_Node, userdata: rawptr) {
		for _, symbol in node.scope.symbols {
			if symbol.type == nil && symbol.kind != .Function {
				error_span(node.span, "nil typed symbol %v", symbol)
			}
		}
	}
	check_everyone_has_types := proc(node: ^Ast_Node, userdata: rawptr) {
		if expr_node, ok := node.data.(Ast_Expr); ok {
			if expr_node.expr.type == nil {
				error_span(
					node.span,
					"Ast Node: %v, Expr Node: %v has no resolved type",
					node,
					expr_node,
				)

			}
		}
	}

	traverse_block(nodes, check_resolved_symbols)
	traverse_block(nodes, check_everyone_has_types)

	for node in nodes {
		check_stmt(c, node)
	}
}
