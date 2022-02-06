.data
    ARRAY:0x05,0x01,0x08,0x02,0x0f,0x07,0x04,0x09
    TMP_CR:0x00
    TMP_REG0:0x00
    TMP_REG1:0x00
    TMP_REG2:0x00
    TMP_REG3:0x00
.code
            XOR R2,R2
OUTER_LOOP: LOAD R2, TMP_REG2
            ADDI R2, R2, 1
            STORE R2, TMP_REG2
            XOR R3,R3
            STORE R3,TMP_REG3
INNER_LOOP: LOAD R3, TMP_REG3
            SET_ADR_MODE
            LOAD R0, ARRAY
            ADDI R3,R3,1
            LOAD R1, ARRAY
            RST_ADR_MODE
            CALL SORT_N_STORE
            CALL DELAY_4X
            STORE R3,TMP_REG3
            SUBI  R3,R3,8
            JMPOVF INNER_LOOP
            LOAD R2, TMP_REG2
            SUBI R2,R2,8
            JMPOVF OUTER_LOOP
            HALT

SORT_N_STORE:       STORE R1,TMP_REG1
                    SUB R1,R0
                    LOAD R1,TMP_REG1
                    JMPOVF NO_SWAP
                    STORE R0,2
                    LOAD R0,1
                    LOAD R1,2
NO_SWAP:            SET_ADR_MODE
                    STORE R1, ARRAY
                    SUBI R3,R3,1
                    STORE R0, ARRAY
                    ADDI R3,R3,1
                    RST_ADR_MODE
                    RET


DELAY:      STORE   R1,TMP_REG0
            STORE   R2,TMP_REG1
            XOR     R1,R1
            ADDI    R1,R1,0x03
OUTER:      XOR     R2,R2
            ADDI    R2,R2,0x03
INNER:      SUBI    R2,R2,1
            JMPNZ   INNER
            SUBI    R1,R1,1
            JMPNZ   OUTER
            LOAD    R1,TMP_REG0
            LOAD    R2,TMP_REG1
            RET


DELAY_4X:   CALL DELAY
            CALL DELAY
            RET
