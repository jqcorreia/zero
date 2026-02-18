package main

import "core:fmt"

Ast_Node :: struct {
	data:  Ast_Data,
	span:  Span,
	scope: ^Scope,
}

Ast_Data :: union {
	Ast_Expr,
	Ast_Var_Assign,
	Ast_Function,
	Ast_Return,
	Ast_Block,
	Ast_If,
	Ast_For,
	Ast_Break,
	Ast_Continue,
	Ast_Var_Decl,
	Ast_Struct_Decl,
}

Ast_Expr :: struct {
	expr: ^Expr,
}

Ast_Var_Assign :: struct {
	name:   string,
	expr:   ^Expr,
	symbol: ^Symbol,
	create: bool,
}

Ast_Var_Decl :: struct {
	name:      string, // var name
	expr:      ^Expr, // nil if default value, whatever that is
	symbol:    ^Symbol, // symbol to be bound
	type_expr: string, // Type expression to be resolved
}


Param :: struct {
	name:            string,
	type_expr:       string,
	symbol:          ^Symbol,
	variadic_marker: bool,
}

Ast_Function :: struct {
	name:          string,
	params:        []Param,
	body:          ^Ast_Block,
	ret_type_expr: string,
	symbol:        ^Symbol,
	external:      bool,
}


Ast_Struct_Decl :: struct {
	name:   string,
	fields: []Struct_Field,
}

Struct_Field :: struct {}

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


Expr :: struct {
	data: Expr_Data,
	type: ^Type,
}

Expr_Data :: union {
	Expr_Int_Literal,
	Expr_String_Literal,
	Expr_Binary,
	Expr_Variable,
	Expr_Call,
}

Expr_String_Literal :: struct {
	value: string,
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


// Generic AST traverse function
traverse_ast :: proc(
	ast: ^Ast_Node,
	func: proc(node: ^Ast_Node, userdata: rawptr = nil),
	userdata: rawptr = nil,
) {
	#partial switch &node in ast.data {
	case Ast_Expr:
		func(ast, userdata)
	case Ast_Var_Assign:
		func(ast, userdata)
	case Ast_Var_Decl:
		func(ast, userdata)
	case Ast_Function:
		func(ast, userdata)
		if !node.external {
			for child in node.body.statements {
				traverse_ast(child, func, userdata)
			}
		}
	case Ast_Return:
		func(ast, userdata)
	case Ast_If:
		func(ast, userdata)
		for child in node.then_block.statements {
			traverse_ast(child, func, userdata)
		}
		if node.else_block != nil {
			for child in node.else_block.statements {
				traverse_ast(child, func, userdata)
			}
		}
	case Ast_For:
		func(ast, userdata)
		for child in node.body.statements {
			traverse_ast(child, func, userdata)
		}
	case Ast_Break:
		func(ast, userdata)
	case:
		unimplemented(fmt.tprint("Unimplement traverse statement", ast))
	}
}
