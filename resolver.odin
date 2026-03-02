package main

import "core:fmt"

error_type := Type {
	kind = .Error,
}

resolve_types :: proc(node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Block:
		for n in data.statements {
			resolve_types(n)
		}
	case Ast_Var_Assign:
		resolve_expr_type(data.lhs, node.scope, node.span)
		resolve_expr_type(data.expr, node.scope, node.span)
	case Ast_Var_Decl:
		resolved_type: ^Type
		initializer_expr_type: ^Type

		if data.expr != nil {
			initializer_expr_type = resolve_expr_type(data.expr, node.scope, node.span)
		}

		if data.type_expr == "" {
			if initializer_expr_type == nil {
				data.symbol.type = &error_type
				return
			}
			resolved_type = initializer_expr_type
			if initializer_expr_type.kind == .Untyped_Int {
				i64_sym, _ := resolve_symbol(node.scope, "i64")
				resolved_type = i64_sym.type
			}
		} else {
			type_sym, ok := resolve_symbol(node.scope, data.type_expr)
			if ok {
				resolved_type = type_sym.type
			} else {
				data.symbol.type = &error_type
				if data.expr != nil {
					data.expr.type = &error_type
				}
				return
			}
		}

		if data.expr != nil {
			coerced_type := type_coercion(initializer_expr_type, resolved_type, node.scope)
			if coerced_type != nil {
				data.symbol.type = coerced_type
				data.expr.type = coerced_type
			} else {
				// Keep natural types so the checker can report a meaningful mismatch
				data.symbol.type = resolved_type
				data.expr.type = initializer_expr_type
			}
		} else {
			data.symbol.type = resolved_type
		}

	case Ast_Struct_Decl:
		type_sym, ok := resolve_symbol(node.scope, data.name)
		if !ok {
			return
		}
		data.symbol.type = type_sym.type
		for &field, idx in data.fields {
			if field_type_sym, field_ok := resolve_symbol(node.scope, field.type_expr); field_ok {
				type_sym.type.fields[idx].type = field_type_sym.type
			} else {
				type_sym.type.fields[idx].type = &error_type
			}
		}

	case Ast_Function:
		for &param in data.params {
			type_sym, ok := resolve_symbol(node.scope, param.type_expr)
			if ok {
				param.symbol.type = type_sym.type
			} else {
				param.symbol.type = &error_type
			}
		}
		if return_type_sym, ok := resolve_symbol(node.scope, data.ret_type_expr); ok {
			data.symbol.type = return_type_sym.type
		} else {
			data.symbol.type = &error_type
		}

		if !data.external {
			resolve_block_types(data.body)
		}

	case Ast_Expr:
		data.expr.type = resolve_expr_type(data.expr, node.scope, node.span)

	case Ast_If:
		resolve_expr_type(data.cond, node.scope, node.span)
		resolve_block_types(data.then_block)
		if data.else_block != nil {
			resolve_block_types(data.else_block)
		}

	case Ast_For:
		resolve_block_types(data.body)

	case Ast_Return:
		if data.expr != nil {
			expr_type := resolve_expr_type(data.expr, node.scope, node.span)
			sym := get_scope_function(node.scope)
			if sym != nil && sym.type != nil && sym.type.kind != .Error {
				coerced_type := type_coercion(expr_type, sym.type, node.scope)
				if coerced_type != nil {
					data.expr.type = coerced_type
				}
				// On coercion failure, leave data.expr.type as the natural type
				// so the checker can report expected vs got
			}
		}

	case Ast_Break:
	case Ast_Import:
	case:
		unimplemented(fmt.tprintf("Unimplemented resolve for node %v", node))
	}
}

resolve_expr_type :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	switch e in expr.data {
	case Expr_Int_Literal:
		sym, _ := resolve_symbol(scope, "untyped_int")
		expr.type = sym.type
		return sym.type

	case Expr_String_Literal:
		sym, _ := resolve_symbol(scope, "str")
		expr.type = sym.type
		return sym.type

	case Expr_Struct_Literal:
		sym, ok := resolve_symbol(scope, e.type_expr)
		if !ok {
			expr.type = &error_type
			return &error_type
		}
		expr.type = sym.type
		for arg_name, arg in e.args {
			for field in sym.type.fields {
				if field.name == arg_name {
					arg_type := resolve_expr_type(arg, scope, span)
					coerced_type := type_coercion(arg_type, field.type, scope)
					if coerced_type != nil {
						arg.type = coerced_type
					} else {
						arg.type = arg_type
					}
				}
			}
		}
		return sym.type

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok || sym.type == nil {
			expr.type = &error_type
			return &error_type
		}
		expr.type = sym.type
		return sym.type

	case Expr_Member:
		struct_name := e.base.data.(Expr_Variable).value
		struct_sym, ok := resolve_symbol(scope, struct_name)
		if !ok || struct_sym.type.kind != .Struct {
			expr.type = &error_type
			return &error_type
		}
		for &f in struct_sym.type.fields {
			if f.name == e.member {
				e.base.type = struct_sym.type
				expr.type = f.type
				return f.type
			}
		}
		expr.type = &error_type
		return &error_type

	case Expr_Unary:
		operand := resolve_expr_type(e.expr, scope, span)
		expr.type = operand
		return operand

	case Expr_Binary:
		left := resolve_expr_type(e.left, scope, span)
		right := resolve_expr_type(e.right, scope, span)
		coerced_type := type_coercion(left, right, scope)
		if coerced_type == nil {
			expr.type = &error_type
			return &error_type
		}
		e.left.type = coerced_type
		e.right.type = coerced_type
		expr.type = coerced_type
		return coerced_type

	case Expr_Call:
		func_name := e.callee.data.(Expr_Variable).value
		sym, ok := resolve_symbol(scope, func_name)
		if !ok {
			expr.type = &error_type
			return &error_type
		}
		decl := sym.decl.data.(Ast_Function)
		if sym.type == nil {
			type_sym, type_ok := resolve_symbol(scope, decl.ret_type_expr)
			if type_ok {
				e.callee.type = type_sym.type
				sym.type = type_sym.type
			} else {
				e.callee.type = &error_type
				sym.type = &error_type
			}
		} else {
			e.callee.type = sym.type
		}
		variadic_found := false
		for arg, i in e.args {
			if variadic_found {
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			if i >= len(decl.params) {
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			param := &decl.params[i]
			if param.variadic_marker {
				variadic_found = true
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			arg_type := resolve_expr_type(arg, scope, span)
			decl_type := param.symbol.type
			if decl_type == nil {
				param_type_sym, _ := resolve_symbol(scope, param.type_expr)
				if param_type_sym != nil {
					param.symbol.type = param_type_sym.type
					decl_type = param_type_sym.type
				}
			}
			if decl_type != nil {
				coerced_type := type_coercion(arg_type, decl_type, scope)
				if coerced_type != nil {
					arg.type = coerced_type
				} else {
					arg.type = arg_type // keep actual type, checker will report
				}
			} else {
				arg.type = arg_type
			}
		}
		return e.callee.type
	}
	unimplemented("You should not be here at all")
}

resolve_block_types :: proc(block: ^Ast_Block) {
	for node in block.statements {
		resolve_types(node)
	}
}
