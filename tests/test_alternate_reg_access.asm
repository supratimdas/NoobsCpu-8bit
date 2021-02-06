.data
    REG0:0x00
    REG1:0x00
    REG2:0x00
    REG3:0x00
    CR:0xaa
    SR:0xaa
    SP:0xaa
.code
        XOR     R0,R0
        XOR     R1,R1
        XOR     R2,R2
        XOR     R3,R3
        ADDI    R0,R0,1
        ADDI    R1,R1,2
        LOAD    R2,0
        LOAD    R3,1
        STORE   R2,REG2
        STORE   R3,REG3
        ADDI    R2,R2,1
        ADDI    R3,R3,2
        STORE   R2,0
        STORE   R3,1
        STORE   R0,REG0
        STORE   R1,REG1
        LOAD    R0,4
        LOAD    R1,5
        LOAD    R2,6
        STORE   R0, CR
        STORE   R1, SR
        STORE   R2, SP
        HALT    
