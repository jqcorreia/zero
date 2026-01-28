test:
	odin run . -- test4.z
	gcc -o calc calc.o
	./calc
