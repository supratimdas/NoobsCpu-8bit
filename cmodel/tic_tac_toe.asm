.data
      ROW0:0x01,0x00,0x80
      ROW1:0x01,0x00,0x80
      ROW2:0x01,0x00,0x80
      ROW3:0x01,0x00,0x80
      ROW4:0x01,0x00,0x80
      ROW5:0xff,0xff,0xff
      ROW6:0x01,0x00,0x80
      ROW7:0x01,0x00,0x80
      ROW8:0x01,0x00,0x80
      ROW9:0x01,0x00,0x80
     ROW10:0x01,0x00,0x80
     ROW11:0xff,0xff,0xff
     ROW12:0x01,0x00,0x80
     ROW13:0x01,0x00,0x80
     ROW14:0x01,0x00,0x80
     ROW15:0x01,0x00,0x80
     TEMP1:0x00
     TEMP2:0x00
     TIC_TAC_TOW_ROW0:0x00
     TIC_TAC_TOW_ROW1:0x00
     TIC_TAC_TOW_ROW2:0x00
.code

LOOP:           NOP 
DRW_0_0:        XOR R0, R0
                XOR R2, R2
                ADDI R0, R0, 0
                ADDI R2, R2, 0
                STORE R2, TEMP2
                LOAD R1, TIC_TAC_TOW_ROW0
                ANDI R1,R1,0x40
                CALLNZ DRAW_X
                LOAD R1, TIC_TAC_TOW_ROW0
                ANDI R1,R1,0x80
                CALLNZ DRAW_O
DRW_0_1:        XOR R0, R0
                XOR R2, R2
                ADDI R0, R0, 0
                ADDI R2, R2, 1
                STORE R2, TEMP2
                LOAD R1, TIC_TAC_TOW_ROW0
                ANDI R1,R1,0x10
                CALLNZ DRAW_X
                LOAD R1, TIC_TAC_TOW_ROW0
                ANDI R1,R1,0x20
                CALLNZ DRAW_O
                JMP   	LOOP
                HALT

DRAW_X: CALL MUL6x
        CALL MUL3x
        XOR R3, R3
        LOAD R2, TEMP2
        SET_ADR_MODE
        ADDI R3,R0, 0
        ADD  R3,R2
        LOAD R2, ROW0
        ORI R2, R2, 0x28
        STORE R2, ROW0
        ADDI R3, R3, 3
        XOR R2, R2
        LOAD R2, ROW0
        ORI R2, R2, 0x10
        STORE R2, ROW0
        ADDI R3, R3, 3
        XOR R2, R2
        LOAD R2, ROW0
        ORI R2, R2, 0x28
        STORE R2, ROW0
        RST_ADR_MODE
        RET


DRAW_O: CALL MUL6x
        CALL MUL3x
        XOR R3, R3
        LOAD R2, TEMP2
        SET_ADR_MODE
        ADDI R3,R0, 0
        ADD  R3,R2
        LOAD R2, ROW0
        ORI R2, R2, 0x38
        STORE R2, ROW0
        ADDI R3, R3, 3
        XOR R2, R2
        LOAD R2, ROW0
        ORI R2, R2, 0x28
        STORE R2, ROW0
        ADDI R3, R3, 3
        XOR R2, R2
        LOAD R2, ROW0
        ORI R2, R2, 0x38
        STORE R2, ROW0
        RST_ADR_MODE
        RET

MUL6x:      RST_ADR_MODE
            XOR R1, R1
            ADDI R1, R1, 6
            STORE  R2, TEMP1
            ADDI   R2,R0,0
            XOR    R0,R0
MUL_LOOP1:  ADD    R0,R2
            SUBI   R1,R1,1
            JMPNZ  MUL_LOOP1
            LOAD   R2, TEMP1
            SET_ADR_MODE
            RET

MUL3x:      RST_ADR_MODE
            XOR R1, R1
            ADDI R1, R1, 3
            STORE  R2, TEMP1
            ADDI   R2,R0,0
            XOR    R0,R0
MUL_LOOP2:  ADD    R0,R2
            SUBI   R1,R1,1
            JMPNZ  MUL_LOOP2
            LOAD   R2, TEMP1
            SET_ADR_MODE
            RET
