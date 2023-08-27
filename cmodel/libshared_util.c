#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/shm.h>
#include <stdint.h>

#define SHM_SIZE 2048
#define SHM_KEY 5679

uint8_t shared_memory[SHM_SIZE];
int shmid;
int size = 2048;
int x1;
int x2;


void init_shared_memory() {
    shmid = shmget(SHM_KEY, SHM_SIZE, 0666);
    if (shmid == -1) {
        perror("shmget");
        exit(-1);
    }
}

void read_updated_shared_memory() {
    void *shm_ptr = shmat(shmid, NULL, 0);
    uint8_t* ptr;
    if (shm_ptr == (void*)-1) {
        perror("shmat");
        exit(-1);
    }
    
    ptr = ((uint8_t*)shm_ptr);
    for (int i=0; i< SHM_SIZE; i++) {
        shared_memory[i] = ptr[i];
    }
    x1=shared_memory[8];
    x2=shared_memory[9];
    //printf("==================================\n");
    //for (int i=0; i<10; i++) {
    //    printf("%d ", shared_memory[i]);
    //}
    //printf("\n==================================\n");


    shmdt(shm_ptr);
}
