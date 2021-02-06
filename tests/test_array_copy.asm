.data
    SRC_ARR:0x01,0x02,0x03,0x04,0x05
    DST_ADR:0x00
.code
        XOR     R0,R0
        XOR     R3,R3
        ADDI    R0,R0,5
        SET_ADR_MODE
LOOP:   LOAD    R1,SRC_ARR
        STORE   R1,DST_ADR
        ADDI    R3,R3,1
        SUBI    R0,R0,1
        JMPNZ   LOOP
        HALT    
