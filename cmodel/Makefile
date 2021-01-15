CC=gcc


noobsCpu : NoobsCpu.c NoobsCpu_defines.h NoobsCpu_Util.c NoobsCpu_Util.h
	${CC} -o noobsCpu NoobsCpu.c NoobsCpu_Util.c

run: noobsCpu
	cp ../tests/*.txt ./
	./noobsCpu

.PHONY clean:
	rm -Rf *.o *.out *.txt noobsCpu
