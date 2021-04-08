.data
    DUMMY: 0
.code
            XOR     R0,R0
FOREVER:    STORE   R0,0x0f
            XORI    R0,R0,0xff
            JMP   FOREVER
