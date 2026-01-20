package main

import "core:fmt"

Token_Kind :: enum {
	Invalid,
	EOF,
	Number,
	Plus, // +
	Minus, // -
	Star, // *
	Slash, // /
	LParen, // (
	RParen, // )
}

Token :: struct {
	kind:   Token_Kind,
	lexeme: string,
	value:  int, // only valid if kind == Number
}

Lexer :: struct {
	input: string,
	pos:   int,
}

is_digit :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_whitespace :: proc(c: byte) -> bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

lex :: proc(input: string) -> []Token {
	lexer := Lexer {
		input = input,
		pos   = 0,
	}

	tokens: [dynamic]Token

	for {
		if lexer.pos >= len(lexer.input) {
			append(&tokens, Token{kind = .EOF})
			break
		}

		c := lexer.input[lexer.pos]

		// Skip whitespace
		if is_whitespace(c) {
			lexer.pos += 1
			continue
		}

		// Numbers
		if is_digit(c) {
			start := lexer.pos
			value := 0

			for lexer.pos < len(lexer.input) && is_digit(lexer.input[lexer.pos]) {
				value = value * 10 + int(lexer.input[lexer.pos] - '0')
				lexer.pos += 1
			}

			append(
				&tokens,
				Token{kind = .Number, lexeme = lexer.input[start:lexer.pos], value = value},
			)
			continue
		}

		// Single-character tokens
		token := Token {
			lexeme = lexer.input[lexer.pos:lexer.pos + 1],
		}

		switch c {
		case '+':
			token.kind = .Plus
		case '-':
			token.kind = .Minus
		case '*':
			token.kind = .Star
		case '/':
			token.kind = .Slash
		case '(':
			token.kind = .LParen
		case ')':
			token.kind = .RParen
		case:
			token.kind = .Invalid
		}

		lexer.pos += 1
		append(&tokens, token)
	}

	return tokens[:]
}

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

parse_expression :: proc(p: ^Parser) -> Expr {
	t := advance(p)

	if t.kind == .Number {
		c := current(p)
		#partial switch c.kind {
		case .Plus:
			return Expr_Binary {
				kind = .Binary,
				left = Expr_Number{value = i64(t.value)},
				op = .Add,
				right = Expr_Number{value = i64(t.value)},
			}
		}
	}
	return {}
}

Expr_Kind :: enum {
	Number,
	Binary,
}

Binary_Op :: enum {
	Add,
	Sub,
	Mul,
	Div,
}

Expr :: struct {
	kind: Expr_Kind,
}

Expr_Number :: struct {
	using base: Expr,
	value:      i64,
}

Expr_Binary :: struct {
	using base: Expr,
	op:         Binary_Op,
	left:       Expr,
	right:      Expr,
}

main :: proc() {
	expr := "12 + 34"
	tokens := lex(expr)

	parser := Parser {
		tokens = tokens,
	}
	pexpr := parse_expression(&parser)
	fmt.println(pexpr)
}
