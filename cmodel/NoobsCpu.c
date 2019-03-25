/*********************************************************** 
* File Name     : NoobsCpu.c
* Description   : C-model for the NoobsCpu ISA
* Organization  : NONE 
* Creation Date : 15-03-2019
* Last Modified : Sunday 24 March 2019 11:49:51 PM IST
* Author        : Supratim Das (supratimofficio.com)
************************************************************/ 
#include "NoobsCpu_Util.h"
#include "NoobsCpu_defines.h"


uint8_t     instruction;    //instruction
uint16_t    pc;             //program counter 12bit
uint8_t     sr;             //status register
uint8_t     sp;             //status register
/****************************STATUS_REGISTER BIT MAP*******************************
 *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 *|  RSVD   |  RSVD   |  RSVD   |  I/TRP  |    Z    |   NZ    | ST-OVF  |   OVF   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */
uint8_t     cr;     //control register
/****************************CONTROL_REGISTER BIT MAP*******************************
 *|    7    |    6    |    5    |    4    |    3    |    2    |    1    |    0    |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 *|  RSVD   |SP_MSB11 |SP_MSB10 | SP_MSB9 | SP_MSB8 |   BU    |  BCNZ   |   BCZ   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */

//cpu registers
uint8_t regs[4];

uint8_t instruction_mem[INST_MEM_SIZE];
uint8_t data_mem[DATA_MEM_SIZE];

uint8_t halted = 0;

typedef struct {
    uint8_t execute_en;
    uint8_t execute_control;
    uint8_t src0_val;
    uint8_t src1_val;
    uint8_t dst_reg;
    uint16_t address;
    uint16_t result;
} execution_frame_t;

/***
 * pipeline stage enables
 */
uint8_t ifetch_en = 0;
uint8_t idecode_en = 0;
uint8_t mem_acc_en = 0;
uint8_t execute_en = 0;
uint8_t wr_mem_en = 0;
execution_frame_t exec_params;

void noobs_cpu_init(){
    pc = 0;
    sr = 0;
    cr = 0;
    sp = 0;
    exec_params.execute_control = 0;
    exec_params.src0_val = 0;
    exec_params.src1_val = 0;
    exec_params.dst_reg = 0;
    exec_params.address = 0;
    exec_params.result = 0;
    exec_params.execute_en = 0;
    ifetch_en = 1;
}


void execute(){
#ifdef NOOBS_DEBUG
    printf("execute \n");
#endif
    if(exec_params.execute_en) {
        switch(exec_params.execute_en) {
            case EXEC_NOP :
                break;
            case ALU_OPERATION_ADD : 
                exec_params.result = exec_params.src0_val + exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                break;
            case ALU_OPERATION_MUL :
                exec_params.result = exec_params.src0_val * exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                break;
            case ALU_OPERATION_AND :
                exec_params.result = exec_params.src0_val & exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                break;
            case ALU_OPERATION_OR :
                exec_params.result = exec_params.src0_val | exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                break;
            case ALU_OPERATION_XOR :
                exec_params.result = exec_params.src0_val ^ exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                break;
            case MEM_OPERATION_RD :
                regs[exec_params.dst_reg] = data_mem[exec_params.address];
                break;
            case MEM_OPERATION_WR :
                data_mem[exec_params.address] = regs[exec_params.dst_reg];
                break;
            case CPU_OPERATION_JMP :
                //TODO: implement jmp
                break;
            case CPU_OPERATION_CALL :
                //TODO: impmenet call
                break;
            default :
                fprintf(stderr,"FATAL: UNKNOWN Execution mode\n");
                break;
        }
    }
}


