"""
test_parser.py — Unit tests for the NoobsC parser.

Run with:
    python -m pytest utils/NoobsC/tests/test_parser.py -v
"""

import sys, os, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from lexer    import Lexer
from parser   import Parser, ParseError
from ast_nodes import (
    Program, VarDecl, Param, FuncDecl,
    Block, IfStmt, WhileStmt, ForStmt, ReturnStmt, BreakStmt, ExprStmt,
    Assign, BinOp, UnaryOp, PostfixOp,
    IntLit, CharLit, Var, ArrayIndex, FuncCall,
)


# ── helpers ────────────────────────────────────────────────────────────────────

def parse_prog(src: str) -> Program:
    """Lex + parse a full program."""
    return Parser(Lexer(src).tokenize()).parse()

def parse_expr(src: str):
    """Lex + parse a single expression."""
    return Parser(Lexer(src).tokenize()).parse_expr()

def first_decl(src: str):
    """Return the first declaration in the program."""
    return parse_prog(src).decls[0]

def first_stmt(src: str):
    """Wrap source in void main(){...} and return the first statement."""
    return parse_prog(f"void main() {{ {src} }}").decls[0].body.stmts[0]


# ──────────────────────────────────────────────────────────────────────────────
# Variable declarations
# ──────────────────────────────────────────────────────────────────────────────

class TestVarDecl(unittest.TestCase):

    def test_scalar(self):
        n = first_decl('char x;')
        self.assertIsInstance(n, VarDecl)
        self.assertEqual(n.name, 'x')
        self.assertIsNone(n.size)
        self.assertIsNone(n.init)

    def test_array(self):
        n = first_decl('char buf[16];')
        self.assertIsInstance(n, VarDecl)
        self.assertEqual(n.name, 'buf')
        self.assertEqual(n.size, 16)
        self.assertIsNone(n.init)

    def test_with_initialiser(self):
        n = first_decl('char x = 5;')
        self.assertIsInstance(n, VarDecl)
        self.assertEqual(n.name, 'x')
        self.assertIsNone(n.size)
        self.assertEqual(n.init, IntLit(5))

    def test_initialiser_hex(self):
        n = first_decl('char x = 0xFF;')
        self.assertEqual(n.init, IntLit(255))

    def test_initialiser_char_literal(self):
        n = first_decl("char x = 'A';")
        self.assertEqual(n.init, CharLit(65))

    def test_multiple_declarations(self):
        prog = parse_prog('char a; char b; char c;')
        self.assertEqual(len(prog.decls), 3)
        names = [d.name for d in prog.decls]
        self.assertEqual(names, ['a', 'b', 'c'])

    def test_zero_size_array_error(self):
        with self.assertRaises(ParseError):
            parse_prog('char arr[0];')

    def test_missing_semi_error(self):
        with self.assertRaises(ParseError):
            parse_prog('char x')

    def test_missing_name_error(self):
        with self.assertRaises(ParseError):
            parse_prog('char ;')


# ──────────────────────────────────────────────────────────────────────────────
# Function declarations
# ──────────────────────────────────────────────────────────────────────────────

class TestFuncDecl(unittest.TestCase):

    def test_void_no_params(self):
        n = first_decl('void main() {}')
        self.assertIsInstance(n, FuncDecl)
        self.assertEqual(n.return_type, 'void')
        self.assertEqual(n.name, 'main')
        self.assertEqual(n.params, [])

    def test_char_return(self):
        n = first_decl('char get() {}')
        self.assertEqual(n.return_type, 'char')

    def test_single_param(self):
        n = first_decl('void foo(char x) {}')
        self.assertEqual(len(n.params), 1)
        self.assertEqual(n.params[0].name, 'x')

    def test_multiple_params(self):
        n = first_decl('char add(char a, char b, char c) {}')
        self.assertEqual(len(n.params), 3)
        names = [p.name for p in n.params]
        self.assertEqual(names, ['a', 'b', 'c'])

    def test_body_has_statements(self):
        n = first_decl('void f() { char x; char y; }')
        self.assertEqual(len(n.body.stmts), 2)

    def test_empty_body(self):
        n = first_decl('void f() {}')
        self.assertEqual(n.body.stmts, [])

    def test_missing_body_error(self):
        with self.assertRaises(ParseError):
            parse_prog('void f();')

    def test_multiple_functions(self):
        prog = parse_prog('void a() {} void b() {} void c() {}')
        self.assertEqual(len(prog.decls), 3)
        names = [d.name for d in prog.decls]
        self.assertEqual(names, ['a', 'b', 'c'])


