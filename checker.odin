package main

import "core:container/queue"
import "core:fmt"

Checker :: struct {
	loops: queue.Queue(Loop),
}

check_stmt :: proc(s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		check_expr(node.expr)
	case Ast_Assignment:
		check_assigment(&node)
	case Ast_Function:
		check_function(&node)
	case Ast_Return:
		check_return(&node)
	case Ast_If:
		check_if(&node)
	case Ast_For:
		check_for_loop(&node)
	case Ast_Break:
		check_break(&node)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

check_assigment :: proc(s: ^Ast_Assignment) {
	v, ok := scope_current().vars[s.name]

	if ok {
	}
}

check_function :: proc(s: ^Ast_Function) {
	check_block(s.body)
}

check_return :: proc(s: ^Ast_Return) {
}

check_call :: proc(e: Expr_Call) {
}

check_expr :: proc(expr: ^Expr) {
}

check_block :: proc(block: ^Ast_Block) {
	for node in block.statements {
		check_stmt(node)
	}
}

check_if :: proc(s: ^Ast_If) {
	check_block(s.then_block)
	if s.else_block != nil {
		check_block(s.else_block)
	}
}

check_for_loop :: proc(s: ^Ast_For) {
	check_block(s.body)
}


check_break :: proc(s: ^Ast_Break) {
	// if queue.len(compiler.loops) == 0 {
	// 	panic("Break statement outside of loop")
	// }
}

check :: proc(nodes: []^Ast_Node) {
	for node in nodes {
		fmt.println("#########", node)
		check_stmt(node)
	}
}
