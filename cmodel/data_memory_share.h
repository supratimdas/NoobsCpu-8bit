#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/shm.h>

#define SHM_SIZE DATA_MEM_SIZE
#define SHM_KEY 5679
uint8_t last_dmem_copy[SHM_SIZE];
int shmid;

void init_shared_memory() {
    shmid = shmget(SHM_KEY, SHM_SIZE, IPC_CREAT | 0666);
    if (shmid == -1) {
        perror("shmget");
        exit(-1);
    }
}


void update_shared_memory(uint8_t* data_mem_ptr, int mode) {
    void *shm_ptr = shmat(shmid, NULL, 0);
    uint8_t *shm_ptr_uint8_t = (uint8_t*)shm_ptr;
    if (shm_ptr == (void*)-1) {
        perror("shmat");
        exit(-1);
    }
    if(mode == 1) {
        memcpy(shm_ptr, (const void*)data_mem_ptr, SHM_SIZE);
        memcpy(last_dmem_copy, (const void*)data_mem_ptr, SHM_SIZE);
        shmdt(shm_ptr);
    }else{
        for (int i=0; i < SHM_SIZE; i++) {
            if(last_dmem_copy[i] != data_mem_ptr[i]) {
                shm_ptr_uint8_t[i] = data_mem_ptr[i];
            }
            if(shm_ptr_uint8_t[i] != data_mem_ptr[i]) {
                data_mem_ptr[i] = shm_ptr_uint8_t[i];
            }
        }
        memcpy(last_dmem_copy, (const void*)data_mem_ptr, SHM_SIZE);
    }
}


void deinit_shared_memory() {
    int shmid = shmget(SHM_KEY, 0, 0);
    if (shmid == -1) {
        perror("shmget");
        exit(-1);
    }

    if (shmctl(shmid, IPC_RMID, 0) == -1) {
        perror("shmctl");
        exit(-1);
    }

    printf("Shared memory segment removed.\n");
}