# ──────────────────────────────────────────────────────────────────────────────
# If statement
# ──────────────────────────────────────────────────────────────────────────────

class TestIfStmt(unittest.TestCase):

    def test_if_only(self):
        n = first_stmt('if (x) {}')
        self.assertIsInstance(n, IfStmt)
        self.assertEqual(n.cond, Var('x'))
        self.assertIsNone(n.else_block)

    def test_if_else(self):
        n = first_stmt('if (x) {} else {}')
        self.assertIsInstance(n, IfStmt)
        self.assertIsNotNone(n.else_block)

    def test_condition_is_comparison(self):
        n = first_stmt('if (x == 0) {}')
        self.assertIsInstance(n.cond, BinOp)
        self.assertEqual(n.cond.op, '==')

    def test_then_block_has_stmt(self):
        n = first_stmt('if (x) { char y; }')
        self.assertEqual(len(n.then_block.stmts), 1)

    def test_else_block_has_stmt(self):
        n = first_stmt('if (x) {} else { char y; }')
        self.assertEqual(len(n.else_block.stmts), 1)

    def test_nested_if(self):
        n = first_stmt('if (a) { if (b) {} }')
        inner = n.then_block.stmts[0]
        self.assertIsInstance(inner, IfStmt)


# ──────────────────────────────────────────────────────────────────────────────
# While statement
# ──────────────────────────────────────────────────────────────────────────────

class TestWhileStmt(unittest.TestCase):

    def test_basic(self):
        n = first_stmt('while (i) {}')
        self.assertIsInstance(n, WhileStmt)
        self.assertEqual(n.cond, Var('i'))

    def test_condition_less_than(self):
        n = first_stmt('while (i < 10) {}')
        self.assertIsInstance(n.cond, BinOp)
        self.assertEqual(n.cond.op, '<')
        self.assertEqual(n.cond.right, IntLit(10))

    def test_body_has_stmts(self):
        n = first_stmt('while (x) { char a; char b; }')
        self.assertEqual(len(n.body.stmts), 2)


# ──────────────────────────────────────────────────────────────────────────────
# For statement
# ──────────────────────────────────────────────────────────────────────────────

class TestForStmt(unittest.TestCase):

    def test_full_for(self):
        n = first_stmt('for (char i = 0; i < 8; i++) {}')
        self.assertIsInstance(n, ForStmt)
        self.assertIsInstance(n.init,   VarDecl)
        self.assertIsInstance(n.cond,   BinOp)
        self.assertIsInstance(n.update, PostfixOp)

    def test_init_is_var_decl(self):
        n = first_stmt('for (char i = 0; i < 8; i++) {}')
        self.assertEqual(n.init.name, 'i')
        self.assertEqual(n.init.init, IntLit(0))

    def test_no_init(self):
        n = first_stmt('for (; i < 8; i++) {}')
        self.assertIsNone(n.init)

    def test_no_cond(self):
        n = first_stmt('for (char i = 0;; i++) {}')
        self.assertIsNone(n.cond)

    def test_no_update(self):
        n = first_stmt('for (char i = 0; i < 8;) {}')
        self.assertIsNone(n.update)

    def test_all_empty(self):
        n = first_stmt('for (;;) {}')
        self.assertIsNone(n.init)
        self.assertIsNone(n.cond)
        self.assertIsNone(n.update)

    def test_expr_stmt_init(self):
        n = first_stmt('for (i = 0; i < 8; i++) {}')
        self.assertIsInstance(n.init, ExprStmt)


# ──────────────────────────────────────────────────────────────────────────────
# Return and break
# ──────────────────────────────────────────────────────────────────────────────

