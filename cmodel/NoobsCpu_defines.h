#ifndef __NOOBS_CPU_DEFINES_H__
#define __NOOBS_CPU_DEFINES_H__

//ISA specific defines
#define INST_MEM_SIZE 4096
#define DATA_MEM_SIZE 4096

//defines and macros for instruction code handling

#define GET_BASE_OP(INST)           ((INST >> 5) & 0x07)    //extracts the base operation from 8 bit op_code
#define GET_MC_CTRL_USR_OP(INST)    ((INST >> 3) & 0x03)    //extracts the base operation from 8 bit op_code
#define IS_IMM(INST)                ((INST >> 4) & 0x01)    //is the operation immediate?
#define GET_REG_PTR0(INST)          ((INST) & 0x03)
#define GET_REG_PTR1(INST)          ((INST >> 2) & 0x03)
#define GET_REG_VALUE(PTR)          (regs[PTR])

#define MC_CTRL_USR     0                           // Machine Control + USR Configurable
#define ADD             1                           // Arithmetic Add
#define MUL             2                           // Arithmetic Multiply
#define AND             3                           // Logical AND
#define OR              4                           // Logical OR
#define XOR             5                           // Logical XOR
#define LD              6                           // Data Load
#define ST              7                           // Data Store

//sub type of MC_CTRL_USR base operation
#define MISC    0x00
#define USR     0x01
#define JMP     0x02
#define CALL    0x03

#define NOP     0x00
#define RET     0x01
#define HALT    0x02
#define RST     0x03

//basic internal operations supported
#define EXEC_NOP            0x00
#define ALU_OPERATION_ADD   0x01
#define ALU_OPERATION_MUL   0x02
#define ALU_OPERATION_AND   0x03 
#define ALU_OPERATION_OR    0x04 
#define ALU_OPERATION_XOR   0x05
#define MEM_OPERATION_RD    0x06
#define MEM_OPERATION_WR    0x07
#define CPU_OPERATION_JMP   0x08
#define CPU_OPERATION_CALL  0x09

#endif
