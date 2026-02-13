package main

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

Symbol_Table :: map[string]^Symbol


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

create_global_scope :: proc() -> ^Scope {
	scope := new(Scope)
	scope.kind = .Global

	u8_t := new(Type)
	u8_t.kind = .Uint8
	scope.symbols["u8"] = make_symbol(.Type, u8_t)

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

	i32_t := new(Type)
	i32_t.kind = .Uint32
	scope.symbols["i32"] = make_symbol(.Type, i32_t)

	u32_t := new(Type)
	u32_t.kind = .Uint32
	scope.symbols["u32"] = make_symbol(.Type, u32_t)
	// bool_t := new(Type)
	// bool_t.kind = .Bool
	// scope.symbols["bool"] = Symbol {
	// 	type = bool_t,
	// 	kind = .Type,
	// }

	return scope
}

bind_scopes :: proc(s: ^Ast_Node, cur_scope: ^Scope) {
	s.scope = cur_scope
	#partial switch &node in s.node {
	case Ast_Assignment:
		sym, ok := resolve_symbol(cur_scope, node.name)
		if !ok {
			sym = make_symbol(.Variable)
			cur_scope.symbols[node.name] = sym
		}
		node.symbol = sym

	case Ast_Function:
		new_scope := make_scope(.Function, parent = cur_scope)

		symbol := new(Symbol)
		symbol.name = node.name
		symbol.kind = .Function

		cur_scope.symbols[node.name] = symbol

		for &param in node.params {
			sym := make_symbol(.Param)
			sym.decl = s
			sym.name = param.name
			new_scope.symbols[param.name] = sym
			param.symbol = sym
		}

		node.symbol = symbol
		get_block_symbols(node.body, new_scope)

	case Ast_If:
		new_scope_then := make_scope(.Block, parent = cur_scope)
		get_block_symbols(node.then_block, new_scope_then)
		if node.else_block != nil {
			new_scope_else := make_scope(.Block, parent = cur_scope)
			get_block_symbols(node.else_block, new_scope_else)
		}

	case Ast_For:
		new_scope := make_scope(.Loop, parent = cur_scope)
		get_block_symbols(node.body, new_scope)
	}
}

get_block_symbols :: proc(s: ^Ast_Block, scope: ^Scope) {
	for node in s.statements {
		bind_scopes(node, scope)
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
		return t
	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if ok {
			if sym.type == nil {
				error_span(span, "unresolved type for symbol %v", sym)
			}
			return sym.type
		} else {
			return &error_type
		}
	case Expr_Binary:
		left := resolve_expr_type(e.left, scope, span)
		right := resolve_expr_type(e.right, scope, span)
		if left == nil || right == nil {
			scope_print(scope)
			fatal_span(span, "left or right are nil. L = %v, R = %v", left, right)
		}
		if left.kind == .Error || right.kind == .Error {
			return &error_type
		}
		if left.kind != right.kind {
			error_span(span, "Type mismatch %s %s %s", left.kind, e.op, right.kind)
		}
		return left

	case Expr_Call:
		func_name := e.callee.(Expr_Variable).value
		sym, ok := resolve_symbol(scope, func_name)
		if ok {
			return sym.type
		}
	}
	return nil
}

resolve_types :: proc(c: ^Checker, s: ^Ast_Node) {
	#partial switch &node in s.node {
	case Ast_Assignment:
		t := resolve_expr_type(node.expr, s.scope, s.span)
		node.symbol.type = t
	case Ast_Function:
		// Resolve function param type expressions
		for &param in node.params {
			type_sym, ok := resolve_symbol(s.scope, param.type_expr)
			if ok {
				param.symbol.type = type_sym.type
			} else {
				error_span(s.span, "unresolved type expression '%v'", param.type_expr)
			}
		}

		if node.ret_type_expr != "" {
			// Resolve function return type expression
			return_type_sym, ok := resolve_symbol(s.scope, node.ret_type_expr)
			if ok {
				node.symbol.type = return_type_sym.type
			} else {
				error_span(s.span, "unresolved type expression '%v'", node.ret_type_expr)
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

make_scope :: proc(kind: ScopeKind, parent: ^Scope) -> ^Scope {
	scope := new(Scope)
	scope.kind = kind
	scope.parent = parent

	return scope
}

make_symbol :: proc(kind: Symbol_Kind, type: ^Type = nil) -> ^Symbol {
	sym := new(Symbol)
	sym.kind = kind
	sym.type = type
	return sym
}
resolve_symbol :: proc(current_scope: ^Scope, name: string) -> (^Symbol, bool) {
	scope := current_scope
	for {
		if sym, ok := scope.symbols[name]; ok {
			return sym, true
		}
		if scope.parent == nil {
			break
		}
		scope = scope.parent
	}

	return nil, false
}
