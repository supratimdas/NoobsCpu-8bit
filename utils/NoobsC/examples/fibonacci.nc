// fibonacci.nc — Compute the Nth Fibonacci number (iterative).
//
// Demonstrates: function, local variables, while loop, multiple assignment.
//
// Uses the iterative method so no recursion is needed:
//   fib(0)=0, fib(1)=1, fib(2)=1, fib(3)=2, fib(4)=3, fib(5)=5 ...
//
// Note: char is 8 bits (0-255), so fib(13)=233 is the largest that fits.

char result;

char fib(char n) {
    char a;
    char b;
    char tmp;
    a = 0;
    b = 1;
    while (n) {
        tmp = b;
        b = a + b;
        a = tmp;
        n = n - 1;
    }
    return a;
}

void main() {
    result = fib(10);   // result = 55
}
