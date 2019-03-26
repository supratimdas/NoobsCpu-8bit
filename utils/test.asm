.data
    VAR1:0x0f
    VAR2:0x01
    VAR3:0x55
.code
       NOP
       LOAD    R0,VAR1
       LOAD    R1,VAR2
       ADDI    R2,R1,1
       ADD     R2,R0
       STORE   R2,VAR3
       CALL    TEST_SUBROUTINE
       HALT

TEST_SUBROUTINE:    NOP
                    NOP
                    NOP
                    NOP
                    RET
