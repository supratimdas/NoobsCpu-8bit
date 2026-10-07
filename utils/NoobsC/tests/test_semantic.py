"""
test_semantic.py — Unit tests for the NoobsC semantic analyser.

Run with:
    python -m pytest utils/NoobsC/tests/test_semantic.py -v
"""

import sys, os, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lexer    import Lexer
from parser   import Parser
from semantic import Analyser, SemanticError, Symbol, SymbolTable


# ── helpers ────────────────────────────────────────────────────────────────────

def analyse(src: str) -> SymbolTable:
    """Lex + parse + analyse a complete program. Returns the symbol table."""
    ast = Parser(Lexer(src).tokenize()).parse()
    return Analyser(ast).analyse()

def check_ok(src: str):
    """Assert that src passes semantic analysis without raising."""
    analyse(src)   # raises SemanticError if something is wrong

def check_err(src: str) -> SemanticError:
    """Assert that src raises SemanticError; return the exception."""
    try:
        analyse(src)
    except SemanticError as e:
        return e
    raise AssertionError("Expected SemanticError but none was raised")


# ──────────────────────────────────────────────────────────────────────────────
# Symbol table unit tests
# ──────────────────────────────────────────────────────────────────────────────

class TestSymbolTable(unittest.TestCase):

    def test_define_and_lookup_global(self):
        t = SymbolTable()
        t.define(Symbol('x', 'scalar'))
        sym = t.lookup('x')
        self.assertEqual(sym.name, 'x')
        self.assertEqual(sym.kind, 'scalar')

    def test_duplicate_global_error(self):
        t = SymbolTable()
        t.define(Symbol('x', 'scalar'))
        with self.assertRaises(SemanticError):
            t.define(Symbol('x', 'scalar'))

    def test_local_shadows_global(self):
        t = SymbolTable()
        t.define(Symbol('x', 'scalar'))
        t.enter_function()
        t.define(Symbol('x', 'array', size=4))
        sym = t.lookup('x')
        self.assertEqual(sym.kind, 'array')   # local wins

    def test_local_gone_after_exit(self):
        t = SymbolTable()
        t.define(Symbol('x', 'scalar'))
        t.enter_function()
        t.define(Symbol('y', 'scalar'))
        t.exit_function()
        t.lookup('x')                        # global still there
        with self.assertRaises(SemanticError):
            t.lookup('y')                    # local is gone

    def test_undeclared_error(self):
        t = SymbolTable()
        with self.assertRaises(SemanticError):
            t.lookup('unknown')

    def test_duplicate_local_error(self):
        t = SymbolTable()
        t.enter_function()
        t.define(Symbol('x', 'scalar'))
        with self.assertRaises(SemanticError):
            t.define(Symbol('x', 'scalar'))


# ──────────────────────────────────────────────────────────────────────────────
# Global declarations — hoisting
# ──────────────────────────────────────────────────────────────────────────────

class TestGlobalDeclarations(unittest.TestCase):

    def test_global_scalar_registered(self):
        t = analyse('char x;')
        sym = t.lookup('x')
        self.assertEqual(sym.kind, 'scalar')

    def test_global_array_registered(self):
        t = analyse('char buf[8];')
        sym = t.lookup('buf')
        self.assertEqual(sym.kind, 'array')
        self.assertEqual(sym.size, 8)

    def test_func_registered(self):
        t = analyse('void main() {}')
        sym = t.lookup('main')
        self.assertEqual(sym.kind, 'func')
        self.assertEqual(sym.return_type, 'void')
        self.assertEqual(sym.param_count, 0)

    def test_func_with_params_registered(self):
        t = analyse('char add(char a, char b) { return a; }')
        sym = t.lookup('add')
        self.assertEqual(sym.param_count, 2)
        self.assertEqual(sym.return_type, 'char')

    def test_duplicate_global_var_error(self):
        e = check_err('char x; char x;')
        self.assertIn("'x'", str(e))

    def test_duplicate_func_error(self):
        e = check_err('void f() {} void f() {}')
        self.assertIn("'f'", str(e))

    def test_mutual_recursion_ok(self):
        # even() calls odd() which is declared later — hoisting makes this work
        check_ok("""
        char even(char n) { if (n == 0) { return 1; } return odd(n - 1); }
        char odd(char n)  { if (n == 0) { return 0; } return even(n - 1); }
        """)


