##blinks an led with changing blinking frequency
##prints hello world in uart in loop
.data
    DELAY1:0xff
    DELAY2:0xff
    STR:72,101,108,108,111,32,119,111,114,108,100,10,13,0
    TMP_REG0:0
    TMP_REG1:0
    TMP_REG3:0
.code
            LOAD    R0,4        ##load control reg to R0
            ANDI    R0,R0,0x07  ##mask upper bits (top 2 msb of stack pointer)
            STORE   R0,4        ##store back control reg
            XOR     R0,R0
FOREVER:    STORE   R0,100     ##led IO address is at 100
            XORI    R0,R0,0xff  ##invert R0 value
            CALL    DELAY_4X
            CALL    DELAY_4X
            CALL    DELAY_4X
            CALL    DELAY_4X
            CALL    PRINT_HELLO_WORLD
            CALL    DELAY_4X
            CALL    DELAY_4X
            CALL    DELAY_4X
            CALL    DELAY_4X
            JMPNC   FOREVER


##PRINT_HELLO_WORLD subroutine
PRINT_HELLO_WORLD:  XOR     R3,R3
       PRINT_LOOP:  SET_ADR_MODE 
                    LOAD    R1,STR
                    RST_ADR_MODE
       WAIT_BUSY:   LOAD    R2,101
                    SUBI    R2,R2,1
                    JMPZ    WAIT_BUSY
                    STORE   R1,101
                    ADDI    R3,R3,1
                    SUBI    R1,R1,0
                    JMPNZ   PRINT_LOOP
                    RET

##DELAY subroutine
DELAY:      STORE   R1,TMP_REG0
            STORE   R2,TMP_REG1
            LOAD    R1,DELAY1
OUTER:      LOAD    R2,DELAY2
INNER:      SUBI    R2,R2,1
            JMPNZ   INNER
            SUBI    R1,R1,1
            JMPNZ   OUTER
            LOAD    R1,TMP_REG0
            LOAD    R2,TMP_REG1
            RET

##DELAY_4X subroutine
DELAY_4X:   CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            RET
