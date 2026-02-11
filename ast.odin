package main

Ast_Node :: struct {
	node:  union {
		Ast_Expr,
		Ast_Assignment,
		Ast_Function,
		Ast_Return,
		Ast_Block,
		Ast_If,
		Ast_For,
		Ast_Break,
		Ast_Continue,
	},
	span:  Span,
	scope: ^Scope,
}


Ast_Expr :: struct {
	expr: ^Expr,
}

Ast_Assignment :: struct {
	name:   string,
	expr:   ^Expr,
	symbol: ^Symbol,
}

Param :: struct {
	name:      string,
	type_expr: string,
	symbol:    ^Symbol,
}

Ast_Function :: struct {
	name:          string,
	params:        []Param,
	body:          ^Ast_Block,
	ret_type_expr: string,
	symbol:        ^Symbol,
}

Ast_Block :: struct {
	statements: []^Ast_Node,
	terminated: bool,
}

Ast_Return :: struct {
	expr: ^Expr,
}

Ast_If :: struct {
	cond:       ^Expr,
	then_block: ^Ast_Block,
	else_block: ^Ast_Block, // nil if no else
}

Ast_For :: struct {
	body: ^Ast_Block,
}

Ast_Break :: struct {}
Ast_Continue :: struct {}


Expr :: union {
	Expr_Int_Literal,
	Expr_Binary,
	Expr_Variable,
	Expr_Call,
}


Expr_Int_Literal :: struct {
	value: i64,
}

Expr_Binary :: struct {
	op:    Token_Kind,
	left:  ^Expr,
	right: ^Expr,
}

Expr_Variable :: struct {
	value: string,
}

Expr_Call :: struct {
	callee: ^Expr,
	args:   []^Expr,
}
