.data
    DELAY1:0x03
    DELAY2:0x02
    NUM_ITER:0x05
.code
            LOAD    R0,4
            ANDI    R0,R0,0x07
            STORE   R0,4
            XOR     R0,R0
            LOAD    R3,NUM_ITER
            HALT
FOREVER:    STORE   R0,0x0f
            CALL    DELAY
            XORI    R0,R0,0xff
            SUBI    R3,R3,1
            JMPNZ   FOREVER
            HALT
DELAY:      LOAD    R1,DELAY1
OUTER:      LOAD    R2,DELAY2
INNER:      SUBI    R2,R2,1
            JMPNZ   INNER
            SUBI    R1,R1,1
            JMPNZ   OUTER
            RET