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

bind_scopes :: proc(c: ^Checker, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Expr:
		s.scope = ss_cur(&c.scopes)
	case Ast_Assignment:
		s.scope = ss_cur(&c.scopes)
	case Ast_Function:
		cur_scope := ss_cur(&c.scopes)
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

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.body)
		ss_pop(&c.scopes)
	case Ast_Return:
		s.scope = ss_cur(&c.scopes)
	case Ast_If:
		cur_scope := ss_cur(&c.scopes)
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
		cur_scope := ss_cur(&c.scopes)
		scope := Symbol_Scope {
			kind   = .Loop,
			parent = cur_scope,
		}

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.body)
		ss_pop(&c.scopes)
	case Ast_Break:
		s.scope = ss_cur(&c.scopes)
		check_break(c, &node, s.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

get_block_symbols :: proc(c: ^Checker, s: ^Ast_Block) {

}
