package main

import "core:container/queue"
import "core:fmt"

Symbol :: struct {
	name:  string,
	kind:  Symbol_Kind,
	type:  ^Type, // your type system
	decl:  ^Ast_Node, // pointer back to the declaration
	scope: ^Scope,
}

Symbol_Kind :: enum {
	Variable,
	Function,
	Type,
	Param,
}

Symbol_Table :: map[string]Symbol


Scope :: struct {
	kind:     ScopeKind,
	symbols:  Symbol_Table,
	function: ^Symbol,
	parent:   ^Scope,
}

ScopeKind :: enum {
	Global,
	Function,
	Block,
	Loop,
}

Symbol_Scopes :: queue.Queue(^Scope)

ss_push :: proc(scopes: ^Symbol_Scopes, scope: ^Scope) {
	queue.push_front(scopes, scope)
}

ss_pop :: proc(scopes: ^Symbol_Scopes) -> ^Scope {
	scope := queue.pop_front(scopes)
	return scope
}

ss_cur :: proc(scopes: ^Symbol_Scopes) -> ^Scope {
	return queue.front(scopes)
}

get_scope_queue_var :: proc(scopes: ^Symbol_Scopes, name: string) -> ^Symbol {
	for i in queue.len(scopes^) - 1 ..= 0 {
		scope := queue.get(scopes, i)
		var, ok := &scope.symbols[name]
		if ok {
			return var
		}
	}

	return nil
}

create_global_scope :: proc() -> ^Scope {

	scope := new(Scope)
	scope.kind = .Global

	u8_t := new(Type)
	u8_t.kind = .Uint8
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

	u32_t := new(Type)
	u32_t.kind = .Uint32
	scope.symbols["u32"] = Symbol {
		type = u32_t,
		kind = .Type,
	}

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
		if get_scope_queue_var(&c.scopes, node.name) == nil {
			cur_scope.symbols[node.name] = Symbol {
				name  = node.name,
				kind  = .Variable,
				scope = cur_scope,
			}
			node.symbol = &cur_scope.symbols[node.name]
		}

	case Ast_Function:
		symbol := new(Symbol)
		symbol.name = node.name
		symbol.kind = .Function
		symbol.type = ident_to_type(node.ret_type_expr)
		symbol.scope = cur_scope

		scope := new(Scope)
		scope.kind = .Function
		scope.parent = cur_scope

		scope.symbols[node.name] = symbol^

		for &param in node.params {
			sym := Symbol {
				name = param.name,
				kind = .Param,
				decl = s,
			}
			scope.symbols[param.name] = sym
			param.symbol = &scope.symbols[param.name]
		}

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.body)
		ss_pop(&c.scopes)

	case Ast_If:
		scope := new(Scope)
		scope.kind = .Block
		scope.parent = cur_scope

		ss_push(&c.scopes, scope)
		get_block_symbols(c, node.then_block)
		if node.else_block != nil {
			get_block_symbols(c, node.else_block)
		}
		ss_pop(&c.scopes)

	case Ast_For:
		scope := new(Scope)
		scope.kind = .Block
		scope.parent = cur_scope

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

error_type := Type {
	kind = .Error,
}

resolve_expr_type :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	switch e in expr {
	case Expr_Int_Literal:
		t := new(Type)
		t.kind = .Int32
	case Expr_Variable:
		sym, ok := resolv_symbol(scope, e.value)
		if ok {
			return sym.type
		} else {
			return &error_type
		}
	case Expr_Binary:
		left := resolve_expr_type(e.left, scope, span)
		right := resolve_expr_type(e.right, scope, span)
		if left.kind == .Error || right.kind == .Error {
			return &error_type
		}
		if left.kind != right.kind {
			error_span(span, "Type mismatch %s %s %s", left.kind, e.op, right.kind)
		}

	case Expr_Call:
		func_name := e.callee.(Expr_Variable).value
		sym, ok := resolv_symbol(scope, func_name)
		if ok {
			return sym.type
		}
	}
	return nil
}
resolve_types :: proc(c: ^Checker, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Assignment:
		node.symbol.type = resolve_expr_type(node.expr, s.scope, s.span)

	case Ast_Function:
		for &param in node.params {
			type_sym, ok := resolv_symbol(s.scope, param.type_expr)
			if ok {
				param.symbol.type = type_sym.type
			}
		}
		resolve_block_types(c, node.body)

	case Ast_If:
		resolve_block_types(c, node.then_block)
		if node.else_block != nil {
			resolve_block_types(c, node.else_block)
		}

	case Ast_For:
		resolve_block_types(c, node.body)
	}
}

resolve_block_types :: proc(c: ^Checker, s: ^Ast_Block) {
	for node in s.statements {
		resolve_types(c, node)
	}
}
