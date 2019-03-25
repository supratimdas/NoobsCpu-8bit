#ifndef __NOOBS_CPU_UTIL_H__
#define __NOOBS_CPU_UTIL_H__
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_instructions();

//load instructions from compiled File
//supported formats: hex/decimal/binary
void load_data();

//dump modified data memory to File
//store in human readble format. MEM_LOC: VALUE
void store_data();

#endif
