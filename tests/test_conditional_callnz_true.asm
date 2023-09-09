.data
    DST:0x00
    DST1:0x00
.code
    XOR R0,R0
    XOR R1,R1
    XOR R2,R2
    ADDI R0,R0,0x55
    ADDI R1,R1,0xaa
    SUBI R2,R1,0x0a
    CALLNZ LABEL1
    STORE R1,DST
    HALT

LABEL1: STORE R0,DST1
        RET 
