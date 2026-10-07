// blinky.nc — Toggle an LED forever.
//
// Demonstrates: global variable, infinite while loop, XOR trick.
// The XOR with 0xFF flips all bits: 0x00 -> 0xFF -> 0x00 -> ...

char led;

void main() {
    led = 0;
    while (1) {
        led = led ^ 0xFF;
    }
}
