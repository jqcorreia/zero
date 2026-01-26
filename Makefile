test:
	odin run . -- test3.z
	gcc -o calc calc.o
	./calc
