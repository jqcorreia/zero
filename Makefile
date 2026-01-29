test:
	odin run . -- test5.z
	gcc -o calc calc.o
	sh -c 'time ./calc'
