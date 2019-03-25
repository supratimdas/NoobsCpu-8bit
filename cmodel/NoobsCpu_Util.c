/*********************************************************** 
* File Name     : NoobsCpu_Util.c
* Description   : utilities code for the NoobsCpu ISA
* Organization  : NONE 
* Creation Date : 25-03-2019
* Last Modified : Monday 25 March 2019 11:47:31 PM IST
* Author        : Supratim Das (supratimofficio@gmail.com)
************************************************************/ 

#include "NoobsCpu_Util.h"
#include "NoobsCpu_defines.h"
#include <stdarg.h>

extern uint8_t data_mem[];
extern uint8_t instruction_mem[];

//a super dumb version of debug printing using environment variable
void debug_printf(const char * format, ... ) {
    va_list ap;
    uint8_t arg_c = 0;
    uint8_t i = 0;
    uint16_t val_0,val_1,val_2,val_3;
    uint8_t debug_print_en = (getenv("NOOBS_DEBUG") != NULL) && atoi((getenv("NOOBS_DEBUG")));
    while(format[i]!='\0') {
        if(format[i] == '%') {
            arg_c++;
        }
        i++;
    }
    va_start(ap,format);
    switch(arg_c) {
        case 0:
            if(debug_print_en) {
                printf(format);
            }
            break;
        case 1:
            val_0 = va_arg(ap,int);
            if(debug_print_en) {
                printf(format,val_0);
            }

            break;
        case 2:
            val_0 = va_arg(ap,int);
            val_1 = va_arg(ap,int);
            if(debug_print_en) {
                printf(format,val_0,val_1);
            }

            break;
        case 3:
            val_0 = va_arg(ap,int);
            val_1 = va_arg(ap,int);
            val_2 = va_arg(ap,int);
            if(debug_print_en) {
                printf(format,val_0,val_1,val_2);
            }

            break;
        case 4:
            val_0 = va_arg(ap,int);
            val_1 = va_arg(ap,int);
            val_2 = va_arg(ap,int);
            val_3 = va_arg(ap,int);
            if(debug_print_en) {
                printf(format,val_0,val_1,val_2,val_3);
            }
            break;
        default: break;
    }
    va_end(ap);
}

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_instructions(){
    uint16_t inst_buff_ptr = 0;
    FILE *inst_file = NULL;
    inst_file = fopen("noobs_inst.txt", "r");
    if(inst_file == NULL) {
        fprintf(stderr, "FATAL: compiled executable: noobs_inst.txt not found.\n");
        exit(1);
    }
    while(!feof(inst_file)) {
        uint8_t inst = 0;
        fscanf(inst_file,"%hhx", &inst);
        instruction_mem[inst_buff_ptr++] = inst;
    }
    fclose(inst_file);
    while(inst_buff_ptr < INST_MEM_SIZE) {
        instruction_mem[inst_buff_ptr++] = 0;
    }

    return;
}

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_data(){
    uint16_t data_buff_ptr = 8;
    FILE *data_file = NULL;
    data_file = fopen("noobs_data.txt", "r");
    if(data_file == NULL) {
        fprintf(stderr, "FATAL: compiled executable: noobs_data.txt not found.\n");
        exit(1);
    }
    while(!feof(data_file)) {
        uint8_t data = 0;
        fscanf(data_file,"%hhx", &data);
        data_mem[data_buff_ptr++] = data;
    }
    fclose(data_file);
    while(data_buff_ptr < DATA_MEM_SIZE) {
        data_mem[data_buff_ptr++] = 0;
    }

    return;
}

//dump modified data memory to File
//store in human readble format. MEM_LOC: VALUE
void store_data(){
    uint16_t data_buff_ptr = 8;
    FILE *data_file = NULL;
    data_file = fopen("noobs_data_result.txt", "w");
    if(data_file == NULL) {
        fprintf(stderr, "FATAL: unable to create file noobs_data_result.txt.\n");
        exit(1);
    }
    for(data_buff_ptr=0; data_buff_ptr < DATA_MEM_SIZE; data_buff_ptr++) {
        fprintf(data_file,"%hhx\n", data_mem[data_buff_ptr]);
    }
    fclose(data_file);

    return;
}