class TestReturnBreak(unittest.TestCase):

    def test_return_with_expr(self):
        n = first_stmt('return x;')
        self.assertIsInstance(n, ReturnStmt)
        self.assertEqual(n.expr, Var('x'))

    def test_return_void(self):
        n = first_stmt('return;')
        self.assertIsInstance(n, ReturnStmt)
        self.assertIsNone(n.expr)

    def test_return_expression(self):
        n = first_stmt('return a + b;')
        self.assertIsInstance(n.expr, BinOp)
        self.assertEqual(n.expr.op, '+')

    def test_break(self):
        n = first_stmt('break;')
        self.assertIsInstance(n, BreakStmt)

    def test_return_missing_semi_error(self):
        with self.assertRaises(ParseError):
            first_stmt('return x')


# ──────────────────────────────────────────────────────────────────────────────
# Literals and variables
# ──────────────────────────────────────────────────────────────────────────────

class TestPrimaries(unittest.TestCase):

    def test_int_literal(self):
        n = parse_expr('42')
        self.assertEqual(n, IntLit(42))

    def test_hex_literal(self):
        n = parse_expr('0xFF')
        self.assertEqual(n, IntLit(255))

    def test_char_literal(self):
        n = parse_expr("'A'")
        self.assertEqual(n, CharLit(65))

    def test_variable(self):
        n = parse_expr('foo')
        self.assertEqual(n, Var('foo'))

    def test_parenthesised(self):
        n = parse_expr('(42)')
        self.assertEqual(n, IntLit(42))

    def test_double_parenthesised(self):
        n = parse_expr('((x))')
        self.assertEqual(n, Var('x'))

    def test_array_index(self):
        n = parse_expr('arr[3]')
        self.assertIsInstance(n, ArrayIndex)
        self.assertEqual(n.name, 'arr')
        self.assertEqual(n.index, IntLit(3))

    def test_array_index_expr(self):
        n = parse_expr('arr[i + 1]')
        self.assertIsInstance(n.index, BinOp)

    def test_func_call_no_args(self):
        n = parse_expr('foo()')
        self.assertIsInstance(n, FuncCall)
        self.assertEqual(n.name, 'foo')
        self.assertEqual(n.args, [])

    def test_func_call_one_arg(self):
        n = parse_expr('foo(x)')
        self.assertEqual(len(n.args), 1)
        self.assertEqual(n.args[0], Var('x'))

    def test_func_call_multiple_args(self):
        n = parse_expr('add(1, 2, 3)')
        self.assertEqual(len(n.args), 3)

    def test_unknown_token_error(self):
        with self.assertRaises(ParseError):
            parse_expr(';')


# ──────────────────────────────────────────────────────────────────────────────
# Unary and postfix operators
# ──────────────────────────────────────────────────────────────────────────────

class TestUnaryPostfix(unittest.TestCase):

    def test_logical_not(self):
        n = parse_expr('!x')
        self.assertIsInstance(n, UnaryOp)
        self.assertEqual(n.op, '!')
        self.assertEqual(n.operand, Var('x'))

    def test_bitwise_not(self):
        n = parse_expr('~x')
        self.assertEqual(n.op, '~')

    def test_unary_minus(self):
        n = parse_expr('-x')
        self.assertEqual(n.op, '-')

    def test_double_not(self):
        # !!x → UnaryOp('!', UnaryOp('!', Var('x')))
        n = parse_expr('!!x')
        self.assertIsInstance(n, UnaryOp)
        self.assertIsInstance(n.operand, UnaryOp)

    def test_postfix_increment(self):
        n = parse_expr('x++')
        self.assertIsInstance(n, PostfixOp)
        self.assertEqual(n.op, '++')
        self.assertEqual(n.operand, Var('x'))

    def test_postfix_decrement(self):
        n = parse_expr('x--')
        self.assertEqual(n.op, '--')

    def test_unary_higher_than_multiply(self):
        # -x * y → BinOp('*', UnaryOp('-', x), y)  not  UnaryOp('-', BinOp(*,x,y))
        n = parse_expr('-x * y')
        self.assertIsInstance(n, BinOp)
        self.assertIsInstance(n.left, UnaryOp)


# ──────────────────────────────────────────────────────────────────────────────
# Binary operators
# ──────────────────────────────────────────────────────────────────────────────

