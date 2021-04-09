##blinks an led with changing blinking frequency
.data
    DELAY1:0xff
    DELAY2:0xff
.code
            LOAD    R0,4        ##load control reg to R0
            ANDI    R0,R0,0x07  ##mask upper bits (top 2 msb of stack pointer)
            STORE   R0,4        ##store back control reg
            XOR     R0,R0
            XOR     R3,R3
FOREVER:    STORE   R0,0x0f     ##led IO address is at 0x0f
            STORE   R3,DELAY1   ##store R3 value to DELAY1 variable
            ADDI    R3,R3,1     ##increment R3
            CALL    DELAY
            CALL    DELAY
            XORI    R0,R0,0xff  ##invert R0 value
            JMPNC   FOREVER

DELAY:      LOAD    R1,DELAY1
OUTER:      LOAD    R2,DELAY2
INNER:      SUBI    R2,R2,1
            JMPNZ   INNER
            SUBI    R1,R1,1
            JMPNZ   OUTER
            RET
