CC=gcc

libshared_util.so : libshared_util.c
	${CC} -shared -o libshared_util.so -fPIC libshared_util.c

noobsCpu : NoobsCpu.c NoobsCpu_defines.h NoobsCpu_Util.c NoobsCpu_Util.h libshared_util.so
	${CC} -o noobsCpu NoobsCpu.c NoobsCpu_Util.c -lrt

run: noobsCpu
	cp ../tests/*.txt ./
	./noobsCpu

.PHONY clean:
	rm -Rf *.o *.out *.txt noobsCpu *.so