# ──────────────────────────────────────────────────────────────────────────────
# Local scoping inside functions
# ──────────────────────────────────────────────────────────────────────────────

class TestLocalScoping(unittest.TestCase):

    def test_param_accessible_in_body(self):
        check_ok('char f(char x) { return x; }')

    def test_local_var_accessible(self):
        check_ok('void f() { char x; x = 1; }')

    def test_duplicate_local_var_error(self):
        e = check_err('void f() { char x; char x; }')
        self.assertIn("'x'", str(e))

    def test_duplicate_param_error(self):
        e = check_err('void f(char x, char x) {}')
        self.assertIn("'x'", str(e))

    def test_param_and_local_same_name_error(self):
        e = check_err('void f(char x) { char x; }')
        self.assertIn("'x'", str(e))

    def test_local_not_visible_outside_function(self):
        # Two separate functions can both declare 'i'
        check_ok('void a() { char i; } void b() { char i; }')

    def test_global_visible_inside_function(self):
        check_ok('char g; void f() { g = 1; }')


# ──────────────────────────────────────────────────────────────────────────────
# Undeclared names
# ──────────────────────────────────────────────────────────────────────────────

class TestUndeclared(unittest.TestCase):

    def test_undeclared_var_error(self):
        e = check_err('void f() { x = 1; }')
        self.assertIn("'x'", str(e))

    def test_undeclared_in_condition_error(self):
        e = check_err('void f() { if (x) {} }')
        self.assertIn("'x'", str(e))

    def test_undeclared_in_return_error(self):
        e = check_err('char f() { return x; }')
        self.assertIn("'x'", str(e))

    def test_undeclared_function_call_error(self):
        e = check_err('void f() { bar(); }')
        self.assertIn("'bar'", str(e))

    def test_undeclared_in_for_cond_error(self):
        e = check_err('void f() { for (;x;) {} }')
        self.assertIn("'x'", str(e))

    def test_declared_before_use_ok(self):
        check_ok('void f() { char x; x = 5; }')


# ──────────────────────────────────────────────────────────────────────────────
# Array / scalar confusion
# ──────────────────────────────────────────────────────────────────────────────

class TestArrayChecks(unittest.TestCase):

    def test_array_without_index_error(self):
        e = check_err('char arr[4]; void f() { char x; x = arr; }')
        self.assertIn("arr", str(e))

    def test_scalar_with_index_error(self):
        e = check_err('char x; void f() { char y; y = x[0]; }')
        self.assertIn("'x'", str(e))

    def test_array_with_index_ok(self):
        check_ok('char arr[4]; void f() { char x; x = arr[0]; }')

    def test_array_index_can_be_expression(self):
        check_ok('char arr[4]; void f() { char i; char x; x = arr[i + 1]; }')

    def test_array_assign_ok(self):
        check_ok('char arr[4]; void f() { arr[0] = 5; }')

    def test_local_array_ok(self):
        check_ok('void f() { char buf[8]; buf[0] = 1; }')


# ──────────────────────────────────────────────────────────────────────────────
# Function / variable confusion
# ──────────────────────────────────────────────────────────────────────────────

class TestFuncVarConfusion(unittest.TestCase):

    def test_variable_called_as_function_error(self):
        e = check_err('char x; void f() { x(); }')
        self.assertIn("'x'", str(e))

    def test_function_used_as_variable_error(self):
        e = check_err('char g() { return 1; } void f() { char x; x = g; }')
        self.assertIn("'g'", str(e))


# ──────────────────────────────────────────────────────────────────────────────
# Function call argument counts
# ──────────────────────────────────────────────────────────────────────────────

class TestArgCounts(unittest.TestCase):

    def test_correct_arg_count_ok(self):
        check_ok('char add(char a, char b) { return a; } void f() { add(1, 2); }')

    def test_too_few_args_error(self):
        e = check_err('char add(char a, char b) { return a; } void f() { add(1); }')
        self.assertIn("'add'", str(e))
        self.assertIn("2", str(e))

    def test_too_many_args_error(self):
        e = check_err('char inc(char x) { return x; } void f() { inc(1, 2); }')
        self.assertIn("'inc'", str(e))
        self.assertIn("1", str(e))

    def test_zero_arg_function_ok(self):
        check_ok('char val() { return 1; } void f() { char x; x = val(); }')

    def test_zero_arg_called_with_arg_error(self):
        e = check_err('char val() { return 1; } void f() { val(1); }')
        self.assertIn("'val'", str(e))


