#include "NoobsCpu_Util.h"
#include "NoobsCpu_defines.h"

extern uint8_t data_mem[];
extern uint8_t instruction_mem[];


//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_instructions(){
    uint16_t inst_buff_ptr = 9;
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
    uint16_t data_buff_ptr = 0;
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
    uint16_t data_buff_ptr = 0;
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