class TestBinaryOps(unittest.TestCase):

    def test_addition(self):
        n = parse_expr('a + b')
        self.assertEqual(n, BinOp('+', Var('a'), Var('b')))

    def test_subtraction(self):
        n = parse_expr('a - b')
        self.assertEqual(n.op, '-')

    def test_multiplication(self):
        n = parse_expr('a * b')
        self.assertEqual(n.op, '*')

    def test_division(self):
        n = parse_expr('a / b')
        self.assertEqual(n.op, '/')

    def test_modulo(self):
        n = parse_expr('a % b')
        self.assertEqual(n.op, '%')

    def test_bitwise_and(self):
        n = parse_expr('a & b')
        self.assertEqual(n.op, '&')

    def test_bitwise_or(self):
        n = parse_expr('a | b')
        self.assertEqual(n.op, '|')

    def test_bitwise_xor(self):
        n = parse_expr('a ^ b')
        self.assertEqual(n.op, '^')

    def test_logical_and(self):
        n = parse_expr('a && b')
        self.assertEqual(n.op, '&&')

    def test_logical_or(self):
        n = parse_expr('a || b')
        self.assertEqual(n.op, '||')

    def test_equal(self):
        n = parse_expr('a == b')
        self.assertEqual(n.op, '==')

    def test_not_equal(self):
        n = parse_expr('a != b')
        self.assertEqual(n.op, '!=')

    def test_less_than(self):
        n = parse_expr('a < b')
        self.assertEqual(n.op, '<')

    def test_greater_equal(self):
        n = parse_expr('a >= b')
        self.assertEqual(n.op, '>=')

    def test_left_associative(self):
        # a + b + c → BinOp('+', BinOp('+', a, b), c)
        n = parse_expr('a + b + c')
        self.assertIsInstance(n, BinOp)
        self.assertIsInstance(n.left, BinOp)    # (a + b) on the left
        self.assertEqual(n.right, Var('c'))


# ──────────────────────────────────────────────────────────────────────────────
# Operator precedence — the most important correctness tests
# ──────────────────────────────────────────────────────────────────────────────

class TestPrecedence(unittest.TestCase):

    def test_mul_before_add(self):
        # 1 + 2 * 3  →  +(1, *(2, 3))
        n = parse_expr('1 + 2 * 3')
        self.assertIsInstance(n, BinOp)
        self.assertEqual(n.op, '+')
        self.assertEqual(n.left, IntLit(1))
        self.assertIsInstance(n.right, BinOp)
        self.assertEqual(n.right.op, '*')

    def test_add_before_comparison(self):
        # a + 1 < b  →  <(+(a,1), b)
        n = parse_expr('a + 1 < b')
        self.assertEqual(n.op, '<')
        self.assertIsInstance(n.left, BinOp)
        self.assertEqual(n.left.op, '+')

    def test_comparison_before_logical_and(self):
        # a < b && c > d  →  &&(<(a,b), >(c,d))
        n = parse_expr('a < b && c > d')
        self.assertEqual(n.op, '&&')
        self.assertEqual(n.left.op, '<')
        self.assertEqual(n.right.op, '>')

    def test_logical_and_before_logical_or(self):
        # a || b && c  →  ||(a, &&(b, c))
        n = parse_expr('a || b && c')
        self.assertEqual(n.op, '||')
        self.assertIsInstance(n.right, BinOp)
        self.assertEqual(n.right.op, '&&')

    def test_parens_override_precedence(self):
        # (1 + 2) * 3  →  *( +(1,2), 3 )
        n = parse_expr('(1 + 2) * 3')
        self.assertEqual(n.op, '*')
        self.assertIsInstance(n.left, BinOp)
        self.assertEqual(n.left.op, '+')

    def test_unary_before_multiply(self):
        # -a * b  →  *(-(a), b)
        n = parse_expr('-a * b')
        self.assertEqual(n.op, '*')
        self.assertIsInstance(n.left, UnaryOp)

    def test_postfix_before_unary(self):
        # !x++  →  !(x++)
        n = parse_expr('!x++')
        self.assertIsInstance(n, UnaryOp)
        self.assertEqual(n.op, '!')
        self.assertIsInstance(n.operand, PostfixOp)

    def test_complex_expression(self):
        # a + b * c - d  →  -( +(a, *(b,c)), d )
        n = parse_expr('a + b * c - d')
        self.assertEqual(n.op, '-')
        self.assertEqual(n.left.op, '+')
        self.assertEqual(n.left.right.op, '*')


