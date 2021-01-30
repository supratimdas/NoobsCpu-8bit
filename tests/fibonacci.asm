.data
    VAR1:0x00
    VAR2:0x07
    VAR3:0x00
.code
        LOAD    R0,VAR1
        ADDI    R1,R0,1
        LOAD    R3,VAR2
        SUBI    R3,R3,1
        JMPZ    FIB_0
        SUBI    R3,R3,1
        JMPZ    FIB_1
LOOP:   CALL    NEXT_FIBONNACCI
        SUBI    R3,R3,1
        JMPNZ   LOOP
       
        STORE   R1,VAR3
        HALT    

FIB_0:  STORE   R0,VAR3
        HALT

FIB_1:  STORE   R1,VAR3
        HALT

NEXT_FIBONNACCI:    ADDI    R2,R1,0
                    ADD     R1,R0
                    ADDI    R0,R2,0
                    RET
