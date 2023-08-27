#include "libshared_util.c"

int main() {
    uint8_t* ptr;
    init_shared_memory();
    while(1) {
        read_updated_shared_memory();
        ptr=shared_memory;
    	printf("Program 2 read: %u %u %d %d %d %d %d %d %d %d %d %d\n", &ptr[0], &ptr[1], ptr[0], ptr[1], ptr[2], ptr[3], ptr[4], ptr[5], ptr[6], ptr[7], ptr[8], ptr[9]);
	    sleep(1);
    }

    return 0;
}