void idecode(){
    static uint8_t prev_instruction = 0;
    static uint8_t imm_mode = 0;
#ifdef NOOBS_DEBUG
    printf("idecode \n");
#endif
    if(idecode_en) {
        if(imm_mode) {  //this inst is the immediate value
            imm_mode = 0;
            exec_params.execute_en = 1;
            switch(GET_BASE_OP(prev_instruction)) {
                case MC_CTRL_USR : 
                    switch(GET_BASE_OP(prev_instruction)) {
                        case JMP:
                        case CALL:
                            exec_params.address = instruction + pc; //FIXME: this needs to be fixed
                            break;
                    }
                    break;
                case ADD : 
                case MUL :
                case AND :
                case XOR :
                    exec_params.src1_val = instruction;
                    break;
                case LD :
                case ST :
                    exec_params.address = (((prev_instruction & 0x0f) << 8 ) | instruction);
                    break;
            }
        }else{
            switch(GET_BASE_OP(instruction)) {
                case MC_CTRL_USR : 
                    imm_mode = IS_IMM(instruction);
                    printf("BASE_OP_CODE: MC_CTRL_USR\n");
                    switch(GET_MC_CTRL_USR_OP(instruction)){
                        case MISC :
                            printf("MC_CTRL_USR:MISC %u\n",instruction);
                            switch(instruction & 0x7) {
                                case NOP :
                                    printf("NOP\n");
                                    break;
                                case RET :
                                    //TODO: implement return
                                    printf("RET\n");
                                    break;
                                case HALT :
                                    printf("HALT\n");
                                    halted = 1;
                                    break;
                                case RST :
                                    printf("RESET\n");
                                    noobs_cpu_init();   //flush pipe and reset everything
                                    break;
                                default:
                                    fprintf(stderr,"FATAL Error: Unimplemented/RSVD machine control operation");
                                    exit(1);
                                    break;
                            }
                            break;
                        case USR :
                            //TODO: user extensible operations. Add extra ops if necessary
                            fprintf(stderr,"FATAL Error: No USR defined OPs defined\n");
                            exit(1);
                            break;
                        case JMP :
                            //TODO: implement branch
                            //the target address is relative to PC
                            fprintf(stderr,"FATAL Error: JMP is not implemented yet\n");
                            exit(1);
                            break;
                        case CALL :
                            //TODO: implement subroutine call
                            //the target address is relative to PC
                            fprintf(stderr,"FATAL Error: CALL is not implemented yet\n");
                            exit(1);
                        default: printf("WTF is this %u\n",GET_MC_CTRL_USR_OP(instruction));
                            break;
                    }
                    break;
                case ADD : 
                    exec_params.execute_control = ALU_OPERATION_ADD;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }
                    break;
                case MUL :
                    exec_params.execute_control = ALU_OPERATION_MUL;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }

                    break;
                case AND :
                    exec_params.execute_control = ALU_OPERATION_AND;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }

                    break;
                case OR :
                    exec_params.execute_control = ALU_OPERATION_OR;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }

                    break;
                case XOR :
                    exec_params.execute_control = ALU_OPERATION_XOR;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                    }

                    break;
                case LD :
                    imm_mode = 1;
                    exec_params.execute_control = MEM_OPERATION_RD;
                    exec_params.dst_reg = (instruction >> 4) & 0x01;
                    break;
                case ST :
                    imm_mode = 1;
                    exec_params.execute_control = MEM_OPERATION_WR;
                    exec_params.dst_reg = (instruction >> 4) & 0x01;
                    break;
            }
            //if mode is immediate, insert a 1 disable execution for 1 cycle 
            if(imm_mode){
                exec_params.execute_en = 0;
            }else{
                exec_params.execute_en = 1;
            }
        }
    }else{
        exec_params.execute_en = 0;
    }
    prev_instruction = instruction;
}

void ifetch(){
#ifdef NOOBS_DEBUG
    printf("ifetch \n");
#endif
    if(ifetch_en) {
        instruction = instruction_mem[pc++];
        printf("instruction_mem[%u] = %u\n",pc-1,instruction);
        if(pc >= INST_MEM_SIZE) {
            //TODO: error/trap in status register
            fprintf(stderr, "FATAL: Instruction memory access out of bounds\n");
            exit(1);
        }
        idecode_en = 1;
    }else{  //if ifetch is disabled return NOP
        instruction = 0;
        idecode_en = 0;
    }

}


int main(int argc, char** argv){
    //TODO: add support to read instruction and data files in binary/hex
    //if(argc >= 2) {
    //    printf("%s %s\n",argv[0], argv[1]);
    //}else{
    //}
    halted = 0;

    uint16_t cycle_counter = 0;

    
    load_instructions();
    printf("Instructions Loaded to Instruction Memory\n");
    load_data();
    printf("Data Loaded to Data Memory\n");

    noobs_cpu_init();
    printf("CPU initialized\n");

    //3 stage basic pipeline
    while(!halted){
        execute();
        idecode();
        ifetch();
        cycle_counter++;
        printf("Execution Cycle : %05d\n",cycle_counter);
    }

    printf("Execution Halted at cycle : %05d. PC: %04d\n",cycle_counter,pc);
    return 0;
}
