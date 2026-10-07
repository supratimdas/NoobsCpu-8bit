// array_fill.nc — Fill an array with values, then sum them.
//
// Demonstrates: global array, for loop, array indexing, function calls.

char arr[8];
char total;

void fill() {
    char i;
    for (i = 0; i < 8; i++) {
        arr[i] = i;           // arr = [0,1,2,3,4,5,6,7]
    }
}

char sum() {
    char i;
    char acc;
    acc = 0;
    for (i = 0; i < 8; i++) {
        acc = acc + arr[i];
    }
    return acc;
}

void main() {
    fill();
    total = sum();   // total = 0+1+2+3+4+5+6+7 = 28
}
