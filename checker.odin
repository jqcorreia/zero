package main

import "core:container/queue"
import "core:fmt"

Checker :: struct {
	loops:  queue.Queue(Loop),
	scopes: Scopes,
}

check_stmt :: proc(c: ^Checker, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		check_expr(c, node.expr, s.span)
	case Ast_Assignment:
		check_assigment(c, &node, s.span)
	case Ast_Function:
		check_function(c, &node, s.span)
	case Ast_Return:
		check_return(c, &node, s.span)
	case Ast_If:
		check_if(c, &node, s.span)
	case Ast_For:
		check_for_loop(c, &node, s.span)
	case Ast_Break:
		check_break(c, &node, s.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

check_assigment :: proc(c: ^Checker, s: ^Ast_Assignment, span: Span) {
	var := resolve_var(&c.scopes, s.name)
	if var.ref != nil {
		expr_type := type_check_expr(s.expr, span)
		// fmt.println(s.name, expr_type, var.type)

		if var.type != expr_type {
			error_span(span, "Cannot assign %v to %v", expr_type.kind, var.type.kind)
		}
	} else {
		new_var := Scope_Var {
			type = type_check_expr(s.expr, span),
		}

		scope := queue.front_ptr(&c.scopes)
		scope.vars[s.name] = new_var
	}
}

check_function :: proc(c: ^Checker, s: ^Ast_Function, span: Span) {
	scope := Scope{}

	for param in s.params {
		scope.vars[param.name] = Scope_Var {
			type = param.type,
		}
	}
	queue.push_front(&c.scopes, scope)
	check_block(c, s.body, span)
	queue.pop_front(&c.scopes)
}

check_return :: proc(c: ^Checker, s: ^Ast_Return, span: Span) {
	if queue.len(c.scopes) == 0 {
		error_span(span, "Calling 'return' outside of function.")
	}
}

check_call :: proc(c: ^Checker, e: Expr_Call, span: Span) {

}

check_expr :: proc(c: ^Checker, expr: ^Expr, span: Span) {
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
	queue.push_front(&c.loops, Loop{})
	check_block(c, s.body, span)
	queue.pop_front(&c.loops)
}


check_break :: proc(c: ^Checker, s: ^Ast_Break, span: Span) {
	if queue.len(c.loops) == 0 {
		error_span(span, "Break statement outside of loop")
	}
}

check :: proc(c: ^Checker, nodes: []^Ast_Node) {
	// flat := flatten_ast(nodes)
	// symbols := create_symbol_table(nodes)

	// when ODIN_DEBUG {
	// 	fmt.println(symbols)
	// }
	// for f in flat {
	// 	fmt.println(f.node)
	// }

	for node in nodes {
		check_stmt(c, node)
	}
}
