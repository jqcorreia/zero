package main

import "core:fmt"
import "core:os"
import "core:strings"

fatal_token :: proc(token: Token, format: string, args: ..any) {
	fatal_span(token.span, format, ..args)
}

fatal_span :: proc(span: Span, format: string, args: ..any) {
	error := error_string(span, format, ..args)
	fmt.println(error)
	os.exit(1)
}

error_token :: proc(token: Token, format: string, args: ..any) {
	error_span(token.span, format, ..args)
}

error_span :: proc(span: Span, format: string, args: ..any) {
	append(
		&compiler.errors,
		Compiler_Error{span = span, message = error_string(span, format, ..args)},
	)
}

error_string :: proc(span: Span, format: string, args: ..any) -> string {
	row, col := span_to_location(span)
	loc := fmt.tprintf("%s:%d:%d", "filename", row, col)
	msg := fmt.tprintf(format, ..args)
	error := fmt.tprintf("%s: %s", loc, msg)

	return error
}

token_serialize :: proc(token: Token) -> string {
	sb := strings.builder_make()
	line, col := span_to_location(token.span)
	lexeme := token.lexeme
	if lexeme == "\n" {
		lexeme = "\\n"
	}
	fmt.sbprintf(&sb, "%s \"%s\", line: %d, col: %d", token.kind, lexeme, line, col)

	return strings.to_string(sb)
}

tokens_print :: proc(tokens: []Token) {
	for token in tokens {
		fmt.println(token_serialize(token))
	}
}

expr_print_sb :: proc(expr: ^Expr, lvl: u32 = 0) -> string {
	sb := strings.builder_make()
	if expr == nil {
		return fmt.sbprint(&sb, "")
	}
	for _ in 0 ..< lvl {
		fmt.sbprint(&sb, " ")
	}
	#partial switch e in expr {
	case Expr_Int_Literal:
		fmt.sbprint(&sb, "Int ", expr.(Expr_Int_Literal).value)
	case Expr_Variable:
		fmt.sbprint(&sb, "Identifier ", expr.(Expr_Variable).value)
	case Expr_Binary:
		fmt.sbprintln(&sb, "Binary ", e.op)
		fmt.sbprintln(&sb, expr_print_sb(e.left, lvl + 1))
		fmt.sbprintln(&sb, expr_print_sb(e.right, lvl + 1))
	}

	return strings.to_string(sb)
}

statement_print :: proc(s: ^Ast_Node, lvl: u32 = 0) {
	if s == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch node in s.node {
	case Ast_Assignment:
		fmt.println("Assignment ", node.name, s.scope)
		expr_print(node.expr, s.scope, lvl + 1)
	case Ast_Return:
		fmt.println("Return ")
		expr_print(node.expr, s.scope, lvl + 1)
	case Ast_Break:
		fmt.println("Break")
	case Ast_Expr:
		expr_print(node.expr, s.scope, lvl + 1)
	case Ast_Function:
		fmt.print("Function", node.name, " ")
		for p in node.params {
			fmt.printf("%s: %s ", p.name, p.type_expr)
		}
		fmt.println(s.scope)
		for st in node.body.statements {
			statement_print(st, lvl + 1)
		}
	case:
		fmt.println(node)
	}
}

expr_print :: proc(expr: ^Expr, scope: ^Scope, lvl: u32 = 0) {
	if expr == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch e in expr {
	case Expr_Int_Literal:
		fmt.println("Int ", e.value)
	case Expr_Variable:
		fmt.println("Identifier ", e.value)
	case Expr_Binary:
		fmt.println("Binary ", e.op)
		expr_print(e.left, scope, lvl + 1)
		expr_print(e.right, scope, lvl + 1)
	case Expr_Call:
		fmt.println("Call ", e.callee.(Expr_Variable).value)
		for arg in e.args {
			expr_print(arg, scope, lvl + 1)
		}
	case:
		fmt.println(e)
	}
}

scope_print :: proc(current_scope: ^Scope) {
	for scope := current_scope; scope.parent != nil; scope = scope.parent {
		fmt.println("Scope", scope)
	}
}


unexpected_token :: proc(token: Token) {
	unimplemented(fmt.tprintf("Unexpected token: %s", token.lexeme))
}

one_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos}

}

two_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos + 1}

}

span_to_location :: proc(span: Span) -> (line: int, col: int) {
	if len(compiler.line_starts) == 1 {
		return 1, span.start
	}
	idx := 0
	start := span.start
	left := compiler.line_starts[idx]
	for idx < len(compiler.line_starts) - 1 {
		left = compiler.line_starts[idx]
		right := compiler.line_starts[idx + 1]

		switch {
		case left <= start && right <= start:
			idx += 1
		case left <= start && right >= start:
			return idx + 1, start - left + 1
		}
	}
	return compiler.line_starts[len(compiler.line_starts) - 1] + 1, start - left + 1
}
