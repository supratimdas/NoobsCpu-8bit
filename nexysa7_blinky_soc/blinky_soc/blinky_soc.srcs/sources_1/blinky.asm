##blinks an led with changing blinking frequency
##prints hello world in uart in loop
.data
    STR:72,101,108,108,111,32,119,111,114,108,100,10,13,0
    TMP_REG0:0
    TMP_REG1:0
    TMP_REG3:48
    CLEAR_COUNT:30
    DELAY1:0xff
    DELAY2:0xff
.code
            LOAD    R0,4                ##load control reg to R0
            ANDI    R0,R0,0x07          ##mask upper bits (top 2 msb of stack pointer)
            STORE   R0,4                ##store back control reg
            XOR     R0,R0
FOREVER:    STORE   R0,100              ##led IO address is at 100
            XORI    R0,R0,0xff          ##invert R0 value
            CALL    PRINT_HELLO_WORLD
            LOAD    R3,CLEAR_COUNT
            SUBI    R3,R3,1
            STORE   R3,CLEAR_COUNT      ##LOAD the CLEAR_COUNT variable subtract 1 and store it back
            CLR_BC                      ##some weird bug, without this the delay isn't taking effect
            SUBI    R3, R3, 0           ##Check if Clear count is 0 or not
            CALLZ   CLEAR_SCREEN
            CLR_BC                      ##some weird bug, without this the delay isn't taking effect
            CALL    DELAY_XX
            CALL    DELAY_XX
            JMPNC   FOREVER


CLEAR_SCREEN:   ADDI R3,R3, 30
                STORE R3, CLEAR_COUNT ##Restore the original value of 30 to the CLEAR_COUNT variable
                CLR_BC
                CALL    DELAY_XX
                CALL    DELAY_XX
                XOR R3,R3
                ADDI R3, R3,1
                STORE R3, 102         ##write 1 to vga ctrl register to clear screen
                CLR_BC
                CALL    DELAY_XX      ##provide time to clear screen
                CALL    DELAY_XX
                XOR R3,R3
                STORE R3, 102         ##write 0 to vga ctrl register to put it back to auto incr mode
                RET



##PRINT_HELLO_WORLD subroutine
PRINT_HELLO_WORLD:  LOAD    R3, TMP_REG3
                    STORE   R3, 101     ##write the increasing count from 0 - 9
                    ADDI    R3, R3, 1
                    STORE   R3, TMP_REG3
                    SUBI    R3, R3, 58
                    JMPNZ   PRE_PRINT_LOOP
                    ADDI    R3,R3, 48      ##restore ascii 0
                    STORE   R3, TMP_REG3
   PRE_PRINT_LOOP:  XOR     R3,R3
       PRINT_LOOP:  SET_ADR_MODE 
                    LOAD    R1,STR
                    RST_ADR_MODE
       WAIT_BUSY:   LOAD    R2,101      ##address of UART is 101
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

DELAY_XX:   CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            CALL DELAY
            RET
