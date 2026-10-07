// multiply.nc — Multiply two numbers using repeated addition.
//
// Demonstrates: function with arguments, while loop, local variables,
//               compound assignment.
//
// NoobsCpu has no MUL instruction, so we implement it as:
//   a * b  =  a + a + a + ... (b times)
//
// Result is stored in the global 'result' for inspection.

char result;

char mul(char a, char b) {
    char acc;
    acc = 0;
    while (b) {
        acc = acc + a;
        b = b - 1;
    }
    return acc;
}

void main() {
    result = mul(6, 7);   // result = 42
}
