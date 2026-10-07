"""
lexer.py — Phase 1 of the NoobsC compiler: Lexical Analysis

═══════════════════════════════════════════════════════════════
THEORY: What is a Lexer?
═══════════════════════════════════════════════════════════════

Source text is just a stream of characters. Before any grammar can
be understood, those characters must be grouped into meaningful
"words" — called TOKENS. That is the lexer's only job.

Example:
    "char x = 3 + y;"
    →  [KW_CHAR] [IDENT "x"] [EQ] [INT_LIT 3] [PLUS] [IDENT "y"] [SEMI]

The lexer answers: "what are the atomic units of the language?"
The parser (next phase) answers: "what sentence structure do they form?"

THEORY: Why Regular Expressions / Finite Automata?
───────────────────────────────────────────────────
Every token type can be described by a REGULAR EXPRESSION:
  - integer literal : [0-9]+  or  0x[0-9a-fA-F]+
  - identifier      : [a-zA-Z_][a-zA-Z0-9_]*
  - keyword         : a fixed string (special case of identifier)

A regular expression can be mechanically compiled into a
DETERMINISTIC FINITE AUTOMATON (DFA) — a state machine that reads
one character at a time and decides, in O(1) per character, which
token is being formed.  Tools like `flex` do this automatically.

We use a hand-written lexer (what GCC/Clang also do in practice)
because it gives cleaner code and better error messages.

THEORY: Maximal Munch
─────────────────────
When two rules could match at the current position, always take
the LONGEST match. Examples:
  - "++" is PLUS_PLUS, not PLUS followed by PLUS
  - "<=" is LT_EQ,    not LT   followed by EQ
  - "charter" is IDENT("charter"), not KW_CHAR + IDENT("ter")

This is implemented by peeking one character ahead before
committing to a shorter token.
═══════════════════════════════════════════════════════════════
"""

from __future__ import annotations
from dataclasses import dataclass
from enum import Enum, auto
from typing import List, Optional


# ──────────────────────────────────────────────────────────────
# Token types
# ──────────────────────────────────────────────────────────────

class TokenType(Enum):
    # Literals
    INT_LIT     = auto()   # 42  0xFF  0b1010
    CHAR_LIT    = auto()   # 'A'  '\n'

    # Names
    IDENT       = auto()   # identifiers that are not keywords

    # Keywords
    KW_CHAR     = auto()   # char
    KW_VOID     = auto()   # void
    KW_IF       = auto()   # if
    KW_ELSE     = auto()   # else
    KW_WHILE    = auto()   # while
    KW_FOR      = auto()   # for
    KW_DO       = auto()   # do
    KW_RETURN   = auto()   # return
    KW_BREAK    = auto()   # break

    # Arithmetic operators
    PLUS        = auto()   # +
    MINUS       = auto()   # -
    STAR        = auto()   # * (multiply; no pointer deref in NoobsC v1)
    SLASH       = auto()   # /
    PERCENT     = auto()   # %

    # Bitwise operators
    AMP         = auto()   # &
    PIPE        = auto()   # |
    CARET       = auto()   # ^
    TILDE       = auto()   # ~

    # Logical operators
    AMP_AMP     = auto()   # &&
    PIPE_PIPE   = auto()   # ||
    BANG        = auto()   # !

    # Comparison operators
    EQ_EQ       = auto()   # ==
    BANG_EQ     = auto()   # !=
    LT          = auto()   # <
    GT          = auto()   # >
    LT_EQ       = auto()   # <=
    GT_EQ       = auto()   # >=

    # Assignment operators
    EQ          = auto()   # =
    PLUS_EQ     = auto()   # +=
    MINUS_EQ    = auto()   # -=
    AMP_EQ      = auto()   # &=
    PIPE_EQ     = auto()   # |=
    CARET_EQ    = auto()   # ^=

    # Increment / Decrement
    PLUS_PLUS   = auto()   # ++
    MINUS_MINUS = auto()   # --

    # Delimiters / punctuation
    LPAREN      = auto()   # (
    RPAREN      = auto()   # )
    LBRACE      = auto()   # {
    RBRACE      = auto()   # }
    LBRACKET    = auto()   # [
    RBRACKET    = auto()   # ]
    SEMI        = auto()   # ;
    COMMA       = auto()   # ,

    # Sentinel
    EOF         = auto()


# Maps identifier text → keyword token type.
# Any identifier not found here stays as IDENT.
KEYWORDS: dict[str, TokenType] = {
    'char':   TokenType.KW_CHAR,
    'void':   TokenType.KW_VOID,
    'if':     TokenType.KW_IF,
    'else':   TokenType.KW_ELSE,
    'while':  TokenType.KW_WHILE,
    'for':    TokenType.KW_FOR,
    'do':     TokenType.KW_DO,
    'return': TokenType.KW_RETURN,
    'break':  TokenType.KW_BREAK,
}


