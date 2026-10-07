.data
    arr:0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    total:0x00
    __fill_i:0x00
    __sum_i:0x00
    __sum_acc:0x00
    __tmp0:0x00
    __tmp1:0x00
    __tmp2:0x00
    __tmp3:0x00
.code
    CALLNC __main
    HALT
__fill: NOP
    XOR R0,R0
    STORE R0,__fill_i
__for_0: NOP
    LOAD R0,__fill_i
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,8
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R1,R0
    JMPOVF __cmp_skip_2
    JMPNC __for_end_1
__cmp_skip_2: NOP
    LOAD R0,__fill_i
    STORE R0,__tmp0
    LOAD R0,__fill_i
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    LOAD R0,__fill_i
    STORE R0,__tmp0
    ADDI R0,R0,1
    STORE R0,__fill_i
    LOAD R0,__tmp0
    JMPNC __for_0
__for_end_1: NOP
    RET
__sum: NOP
    XOR R0,R0
    STORE R0,__sum_acc
    XOR R0,R0
    STORE R0,__sum_i
__for_3: NOP
    LOAD R0,__sum_i
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,8
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R1,R0
    JMPOVF __cmp_skip_5
    JMPNC __for_end_4
__cmp_skip_5: NOP
    LOAD R0,__sum_acc
    STORE R0,__tmp0
    LOAD R0,__sum_i
    ADDI R3,R0,0
    SET_ADR_MODE
    LOAD R0,arr
    RST_ADR_MODE
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    STORE R0,__sum_acc
    LOAD R0,__sum_i
    STORE R0,__tmp0
    ADDI R0,R0,1
    STORE R0,__sum_i
    LOAD R0,__tmp0
    JMPNC __for_3
__for_end_4: NOP
    LOAD R0,__sum_acc
    RET
__main: NOP
    CALLNC __fill
    CALLNC __sum
    STORE R0,total
    RET