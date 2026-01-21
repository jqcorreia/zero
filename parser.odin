package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

advance :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

match :: proc(p: ^Parser, kind: Token_Kind) -> bool {
	if current(p).kind == kind {
		p.pos += 1
		return true
	}
	return false
}

parse_expression :: proc(p: ^Parser) -> ^Expr {
	t := advance(p)

	fmt.println(t)
	if t.kind == .Number {
		c := current(p)
		#partial switch c.kind {
		case .Plus:
			advance(p)
			return make_expr_binary(
				left = make_expr_int_lit(i64(t.value)),
				right = parse_expression(p),
				op = .Plus,
			)
		case .EOF:
			return make_expr_int_lit(value = i64(t.value))
		}
	}
	return {}
}

Expr :: struct {
	kind: Expr_Kind,
	data: Expr_Data,
}

Expr_Kind :: enum {
	Int_Lit,
	Binary,
}

Expr_Data :: union {
	Expr_Int_Lit,
	Expr_Binary,
}

Expr_Int_Lit :: struct {
	value: i64,
}

Expr_Binary :: struct {
	op:          Token_Kind,
	left, right: ^Expr,
}

make_expr_int_lit :: proc(value: i64) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Int_Lit
	expr.data = Expr_Int_Lit {
		value = value,
	}
	return expr
}

make_expr_binary :: proc(left, right: ^Expr, op: Token_Kind) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Binary
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}
