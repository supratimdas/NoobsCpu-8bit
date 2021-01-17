.data
    DST:0x00
.code
    XOR R0,R0
    XOR R1,R1
    ADDI R0,R0,0x55
    ADDI R1,R1,0xaa
    JMP LABEL1
    STORE R1,DST
    HALT

LABEL1: STORE R0,DST
        HALT 
