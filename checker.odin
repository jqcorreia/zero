package main

import "core:container/queue"
import "core:fmt"

Checker :: struct {}

check_stmt :: proc(c: ^Checker, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		check_expr(c, node.expr, s.span, s.scope)
	case Ast_Assignment:
		check_assigment(c, &node, s.span, s.scope)
	case Ast_Function:
		check_function(c, &node, s.span, s.scope)
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


check_assigment :: proc(c: ^Checker, s: ^Ast_Assignment, span: Span, scope: ^Scope) {
	var, ok := resolve_symbol(scope, s.name)
	if ok {
		expr_type := check_expr(c, s.expr, span, scope)
		if var.type != expr_type {
			error_span(span, "Cannot assign %v to %v", expr_type.kind, var.type.kind)
		}
	} else {
		new_var := Symbol {
			type = check_expr(c, s.expr, span, scope),
		}
		_ = new_var
	}
}

check_function :: proc(c: ^Checker, s: ^Ast_Function, span: Span, scope: ^Scope) {
	// symbol := new(Symbol)
	// symbol.name = s.name
	// symbol.kind = .Function
	// symbol.type = ident_to_type(s.ret_type_ident)
	// symbol.scope = ss_cur(&c.scopes)

	// scope := Symbol_Scope {
	// 	kind     = .Function,
	// 	function = symbol,
	// }

	// for &param in s.params {
	// 	param.type = ident_to_type(param.type_ident)
	// 	scope.symbols[param.name] = Symbol {
	// 		name = param.name,
	// 		kind = .Variable,
	// 		type = param.type,
	// 	}
	// }
	for p in s.params {

	}

	check_block(c, s.body, span)
}

check_return :: proc(c: ^Checker, s: ^Ast_Return, span: Span) {
	// if queue.len(c.scopes) == 0 {
	// 	error_span(span, "Calling 'return' outside of function.")
	// }
}

check_call :: proc(c: ^Checker, e: Expr_Call, span: Span) {

}

check_expr :: proc(c: ^Checker, expr: ^Expr, span: Span, scope: ^Scope) -> ^Type {
	#partial switch e in expr {
	case Expr_Binary:
		left := check_expr(c, e.left, span, scope)
		right := check_expr(c, e.right, span, scope)

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
	// case Expr_Int_Literal:
	// 	return e.type

	case Expr_Variable:
		sym, _ := resolve_symbol(scope, e.value)
		return sym.type

	case Expr_Call:
		func_name := e.callee.(Expr_Variable).value
		sym, ok := resolve_symbol(scope, func_name)
		if !ok {
			error_span(span, "Function '%s' not found", func_name)
			return nil
		}
		return sym.type
	}
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

check_break :: proc(c: ^Checker, s: ^Ast_Break, span: Span) {
	// inside_loop := false

	// for i in queue.len(c.scopes) - 1 ..= 0 {
	// 	scope := queue.get(&c.scopes, i)
	// 	if scope.kind == .Loop {
	// 		inside_loop = true
	// 		break
	// 	}
	// }

	// if !inside_loop {
	// 	error_span(span, "Break statement outside of loop")
	// }
}

check :: proc(c: ^Checker, nodes: []^Ast_Node) {
	global_scope := create_global_scope()
	for node in nodes {
		bind_scopes(node, global_scope)
	}

	fmt.println("----------------- END OF BIND ---------------\n\n\n")
	for node in nodes {
		if func, ok := node.node.(Ast_Function); ok {
			fmt.println("Func", func.name)
			fmt.println("Params: ")
			for p in func.params {
				fmt.println(p.name)
			}
			fmt.println("OWN:", scope_string(node.scope))
			fmt.println("CHILDREN:", scope_string(func.body.statements[0].scope))
		}
	}

	for node in nodes {
		resolve_types(c, node)
	}

	// for node in nodes {
	// 	statement_print(node)
	// }

	// for node in nodes {
	// 	check_stmt(c, node)
	// }
}
