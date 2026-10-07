.data
    arr:0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    sorted:0x00
    __sort_i:0x00
    __sort_j:0x00
    __sort_tmp:0x00
    __sort_swapped:0x00
    __tmp0:0x00
    __tmp1:0x00
    __tmp2:0x00
    __tmp3:0x00
.code
    CALLNC __main
    HALT
__init: NOP
    XOR R0,R0
    ADDI R0,R0,5
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,1
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,8
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,2
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,2
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,3
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,15
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,4
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,7
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,5
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,4
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,6
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,9
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,7
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    RET
__sort: NOP
    XOR R0,R0
    STORE R0,__sort_i
__while_0: NOP
    LOAD R0,__sort_i
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,8
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R1,R0
    JMPOVF __cmp_skip_2
    JMPNC __while_end_1
__cmp_skip_2: NOP
    XOR R0,R0
    STORE R0,__sort_swapped
    XOR R0,R0
    STORE R0,__sort_j
__while_3: NOP
    LOAD R0,__sort_j
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,7
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R1,R0
    JMPOVF __cmp_skip_5
    JMPNC __while_end_4
__cmp_skip_5: NOP
    LOAD R0,__sort_j
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    ADDI R3,R0,0
    SET_ADR_MODE
    LOAD R0,arr
    RST_ADR_MODE
    STORE R0,__tmp0
    LOAD R0,__sort_j
    ADDI R3,R0,0
    SET_ADR_MODE
    LOAD R0,arr
    RST_ADR_MODE
    ADDI R1,R0,0
    LOAD R0,__tmp0
    SUB R1,R0
    JMPOVF __cmp_skip_7
    JMPNC __if_end_6
__cmp_skip_7: NOP
    LOAD R0,__sort_j
    ADDI R3,R0,0
    SET_ADR_MODE
    LOAD R0,arr
    RST_ADR_MODE
    STORE R0,__sort_tmp
    LOAD R0,__sort_j
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    ADDI R3,R0,0
    SET_ADR_MODE
    LOAD R0,arr
    RST_ADR_MODE
    STORE R0,__tmp0
    LOAD R0,__sort_j
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    LOAD R0,__sort_tmp
    STORE R0,__tmp0
    LOAD R0,__sort_j
    STORE R0,__tmp1
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp1
    ADD R0,R1
    ADDI R3,R0,0
    LOAD R0,__tmp0
    SET_ADR_MODE
    STORE R0,arr
    RST_ADR_MODE
    XOR R0,R0
    ADDI R0,R0,1
    STORE R0,__sort_swapped
__if_end_6: NOP
    LOAD R0,__sort_j
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    STORE R0,__sort_j
    JMPNC __while_3
__while_end_4: NOP
    LOAD R0,__sort_swapped
    ADDI R0,R0,0
    JMPZ __cond_skip_9
    JMPNC __if_end_8
__cond_skip_9: NOP
    JMPNC __while_end_1
__if_end_8: NOP
    LOAD R0,__sort_i
    STORE R0,__tmp0
    XOR R0,R0
    ADDI R0,R0,1
    ADDI R1,R0,0
    LOAD R0,__tmp0
    ADD R0,R1
    STORE R0,__sort_i
    JMPNC __while_0
__while_end_1: NOP
    XOR R0,R0
    ADDI R0,R0,1
    STORE R0,sorted
    RET
__main: NOP
    CALLNC __init
    CALLNC __sort
    RET