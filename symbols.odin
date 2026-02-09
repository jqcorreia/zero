package main

import "core:container/queue"

Symbol :: struct {
	name:  string,
	kind:  Symbol_Kind,
	type:  ^Type, // your type system
	decl:  ^Ast_Node, // pointer back to the declaration
	scope: ^Symbol_Scope,
}

Symbol_Kind :: enum {
	Variable,
	Function,
}

Symbol_Table :: map[string]Symbol


Symbol_Scope :: struct {
	kind:     ScopeKind,
	symbols:  Symbol_Table,
	function: ^Symbol,
}

ScopeKind :: enum {
	Global,
	Function,
	Block,
	Loop,
}

Symbol_Scopes :: queue.Queue(Symbol_Scope)

ss_push :: proc(scopes: ^Symbol_Scopes, scope: Symbol_Scope) {
	queue.push_front(scopes, scope)
}

ss_pop :: proc(scopes: ^Symbol_Scopes) -> Symbol_Scope {
	scope := queue.pop_front(scopes)
	return scope
}

ss_cur :: proc(scopes: ^Symbol_Scopes) -> ^Symbol_Scope {
	return queue.front_ptr(scopes)
}

resolv_var :: proc(scopes: ^Symbol_Scopes, name: string) -> ^Symbol {
	for i in queue.len(scopes^) - 1 ..= 0 {
		scope := queue.get(scopes, i)
		var, ok := &scope.symbols[name]
		if ok {
			return var
		}
	}

	return nil
}

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
