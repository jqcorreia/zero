package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

Ast_Module :: []^Ast_Node


current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

peek :: proc(p: ^Parser, n: int = 1) -> Token {
	return p.tokens[p.pos + n]
}

advance :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

expect :: proc(p: ^Parser, kind: Token_Kind) -> Token {
	if current(p).kind != kind {
		fatal_token(current(p), "Expected %v, got %v", kind, current(p).kind)
	}
	return advance(p)
}

parse_program :: proc(p: ^Parser) -> []^Ast_Node {
	stmts: [dynamic]^Ast_Node
	for {
		t := current(p)
		if t.kind == .EOF do break

		// Deal with rogue newlines, like at the beginning of a line
		if t.kind == .NewLine {
			advance(p)
			continue
		}

		stmt := parse_statement(p)
		append(&stmts, stmt)
	}

	return stmts[:]
}

parse_statement :: proc(p: ^Parser) -> ^Ast_Node {
	t := current(p)
	span := Span {
		start = t.span.start,
	}
	ast_node := new(Ast_Node)
	data := &ast_node.data

	switch {
	case t.kind == .External_Keyword:
		advance(p)

		lib_name := expect(p, .QuotedString)
		data^ = parse_external_block(p, lib_name.value.(string))^

	case t.kind == .Identifier:
		data^ = parse_identifier(p)
	case t.kind == .Func_Keyword:
		advance(p)
		data^ = parse_function_decl(p, external = false)^
	case t.kind == .Struct_Keyword:
		advance(p)
		data^ = parse_struct_decl(p)^
	case t.kind == .For_Keyword:
		advance(p)
		data^ = parse_for_loop(p)^
	case t.kind == .Break_Keyword:
		advance(p)
		data^ = parse_break(p)^
	case t.kind == .Continue_Keyword:
		advance(p)
		data^ = parse_continue(p)^
	case t.kind == .Return_Keyword:
		advance(p)
		expr := parse_expression(p, 0)
		expect(p, .NewLine)

		data^ = Ast_Return {
			expr = expr,
		}
	case t.kind == .If_Keyword:
		advance(p)
		data^ = parse_if(p)^
	case:
		unimplemented(fmt.tprintf("Unexpected token: %s", token_serialize(t)))
	}
	span.end = current(p).span.end
	ast_node.span = span
	return ast_node
}

parse_identifier :: proc(p: ^Parser) -> Ast_Data {
	switch {
	case peek(p).kind == .Equal:
		// --- Assignment ---
		// Get variable name
		name_tok := current(p)

		// Advance and expect an '='
		advance(p)
		expect(p, .Equal)

		data := Ast_Var_Assign {
			name = name_tok.lexeme,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine) // This should end with newline

		return data

	case peek(p).kind == .LParen:
		// --- Function Call ---
		expr := parse_expression(p)
		expect(p, .NewLine)
		return Ast_Expr{expr = expr}

	case peek(p).kind == .ColonEqual:
		// --- Assignment and initialization---
		// Get variable name
		name_tok := current(p)

		// Advance and expect an '='
		advance(p)
		expect(p, .ColonEqual)

		data := Ast_Var_Decl {
			name = name_tok.lexeme,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine) // This should end with newline
		return data

	case peek(p).kind == .Colon:
		// Get variable name
		name_tok := current(p)

		advance(p)
		expect(p, .Colon)

		type_expr := expect(p, .Identifier).lexeme
		default_value_expr: ^Expr
		if current(p).kind == .Equal {
			advance(p)
			default_value_expr = parse_expression(p, 0)

		}

		// fmt.println(type_expr, default_value_expr)
		return Ast_Var_Decl {
			name = name_tok.lexeme,
			type_expr = type_expr,
			expr = default_value_expr,
		}
	case:
		next_token := peek(p)
		fatal_token(next_token, "Unexpected token %s", next_token.kind)
	}
	panic("Should be unreachable")
}

parse_struct_decl :: proc(p: ^Parser) -> ^Ast_Struct_Decl {
	decl := new(Ast_Struct_Decl)

	return decl
}

expr_int_literal :: proc(value: i64) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Int_Literal {
		value = value,
	}
	return ret
}

expr_string_literal :: proc(value: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_String_Literal {
		value = value,
	}
	return ret
}

expr_unary :: proc(op: Token_Kind, e: ^Expr) -> ^Expr {
	expr := new(Expr)
	expr.data = Expr_Unary {
		op   = op,
		expr = e,
	}
	return expr
}

expr_binary :: proc(op: Token_Kind, left: ^Expr, right: ^Expr) -> ^Expr {
	expr := new(Expr)
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}

expr_ident :: proc(value: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Variable {
		value = value,
	}

	return ret
}

expr_call :: proc(callee: ^Expr, args: []^Expr) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Call {
		callee = callee,
		args   = args,
	}
	return ret
}

precedence :: proc(op: Token_Kind) -> int {
	#partial switch op {
	case .LParen:
		return 200
	case .Star, .Slash:
		return 20
	case .Plus, .Minus:
		return 10
	case .Lesser, .Greater, .GreaterOrEqual, .LesserOrEqual, .DoubleEqual, .NotEqual:
		return 5
	}
	return -1
}
prefix_precedence :: proc(op: Token_Kind) -> int {
	#partial switch op {
	case .Minus:
		return 50
	case .Bang:
		return 50
	}
	return -1
}

