package main

import "core:container/queue"
import "core:fmt"

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
	Type,
}

Symbol_Table :: map[string]Symbol


Symbol_Scope :: struct {
	kind:     ScopeKind,
	symbols:  Symbol_Table,
	function: ^Symbol,
	parent:   ^Symbol_Scope,
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

create_global_scope :: proc() -> Symbol_Scope {
	scope := Symbol_Scope {
		kind = .Global,
	}

	u8_t := new(Type)
	u8_t.kind = .U8
	scope.symbols["u8"] = Symbol {
		type = u8_t,
		kind = .Type,
	}

	// i8_t := new(Type)
	// i8_t.kind = .Int8
	// scope.symbols["i8"] = Symbol {
	// 	type = i8_t,
	// 	kind = .Type,
	// }

	// i16_t := new(Type)
	// i16_t.kind = .Int16
	// scope.symbols["i16"] = Symbol {
	// 	type = i16_t,
	// 	kind = .Type,
	// }

	// i32_t := new(Type)
	// i32_t.kind = .Int32
	// scope.symbols["i32"] = Symbol {
	// 	type = i32_t,
	// 	kind = .Type,
	// }

	// u32_t := new(Type)
	// u32_t.kind = .Uint32
	// scope.symbols["u32"] = Symbol {
	// 	type = u32_t,
	// 	kind = .Type,
	// }

	// bool_t := new(Type)
	// bool_t.kind = .Bool
	// scope.symbols["bool"] = Symbol {
	// 	type = bool_t,
	// 	kind = .Type,
	// }

	return scope
}

bind_scopes :: proc(c: ^Checker, s: ^Ast_Node) {
	// Set the current scope first thing
	cur_scope := ss_cur(&c.scopes)
	s.scope = cur_scope

	#partial switch &node in s.node {
	case Ast_Assignment:
		// For now use resolv_var inside to check if var already exists.
		// TODO(quadrado): if in the future we implement let or := then we change here
		// Add the the symbol table if not existing
		if resolv_var(&c.scopes, node.name) == nil {
			cur_scope.symbols[node.name] = Symbol {
				name  = node.name,
				kind  = .Variable,
				scope = cur_scope,
			}
		}

	case Ast_Function:
		symbol := new(Symbol)
		symbol.name = node.name
		symbol.kind = .Function
		symbol.type = ident_to_type(node.ret_type_ident)
		symbol.scope = cur_scope

		scope := Symbol_Scope {
			kind     = .Function,
			function = symbol,
			parent   = cur_scope,
		}

		scope.symbols[node.name] = symbol^

		for &param in node.params {
			scope.symbols[param.name] = Symbol {
				name = param.name,
				kind = .Variable,
			}
		}

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.body)
		ss_pop(&c.scopes)

	case Ast_If:
		scope := Symbol_Scope {
			kind   = .Block,
			parent = cur_scope,
		}

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.then_block)
		if node.else_block != nil {
			get_block_symbols(c, node.else_block)
		}
		ss_pop(&c.scopes)

	case Ast_For:
		scope := Symbol_Scope {
			kind   = .Loop,
			parent = cur_scope,
		}

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.body)
		ss_pop(&c.scopes)
	}
}

get_block_symbols :: proc(c: ^Checker, s: ^Ast_Block) {
	for node in s.statements {
		bind_scopes(c, node)
	}
}