# ──────────────────────────────────────────────────────────────────────────────
# Void function in expression context
# ──────────────────────────────────────────────────────────────────────────────

class TestVoidInExpression(unittest.TestCase):

    def test_void_call_as_statement_ok(self):
        check_ok('void reset() {} void f() { reset(); }')

    def test_void_call_in_assign_error(self):
        e = check_err('void reset() {} void f() { char x; x = reset(); }')
        self.assertIn("'reset'", str(e))

    def test_void_call_in_condition_error(self):
        e = check_err('void reset() {} void f() { if (reset()) {} }')
        self.assertIn("'reset'", str(e))

    def test_void_call_as_arg_error(self):
        e = check_err("""
        void reset() {}
        char inc(char x) { return x; }
        void f() { inc(reset()); }
        """)
        self.assertIn("'reset'", str(e))

    def test_void_call_in_return_error(self):
        e = check_err('void reset() {} char f() { return reset(); }')
        self.assertIn("'reset'", str(e))

    def test_char_call_in_expression_ok(self):
        check_ok('char val() { return 1; } void f() { char x; x = val(); }')


# ──────────────────────────────────────────────────────────────────────────────
# Return statement
# ──────────────────────────────────────────────────────────────────────────────

class TestReturn(unittest.TestCase):

    def test_void_return_nothing_ok(self):
        check_ok('void f() { return; }')

    def test_void_return_value_error(self):
        e = check_err('void f() { return 1; }')
        self.assertIn("void", str(e))
        self.assertIn("'f'", str(e))

    def test_char_return_value_ok(self):
        check_ok('char f() { return 1; }')

    def test_char_return_expr_ok(self):
        check_ok('char f(char x) { return x + 1; }')

    def test_void_return_nothing_implicit_ok(self):
        check_ok('void f() {}')   # no return at all is fine


# ──────────────────────────────────────────────────────────────────────────────
# Break statement
# ──────────────────────────────────────────────────────────────────────────────

class TestBreak(unittest.TestCase):

    def test_break_in_while_ok(self):
        check_ok('void f() { while (1) { break; } }')

    def test_break_in_for_ok(self):
        check_ok('void f() { for (;;) { break; } }')

    def test_break_outside_loop_error(self):
        e = check_err('void f() { break; }')
        self.assertIn("break", str(e))

    def test_break_in_if_outside_loop_error(self):
        e = check_err('void f() { char x; if (x) { break; } }')
        self.assertIn("break", str(e))

    def test_break_in_nested_loop_ok(self):
        check_ok('void f() { while (1) { while (1) { break; } break; } }')


# ──────────────────────────────────────────────────────────────────────────────
# Full programs
# ──────────────────────────────────────────────────────────────────────────────

class TestFullPrograms(unittest.TestCase):

    def test_fibonacci(self):
        check_ok("""
        char fib(char n) {
            if (n == 0) { return 0; }
            if (n == 1) { return 1; }
            return fib(n - 1) + fib(n - 2);
        }
        void main() {
            char result;
            result = fib(10);
        }
        """)

    def test_blinky(self):
        check_ok("""
        char led;
        void main() {
            led = 0;
            while (1) {
                led = led ^ 0xFF;
            }
        }
        """)

    def test_array_fill(self):
        check_ok("""
        char arr[8];
        void fill() {
            char i;
            i = 0;
            while (i < 8) {
                arr[i] = i;
                i = i + 1;
            }
        }
        """)

    def test_multiply_via_loop(self):
        check_ok("""
        char mul(char a, char b) {
            char result;
            result = 0;
            while (b) {
                result = result + a;
                b = b - 1;
            }
            return result;
        }
        """)

    def test_for_loop(self):
        check_ok("""
        char sum(char n) {
            char acc;
            acc = 0;
            for (char i = 0; i < n; i++) {
                acc = acc + i;
            }
            return acc;
        }
        """)


if __name__ == '__main__':
    unittest.main(verbosity=2)
