"""
test_lexer.py — Unit tests for the NoobsC lexer.

Each test group targets one concept so failures point directly at the
broken rule.  Run with:
    python -m pytest utils/NoobsC/tests/test_lexer.py -v
or
    python utils/NoobsC/tests/test_lexer.py
"""

import sys
import os
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from lexer import Lexer, Token, TokenType, LexError


# ── helpers ────────────────────────────────────────────────────────────────────

def lex(src: str):
    """Return all tokens (including EOF)."""
    return Lexer(src).tokenize()

def types(src: str):
    """Return only the TokenType values, excluding EOF."""
    return [t.type for t in lex(src) if t.type is not TokenType.EOF]

def first(src: str) -> Token:
    """Return the first non-EOF token."""
    toks = [t for t in lex(src) if t.type is not TokenType.EOF]
    assert toks, "No tokens produced"
    return toks[0]


# ──────────────────────────────────────────────────────────────────────────────
# Integer literals
# ──────────────────────────────────────────────────────────────────────────────

class TestIntLiterals(unittest.TestCase):

    def test_decimal_zero(self):
        t = first('0')
        self.assertEqual(t.type, TokenType.INT_LIT)
        self.assertEqual(t.value, 0)

    def test_decimal_positive(self):
        t = first('255')
        self.assertEqual(t.type, TokenType.INT_LIT)
        self.assertEqual(t.value, 255)

    def test_decimal_multi_digit(self):
        self.assertEqual(first('42').value, 42)

    def test_hex_lowercase(self):
        self.assertEqual(first('0xff').value, 255)

    def test_hex_uppercase(self):
        self.assertEqual(first('0xFF').value, 255)

    def test_hex_mixed(self):
        self.assertEqual(first('0xAb').value, 171)

    def test_hex_zero(self):
        self.assertEqual(first('0x00').value, 0)

    def test_binary(self):
        self.assertEqual(first('0b1010').value, 10)

    def test_binary_all_ones(self):
        self.assertEqual(first('0b11111111').value, 255)

    def test_binary_zero(self):
        self.assertEqual(first('0b0').value, 0)

    def test_bad_hex_no_digits(self):
        with self.assertRaises(LexError):
            lex('0x')

    def test_bad_binary_no_digits(self):
        with self.assertRaises(LexError):
            lex('0b')

    def test_literal_followed_by_semi(self):
        toks = types('10;')
        self.assertEqual(toks, [TokenType.INT_LIT, TokenType.SEMI])

    def test_literal_value_preserved(self):
        # make sure different bases all parse to the same integer
        self.assertEqual(first('0x0a').value, first('10').value)
        self.assertEqual(first('0b00001010').value, first('10').value)


# ──────────────────────────────────────────────────────────────────────────────
# Char literals
# ──────────────────────────────────────────────────────────────────────────────

class TestCharLiterals(unittest.TestCase):

    def test_ascii_letter(self):
        t = first("'A'")
        self.assertEqual(t.type, TokenType.CHAR_LIT)
        self.assertEqual(t.value, 65)

    def test_ascii_digit_char(self):
        self.assertEqual(first("'0'").value, 48)

    def test_escape_newline(self):
        self.assertEqual(first(r"'\n'").value, 10)

    def test_escape_tab(self):
        self.assertEqual(first(r"'\t'").value, 9)

    def test_escape_carriage_return(self):
        self.assertEqual(first(r"'\r'").value, 13)

    def test_escape_null(self):
        self.assertEqual(first(r"'\0'").value, 0)

    def test_escape_backslash(self):
        self.assertEqual(first(r"'\\'").value, 92)

    def test_escape_single_quote(self):
        self.assertEqual(first(r"'\''").value, 39)

    def test_empty_char_literal_error(self):
        with self.assertRaises(LexError):
            lex("''")

    def test_unknown_escape_error(self):
        with self.assertRaises(LexError):
            lex(r"'\q'")

    def test_unclosed_char_literal_error(self):
        with self.assertRaises(LexError):
            lex("'A")


# ──────────────────────────────────────────────────────────────────────────────
# Keywords
# ──────────────────────────────────────────────────────────────────────────────

