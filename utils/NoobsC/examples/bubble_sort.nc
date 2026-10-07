// bubble_sort.nc — Sort an 8-element array using bubble sort.
//
// Demonstrates: nested loops, array read/write with computed index,
//               if/else, local variables, break.

char data[8];
char sorted;

void init() {
    data[0] = 5;
    data[1] = 1;
    data[2] = 8;
    data[3] = 2;
    data[4] = 15;
    data[5] = 7;
    data[6] = 4;
    data[7] = 9;
}

void sort() {
    char i;
    char j;
    char tmp;
    char swapped;

    i = 0;
    while (i < 8) {
        swapped = 0;
        j = 0;
        while (j < 7) {
            if (data[j] > data[j + 1]) {
                tmp        = data[j];
                data[j]    = data[j + 1];
                data[j + 1] = tmp;
                swapped = 1;
            }
            j = j + 1;
        }
        if (!swapped) {
            break;
        }
        i = i + 1;
    }
    sorted = 1;
}

void main() {
    init();
    sort();
}
