/*********************************************************** 
* File Name     : NoobsCpu.c
* Description   : C-model for the NoobsCpu ISA
* Organization  : NONE 
* Creation Date : 15-03-2019
* Last Modified : Friday 15 March 2019 02:20:02 AM IST
* Author        : Supratim Das (supratimofficio.com)
************************************************************/ 
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define INST_MEM_SIZE 2048
#define DATA_MEM_SIZE 4096

uint8_t     inst;   //instruction
uint16_t    pc;     //program counter 12bit
uint8_t     sr;     //status register
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
 *|  RSVD   |  RSVD   |  RSVD   |  RSVD   | 16bit_s |   BU    |  BCNZ   |   BCZ   |
 *+---------+---------+---------+---------+---------+---------+---------+---------+
 */

//cpu registers
uint8_t regs[4];

uint8_t instruction_mem[INST_MEM_SIZE];
uint8_t data_mem[DATA_MEM_SIZE];

void wr_mem(){
#ifdef NOOBS_DEBUG
    printf("wr_mem \n");
#endif
}


void execute(){
#ifdef NOOBS_DEBUG
    printf("execute \n");
#endif

}

void dfetch(){
#ifdef NOOBS_DEBUG
    printf("dfetch \n");
#endif
}

void idecode(){
#ifdef NOOBS_DEBUG
    printf("idecode \n");
#endif
}

void ifetch(){
#ifdef NOOBS_DEBUG
    printf("ifetch \n");
#endif
}

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_instructions(){
}

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_data(){
}

//dump modified data memory to File
//store in human readble format. MEM_LOC: VALUE
void store_data(){
}

int main(){
    load_instructions();
    load_data();

    //5 stage pipeline
    while(1){
        wr_mem();
        execute();
        dfetch();
        idecode();
        ifetch();
    }
    return 0;
}
