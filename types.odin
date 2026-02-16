#+feature dynamic-literals

package main

Type :: struct {
	kind: Type_Kind,
}

Type_Kind :: enum {
	Undefined,
	Error,
	Void,
	Bool,
	Uint8,
	Int8,
	Int16,
	Int32,
	Uint32,
}