class TestKeywords(unittest.TestCase):

    def test_char(self):
        self.assertEqual(first('char').type, TokenType.KW_CHAR)

    def test_void(self):
        self.assertEqual(first('void').type, TokenType.KW_VOID)

    def test_if(self):
        self.assertEqual(first('if').type, TokenType.KW_IF)

    def test_else(self):
        self.assertEqual(first('else').type, TokenType.KW_ELSE)

    def test_while(self):
        self.assertEqual(first('while').type, TokenType.KW_WHILE)

    def test_for(self):
        self.assertEqual(first('for').type, TokenType.KW_FOR)

    def test_do(self):
        self.assertEqual(first('do').type, TokenType.KW_DO)

    def test_return(self):
        self.assertEqual(first('return').type, TokenType.KW_RETURN)

    def test_break(self):
        self.assertEqual(first('break').type, TokenType.KW_BREAK)

    def test_keyword_value_is_none(self):
        # keywords carry no payload — only the type matters
        self.assertIsNone(first('char').value)

    def test_keyword_prefix_is_ident(self):
        # "character" starts with "char" but must lex as a single IDENT
        t = first('character')
        self.assertEqual(t.type, TokenType.IDENT)
        self.assertEqual(t.value, 'character')

    def test_keyword_suffix_is_ident(self):
        t = first('iffy')
        self.assertEqual(t.type, TokenType.IDENT)

    def test_keyword_adjacent_ident(self):
        # "char x" → KW_CHAR, IDENT
        self.assertEqual(types('char x'), [TokenType.KW_CHAR, TokenType.IDENT])


# ──────────────────────────────────────────────────────────────────────────────
# Identifiers
# ──────────────────────────────────────────────────────────────────────────────

class TestIdentifiers(unittest.TestCase):

    def test_simple(self):
        t = first('hello')
        self.assertEqual(t.type, TokenType.IDENT)
        self.assertEqual(t.value, 'hello')

    def test_with_digits(self):
        t = first('var2')
        self.assertEqual(t.type, TokenType.IDENT)
        self.assertEqual(t.value, 'var2')

    def test_with_underscores(self):
        t = first('__my_var__')
        self.assertEqual(t.type, TokenType.IDENT)
        self.assertEqual(t.value, '__my_var__')

    def test_leading_underscore(self):
        t = first('_x')
        self.assertEqual(t.type, TokenType.IDENT)

    def test_all_caps(self):
        t = first('LED_GPIO')
        self.assertEqual(t.type, TokenType.IDENT)
        self.assertEqual(t.value, 'LED_GPIO')

    def test_single_char(self):
        t = first('i')
        self.assertEqual(t.type, TokenType.IDENT)


# ──────────────────────────────────────────────────────────────────────────────
# Operators — maximal munch
# ──────────────────────────────────────────────────────────────────────────────

class TestOperators(unittest.TestCase):

    # arithmetic
    def test_plus(self):        self.assertEqual(types('+'),  [TokenType.PLUS])
    def test_minus(self):       self.assertEqual(types('-'),  [TokenType.MINUS])
    def test_star(self):        self.assertEqual(types('*'),  [TokenType.STAR])
    def test_slash(self):       self.assertEqual(types('/'),  [TokenType.SLASH])
    def test_percent(self):     self.assertEqual(types('%'),  [TokenType.PERCENT])

    # bitwise
    def test_amp(self):         self.assertEqual(types('&'),  [TokenType.AMP])
    def test_pipe(self):        self.assertEqual(types('|'),  [TokenType.PIPE])
    def test_caret(self):       self.assertEqual(types('^'),  [TokenType.CARET])
    def test_tilde(self):       self.assertEqual(types('~'),  [TokenType.TILDE])

    # logical
    def test_amp_amp(self):     self.assertEqual(types('&&'), [TokenType.AMP_AMP])
    def test_pipe_pipe(self):   self.assertEqual(types('||'), [TokenType.PIPE_PIPE])
    def test_bang(self):        self.assertEqual(types('!'),  [TokenType.BANG])

    # comparison
    def test_eq_eq(self):       self.assertEqual(types('=='), [TokenType.EQ_EQ])
    def test_bang_eq(self):     self.assertEqual(types('!='), [TokenType.BANG_EQ])
    def test_lt(self):          self.assertEqual(types('<'),  [TokenType.LT])
    def test_gt(self):          self.assertEqual(types('>'),  [TokenType.GT])
    def test_lt_eq(self):       self.assertEqual(types('<='), [TokenType.LT_EQ])
    def test_gt_eq(self):       self.assertEqual(types('>='), [TokenType.GT_EQ])

    # assignment
    def test_eq(self):          self.assertEqual(types('='),  [TokenType.EQ])
    def test_plus_eq(self):     self.assertEqual(types('+='), [TokenType.PLUS_EQ])
    def test_minus_eq(self):    self.assertEqual(types('-='), [TokenType.MINUS_EQ])
    def test_amp_eq(self):      self.assertEqual(types('&='), [TokenType.AMP_EQ])
    def test_pipe_eq(self):     self.assertEqual(types('|='), [TokenType.PIPE_EQ])
    def test_caret_eq(self):    self.assertEqual(types('^='), [TokenType.CARET_EQ])

    # increment / decrement
    def test_plus_plus(self):   self.assertEqual(types('++'), [TokenType.PLUS_PLUS])
    def test_minus_minus(self): self.assertEqual(types('--'), [TokenType.MINUS_MINUS])

    # maximal munch edge cases
    def test_plus_then_eq_separate(self):
        # "= =" is two separate EQ tokens, not EQ_EQ
        self.assertEqual(types('= ='), [TokenType.EQ, TokenType.EQ])

    def test_lt_then_eq_separate(self):
        self.assertEqual(types('< ='), [TokenType.LT, TokenType.EQ])

    def test_amp_not_amp_amp(self):
        # "& x" → AMP, not AMP_AMP
        self.assertEqual(types('& x'), [TokenType.AMP, TokenType.IDENT])

    def test_bang_not_bang_eq(self):
        self.assertEqual(types('! x'), [TokenType.BANG, TokenType.IDENT])


