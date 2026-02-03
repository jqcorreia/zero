package main

import "core:container/queue"
import "core:fmt"

Checker :: struct {
	loops: queue.Queue(Loop),
}

checker := Checker{}

check_stmt :: proc(s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		check_expr(node.expr, s.span)
	case Ast_Assignment:
		check_assigment(&node, s.span)
	case Ast_Function:
		check_function(&node, s.span)
	case Ast_Return:
		check_return(&node, s.span)
	case Ast_If:
		check_if(&node, s.span)
	case Ast_For:
		check_for_loop(&node, s.span)
	case Ast_Break:
		check_break(&node, s.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

check_assigment :: proc(s: ^Ast_Assignment, span: Span) {
	fmt.println("$$$$$$$$$ check assignment")
	if v, ok := scope_current().vars[s.name]; ok {
		expr_type := type_check_expr(s.expr)
		fmt.println(s.name, expr_type, v.type)

		if v.type != expr_type {
			error_span(span, "Cannot assign %v to %v", expr_type, v.type)
		}
	} else {
		var := Scope_Var {
			type = type_check_expr(s.expr),
		}

		scope_current().vars[s.name] = var
	}
}

check_function :: proc(s: ^Ast_Function, span: Span) {
	scope := Scope{}

	for param in s.params {
		scope.vars[param.name] = Scope_Var {
			type = param.type,
		}
	}
	scope_push(Scope{})
	check_block(s.body, span)
	scope_pop()
}

check_return :: proc(s: ^Ast_Return, span: Span) {
}

check_call :: proc(e: Expr_Call, span: Span) {
}

check_expr :: proc(expr: ^Expr, span: Span) {
}

check_block :: proc(block: ^Ast_Block, span: Span) {
	for node in block.statements {
		check_stmt(node)
	}
}

check_if :: proc(s: ^Ast_If, span: Span) {
	check_block(s.then_block, span)
	if s.else_block != nil {
		check_block(s.else_block, span)
	}
}

check_for_loop :: proc(s: ^Ast_For, span: Span) {
	queue.push_front(&checker.loops, Loop{})
	check_block(s.body, span)
	queue.pop_front(&checker.loops)
}


check_break :: proc(s: ^Ast_Break, span: Span) {
	if queue.len(checker.loops) == 0 {
		panic("Break statement outside of loop")
	}
}

check :: proc(nodes: []^Ast_Node) {
	for node in nodes {
		fmt.println("#########", node)
		check_stmt(node)
	}
}
