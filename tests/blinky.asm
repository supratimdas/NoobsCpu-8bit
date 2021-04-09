.data
    DELAY1:0x55
.code
            XOR     R0,R0
            XOR     R1,R1
            ADDI    R1,R1,0x05
            NOP
            NOP
            NOP
            NOP
            NOP
            LOAD    R1,DELAY1
            NOP
FOREVER:    STORE   R0,0x0f
            XORI    R0,R0,0xff
            SUBI    R1,R1,1
            JMPNZ   FOREVER
            NOP
            HALT
