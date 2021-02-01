.data
    MULTIPLIER1:0x05
    MULTIPLIER2:0x07
    MULTIPLICAND:0x00
.code
        LOAD    R0,MULTIPLIER1
        LOAD    R1,MULTIPLIER2
        CALL    MUL
        STORE   R0,MULTIPLICAND
        HALT    

MUL:        ADDI   R2,R0,0
            XOR    R0,R0
MUL_LOOP:   ADD    R0,R2
            SUBI   R1,R1,1
            JMPNZ  MUL_LOOP
            RET
