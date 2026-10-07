"""
semantic.py — Phase 3 of the NoobsC compiler: Semantic Analysis.

═══════════════════════════════════════════════════════════════
THEORY: What is Semantic Analysis?
═══════════════════════════════════════════════════════════════

The parser checked SYNTAX — does the program follow the grammar?
Semantic analysis checks MEANING — does the program make sense?

A program can be syntactically valid but semantically wrong:

    x = 5;                 ← valid grammar, but what is x?
    foo(1, 2);             ← valid grammar, but foo takes 3 args
    break;                 ← valid grammar, but we're not in a loop
    void f() { return 1; } ← valid grammar, but f is void

The parser cannot catch these — it only knows about token shapes,
not what names mean or how they relate to each other.

THEORY: The Symbol Table
─────────────────────────
The central data structure is the SYMBOL TABLE: a dictionary that maps
every declared name to a description of what it is.

    name  →  Symbol(kind, ...)

    'x'   →  Symbol(kind='scalar')
    'buf' →  Symbol(kind='array', size=8)
    'add' →  Symbol(kind='func', return_type='char', param_count=2)

Every time a name is declared (VarDecl, FuncDecl, Param) we INSERT it.
Every time a name is used (Var, ArrayIndex, FuncCall) we LOOK IT UP.
If the lookup fails, the name is undeclared — that's an error.

THEORY: Scopes
───────────────
NoobsC has exactly TWO scope levels:

    global scope   — top-level variables and functions
    local scope    — parameters + local variables inside a function

When we enter a function we create a fresh local scope.
When we leave we discard it.
Lookup checks local first, then global (so a local can shadow a global).

NoobsC does NOT have nested block scopes (no { int x; { int x; } } like C99).
All locals declared anywhere inside a function share one flat scope.

THEORY: Two-Pass Analysis
──────────────────────────
We make two passes over the top-level declarations:

    Pass 1 — HOIST:  register every function and global variable name
                     before looking at any body.
    Pass 2 — CHECK:  walk each function body and verify every name use.

Why two passes? So that mutually-recursive functions work:

    char even(char n) { ... return odd(n-1); ... }   ← calls odd
    char odd(char n)  { ... return even(n-1); ... }  ← calls even

In a single pass, when we check even() we haven't seen odd() yet.
Hoisting fixes this by pre-registering all names first.

═══════════════════════════════════════════════════════════════
CHECKS PERFORMED
═══════════════════════════════════════════════════════════════

  ✓ Undeclared variable or function
  ✓ Duplicate declaration in the same scope
  ✓ Array used without index  (arr instead of arr[i])
  ✓ Scalar used with index    (x[i] where x is a plain variable)
  ✓ Variable used as function (x() where x is a variable)
  ✓ Function used as variable (f where f is a function name)
  ✓ Wrong number of arguments to a function call
  ✓ Void function used as a value (x = void_fn())
  ✓ Void function returning a value  (return 1; inside void f())
  ✓ break outside a loop

═══════════════════════════════════════════════════════════════
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from ast_nodes import (
    Node, Program,
    VarDecl, Param, FuncDecl,
    Block, IfStmt, WhileStmt, ForStmt, ReturnStmt, BreakStmt, ExprStmt,
    Assign, BinOp, UnaryOp, PostfixOp,
    IntLit, CharLit, Var, ArrayIndex, FuncCall,
)


# ── Error type ─────────────────────────────────────────────────────────────────

class SemanticError(Exception):
    def __init__(self, msg: str, line: int = 0, col: int = 0):
        super().__init__(f"Semantic error at {line}:{col}: {msg}")
        self.line = line
        self.col  = col


# ── Symbol ─────────────────────────────────────────────────────────────────────

@dataclass
class Symbol:
    """One entry in the symbol table."""
    name:        str
    kind:        str   # 'scalar' | 'array' | 'func'
    size:        int = 0   # array: number of elements
    return_type: str = ''  # func:  'char' or 'void'
    param_count: int = 0   # func:  number of parameters


# ── Symbol table ───────────────────────────────────────────────────────────────

class SymbolTable:
    """
    Two-level scope: global (always present) and local (inside a function).
    Lookup checks local first, then global.
    """

    def __init__(self):
        self._globals: Dict[str, Symbol] = {}
        self._locals:  Optional[Dict[str, Symbol]] = None  # None = top level

    # ── scope management ─────────────────────────────────────────────────────

    def enter_function(self):
        """Open a fresh local scope."""
        self._locals = {}

    def exit_function(self):
        """Discard the local scope."""
        self._locals = None

    # ── insert / query ───────────────────────────────────────────────────────

    def define(self, sym: Symbol, line: int = 0, col: int = 0):
        """Insert sym into the current scope; raise SemanticError on duplicate."""
        scope = self._locals if self._locals is not None else self._globals
        if sym.name in scope:
            raise SemanticError(
                f"'{sym.name}' already declared in this scope", line, col)
        scope[sym.name] = sym

    def lookup(self, name: str, line: int = 0, col: int = 0) -> Symbol:
        """Return the Symbol for name; raise SemanticError if not found."""
        if self._locals is not None and name in self._locals:
            return self._locals[name]
        if name in self._globals:
            return self._globals[name]
        raise SemanticError(f"'{name}' undeclared", line, col)

    @property
    def globals(self) -> Dict[str, Symbol]:
        return self._globals


# ── Analyser ───────────────────────────────────────────────────────────────────

class Analyser:
    """
    Walk the AST and enforce all semantic rules.

    Usage:
        table = Analyser(ast).analyse()

    Returns the populated SymbolTable so later phases (codegen) can reuse it.
    Raises SemanticError on the first violation found.
    """

    def __init__(self, program: Program):
        self.program       = program
        self.symbols       = SymbolTable()
        self._loop_depth   = 0
        self._current_func: Optional[FuncDecl] = None

    def analyse(self) -> SymbolTable:
        # Pass 1: register every top-level name first
        for decl in self.program.decls:
            self._hoist(decl)
        # Pass 2: check each function body
        for decl in self.program.decls:
            if isinstance(decl, FuncDecl):
                self._check_func(decl)
        return self.symbols

    # ── pass 1: hoisting ─────────────────────────────────────────────────────

    def _hoist(self, node: Node):
        if isinstance(node, VarDecl):
            kind = 'array' if node.size is not None else 'scalar'
            self.symbols.define(
                Symbol(node.name, kind, size=node.size or 0),
                node.line, node.col)
        elif isinstance(node, FuncDecl):
            self.symbols.define(
                Symbol(node.name, 'func',
                       return_type=node.return_type,
                       param_count=len(node.params)),
                node.line, node.col)

    # ── pass 2: function bodies ───────────────────────────────────────────────

    def _check_func(self, func: FuncDecl):
        self._current_func = func
        self.symbols.enter_function()
        for p in func.params:
            self.symbols.define(Symbol(p.name, 'scalar'), p.line, p.col)
        self._check_block(func.body)
        self.symbols.exit_function()
        self._current_func = None

    # ── statements ───────────────────────────────────────────────────────────

    def _check_block(self, block: Block):
        for stmt in block.stmts:
            self._check_stmt(stmt)

    def _check_stmt(self, node: Node):
        if isinstance(node, VarDecl):
            kind = 'array' if node.size is not None else 'scalar'
            self.symbols.define(
                Symbol(node.name, kind, size=node.size or 0),
                node.line, node.col)
            if node.init:
                self._check_expr(node.init)

        elif isinstance(node, IfStmt):
            self._check_expr(node.cond)
            self._check_block(node.then_block)
            if node.else_block:
                self._check_block(node.else_block)

        elif isinstance(node, WhileStmt):
            self._check_expr(node.cond)
            self._loop_depth += 1
            self._check_block(node.body)
            self._loop_depth -= 1

        elif isinstance(node, ForStmt):
            if node.init:
                self._check_stmt(node.init)
            if node.cond:
                self._check_expr(node.cond)
            if node.update:
                self._check_expr(node.update)
            self._loop_depth += 1
            self._check_block(node.body)
            self._loop_depth -= 1

        elif isinstance(node, ReturnStmt):
            if node.expr is not None and self._current_func.return_type == 'void':
                raise SemanticError(
                    f"void function '{self._current_func.name}' cannot return a value",
                    node.line, node.col)
            if node.expr is not None:
                self._check_expr(node.expr)

        elif isinstance(node, BreakStmt):
            if self._loop_depth == 0:
                raise SemanticError("'break' outside a loop", node.line, node.col)

        elif isinstance(node, ExprStmt):
            # Statement context: a void function call is allowed here.
            self._check_expr(node.expr, value_required=False)

    # ── expressions ──────────────────────────────────────────────────────────

    def _check_expr(self, node: Node, value_required: bool = True):
        """
        value_required — True in most expression contexts (right-hand side of
        assignment, function argument, condition, etc.).  False only when the
        expression is the direct child of an ExprStmt, where a void call is OK.
        """

        if isinstance(node, (IntLit, CharLit)):
            pass  # always fine

        elif isinstance(node, Var):
            sym = self.symbols.lookup(node.name, node.line, node.col)
            if sym.kind == 'func':
                raise SemanticError(
                    f"'{node.name}' is a function; did you mean '{node.name}()'?",
                    node.line, node.col)
            if sym.kind == 'array':
                raise SemanticError(
                    f"'{node.name}' is an array; use '{node.name}[i]'",
                    node.line, node.col)

        elif isinstance(node, ArrayIndex):
            sym = self.symbols.lookup(node.name, node.line, node.col)
            if sym.kind != 'array':
                raise SemanticError(
                    f"'{node.name}' is not an array", node.line, node.col)
            self._check_expr(node.index)

        elif isinstance(node, FuncCall):
            sym = self.symbols.lookup(node.name, node.line, node.col)
            if sym.kind != 'func':
                raise SemanticError(
                    f"'{node.name}' is not a function", node.line, node.col)
            if value_required and sym.return_type == 'void':
                raise SemanticError(
                    f"void function '{node.name}' cannot be used as a value",
                    node.line, node.col)
            if len(node.args) != sym.param_count:
                raise SemanticError(
                    f"'{node.name}' expects {sym.param_count} argument(s), "
                    f"got {len(node.args)}",
                    node.line, node.col)
            for arg in node.args:
                self._check_expr(arg)

        elif isinstance(node, Assign):
            # target is checked with value_required=True (arrays/funcs already
            # handled by Var/ArrayIndex branches above)
            self._check_expr(node.target)
            self._check_expr(node.value)

        elif isinstance(node, BinOp):
            self._check_expr(node.left)
            self._check_expr(node.right)

        elif isinstance(node, UnaryOp):
            self._check_expr(node.operand)

        elif isinstance(node, PostfixOp):
            self._check_expr(node.operand)
