"""
test_codegen.py — Unit tests for the NoobsC code generator.

Strategy: compile a snippet → assemble with noobsASM.pl → run in cmodel.
For fast unit tests we only check the *structure* of the emitted assembly
(labels present, correct instructions) since running the cmodel adds
process overhead.  A small set of integration tests actually assemble
the output to verify the assembler accepts it.

Run with:
    python -m pytest utils/NoobsC/tests/test_codegen.py -v
"""

import sys, os, subprocess, tempfile, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lexer    import Lexer
from parser   import Parser
from semantic import Analyser
from codegen  import CodeGen, CodeGenError

# Path to the assembler (relative to repo root)
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
_ASM  = os.path.join(_REPO, 'utils', 'noobsASM.pl')


# ── helpers ────────────────────────────────────────────────────────────────────

def compile_src(src: str) -> str:
    """Lex → parse → sema → codegen.  Return the .asm text."""
    ast     = Parser(Lexer(src).tokenize()).parse()
    symbols = Analyser(ast).analyse()
    return CodeGen(ast, symbols).generate()

def asm_lines(src: str) -> list:
    """Return non-empty, non-comment lines of the generated assembly."""
    return [l.strip() for l in compile_src(src).splitlines()
            if l.strip() and not l.strip().startswith('#')]

def has_instruction(src: str, instr: str) -> bool:
    return any(instr in line for line in asm_lines(src))

def assembles_ok(asm_text: str) -> bool:
    """
    Run noobsASM.pl on the asm text in a temp directory.
    Returns True if the assembler exits with code 0.
    """
    if not os.path.exists(_ASM):
        return True   # skip if assembler not found (CI without Perl)
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, 'test.asm')
        with open(src, 'w') as f:
            f.write(asm_text)
        result = subprocess.run(
            ['perl', _ASM, src],
            cwd=d, capture_output=True, text=True
        )
        return result.returncode == 0


# ──────────────────────────────────────────────────────────────────────────────
# Data section
# ──────────────────────────────────────────────────────────────────────────────

