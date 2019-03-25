/*********************************************************** 
* File Name     : NoobsCpu.c
* Description   : C-model for the NoobsCpu ISA
* Organization  : NONE 
* Creation Date : 15-03-2019
* Last Modified : Monday 25 March 2019 11:46:22 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
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
 *|  RSVD   |  RSVD   |SP_MSB10 | SP_MSB9 | SP_MSB8 |   BU    |  BCNZ   |   BCZ   |
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
    cr = CR_SP_INIT_MSB;
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

void update_status_regs(){
    //update status reg
    switch(exec_params.execute_control){
        case EXEC_NOP:
        case MEM_OPERATION_RD:
        case MEM_OPERATION_WR:
        case CPU_OPERATION_JMP:
        case CPU_OPERATION_CALL:
            sr = sr & ~(SR_Z | SR_NZ | SR_OVF);
            break;
        case ALU_OPERATION_ADD:
        case ALU_OPERATION_SUB:
            if(exec_params.result & 0xff00) {
                sr = sr | SR_OVF;
            }else{
                sr = sr & ~SR_OVF;
            }

            if(exec_params.result & 0x00ff) {
                sr = sr | SR_NZ;
                sr = sr & ~SR_Z;
            }else{
                sr = sr | SR_Z;
                sr = sr & ~SR_NZ;
            }
            break;
        case ALU_OPERATION_AND:
        case ALU_OPERATION_OR:
        case ALU_OPERATION_XOR:
            sr = sr & ~(SR_OVF);
            break;

    }
}


void execute(){
    uint16_t stack_addr;
    uint16_t ret_addr;
#ifdef NOOBS_DEBUG
    printf("execute \n");
#endif
    if(exec_params.execute_en) {
        switch(exec_params.execute_control) {
            case EXEC_NOP :
                update_status_regs();
                debug_printf("{EXEC_NOP:} ");
                break;
            case ALU_OPERATION_ADD : 
                exec_params.result = exec_params.src0_val + exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                update_status_regs();
                debug_printf("{EXEC_ADD: regs[%u] = %u + %u. value = %u} ",exec_params.dst_reg, exec_params.src0_val,exec_params.src1_val,exec_params.result);
                break;
            case ALU_OPERATION_SUB :
                exec_params.result = exec_params.src0_val - exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                update_status_regs();
                debug_printf("{EXEC_SUB: regs[%u] = %u - %u. value = %u} ",exec_params.dst_reg, exec_params.src0_val,exec_params.src1_val,exec_params.result);
                break;
            case ALU_OPERATION_AND :
                exec_params.result = exec_params.src0_val & exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                update_status_regs();
                debug_printf("{EXEC_AND: regs[%u] = %u & %u. value = %u} ",exec_params.dst_reg, exec_params.src0_val,exec_params.src1_val,exec_params.result);
                break;
            case ALU_OPERATION_OR :
                exec_params.result = exec_params.src0_val | exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                update_status_regs();
                debug_printf("{EXEC_OR: regs[%u] = %u | %u. value = %u} ",exec_params.dst_reg, exec_params.src0_val,exec_params.src1_val,exec_params.result);
                break;
            case ALU_OPERATION_XOR :
                exec_params.result = exec_params.src0_val ^ exec_params.src1_val;
                regs[exec_params.dst_reg] = exec_params.result;
                update_status_regs();
                debug_printf("{EXEC_XOR: regs[%u] = %u ^ %u. value = %u} ",exec_params.dst_reg, exec_params.src0_val,exec_params.src1_val,exec_params.result);
                break;
            case MEM_OPERATION_RD :
                regs[exec_params.dst_reg] = data_mem[exec_params.address];
                update_status_regs();
                debug_printf("{MEM_OPERATION_RD: regs[%u] <= data[%u]. value = %u} ",exec_params.dst_reg,exec_params.address, data_mem[exec_params.address]);
                break;
            case MEM_OPERATION_WR :
                data_mem[exec_params.address] = regs[exec_params.dst_reg];
                update_status_regs();
                debug_printf("{MEM_OPERATION_WR: regs[%u] => data[%u]. value = %u} ",exec_params.dst_reg,exec_params.address, data_mem[exec_params.address]);
                break;
            case CPU_OPERATION_JMP :
                if((cr & SET_BCZ) && (sr & SR_Z)){  //branch if zero
                    pc = exec_params.address;
                }else if((cr & SET_BCNZ) && (sr & SR_NZ)){  //branch if not-zero
                    pc = exec_params.address;
                }else if((cr & (SET_BCZ|SET_BCNZ))){    //unconditionl branch
                    pc = exec_params.address;
                }
                ifetch_en = 1;
                update_status_regs();
                break;
            case CPU_OPERATION_CALL :
                stack_addr = (((cr >> 3) & 0x07) << 8) | sp;
                data_mem[stack_addr] = ((pc >> 8) & 0x07);
                data_mem[stack_addr+1] = (pc & 0xff);
                if((cr & SET_BCZ) && (sr & SR_Z)){  //branch if zero
                    pc = exec_params.address;
                    sp+=2;
                }else if((cr & SET_BCNZ) && (sr & SR_NZ)){  //branch if not-zero
                    pc = exec_params.address;
                    sp+=2;
                }else if((cr & (SET_BCZ|SET_BCNZ))){    //unconditionl branch
                    pc = exec_params.address;
                    sp+=2;
                }
                ifetch_en = 1;
                update_status_regs();
                break;
            case CPU_OPERATION_RET :
                stack_addr = (((cr >> 3) & 0x07) << 8)|sp;
                ret_addr = (data_mem[stack_addr-2] << 8)|data_mem[stack_addr-1]; 
                if((cr & SET_BCZ) && (sr & SR_Z)){  //return if zero
                    pc = ret_addr;
                    sp-=2;
                }else if((cr & SET_BCNZ) && (sr & SR_NZ)){  //return if not-zero
                    pc = ret_addr;
                    sp-=2;
                }else if((cr & (SET_BCZ|SET_BCNZ))){    //unconditionl return
                    pc = ret_addr;
                    sp-=2;
                }
                ifetch_en = 1;
                update_status_regs();
                break;
            default :
                fprintf(stderr,"FATAL: UNKNOWN Execution mode\n");
                break;
        }
        exec_params.execute_en = 0;
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
                            exec_params.address = (((prev_instruction & 0x07) << 8 ) | instruction);
                            ifetch_en = 0;  //stop fetching new instructions untill the jump call
                            break;
                    }
                    break;
                case ADD : 
                case SUB :
                case AND :
                case XOR :
                    exec_params.src1_val = instruction;
                    debug_printf("{IDECODE: IMMEDIATE_VAL = %u} ",exec_params.src1_val);
                    break;
                case LD :
                case ST :
                    exec_params.address = (((prev_instruction & 0x07) << 8 ) | instruction);
                    debug_printf("{IDECODE: ADDRESS = %u} ",exec_params.address);
                    break;
            }
        }else{
            switch(GET_BASE_OP(instruction)) {
                case MC_CTRL_USR : 
                    imm_mode = IS_IMM(instruction);
                    switch(GET_MC_CTRL_USR_OP(instruction)){
                        case MISC :
                            switch(instruction & 0x7) {
                                case NOP :
                                    exec_params.execute_control = EXEC_NOP; 
                                    debug_printf("{IDECODE: NOP} ");
                                    break;
                                case RET :
                                    debug_printf("{IDECODE: RET} ");
                                    exec_params.execute_control = CPU_OPERATION_RET; 
                                    break;
                                case HALT :
                                    debug_printf("{IDECODE: HALT} ");
                                    halted = 1;
                                    break;
                                case RST :
                                    debug_printf("{IDECODE: RESET} ");
                                    noobs_cpu_init();   //flush pipe and reset everything
                                    break;
                                case SET_BCZ :
                                    debug_printf("{IDECODE: SET_BCZ} ");
                                    cr = (cr & (~CR_BCNZ)) | CR_BCZ;
                                    break;
                                case SET_BCNZ :
                                    debug_printf("{IDECODE: SET_BCNZ} ");
                                    cr = (cr & (~CR_BCZ)) | CR_BCNZ;
                                    break;
                                case CLR_BC :
                                    cr = (cr & (~CR_BCZ));
                                    cr = (cr & (~CR_BCNZ));
                                    break;
                                default:
                                    fprintf(stderr,"FATAL Error: Unimplemented/RSVD machine control operation\n");
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
                            debug_printf("{IDECODE: JMP} ");
                            break;
                        case CALL :
                            debug_printf("{IDECODE: CALL} ");
                            break;
                    }
                    break;
                case ADD : 
                    exec_params.execute_control = ALU_OPERATION_ADD;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: ADDI: src0_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.dst_reg);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: ADD: src0_val = %u, src1_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.src1_val,exec_params.dst_reg);
                    }
                    break;
                case SUB :
                    exec_params.execute_control = ALU_OPERATION_SUB;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: SUBI: src0_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.dst_reg);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: SUB: src0_val = %u, src1_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.src1_val,exec_params.dst_reg);
                    }

                    break;
                case AND :
                    exec_params.execute_control = ALU_OPERATION_AND;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: ANDI: src0_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.dst_reg);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: AND: src0_val = %u, src1_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.src1_val,exec_params.dst_reg);
                    }

                    break;
                case OR :
                    exec_params.execute_control = ALU_OPERATION_OR;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: ORI: src0_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.dst_reg);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: OR: src0_val = %u, src1_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.src1_val,exec_params.dst_reg);
                    }

                    break;
                case XOR :
                    exec_params.execute_control = ALU_OPERATION_XOR;
                    imm_mode = IS_IMM(instruction);
                    if(imm_mode){
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: XORI: src0_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.dst_reg);
                    }else{
                        exec_params.src0_val = GET_REG_VALUE(GET_REG_PTR0(instruction));
                        exec_params.src1_val = GET_REG_VALUE(GET_REG_PTR1(instruction));
                        exec_params.dst_reg = GET_REG_PTR1(instruction);
                        debug_printf("{IDECODE: XOR: src0_val = %u, src1_val = %u, dst_reg = %u} ",exec_params.src0_val,exec_params.src1_val,exec_params.dst_reg);
                    }

                    break;
                case LD :
                    imm_mode = 1;
                    exec_params.execute_control = MEM_OPERATION_RD;
                    exec_params.dst_reg = GET_LD_ST_REG_PTR(instruction);
                    debug_printf("{IDECODE: LOAD reg[%u]} ", exec_params.dst_reg);
                    break;
                case ST :
                    imm_mode = 1;
                    exec_params.execute_control = MEM_OPERATION_WR;
                    exec_params.dst_reg = GET_LD_ST_REG_PTR(instruction);
                    debug_printf("{IDECODE: STORE reg[%u]} ", exec_params.dst_reg);
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
        if(pc >= INST_MEM_SIZE) {
            //TODO: error/trap in status register
            fprintf(stderr, "FATAL: Instruction memory access out of bounds\n");
            exit(1);
        }
        debug_printf("{IFETCH: PC=%04u  instruction=%hhx} ",(pc-1),instruction);
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

    if(getenv("NOOBS_DEBUG")){
        uint8_t val = atoi((getenv("NOOBS_DEBUG")));
        printf("debug_mode %u\n",val);
    }
    
    load_instructions();
    printf("Instructions Loaded to Instruction Memory\n");
    load_data();
    printf("Data Loaded to Data Memory\n");

    noobs_cpu_init();
    printf("CPU initialized\n");

    //3 stage basic pipeline
    while(!halted){
        debug_printf("\nExecution Cycle : %05d ::>",cycle_counter);
        execute();
        idecode();
        ifetch();
        cycle_counter++;
    }

    printf("\nExecution Halted at cycle : %05d. PC: %04d",cycle_counter,pc);

    store_data();
    printf("\nfinal_memory dumped in noobs_data_result.txt\n");

    return 0;
}
