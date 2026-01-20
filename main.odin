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

advance :: proc(p: ^Parser) -> Token {
	res := p.tokens[p.pos]
	p.pos += 1

	return res
}
current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
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
	left:       ^Expr,
	right:      ^Expr,
}

main :: proc() {
	done := false
	expr := "12 + 34"
	tokens := lex(expr)

	parser := Parser {
		tokens = tokens,
	}
	for !done {
		token := advance(&parser)
		#partial switch token.kind {
		case .EOF:
			done = true
		case:
			fmt.println(token)
		}
	}
}