class TestDataSection(unittest.TestCase):

    def test_global_scalar_in_data(self):
        asm = compile_src('char x; void main() {}')
        self.assertIn('x:0x00', asm)

    def test_global_array_in_data(self):
        asm = compile_src('char buf[4]; void main() {}')
        self.assertIn('buf:0x00,0x00,0x00,0x00', asm)

    def test_global_with_init_in_data(self):
        asm = compile_src('char x = 5; void main() {}')
        self.assertIn('x:0x05', asm)

    def test_local_var_in_data(self):
        asm = compile_src('void f() { char x; }')
        self.assertIn('__f_x:0x00', asm)

    def test_param_in_data(self):
        asm = compile_src('void f(char n) {}')
        self.assertIn('__f_n:0x00', asm)

    def test_scratch_temps_in_data(self):
        asm = compile_src('void main() {}')
        self.assertIn('__tmp0:0x00', asm)
        self.assertIn('__tmp1:0x00', asm)

    def test_data_section_marker(self):
        asm = compile_src('void main() {}')
        self.assertIn('.data', asm)

    def test_code_section_marker(self):
        asm = compile_src('void main() {}')
        self.assertIn('.code', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Program entry point
# ──────────────────────────────────────────────────────────────────────────────

class TestEntryPoint(unittest.TestCase):

    def test_calls_main(self):
        asm = compile_src('void main() {}')
        self.assertIn('CALLNC __main', asm)

    def test_halt_after_main(self):
        lines = asm_lines('void main() {}')
        call_idx = next(i for i, l in enumerate(lines) if 'CALLNC __main' in l)
        self.assertIn('HALT', lines[call_idx + 1])

    def test_function_label(self):
        asm = compile_src('void main() {}')
        self.assertIn('__main:', asm)

    def test_function_ret(self):
        asm = compile_src('void f() {}')
        self.assertIn('RET', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Constants and variables
# ──────────────────────────────────────────────────────────────────────────────

class TestConstantsAndVars(unittest.TestCase):

    def test_zero_literal(self):
        asm = compile_src('void f() { char x; x = 0; }')
        self.assertIn('XOR R0,R0', asm)

    def test_nonzero_literal(self):
        asm = compile_src('void f() { char x; x = 5; }')
        self.assertIn('ADDI R0,R0,5', asm)

    def test_store_to_local(self):
        asm = compile_src('void f() { char x; x = 1; }')
        self.assertIn('STORE R0,__f_x', asm)

    def test_load_local(self):
        asm = compile_src('void f() { char x; char y; y = x; }')
        self.assertIn('LOAD R0,__f_x', asm)

    def test_store_to_global(self):
        asm = compile_src('char g; void f() { g = 1; }')
        self.assertIn('STORE R0,g', asm)

    def test_load_global(self):
        asm = compile_src('char g; void f() { char x; x = g; }')
        self.assertIn('LOAD R0,g', asm)

    def test_char_literal(self):
        asm = compile_src("void f() { char x; x = 'A'; }")
        self.assertIn('ADDI R0,R0,65', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Arithmetic and bitwise binary ops
# ──────────────────────────────────────────────────────────────────────────────

class TestBinaryOps(unittest.TestCase):

    def test_addition(self):
        asm = compile_src('void f() { char x; char y; char z; z = x + y; }')
        self.assertIn('ADD R0,R1', asm)

    def test_subtraction(self):
        asm = compile_src('void f() { char x; char y; char z; z = x - y; }')
        self.assertIn('SUB R0,R1', asm)

    def test_bitwise_and(self):
        asm = compile_src('void f() { char x; char y; char z; z = x & y; }')
        self.assertIn('AND R0,R1', asm)

    def test_bitwise_or(self):
        asm = compile_src('void f() { char x; char y; char z; z = x | y; }')
        self.assertIn('OR R0,R1', asm)

    def test_bitwise_xor(self):
        asm = compile_src('void f() { char x; char y; char z; z = x ^ y; }')
        self.assertIn('XOR R0,R1', asm)

    def test_saves_left_to_tmp(self):
        asm = compile_src('void f() { char x; char y; char z; z = x + y; }')
        self.assertIn('STORE R0,__tmp0', asm)
        self.assertIn('LOAD R0,__tmp0', asm)

    def test_mul_raises_error(self):
        with self.assertRaises(CodeGenError):
            compile_src('void f() { char x; char y; char z; z = x * y; }')


# ──────────────────────────────────────────────────────────────────────────────
# Unary operators
# ──────────────────────────────────────────────────────────────────────────────

class TestUnaryOps(unittest.TestCase):

    def test_bitwise_not(self):
        asm = compile_src('void f() { char x; char y; y = ~x; }')
        self.assertIn('XORI R0,R0,0xFF', asm)

    def test_unary_minus(self):
        asm = compile_src('void f() { char x; char y; y = -x; }')
        self.assertIn('XORI R0,R0,0xFF', asm)
        self.assertIn('ADDI R0,R0,1', asm)

    def test_logical_not(self):
        asm = compile_src('void f() { char x; char y; y = !x; }')
        self.assertIn('ADDI R0,R0,0', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Compound assignment
# ──────────────────────────────────────────────────────────────────────────────

class TestCompoundAssign(unittest.TestCase):

    def test_plus_assign(self):
        asm = compile_src('void f() { char x; x += 1; }')
        self.assertIn('ADD R0,R1', asm)
        self.assertIn('STORE R0,__f_x', asm)

    def test_xor_assign(self):
        asm = compile_src('char led; void f() { led ^= 0xFF; }')
        self.assertIn('XOR R0,R1', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Postfix operators
# ──────────────────────────────────────────────────────────────────────────────

class TestPostfix(unittest.TestCase):

    def test_increment(self):
        asm = compile_src('void f() { char i; i++; }')
        self.assertIn('ADDI R0,R0,1', asm)
        self.assertIn('STORE R0,__f_i', asm)

    def test_decrement(self):
        asm = compile_src('void f() { char i; i--; }')
        self.assertIn('SUBI R0,R0,1', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Array access
# ──────────────────────────────────────────────────────────────────────────────

class TestArrayAccess(unittest.TestCase):

    def test_array_read_uses_indirect(self):
        asm = compile_src('char arr[4]; void f() { char x; x = arr[0]; }')
        self.assertIn('SET_ADR_MODE', asm)
        self.assertIn('RST_ADR_MODE', asm)
        self.assertIn('LOAD R0,arr', asm)

    def test_array_write_uses_indirect(self):
        asm = compile_src('char arr[4]; void f() { arr[0] = 5; }')
        self.assertIn('SET_ADR_MODE', asm)
        self.assertIn('STORE R0,arr', asm)

    def test_r3_set_before_indirect(self):
        asm = compile_src('char arr[4]; void f() { char x; x = arr[0]; }')
        self.assertIn('ADDI R3,R0,0', asm)


# ──────────────────────────────────────────────────────────────────────────────
# Function calls
# ──────────────────────────────────────────────────────────────────────────────

class TestFuncCalls(unittest.TestCase):

    def test_call_no_args(self):
        asm = compile_src('char val() { return 1; } void f() { char x; x = val(); }')
        self.assertIn('CALLNC __val', asm)

    def test_call_one_arg(self):
        asm = compile_src('char inc(char x) { return x; } void f() { char y; y = inc(1); }')
        self.assertIn('CALLNC __inc', asm)

    def test_call_two_args(self):
        asm = compile_src('char add(char a, char b) { return a; } void f() { char z; z = add(1,2); }')
        self.assertIn('ADDI R1,R0,0', asm)   # second arg moved to R1
        self.assertIn('CALLNC __add', asm)

    def test_callee_saves_params(self):
        asm = compile_src('char inc(char x) { return x; }')
        self.assertIn('STORE R0,__inc_x', asm)


# ──────────────────────────────────────────────────────────────────────────────
# If statement
# ──────────────────────────────────────────────────────────────────────────────

class TestIfStmt(unittest.TestCase):

    def test_if_emits_conditional_jump(self):
        asm = compile_src('void f() { char x; if (x) {} }')
        self.assertIn('JMPZ', asm)

    def test_if_else_emits_unconditional_jump(self):
        asm = compile_src('void f() { char x; if (x) {} else {} }')
        self.assertIn('JMPNC', asm)

    def test_equality_check(self):
        asm = compile_src('void f() { char x; if (x == 0) {} }')
        self.assertIn('SUB R0,R1', asm)
        self.assertIn('JMPNZ', asm)

    def test_less_than_check(self):
        asm = compile_src('void f() { char x; if (x < 8) {} }')
        self.assertIn('SUB R0,R1', asm)
        self.assertIn('JMPOVF', asm)


# ──────────────────────────────────────────────────────────────────────────────
# While loop
# ──────────────────────────────────────────────────────────────────────────────

class TestWhileLoop(unittest.TestCase):

    def test_while_emits_loop_labels(self):
        asm = compile_src('void f() { while (1) {} }')
        self.assertIn('__while_', asm)
        self.assertIn('__while_end_', asm)

    def test_while_jumps_back(self):
        asm = compile_src('void f() { while (1) {} }')
        self.assertIn('JMPNC', asm)   # unconditional jump back

    def test_break_jumps_to_end(self):
        asm = compile_src('void f() { while (1) { break; } }')
        lines = asm_lines('void f() { while (1) { break; } }')
        # find the while_end label
        end_lbl = next(l.split(':')[0] for l in lines if '__while_end_' in l and ':' in l)
        self.assertTrue(any(f'JMPNC {end_lbl}' in l for l in lines))


# ──────────────────────────────────────────────────────────────────────────────
# For loop
# ──────────────────────────────────────────────────────────────────────────────

class TestForLoop(unittest.TestCase):

    def test_for_emits_labels(self):
        asm = compile_src('void f() { for (;;) {} }')
        self.assertIn('__for_', asm)
        self.assertIn('__for_end_', asm)

    def test_for_init_var_decl(self):
        asm = compile_src('void f() { for (char i = 0; i < 8; i++) {} }')
        self.assertIn('__f_i:0x00', asm)   # local in data section
        self.assertIn('STORE R0,__f_i', asm)

    def test_for_update_emitted(self):
        asm = compile_src('void f() { for (char i = 0; i < 8; i++) {} }')
        self.assertIn('ADDI R0,R0,1', asm)  # i++ → addi


# ──────────────────────────────────────────────────────────────────────────────
# Integration: assembler accepts the output
# ──────────────────────────────────────────────────────────────────────────────

class TestAssemblesOk(unittest.TestCase):

    def test_empty_main(self):
        self.assertTrue(assembles_ok(compile_src('void main() {}')))

    def test_blinky(self):
        src = """
        char led;
        void main() {
            led = 0;
            while (1) {
                led = led ^ 0xFF;
            }
        }
        """
        self.assertTrue(assembles_ok(compile_src(src)))

    def test_array_fill(self):
        src = """
        char arr[8];
        void fill() {
            char i;
            i = 0;
            while (i < 8) {
                arr[i] = i;
                i = i + 1;
            }
        }
        void main() { fill(); }
        """
        self.assertTrue(assembles_ok(compile_src(src)))

    def test_multiply(self):
        src = """
        char mul(char a, char b) {
            char result;
            result = 0;
            while (b) {
                result = result + a;
                b = b - 1;
            }
            return result;
        }
        void main() {
            char x;
            x = mul(3, 4);
        }
        """
        self.assertTrue(assembles_ok(compile_src(src)))

    def test_fibonacci_iterative(self):
        src = """
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
            char result;
            result = fib(10);
        }
        """
        self.assertTrue(assembles_ok(compile_src(src)))


if __name__ == '__main__':
    unittest.main(verbosity=2)