parse_expression :: proc(p: ^Parser, min_lbp: int = 0) -> ^Expr {
	t := advance(p)

	left: ^Expr

	#partial switch t.kind {
	case .Number:
		left = expr_int_literal(i64(t.value.(int)))
	case .QuotedString:
		left = expr_string_literal(t.value.(string))
	case .Identifier:
		left = expr_ident(t.value.(string))
	case .LParen:
		left = parse_expression(p, 0)
		expect(p, .RParen)
	case .Minus, .Bang:
		rbp := prefix_precedence(t.kind)
		right := parse_expression(p, rbp)
		left = expr_unary(t.kind, right)
	case:
		panic("Invalid expression")
	}

	for {
		op := current(p)
		lbp := precedence(op.kind)

		if lbp < min_lbp do break
		advance(p)

		#partial switch op.kind {
		case .LParen:
			args := parse_call_args(p)
			left = expr_call(left, args)
		case:
			rbp := lbp + 1

			right := parse_expression(p, rbp)
			left = expr_binary(op.kind, left, right)
		}
	}
	return left
}

parse_call_args :: proc(p: ^Parser) -> []^Expr {
	args: [dynamic]^Expr

	// '(' already consumed
	if current(p).kind == .RParen {
		advance(p)
		return args[:]
	}

	for {
		arg := parse_expression(p, 0)
		append(&args, arg)

		if current(p).kind == .Comma {
			advance(p)
			continue
		}

		break
	}

	expect(p, .RParen)

	return args[:]
}

parse_function_decl :: proc(p: ^Parser, external: bool = false) -> ^Ast_Function {
	func_name := expect(p, .Identifier).value.(string)
	params := parse_function_decl_params(p)
	ret_type := parse_function_ret_type(p)

	body: ^Ast_Block
	if !external {
		body = parse_block(p)
	}

	func := new(Ast_Function)

	func.name = func_name
	func.params = params
	func.body = body
	func.ret_type_expr = ret_type
	func.external = external

	return func
}

parse_function_decl_params :: proc(p: ^Parser) -> []Param {
	params: [dynamic]Param
	done := false
	expect(p, .LParen)
	for !done {
		#partial switch current(p).kind {
		case .Identifier:
			param_name := current(p).lexeme
			advance(p)
			expect(p, .Colon)
			type_ident := expect(p, .Identifier)
			append(&params, Param{name = param_name, type_expr = type_ident.lexeme})

		case .Ellipsis:
			append(&params, Param{variadic_marker = true})
			advance(p)
		case .Comma:
			if peek(p).kind == .RParen {
				unexpected_token(peek(p))
			}
			advance(p)
		case .RParen:
			advance(p)
			done = true
		case:
			unexpected_token(current(p))
		}
	}

	return params[:]
}

parse_function_ret_type :: proc(p: ^Parser) -> string {
	if current(p).kind == .RightArrow {
		advance(p)
		type_token := expect(p, .Identifier)

		return type_token.lexeme
	}

	return ""
}

parse_block :: proc(p: ^Parser) -> ^Ast_Block {
	res: [dynamic]^Ast_Node

	expect(p, .LBrace)


	for current(p).kind != .RBrace {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		stmt := parse_statement(p)
		append(&res, stmt)
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	sb := new(Ast_Block)
	sb.statements = res[:]

	return sb
}

parse_external_block :: proc(p: ^Parser, lib_name: string) -> ^Ast_Block {
	append(&compiler.external_linker_libs, lib_name)

	res: [dynamic]^Ast_Node

	expect(p, .LBrace)

	for current(p).kind != .RBrace {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		expect(p, .Func_Keyword)
		data := parse_function_decl(p, external = true)
		stmt := new(Ast_Node)
		stmt.data = data^
		append(&res, stmt)
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	sb := new(Ast_Block)
	sb.statements = res[:]
	sb.is_external_functions = true

	return sb
}

parse_if :: proc(p: ^Parser) -> ^Ast_If {
	cond := parse_expression(p)
	then_block := parse_block(p)
	else_block: ^Ast_Block = nil

	if current(p).kind == .Else_Keyword {
		advance(p)
		else_block = parse_block(p)
	}

	stmt_if := new(Ast_If)
	stmt_if.cond = cond
	stmt_if.then_block = then_block
	stmt_if.else_block = else_block

	return stmt_if
}

parse_for_loop :: proc(p: ^Parser) -> ^Ast_For {
	// No condition parsing for now

	stmt := new(Ast_For)
	stmt.body = parse_block(p)

	return stmt
}

parse_break :: proc(p: ^Parser) -> ^Ast_Break {
	stmt := new(Ast_Break)

	expect(p, .NewLine)
	return stmt
}

parse_continue :: proc(p: ^Parser) -> ^Ast_Continue {
	stmt := new(Ast_Continue)

	expect(p, .NewLine)
	return stmt
}
