"""
ast_nodes.py — Abstract Syntax Tree node definitions for NoobsC.

═══════════════════════════════════════════════════════════════
THEORY: What is an AST?
═══════════════════════════════════════════════════════════════

After the parser reads the token stream, it builds a tree that captures
the meaning of the program, throwing away tokens that only existed to
satisfy grammar rules (semicolons, parentheses, braces).

Example — source text:
    x = 3 + y;

Example — token stream (lexer output):
    IDENT("x")  EQ  INT_LIT(3)  PLUS  IDENT("y")  SEMI

Example — AST (parser output):
    ExprStmt
    └── Assign("=")
          ├── Var("x")          ← left side
          └── BinOp("+")        ← right side
                ├── IntLit(3)
                └── Var("y")

The semicolon and the "=" token are gone — the tree structure itself
encodes that information.  Every later phase (semantic analysis, code
generation) works on this tree, not on raw tokens.

THEORY: Node hierarchy
───────────────────────
All nodes inherit from Node.  There are three families:

  Declarations  — things at the top of a file or function
  Statements    — things inside a function body
  Expressions   — things that produce a value

═══════════════════════════════════════════════════════════════
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List, Optional


# ── Base ───────────────────────────────────────────────────────────────────────

class Node:
    """Base class for every AST node."""
    pass


# ──────────────────────────────────────────────────────────────────────────────
# Top level
# ──────────────────────────────────────────────────────────────────────────────

@dataclass
class Program(Node):
    """The root node.  Contains all top-level declarations."""
    decls: List[Node]


# ──────────────────────────────────────────────────────────────────────────────
# Declarations
# ──────────────────────────────────────────────────────────────────────────────

@dataclass
class VarDecl(Node):
    """
    char x;           → name='x', size=None, init=None
    char arr[8];      → name='arr', size=8, init=None
    char x = 5;       → name='x', size=None, init=IntLit(5)
    """
    name: str
    size: Optional[int]   # None = scalar, N = array of N chars
    init: Optional[Node]  # optional initialiser expression (scalars only)
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class Param(Node):
    """A single function parameter: char name"""
    name: str
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class FuncDecl(Node):
    """
    char add(char a, char b) { ... }
    void main() { ... }
    """
    return_type: str         # 'char' or 'void'
    name:        str
    params:      List[Param]
    body:        Block
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


# ──────────────────────────────────────────────────────────────────────────────
# Statements
# ──────────────────────────────────────────────────────────────────────────────

@dataclass
class Block(Node):
    """A brace-enclosed sequence of statements: { stmt* }"""
    stmts: List[Node]
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class IfStmt(Node):
    """if (cond) block  or  if (cond) block else block"""
    cond:       Node
    then_block: Block
    else_block: Optional[Block]
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class WhileStmt(Node):
    """while (cond) block"""
    cond: Node
    body: Block
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class ForStmt(Node):
    """
    for (init; cond; update) block
    Any of init / cond / update may be None.
    init is either VarDecl or ExprStmt or None.
    """
    init:   Optional[Node]
    cond:   Optional[Node]
    update: Optional[Node]
    body:   Block
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class ReturnStmt(Node):
    """return expr;  or  return;"""
    expr: Optional[Node]
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class BreakStmt(Node):
    """break;"""
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class ExprStmt(Node):
    """An expression used as a statement: expr;"""
    expr: Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


# ──────────────────────────────────────────────────────────────────────────────
# Expressions
# ──────────────────────────────────────────────────────────────────────────────

@dataclass
class Assign(Node):
    """
    x = expr      op='='
    x += expr     op='+='
    x &= expr     op='&='   etc.
    target must be Var or ArrayIndex (checked by parser).
    """
    op:     str
    target: Node
    value:  Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class BinOp(Node):
    """
    left OP right
    op is one of: + - * / % & | ^ && || == != < > <= >=
    """
    op:    str
    left:  Node
    right: Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class UnaryOp(Node):
    """
    OP operand
    op is one of: ! ~ - (prefix minus)
    """
    op:      str
    operand: Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class PostfixOp(Node):
    """operand++  or  operand--"""
    op:      str   # '++' or '--'
    operand: Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class IntLit(Node):
    """Integer literal: 42, 0xFF, 0b1010"""
    value: int
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class CharLit(Node):
    """Character literal: 'A', '\\n' — stored as integer ASCII code"""
    value: int
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class Var(Node):
    """A plain variable reference: x"""
    name: str
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class ArrayIndex(Node):
    """arr[index]"""
    name:  str
    index: Node
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


@dataclass
class FuncCall(Node):
    """foo(arg1, arg2, ...)"""
    name: str
    args: List[Node]
    line: int = field(default=0, compare=False, repr=False)
    col:  int = field(default=0, compare=False, repr=False)


# ──────────────────────────────────────────────────────────────────────────────
# Pretty printer
# ──────────────────────────────────────────────────────────────────────────────

def pretty(node: Node, indent: int = 0) -> str:
    """
    Return a human-readable tree representation of any AST node.
    Useful for debugging the parser output.

    Example:
        print(pretty(ast))
    """
    p = '  ' * indent

    if isinstance(node, Program):
        body = '\n'.join(pretty(d, indent + 1) for d in node.decls)
        return f"{p}Program\n{body}"

    if isinstance(node, VarDecl):
        sz   = f"[{node.size}]" if node.size is not None else ''
        init = f" = ..." if node.init else ''
        return f"{p}VarDecl(char {node.name}{sz}{init})"

    if isinstance(node, Param):
        return f"{p}Param(char {node.name})"

    if isinstance(node, FuncDecl):
        params = ', '.join(f"char {pr.name}" for pr in node.params)
        body   = pretty(node.body, indent + 1)
        return f"{p}FuncDecl({node.return_type} {node.name}({params}))\n{body}"

    if isinstance(node, Block):
        if not node.stmts:
            return f"{p}Block(empty)"
        body = '\n'.join(pretty(s, indent + 1) for s in node.stmts)
        return f"{p}Block\n{body}"

    if isinstance(node, IfStmt):
        lines = [
            f"{p}IfStmt",
            f"{p}  cond:", pretty(node.cond, indent + 2),
            f"{p}  then:", pretty(node.then_block, indent + 2),
        ]
        if node.else_block:
            lines += [f"{p}  else:", pretty(node.else_block, indent + 2)]
        return '\n'.join(lines)

    if isinstance(node, WhileStmt):
        return '\n'.join([
            f"{p}WhileStmt",
            f"{p}  cond:", pretty(node.cond, indent + 2),
            f"{p}  body:", pretty(node.body, indent + 2),
        ])

    if isinstance(node, ForStmt):
        lines = [f"{p}ForStmt"]
        if node.init:   lines += [f"{p}  init:",   pretty(node.init,   indent + 2)]
        if node.cond:   lines += [f"{p}  cond:",   pretty(node.cond,   indent + 2)]
        if node.update: lines += [f"{p}  update:", pretty(node.update, indent + 2)]
        lines += [f"{p}  body:", pretty(node.body, indent + 2)]
        return '\n'.join(lines)

    if isinstance(node, ReturnStmt):
        if node.expr:
            return f"{p}ReturnStmt\n{pretty(node.expr, indent + 1)}"
        return f"{p}ReturnStmt(void)"

    if isinstance(node, BreakStmt):
        return f"{p}BreakStmt"

    if isinstance(node, ExprStmt):
        return f"{p}ExprStmt\n{pretty(node.expr, indent + 1)}"

    if isinstance(node, Assign):
        return '\n'.join([
            f"{p}Assign({node.op})",
            pretty(node.target, indent + 1),
            pretty(node.value,  indent + 1),
        ])

    if isinstance(node, BinOp):
        return '\n'.join([
            f"{p}BinOp({node.op})",
            pretty(node.left,  indent + 1),
            pretty(node.right, indent + 1),
        ])

    if isinstance(node, UnaryOp):
        return f"{p}UnaryOp({node.op})\n{pretty(node.operand, indent + 1)}"

    if isinstance(node, PostfixOp):
        return f"{p}PostfixOp({node.op})\n{pretty(node.operand, indent + 1)}"

    if isinstance(node, IntLit):
        return f"{p}IntLit({node.value})"

    if isinstance(node, CharLit):
        return f"{p}CharLit({node.value})"

    if isinstance(node, Var):
        return f"{p}Var({node.name})"

    if isinstance(node, ArrayIndex):
        return f"{p}ArrayIndex({node.name})\n{pretty(node.index, indent + 1)}"

    if isinstance(node, FuncCall):
        if not node.args:
            return f"{p}FuncCall({node.name})"
        args = '\n'.join(pretty(a, indent + 1) for a in node.args)
        return f"{p}FuncCall({node.name})\n{args}"

    return f"{p}<Unknown:{type(node).__name__}>"