# ──────────────────────────────────────────────────────────────
# Token dataclass
# ──────────────────────────────────────────────────────────────

@dataclass
class Token:
    type:  TokenType
    value: object    # int for INT_LIT/CHAR_LIT, str for IDENT, None otherwise
    line:  int       # 1-based source line
    col:   int       # 1-based source column

    def __repr__(self) -> str:
        loc = f"{self.line}:{self.col}"
        if self.value is not None:
            return f"Token({self.type.name}, {self.value!r}, {loc})"
        return f"Token({self.type.name}, {loc})"


# ──────────────────────────────────────────────────────────────
# Error type
# ──────────────────────────────────────────────────────────────

class LexError(Exception):
    def __init__(self, msg: str, line: int, col: int):
        super().__init__(f"Lex error at {line}:{col}: {msg}")
        self.line = line
        self.col  = col


# ──────────────────────────────────────────────────────────────
# Lexer
# ──────────────────────────────────────────────────────────────

class Lexer:
    """
    Hand-written lexer for NoobsC.

    The public interface is:
        tokens = Lexer(source_text).tokenize()    # returns List[Token]
        tok    = lexer.next_token()               # one at a time
    """

    def __init__(self, source: str):
        self.src  = source
        self.pos  = 0
        self.line = 1
        self.col  = 1

    # ── low-level character helpers ───────────────────────────

    def _peek(self, offset: int = 0) -> Optional[str]:
        """Return the character at pos+offset without consuming it."""
        idx = self.pos + offset
        return self.src[idx] if idx < len(self.src) else None

    def _advance(self) -> str:
        """Consume and return the current character, updating line/col."""
        ch = self.src[self.pos]
        self.pos += 1
        if ch == '\n':
            self.line += 1
            self.col  = 1
        else:
            self.col += 1
        return ch

    def _match(self, expected: str) -> bool:
        """Consume the next character only if it equals expected (maximal munch)."""
        if self._peek() == expected:
            self._advance()
            return True
        return False

    # ── whitespace and comment skipping ──────────────────────

    def _skip_whitespace_and_comments(self) -> None:
        while self.pos < len(self.src):
            ch = self._peek()
            if ch in ' \t\r\n':
                self._advance()
            elif ch == '/' and self._peek(1) == '/':
                # line comment — skip to end of line
                while self.pos < len(self.src) and self._peek() != '\n':
                    self._advance()
            elif ch == '/' and self._peek(1) == '*':
                # block comment — skip until */
                start_line, start_col = self.line, self.col
                self._advance(); self._advance()      # consume /*
                while self.pos < len(self.src):
                    if self._peek() == '*' and self._peek(1) == '/':
                        self._advance(); self._advance()  # consume */
                        break
                    self._advance()
                else:
                    raise LexError("Unterminated block comment", start_line, start_col)
            else:
                break

    # ── specialised scanners ──────────────────────────────────

    def _scan_number(self) -> Token:
        """
        Scan a numeric literal: decimal, 0x hex, or 0b binary.
        The CPU's assembler already supports all three; so does NoobsC.
        """
        line, col = self.line, self.col
        text = ''

        if self._peek() == '0' and self._peek(1) in ('x', 'X'):
            text += self._advance() + self._advance()   # 0x
            if not (self._peek() and self._peek() in '0123456789abcdefABCDEF'):
                raise LexError("Expected hex digit after 0x", line, col)
            while self._peek() and self._peek() in '0123456789abcdefABCDEF':
                text += self._advance()
            return Token(TokenType.INT_LIT, int(text, 16), line, col)

        if self._peek() == '0' and self._peek(1) in ('b', 'B'):
            text += self._advance() + self._advance()   # 0b
            if self._peek() not in ('0', '1'):
                raise LexError("Expected binary digit after 0b", line, col)
            while self._peek() in ('0', '1'):
                text += self._advance()
            return Token(TokenType.INT_LIT, int(text, 2), line, col)

        while self._peek() and self._peek().isdigit():
            text += self._advance()
        return Token(TokenType.INT_LIT, int(text, 10), line, col)

    def _scan_char_lit(self) -> Token:
        """
        Scan a character literal: 'c' or an escape sequence like '\\n'.
        The value stored is the integer ASCII code.
        """
        line, col = self.line, self.col
        self._advance()   # consume opening '

        if self._peek() == "'":
            raise LexError("Empty character literal", line, col)

        if self._peek() == '\\':
            self._advance()   # consume backslash
            esc = self._advance()
            escape_map = {'n': 10, 't': 9, 'r': 13, '0': 0, '\\': 92, "'": 39}
            if esc not in escape_map:
                raise LexError(f"Unknown escape sequence '\\{esc}'", line, col)
            val = escape_map[esc]
        else:
            val = ord(self._advance())

        if self._peek() != "'":
            raise LexError("Expected closing ' after character literal", line, col)
        self._advance()   # consume closing '
        return Token(TokenType.CHAR_LIT, val, line, col)

    def _scan_ident_or_keyword(self) -> Token:
        """
        Scan an identifier.  If the result is in KEYWORDS, return the
        keyword token type; otherwise return IDENT.

        This implements maximal munch for keywords: 'charter' is scanned
        as a single identifier, not KW_CHAR + IDENT('ter').
        """
        line, col = self.line, self.col
        text = ''
        while self._peek() and (self._peek().isalnum() or self._peek() == '_'):
            text += self._advance()
        tt = KEYWORDS.get(text, TokenType.IDENT)
        return Token(tt, text if tt is TokenType.IDENT else None, line, col)

    # ── main token scanner ────────────────────────────────────

    def next_token(self) -> Token:
        """Return the next token from the source, or EOF repeatedly at end."""
        self._skip_whitespace_and_comments()

        if self.pos >= len(self.src):
            return Token(TokenType.EOF, None, self.line, self.col)

        line, col = self.line, self.col
        ch = self._peek()

        if ch.isdigit():
            return self._scan_number()

        if ch == "'":
            return self._scan_char_lit()

        if ch.isalpha() or ch == '_':
            return self._scan_ident_or_keyword()

        # consume the leading character, then decide using the next one
        self._advance()

        # ── two-character operators (maximal munch) ───────────
        if ch == '+':
            if self._match('+'): return Token(TokenType.PLUS_PLUS,   None, line, col)
            if self._match('='): return Token(TokenType.PLUS_EQ,     None, line, col)
            return Token(TokenType.PLUS, None, line, col)

        if ch == '-':
            if self._match('-'): return Token(TokenType.MINUS_MINUS, None, line, col)
            if self._match('='): return Token(TokenType.MINUS_EQ,    None, line, col)
            return Token(TokenType.MINUS, None, line, col)

        if ch == '&':
            if self._match('&'): return Token(TokenType.AMP_AMP,     None, line, col)
            if self._match('='): return Token(TokenType.AMP_EQ,      None, line, col)
            return Token(TokenType.AMP, None, line, col)

        if ch == '|':
            if self._match('|'): return Token(TokenType.PIPE_PIPE,   None, line, col)
            if self._match('='): return Token(TokenType.PIPE_EQ,     None, line, col)
            return Token(TokenType.PIPE, None, line, col)

        if ch == '^':
            if self._match('='): return Token(TokenType.CARET_EQ,   None, line, col)
            return Token(TokenType.CARET, None, line, col)

        if ch == '!':
            if self._match('='): return Token(TokenType.BANG_EQ,    None, line, col)
            return Token(TokenType.BANG, None, line, col)

        if ch == '=':
            if self._match('='): return Token(TokenType.EQ_EQ,      None, line, col)
            return Token(TokenType.EQ, None, line, col)

        if ch == '<':
            if self._match('='): return Token(TokenType.LT_EQ,      None, line, col)
            return Token(TokenType.LT, None, line, col)

        if ch == '>':
            if self._match('='): return Token(TokenType.GT_EQ,      None, line, col)
            return Token(TokenType.GT, None, line, col)

        # ── single-character tokens ───────────────────────────
        single = {
            '*': TokenType.STAR,
            '/': TokenType.SLASH,
            '%': TokenType.PERCENT,
            '~': TokenType.TILDE,
            '(': TokenType.LPAREN,
            ')': TokenType.RPAREN,
            '{': TokenType.LBRACE,
            '}': TokenType.RBRACE,
            '[': TokenType.LBRACKET,
            ']': TokenType.RBRACKET,
            ';': TokenType.SEMI,
            ',': TokenType.COMMA,
        }
        if ch in single:
            return Token(single[ch], None, line, col)

        raise LexError(f"Unexpected character: {ch!r}", line, col)

    def tokenize(self) -> List[Token]:
        """Convenience method: lex the entire source and return all tokens."""
        tokens: List[Token] = []
        while True:
            tok = self.next_token()
            tokens.append(tok)
            if tok.type is TokenType.EOF:
                break
        return tokens
