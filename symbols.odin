package main

import "core:fmt"

Symbol :: struct {
	name: string,
	kind: Symbol_Kind,
}

Symbol_Kind :: enum {
	Variable,
	Function,
}

Symbol_Table :: map[string]Symbol


flatten_ast :: proc(nodes: []^Ast_Node) -> []^Ast_Node {
	res: [dynamic]^Ast_Node
	for node in nodes {
		#partial switch n in node.node {
		case Ast_Block:
			for inner_node in flatten_ast(n.statements) {
				append(&res, inner_node)
			}
		case Ast_Function:
			for inner_node in flatten_ast(n.body.statements) {
				append(&res, inner_node)
			}
		case Ast_For:
			for inner_node in flatten_ast(n.body.statements) {
				append(&res, inner_node)
			}
		case Ast_If:
			for inner_node in flatten_ast(n.then_block.statements) {
				append(&res, inner_node)
			}
			for inner_node in flatten_ast(n.else_block.statements) {
				append(&res, inner_node)
			}
		}
		append(&res, node)
	}

	return res[:]
}

// create_symbol_table :: proc(c: ^Checker, nodes: Ast_Module) {
// 	for node in nodes {
// 		#partial switch n in node.node {
// 		case Ast_Block:
// 			for inner_node in flatten_ast(n.statements) {
// 				append(&res, inner_node)
// 			}
// 		case Ast_Function:
// 			for inner_node in flatten_ast(n.body.statements) {
// 				append(&res, inner_node)
// 			}
// 		case Ast_For:
// 			for inner_node in flatten_ast(n.body.statements) {
// 				append(&res, inner_node)
// 			}
// 		case Ast_If:
// 			for inner_node in flatten_ast(n.then_block.statements) {
// 				append(&res, inner_node)
// 			}
// 			for inner_node in flatten_ast(n.else_block.statements) {
// 				append(&res, inner_node)
// 			}
// 		}
// 		append(&res, node)
// 	}

// }

get_symbols :: proc(ast: ^Ast_Node) -> []Symbol {
	syms: [dynamic]Symbol

	#partial switch e in ast.node {
	case Ast_Assignment:
		sym: Symbol = {
			name = e.name,
			kind = .Variable,
		}
		append(&syms, sym)
	case Ast_Function:
		sym: Symbol = {
			name = e.name,
			kind = .Function,
		}
		append(&syms, sym)
	}

	return syms[:]
}
