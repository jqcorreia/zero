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
	Field,
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

	create_primitive_types(scope)

	return scope
}

bind_scopes :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	node.scope = cur_scope
	#partial switch &data in node.data {
	case Ast_Block:
		for s in data.statements {
			bind_scopes(s, cur_scope)
		}
	case Ast_Var_Decl:
		sym, ok := resolve_symbol(cur_scope, data.name)
		if !ok {
			sym = make_symbol(.Variable)
			cur_scope.symbols[data.name] = sym
			data.symbol = sym
		} else {
			error_span(node.span, "Re-declaration of variable '%s'", data.name)
		}

	case Ast_Struct_Decl:
		sym, ok := resolve_symbol(cur_scope, data.name)
		if !ok {
			type := new(Type)
			type.kind = .Struct
			type.fields = {}

			sym = make_symbol(.Type)
			sym.name = data.name
			sym.type = type
			cur_scope.symbols[data.name] = sym
			data.symbol = sym

			for &field, idx in data.fields {
				// field_sym := make_symbol(.Field)
				// field_sym.decl = node
				// field_sym.name = field.name
				// // cur_scope.symbols[field.name] = field_sym
				// field.symbol = field_sym
				append(&sym.type.fields, Struct_Field{name = field.name, index = idx})
			}
		} else {
			error_span(node.span, "Re-declaration of struct '%s'", data.name)
		}

	case Ast_Function:
		new_scope := make_scope(.Function, parent = cur_scope)

		symbol := new(Symbol)
		symbol.name = data.name
		symbol.kind = .Function
		symbol.decl = node

		cur_scope.symbols[data.name] = symbol

		for &param in data.params {
			sym := make_symbol(.Param)
			sym.decl = node
			sym.name = param.name
			new_scope.symbols[param.name] = sym
			param.symbol = sym
		}

		data.symbol = symbol
		if !data.external {
			get_block_symbols(data.body, new_scope)
		}
	case Ast_If:
		new_scope_then := make_scope(.Block, parent = cur_scope)
		get_block_symbols(data.then_block, new_scope_then)
		if data.else_block != nil {
			new_scope_else := make_scope(.Block, parent = cur_scope)
			get_block_symbols(data.else_block, new_scope_else)
		}

	case Ast_For:
		new_scope := make_scope(.Loop, parent = cur_scope)
		get_block_symbols(data.body, new_scope)
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

resolve_types :: proc(c: ^Checker, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Block:
		for n in data.statements {
			resolve_types(c, n)
		}
	case Ast_Var_Assign:
		// Just tag expr with a type, check it in the checker later
		resolve_expr_type(data.expr, node.scope, node.span)
	case Ast_Var_Decl:
		resolved_type: ^Type
		// If no type was provided, try and resolve type from expression
		if data.type_expr == "" {
			resolved_type = resolve_expr_type(data.expr, node.scope, node.span)
		} else {
			// If type was provided, resolve the type symbol from type expression
			type_sym, ok := resolve_symbol(node.scope, data.type_expr)
			if ok {
				resolved_type = type_sym.type
			} else {
				error_span(node.span, "unresolved type expression '%v'", data.type_expr)
			}
		}

		// Store the result in the symbol
		data.symbol.type = resolved_type
	case Ast_Struct_Decl:
		type_sym, ok := resolve_symbol(node.scope, data.name)
		if !ok {
			error_span(node.span, "Symbol %s not found", data.name)
		}

		data.symbol.type = type_sym.type

		for &field, idx in data.fields {
			field_type_sym, field_ok := resolve_symbol(node.scope, field.type_expr)
			if field_ok {
				fmt.println(field.symbol, field_type_sym)
				type_sym.type.fields[idx].type = field_type_sym.type
			} else {
				error_span(node.span, "unresolved type expression '%v'", field.type_expr)
			}
		}

	case Ast_Function:
		// Resolve function param type expressions
		for &param in data.params {
			type_sym, ok := resolve_symbol(node.scope, param.type_expr)
			if ok {
				param.symbol.type = type_sym.type
			} else {
				error_span(node.span, "unresolved type expression '%v'", param.type_expr)
			}
		}

		// Resolve function return type expression
		return_type_sym, ok := resolve_symbol(node.scope, data.ret_type_expr)
		if ok {
			data.symbol.type = return_type_sym.type
		} else {
			error_span(node.span, "unresolved type expression '%v'", data.ret_type_expr)
		}

		if !data.external {
			resolve_block_types(c, data.body)
		}
	case Ast_Expr:
		type := resolve_expr_type(data.expr, node.scope, node.span)
		data.expr.type = type
	case Ast_If:
		resolve_expr_type(data.cond, node.scope, node.span)
		resolve_block_types(c, data.then_block)
		if data.else_block != nil {
			resolve_block_types(c, data.else_block)
		}
	case Ast_For:
		resolve_block_types(c, data.body)
	case Ast_Return:
		resolve_expr_type(data.expr, node.scope, node.span)
	case Ast_Break:
	// Nothing to do here
	case Ast_Import:
	// Nothing to do here
	case:
		unimplemented(fmt.tprintf("Unimplemented resolve for node %v", node))
	}
}

resolve_expr_type :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	switch e in expr.data {
	case Expr_Int_Literal:
		sym, _ := resolve_symbol(scope, "i32")
		expr.type = sym.type
		return sym.type

	case Expr_String_Literal:
		sym, _ := resolve_symbol(scope, "str")
		expr.type = sym.type
		return sym.type

	case Expr_Struct_Literal:
		sym, _ := resolve_symbol(scope, e.type_expr)
		expr.type = sym.type
		return sym.type

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		type: ^Type
		if ok {
			if sym.type == nil {
				error_span(span, "unresolved type for symbol %v", sym)
			}
			type = sym.type
		} else {
			type = &error_type
		}

		expr.type = sym.type
		return type

	case Expr_Unary:
		operand := resolve_expr_type(e.expr, scope, span)
		expr.type = operand
		return expr.type

	case Expr_Binary:
		left := resolve_expr_type(e.left, scope, span)
		right := resolve_expr_type(e.right, scope, span)

		if left == nil || right == nil {
			scope_print(scope)
			fatal_span(span, "left or right are nil. L = %v, R = %v", left, right)
		}
		if left.kind == .Error || right.kind == .Error {
			expr.type = &error_type
			return &error_type
		}
		if left.kind != right.kind {
			expr.type = &error_type
			error_span(span, "Type mismatch %s %s %s", left.kind, e.op, right.kind)
			return &error_type
		}
		expr.type = left
		return left

	case Expr_Call:
		func_name := e.callee.data.(Expr_Variable).value
		sym, ok := resolve_symbol(scope, func_name)
		if ok {
			if sym.type == nil {
				fmt.println("sym type nil", func_name, sym)
				// type_sym, _ := resolve_symbol(scope, sym.decl.data.(Ast_Function).ret_type_expr)
				// e.callee.type = type_sym.type

			} else {
				e.callee.type = sym.type
			}
			for arg in e.args {
				arg.type = resolve_expr_type(arg, scope, span)
			}
			return sym.type
		} else {
			e.callee.type = &error_type
		}
	}
	return nil
}
resolve_block_types :: proc(c: ^Checker, node: ^Ast_Block) {
	for node in node.statements {
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
