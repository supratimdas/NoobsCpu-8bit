.data
    DELAY1:0x0f
    DELAY2:0x3f
.code
            XOR     R0,R0
FOREVER:    STORE   R0,0x0f
DELAY:      LOAD    R1,DELAY1
OUTER:      LOAD    R2,DELAY2
INNER:      SUBI    R2,R2,1
            JMPNZ   INNER
            SUBI    R1,R1,1
            JMPNZ   OUTER
            XORI    R0,R0,0xff
            JMPNC   FOREVER
