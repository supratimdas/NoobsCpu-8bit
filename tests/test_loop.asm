.data
    ITER:0x0a
    INCR:0x05
    DST:0x00
.code
        LOAD    R0,ITER
        LOAD    R1,INCR

LOOP:   ADD     R2,R1
        SUBI    R0,R0,0x01
        JMPNZ   LOOP
        STORE   R2,DST
        HALT