# ──────────────────────────────────────────────────────────────────────────────
# Assignment
# ──────────────────────────────────────────────────────────────────────────────

class TestAssignment(unittest.TestCase):

    def test_simple_assign(self):
        n = parse_expr('x = 5')
        self.assertIsInstance(n, Assign)
        self.assertEqual(n.op, '=')
        self.assertEqual(n.target, Var('x'))
        self.assertEqual(n.value, IntLit(5))

    def test_plus_assign(self):
        n = parse_expr('x += 1')
        self.assertEqual(n.op, '+=')

    def test_minus_assign(self):
        n = parse_expr('x -= 1')
        self.assertEqual(n.op, '-=')

    def test_amp_assign(self):
        n = parse_expr('x &= 3')
        self.assertEqual(n.op, '&=')

    def test_pipe_assign(self):
        n = parse_expr('x |= 3')
        self.assertEqual(n.op, '|=')

    def test_caret_assign(self):
        n = parse_expr('x ^= 3')
        self.assertEqual(n.op, '^=')

    def test_array_assign(self):
        n = parse_expr('arr[i] = 5')
        self.assertIsInstance(n, Assign)
        self.assertIsInstance(n.target, ArrayIndex)

    def test_right_associative(self):
        # x = y = 5  →  Assign(x, Assign(y, 5))
        n = parse_expr('x = y = 5')
        self.assertIsInstance(n, Assign)
        self.assertIsInstance(n.value, Assign)

    def test_assign_rhs_is_expression(self):
        n = parse_expr('x = a + b')
        self.assertIsInstance(n.value, BinOp)

    def test_literal_assign_target_error(self):
        with self.assertRaises(ParseError):
            parse_expr('5 = x')

    def test_call_assign_target_error(self):
        with self.assertRaises(ParseError):
            parse_expr('foo() = x')


# ──────────────────────────────────────────────────────────────────────────────
# Full programs (integration)
# ──────────────────────────────────────────────────────────────────────────────

class TestFullPrograms(unittest.TestCase):

    def test_fibonacci(self):
        src = """
        char fib(char n) {
            if (n == 0) { return 0; }
            if (n == 1) { return 1; }
            return fib(n - 1) + fib(n - 2);
        }
        void main() {
            char result = fib(10);
        }
        """
        prog = parse_prog(src)
        self.assertEqual(len(prog.decls), 2)
        fib  = prog.decls[0]
        main = prog.decls[1]
        self.assertIsInstance(fib,  FuncDecl)
        self.assertIsInstance(main, FuncDecl)
        self.assertEqual(fib.name,  'fib')
        self.assertEqual(main.name, 'main')

    def test_blinky_pattern(self):
        # mirrors the LED toggle loop from blinky_soc
        src = """
        char led;
        void main() {
            led = 0;
            while (1) {
                led = led ^ 0xFF;
            }
        }
        """
        prog = parse_prog(src)
        self.assertEqual(len(prog.decls), 2)
        self.assertIsInstance(prog.decls[0], VarDecl)
        self.assertIsInstance(prog.decls[1], FuncDecl)

    def test_array_fill_loop(self):
        src = """
        char arr[8];
        void fill() {
            char i = 0;
            while (i < 8) {
                arr[i] = i;
                i = i + 1;
            }
        }
        """
        prog = parse_prog(src)
        fill  = prog.decls[1]
        while_ = fill.body.stmts[1]
        self.assertIsInstance(while_, WhileStmt)
        assign = while_.body.stmts[0]
        self.assertIsInstance(assign, ExprStmt)
        self.assertIsInstance(assign.expr, Assign)
        self.assertIsInstance(assign.expr.target, ArrayIndex)

    def test_multiply_via_loop(self):
        src = """
        char mul(char a, char b) {
            char result = 0;
            while (b) {
                result = result + a;
                b = b - 1;
            }
            return result;
        }
        """
        prog = parse_prog(src)
        mul  = prog.decls[0]
        self.assertEqual(len(mul.params), 2)
        self.assertIsInstance(mul.body.stmts[-1], ReturnStmt)


if __name__ == '__main__':
    unittest.main(verbosity=2)
