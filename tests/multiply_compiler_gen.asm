.data
    result:0x00
    __mul_a:0x00
    __mul_b:0x00
    __mul_acc:0x00
    __tmp0:0x00
    __tmp1:0x00
    __tmp2:0x00
    __tmp3:0x00
.code
    CALLNC __main
    HALT
__mul: STORE R0,__mul_a
    STORE R1,__mul_b
    XOR R0,R0
    STORE R0,__mul_acc
__while_0: NOP
    LOAD R0,__mul_b
    ADDI R0,R0,0
    JMPZ __while_end_1
    LOAD R0,__mul_acc
    STORE R0,__tmp0
    LOAD R0,__mul_a
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    STORE R0,__mul_acc
    LOAD R0,__mul_b
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R0,R1
    STORE R0,__mul_b
    JMPNC __while_0
__while_end_1: NOP
    LOAD R0,__mul_acc
    RET
__main: NOP
    XOR R0,R0
    ADDI R0,R0,7
    ADDI R1,R0,0
    XOR R0,R0
    ADDI R0,R0,6
    CALLNC __mul
    STORE R0,result
    RET