# ──────────────────────────────────────────────────────────────────────────────
# Delimiters
# ──────────────────────────────────────────────────────────────────────────────

class TestDelimiters(unittest.TestCase):

    def test_all_delimiters(self):
        self.assertEqual(
            types('( ) { } [ ] ; ,'),
            [TokenType.LPAREN, TokenType.RPAREN,
             TokenType.LBRACE, TokenType.RBRACE,
             TokenType.LBRACKET, TokenType.RBRACKET,
             TokenType.SEMI, TokenType.COMMA],
        )

    def test_nested_parens(self):
        self.assertEqual(types('(())'), [
            TokenType.LPAREN, TokenType.LPAREN,
            TokenType.RPAREN, TokenType.RPAREN,
        ])


# ──────────────────────────────────────────────────────────────────────────────
# Whitespace and comments
# ──────────────────────────────────────────────────────────────────────────────

class TestWhitespaceAndComments(unittest.TestCase):

    def test_spaces_stripped(self):
        self.assertEqual(types('  char   x  '), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_tabs_stripped(self):
        self.assertEqual(types('char\tx'), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_newlines_stripped(self):
        self.assertEqual(types('char\nx'), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_line_comment_skipped(self):
        self.assertEqual(types('char // comment\nx'), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_line_comment_at_end_of_file(self):
        # no newline after comment — must not crash
        self.assertEqual(types('x // eof'), [TokenType.IDENT])

    def test_block_comment_skipped(self):
        self.assertEqual(types('char /* comment */ x'), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_block_comment_multiline(self):
        self.assertEqual(types('char /*\nline2\n*/ x'), [TokenType.KW_CHAR, TokenType.IDENT])

    def test_block_comment_inline(self):
        self.assertEqual(types('a/*b*/c'), [TokenType.IDENT, TokenType.IDENT])

    def test_unterminated_block_comment(self):
        with self.assertRaises(LexError):
            lex('/* not closed')

    def test_empty_source(self):
        self.assertEqual(types(''), [])

    def test_only_whitespace(self):
        self.assertEqual(types('   \n\t  '), [])

    def test_only_comment(self):
        self.assertEqual(types('// whole file is a comment'), [])


# ──────────────────────────────────────────────────────────────────────────────
# Line and column tracking
# ──────────────────────────────────────────────────────────────────────────────

class TestSourceLocation(unittest.TestCase):

    def test_first_token_line_1(self):
        self.assertEqual(first('x').line, 1)

    def test_first_token_col(self):
        # "   x" → x is at column 4
        self.assertEqual(first('   x').col, 4)

    def test_second_line(self):
        toks = [t for t in lex('char\nx') if t.type is not TokenType.EOF]
        self.assertEqual(toks[1].line, 2)

    def test_col_reset_after_newline(self):
        toks = [t for t in lex('a\nb') if t.type is not TokenType.EOF]
        self.assertEqual(toks[1].col, 1)

    def test_eof_has_location(self):
        t = lex('')[-1]
        self.assertEqual(t.type, TokenType.EOF)
        self.assertEqual(t.line, 1)


# ──────────────────────────────────────────────────────────────────────────────
# Error cases
# ──────────────────────────────────────────────────────────────────────────────

class TestErrors(unittest.TestCase):

    def test_at_sign_unknown(self):
        with self.assertRaises(LexError):
            lex('@')

    def test_hash_unknown(self):
        # NoobsC does not have a preprocessor; # is not a token
        with self.assertRaises(LexError):
            lex('#define')

    def test_question_mark_unknown(self):
        with self.assertRaises(LexError):
            lex('?')

    def test_error_carries_location(self):
        try:
            lex('char\n@')
        except LexError as e:
            self.assertEqual(e.line, 2)
            self.assertEqual(e.col, 1)
        else:
            self.fail("Expected LexError")


# ──────────────────────────────────────────────────────────────────────────────
# EOF behaviour
# ──────────────────────────────────────────────────────────────────────────────

class TestEOF(unittest.TestCase):

    def test_eof_always_last(self):
        toks = lex('x + 1')
        self.assertEqual(toks[-1].type, TokenType.EOF)

    def test_eof_on_empty_source(self):
        toks = lex('')
        self.assertEqual(len(toks), 1)
        self.assertEqual(toks[0].type, TokenType.EOF)

    def test_calling_next_token_past_eof_is_safe(self):
        lexer = Lexer('')
        t1 = lexer.next_token()
        t2 = lexer.next_token()   # should not raise
        self.assertEqual(t1.type, TokenType.EOF)
        self.assertEqual(t2.type, TokenType.EOF)


# ──────────────────────────────────────────────────────────────────────────────
# Real NoobsC snippets (integration)
# ──────────────────────────────────────────────────────────────────────────────

class TestRealSnippets(unittest.TestCase):

    def test_variable_declaration(self):
        self.assertEqual(types('char x;'), [
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.SEMI,
        ])

    def test_array_declaration(self):
        self.assertEqual(types('char arr[8];'), [
            TokenType.KW_CHAR, TokenType.IDENT,
            TokenType.LBRACKET, TokenType.INT_LIT, TokenType.RBRACKET,
            TokenType.SEMI,
        ])

    def test_assignment(self):
        self.assertEqual(types('x = 3 + y;'), [
            TokenType.IDENT, TokenType.EQ,
            TokenType.INT_LIT, TokenType.PLUS, TokenType.IDENT,
            TokenType.SEMI,
        ])

    def test_function_signature(self):
        self.assertEqual(types('char add(char a, char b)'), [
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.LPAREN,
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.COMMA,
            TokenType.KW_CHAR, TokenType.IDENT,
            TokenType.RPAREN,
        ])

    def test_if_statement(self):
        self.assertEqual(types('if (x == 0) {'), [
            TokenType.KW_IF,
            TokenType.LPAREN, TokenType.IDENT, TokenType.EQ_EQ,
            TokenType.INT_LIT, TokenType.RPAREN,
            TokenType.LBRACE,
        ])

    def test_while_loop(self):
        self.assertEqual(types('while (i < 8) {'), [
            TokenType.KW_WHILE,
            TokenType.LPAREN, TokenType.IDENT, TokenType.LT,
            TokenType.INT_LIT, TokenType.RPAREN,
            TokenType.LBRACE,
        ])

    def test_return_statement(self):
        self.assertEqual(types('return a + b;'), [
            TokenType.KW_RETURN,
            TokenType.IDENT, TokenType.PLUS, TokenType.IDENT,
            TokenType.SEMI,
        ])

    def test_full_function(self):
        src = """
        char add(char a, char b) {
            return a + b;
        }
        """
        expected = [
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.LPAREN,
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.COMMA,
            TokenType.KW_CHAR, TokenType.IDENT, TokenType.RPAREN,
            TokenType.LBRACE,
            TokenType.KW_RETURN,
            TokenType.IDENT, TokenType.PLUS, TokenType.IDENT,
            TokenType.SEMI,
            TokenType.RBRACE,
        ]
        self.assertEqual(types(src), expected)

    def test_hex_literal_in_expression(self):
        self.assertEqual(types('x = 0xFF;'), [
            TokenType.IDENT, TokenType.EQ, TokenType.INT_LIT, TokenType.SEMI,
        ])
        t = [t for t in lex('x = 0xFF;') if t.type is TokenType.INT_LIT][0]
        self.assertEqual(t.value, 255)

    def test_memory_mapped_io_pattern(self):
        # pattern from blinky_soc equivalent in C
        src = 'arr[100] = 0xFF;'
        self.assertEqual(types(src), [
            TokenType.IDENT, TokenType.LBRACKET, TokenType.INT_LIT,
            TokenType.RBRACKET, TokenType.EQ, TokenType.INT_LIT, TokenType.SEMI,
        ])


if __name__ == '__main__':
    unittest.main(verbosity=2)
