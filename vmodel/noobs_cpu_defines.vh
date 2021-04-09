`ifndef __NOOBS_CPU_DEFINES_H__
`define __NOOBS_CPU_DEFINES_H__

//ISA specific defines
`define INST_MEM_SIZE 2048 
`define DATA_MEM_SIZE 2048 

//defines and macros for instruction code handling

`define GET_BASE_OP(INST)           ((INST >> 5) & 8'h07)    //extracts the base operation from 8 bit op_code
`define GET_MC_CTRL_USR_OP(INST)    ((INST >> 3) & 8'h03)    //extracts the base operation from 8 bit op_code
`define IS_IMM(INST)                ((INST >> 4) & 8'h01)    //is the operation immediate?
`define GET_REG_PTR0(INST)          ((INST) & 8'h03)
`define GET_REG_PTR1(INST)          ((INST >> 2) & 8'h03)
`define GET_REG_VALUE(PTR)          (regs[PTR])
`define GET_LD_ST_REG_PTR(INST)     ((INST >> 3) & 8'h03)    //extracts the load_store src/dst reg pointer

`define MC_CTRL_USR     0                           // Machine Control + USR Configurable
`define ADD             1                           // Arithmetic Add
`define SUB             2                           // Arithmetic Multiply
`define AND             3                           // Logical AND
`define OR              4                           // Logical OR
`define XOR             5                           // Logical XOR
`define LD              6                           // Data Load
`define ST              7                           // Data Store

`define CR_SP_INIT_MSB     8'h1c
`define CR_BCNZ            8'h02
`define CR_BCZ             8'h01
`define CR_ADR_MODE        8'h40 

`define CR_BCNZ_BIT_POS  1  
`define CR_BCZ_BIT_POS   0 

//sub type of MC_CTRL_USR base operation
`define MISC    8'h00
`define USR     8'h01
`define JMP     8'h02
`define CALL    8'h03

`define NOP             8'h00
`define RET             8'h01
`define HALT            8'h02
`define SET_BCZ         8'h03
`define SET_BCNZ        8'h04 
`define CLR_BC          8'h05
`define SET_ADR_MODE    8'h06
`define RST_ADR_MODE    8'h07

//basic internal operations supported
`define EXEC_NOP            4'h0
`define ALU_OPERATION_ADD   4'h1
`define ALU_OPERATION_SUB   4'h2
`define ALU_OPERATION_AND   4'h3 
`define ALU_OPERATION_OR    4'h4 
`define ALU_OPERATION_XOR   4'h5
`define MEM_OPERATION_RD    4'h6
`define MEM_OPERATION_WR    4'h7
`define CPU_OPERATION_JMP   4'h8
`define CPU_OPERATION_CALL  4'h9
`define CPU_OPERATION_RET   4'ha

`define SR_OVF              8'h01
`define SR_ST_OVF           8'h02
`define SR_NZ               8'h04
`define SR_Z                8'h08
`define SR_I_TRP            8'h10

`define SR_OVF_BIT_POS     0 
`define SR_ST_OVF_BIT_POS  1 
`define SR_NZ_BIT_POS      2 
`define SR_Z_BIT_POS       3 
`define SR_I_TRP_BIT_POS   4 

`define OP_CODE_NOP 8'd0

`define ASSERT_NEVER(MSG, INST, CLK, RST, EXPR) \
`ifndef SYNTHESIS \
    assert_never #(MSG) INST (CLK, RST, EXPR);  \
`endif \

`define ASSERT_ALWAYS(MSG, INST, CLK, RST, EXPR) \
`ifndef SYNTHESIS \
    assert_always #(MSG) INST (CLK, RST, EXPR);  \
`endif \

`define ASSERT_IMPL(MSG, INST, CLK, RST, ANT_EXPR, CONS_EXPR) \
`ifndef SYNTHESIS \
    assert_impl #(MSG) INST (CLK, RST, ANT_EXPR, CONS_EXPR);  \
`endif \

`define ASSERT_NO_X(MSG, INST, CLK, RST, EXPR) \
`ifndef SYNTHESIS \
    assert_no_x #(MSG) INST (CLK, RST, EXPR);  \
`endif \


`endif
