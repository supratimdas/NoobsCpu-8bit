.data
    DST0:0xff
    DST1:0xff
    DST2:0xff
    DST3:0xff
.code
    XOR R0,R0
    XOR R1,R1
    XOR R2,R2
    XOR R3,R3
    ADDI R0,R0,0x55
    ADDI R1,R1,0xaa
    SUBI R2,R1,0xaa
    CALLZ LABEL1
    STORE R0,DST0
    HALT

LABEL1: STORE R1,DST1
        SUBI R0,R0,0x55
        CALLZ LABEL2
        STORE R3, DST3
        RET 

LABEL2: STORE R2,DST2
        RET
