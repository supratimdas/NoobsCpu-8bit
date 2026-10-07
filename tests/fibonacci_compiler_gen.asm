.data
    result:0x00
    __fib_n:0x00
    __fib_a:0x00
    __fib_b:0x00
    __fib_tmp:0x00
    __tmp0:0x00
    __tmp1:0x00
    __tmp2:0x00
    __tmp3:0x00
.code
    CALLNC __main
    HALT
__fib: STORE R0,__fib_n
    XOR R0,R0
    STORE R0,__fib_a
    XOR R0,R0
    ADDI R0,R0,1
    STORE R0,__fib_b
__while_0: NOP
    LOAD R0,__fib_n
    ADDI R0,R0,0
    JMPZ __while_end_1
    LOAD R0,__fib_b
    STORE R0,__fib_tmp
    LOAD R0,__fib_a
    STORE R0,__tmp0
    LOAD R0,__fib_b
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    STORE R0,__fib_b
    LOAD R0,__fib_tmp
    STORE R0,__fib_a
    XOR R0,R0
    ADDI R0,R0,1
    STORE R0,__tmp0
    LOAD R0,__fib_n
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R0,R1
    STORE R0,__fib_n
    JMPNC __while_0
__while_end_1: NOP
    LOAD R0,__fib_a
    RET
__main: NOP
    XOR R0,R0
    ADDI R0,R0,10
    CALLNC __fib
    STORE R0,result
    RET