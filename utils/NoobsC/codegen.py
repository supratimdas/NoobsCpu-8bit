"""
codegen.py — Phase 4 of the NoobsC compiler: Code Generation.

═══════════════════════════════════════════════════════════════
THEORY: What does the code generator do?
═══════════════════════════════════════════════════════════════

The code generator walks the AST and emits NoobsCpu assembly.
Input:  AST (from parser) + symbol table (from semantic analysis)
Output: a .asm file ready to feed into noobsASM.pl

═══════════════════════════════════════════════════════════════
DESIGN DECISIONS
═══════════════════════════════════════════════════════════════

REGISTER ROLES
──────────────
  R0  accumulator — every expression result lands here
  R1  secondary   — right-hand operand for binary instructions
  R2  arg/temp    — third function argument; scratch in nested calls
  R3  index       — used as the array-index offset in SET_ADR_MODE

CALLING CONVENTION
──────────────────
  Args (up to 3) passed in R0, R1, R2 before CALLNC.
  Return value comes back in R0.
  Callee saves incoming args to per-function static data locations
  immediately on entry.

  Limitation: no recursion — locals are statically allocated, so a
  function that calls itself would overwrite its own locals.

VARIABLE STORAGE
────────────────
  Global var/array → data label = the variable name itself.
  Local var/param  → data label = __funcname_varname.
  Scratch temps    → __tmp0 … __tmp3 (shared; managed by _tmp_depth).

EXPRESSION EVALUATION
─────────────────────
  Every _gen_expr() call leaves its result in R0.
  When a BinOp needs to hold the left result while computing the right,
  it saves R0 to the next free __tmpN slot (_push_tmp / _pop_tmp).

ARRAY ACCESS (indirect mode)
─────────────────────────────
  SET_ADR_MODE makes every LOAD/STORE use  Mem[label + R3].
  So: ADDI R3,R0,0 (copy index from R0) then SET_ADR_MODE then
  LOAD/STORE then RST_ADR_MODE.

CONDITIONS AND BRANCHES
────────────────────────
  _gen_cond_jump_false(cond, label) generates code that jumps to
  'label' when 'cond' evaluates to false (0).

  Comparison mapping (after SUB R0,R1):
    ==   → JMPNZ label     (NZ set means not equal → false)
    !=   → JMPZ  label     (Z  set means equal     → false)
    <    → OVF=true is correct, so: JMPOVF skip; JMPNC label; skip:
    >=   → JMPOVF label    (OVF means left<right   → false)
    >    → swap operands, same as <
    <=   → swap operands, same as >=

LABEL FORMAT
────────────
  The assembler requires a label on the SAME line as an instruction.
  Standalone labels use NOP:  __loop_0: NOP

ASSEMBLER SYNTAX
────────────────
  ADDI Rd,Rs,imm   (Rd = Rs + imm)
  ADD  Rd,Rs       (Rd = Rd + Rs)
  SUB  Rd,Rs       (Rd = Rd - Rs)
  LOAD Rd,label    STORE Rs,label
  JMPNC label      (unconditional)
  JMPZ/JMPNZ/JMPOVF label
  CALLNC label     (unconditional call)
  SET_ADR_MODE / RST_ADR_MODE
  XOR  Rd,Rs       (Rd = Rd ^ Rs)   — used as: XOR R0,R0 to zero R0

═══════════════════════════════════════════════════════════════
"""

from __future__ import annotations
from typing import List, Set, Optional

from ast_nodes import (
    Node, Program, VarDecl, FuncDecl,
    Block, IfStmt, WhileStmt, ForStmt, ReturnStmt, BreakStmt, ExprStmt,
    Assign, BinOp, UnaryOp, PostfixOp,
    IntLit, CharLit, Var, ArrayIndex, FuncCall,
)
from semantic import SymbolTable


# ── Error ─────────────────────────────────────────────────────────────────────

class CodeGenError(Exception):
    def __init__(self, msg: str, line: int = 0, col: int = 0):
        super().__init__(f"CodeGen error at {line}:{col}: {msg}")
        self.line = line
        self.col  = col


# ── Helpers ───────────────────────────────────────────────────────────────────

# Binary ops that map 1-to-1 to a NoobsCpu register instruction.
_REG_OP = {'+': 'ADD', '-': 'SUB', '&': 'AND', '|': 'OR', '^': 'XOR'}

NUM_TMPS = 4   # scratch __tmp0…__tmp3 in data section


# ── Code Generator ────────────────────────────────────────────────────────────

class CodeGen:
    """
    Walk the AST and produce a NoobsCpu .asm file as a string.

    Usage:
        asm_text = CodeGen(ast, symbol_table).generate()
    """

    def __init__(self, program: Program, symbols: SymbolTable):
        self.program  = program
        self.symbols  = symbols
        self._out:  List[str] = []
        self._label_n    = 0       # global counter for unique labels
        self._tmp_depth  = 0       # current scratch-temp nesting depth
        self._loop_ends: List[str] = []     # stack of loop-end labels (for break)
        self._cur_func: Optional[FuncDecl] = None
        self._locals:   Set[str] = set()   # local/param names in current function

    # ── public ───────────────────────────────────────────────────────────────

    def generate(self) -> str:
        self._data_section()
        self._code_section()
        return '\n'.join(self._out)

    # ── data section ─────────────────────────────────────────────────────────

    def _data_section(self):
        self._emit('.data')

        # global variables and arrays
        for decl in self.program.decls:
            if isinstance(decl, VarDecl):
                if decl.size is not None:
                    vals = ','.join(['0x00'] * decl.size)
                    self._emit(f'    {decl.name}:{vals}')
                else:
                    init = 0
                    if isinstance(decl.init, (IntLit, CharLit)):
                        init = decl.init.value & 0xFF
                    self._emit(f'    {decl.name}:0x{init:02x}')

        # per-function static storage (params + locals)
        for decl in self.program.decls:
            if isinstance(decl, FuncDecl):
                self._emit_func_statics(decl)

        # scratch temporaries
        for i in range(NUM_TMPS):
            self._emit(f'    __tmp{i}:0x00')

    def _emit_func_statics(self, func: FuncDecl):
        prefix = func.name
        for p in func.params:
            self._emit(f'    __{prefix}_{p.name}:0x00')
        self._emit_block_statics(func.body, prefix)

    def _emit_block_statics(self, block: Block, prefix: str):
        for stmt in block.stmts:
            if isinstance(stmt, VarDecl):
                if stmt.size is not None:
                    vals = ','.join(['0x00'] * stmt.size)
                    self._emit(f'    __{prefix}_{stmt.name}:{vals}')
                else:
                    self._emit(f'    __{prefix}_{stmt.name}:0x00')
            elif isinstance(stmt, IfStmt):
                self._emit_block_statics(stmt.then_block, prefix)
                if stmt.else_block:
                    self._emit_block_statics(stmt.else_block, prefix)
            elif isinstance(stmt, WhileStmt):
                self._emit_block_statics(stmt.body, prefix)
            elif isinstance(stmt, ForStmt):
                if isinstance(stmt.init, VarDecl):
                    self._emit(f'    __{prefix}_{stmt.init.name}:0x00')
                self._emit_block_statics(stmt.body, prefix)

    # ── code section ─────────────────────────────────────────────────────────

    def _code_section(self):
        self._emit('.code')
        # program entry
        self._emit('    CALLNC __main')
        self._emit('    HALT')
        # each function
        for decl in self.program.decls:
            if isinstance(decl, FuncDecl):
                self._gen_func(decl)

    # ── function ─────────────────────────────────────────────────────────────

    def _gen_func(self, func: FuncDecl):
        self._cur_func = func
        self._locals = set()
        for p in func.params:
            self._locals.add(p.name)
        self._collect_locals(func.body)

        # function entry label + save incoming register args to static locals
        arg_regs = ['R0', 'R1', 'R2']
        if func.params:
            first_store = f'STORE {arg_regs[0]},__{func.name}_{func.params[0].name}'
            self._emit(f'__{func.name}: {first_store}')
            for i, p in enumerate(func.params[1:], start=1):
                lbl = f'__{func.name}_{p.name}'
                self._emit(f'    STORE {arg_regs[i]},{lbl}')
        else:
            self._emit(f'__{func.name}: NOP')

        self._gen_block(func.body)

        if func.return_type == 'void':
            self._emit('    RET')

        self._cur_func = None
        self._locals   = set()

    def _collect_locals(self, block: Block):
        for stmt in block.stmts:
            if isinstance(stmt, VarDecl):
                self._locals.add(stmt.name)
            elif isinstance(stmt, IfStmt):
                self._collect_locals(stmt.then_block)
                if stmt.else_block:
                    self._collect_locals(stmt.else_block)
            elif isinstance(stmt, WhileStmt):
                self._collect_locals(stmt.body)
            elif isinstance(stmt, ForStmt):
                if isinstance(stmt.init, VarDecl):
                    self._locals.add(stmt.init.name)
                self._collect_locals(stmt.body)

    # ── statements ───────────────────────────────────────────────────────────

    def _gen_block(self, block: Block):
        for stmt in block.stmts:
            self._gen_stmt(stmt)

    def _gen_stmt(self, node: Node):
        if isinstance(node, VarDecl):
            if node.init:
                self._gen_expr(node.init)
                self._emit(f'    STORE R0,{self._vlabel(node.name)}')

        elif isinstance(node, ExprStmt):
            self._gen_expr(node.expr)

        elif isinstance(node, IfStmt):
            end_lbl = self._lbl('if_end')
            if node.else_block:
                else_lbl = self._lbl('else')
                self._cond_false(node.cond, else_lbl)
                self._gen_block(node.then_block)
                self._emit(f'    JMPNC {end_lbl}')
                self._emit(f'{else_lbl}: NOP')
                self._gen_block(node.else_block)
            else:
                self._cond_false(node.cond, end_lbl)
                self._gen_block(node.then_block)
            self._emit(f'{end_lbl}: NOP')

        elif isinstance(node, WhileStmt):
            top = self._lbl('while')
            end = self._lbl('while_end')
            self._loop_ends.append(end)
            self._emit(f'{top}: NOP')
            self._cond_false(node.cond, end)
            self._gen_block(node.body)
            self._emit(f'    JMPNC {top}')
            self._emit(f'{end}: NOP')
            self._loop_ends.pop()

        elif isinstance(node, ForStmt):
            top = self._lbl('for')
            end = self._lbl('for_end')
            self._loop_ends.append(end)
            if node.init:
                self._gen_stmt(node.init)
            self._emit(f'{top}: NOP')
            if node.cond:
                self._cond_false(node.cond, end)
            self._gen_block(node.body)
            if node.update:
                self._gen_expr(node.update)
            self._emit(f'    JMPNC {top}')
            self._emit(f'{end}: NOP')
            self._loop_ends.pop()

        elif isinstance(node, ReturnStmt):
            if node.expr:
                self._gen_expr(node.expr)
            self._emit('    RET')

        elif isinstance(node, BreakStmt):
            self._emit(f'    JMPNC {self._loop_ends[-1]}')

    # ── expressions ──────────────────────────────────────────────────────────

    def _gen_expr(self, node: Node):
        """Generate code whose result lands in R0."""

        if isinstance(node, IntLit):
            self._load_const(node.value)

        elif isinstance(node, CharLit):
            self._load_const(node.value)

        elif isinstance(node, Var):
            self._emit(f'    LOAD R0,{self._vlabel(node.name)}')

        elif isinstance(node, ArrayIndex):
            lbl = self._vlabel(node.name)
            self._gen_expr(node.index)           # index → R0
            self._emit('    ADDI R3,R0,0')       # R3 = index
            self._emit('    SET_ADR_MODE')
            self._emit(f'    LOAD R0,{lbl}')     # R0 = arr[R3]
            self._emit('    RST_ADR_MODE')

        elif isinstance(node, FuncCall):
            self._gen_call(node)

        elif isinstance(node, Assign):
            self._gen_assign(node)

        elif isinstance(node, BinOp):
            self._gen_binop(node)

        elif isinstance(node, UnaryOp):
            self._gen_unary(node)

        elif isinstance(node, PostfixOp):
            self._gen_postfix(node)

        else:
            raise CodeGenError(f"Cannot generate code for {type(node).__name__}")

    def _load_const(self, value: int):
        v = value & 0xFF
        self._emit('    XOR R0,R0')
        if v != 0:
            self._emit(f'    ADDI R0,R0,{v}')

    def _gen_call(self, node: FuncCall):
        n = len(node.args)
        if n >= 3:
            self._gen_expr(node.args[2])
            self._emit('    ADDI R2,R0,0')      # R2 = arg2
        if n >= 2:
            self._gen_expr(node.args[1])
            self._emit('    ADDI R1,R0,0')      # R1 = arg1
        if n >= 1:
            self._gen_expr(node.args[0])         # R0 = arg0
        self._emit(f'    CALLNC __{node.name}')

    def _gen_assign(self, node: Assign):
        if node.op == '=':
            self._gen_expr(node.value)
            self._store_target(node.target)
        else:
            # compound: x += y  →  x = x + y
            base = node.op[:-1]       # '+=' → '+'
            mnem = _REG_OP.get(base)
            if mnem is None:
                raise CodeGenError(f"Unsupported compound op: {node.op}",
                                   node.line, node.col)
            if base == '-':
                # SUB R0,R1 = R1-R0; need R1=LHS, R0=RHS to get LHS-RHS.
                self._gen_expr(node.value)          # RHS → R0
                slot = self._push_tmp()             # save RHS
                self._gen_expr(node.target)         # LHS → R0
                self._emit('    ADDI R1,R0,0')      # R1 = LHS
                self._emit(f'    LOAD R0,{slot}')   # R0 = RHS
                self._pop_tmp()
                self._emit('    SUB R0,R1')          # R0 = R1-R0 = LHS-RHS
            else:
                self._gen_expr(node.value)          # RHS → R0
                slot = self._push_tmp()             # save RHS
                self._gen_expr(node.target)         # load current LHS → R0
                self._emit(f'    LOAD R1,{slot}')   # R1 = RHS
                self._pop_tmp()
                self._emit(f'    {mnem} R0,R1')     # R0 = LHS op RHS
            self._store_target(node.target)

    def _store_target(self, target: Node):
        """Store R0 into target (Var or ArrayIndex)."""
        if isinstance(target, Var):
            self._emit(f'    STORE R0,{self._vlabel(target.name)}')
        elif isinstance(target, ArrayIndex):
            lbl  = self._vlabel(target.name)
            slot = self._push_tmp()             # save value to write
            self._gen_expr(target.index)        # index → R0
            self._emit('    ADDI R3,R0,0')      # R3 = index
            self._emit(f'    LOAD R0,{slot}')   # R0 = value
            self._pop_tmp()
            self._emit('    SET_ADR_MODE')
            self._emit(f'    STORE R0,{lbl}')   # arr[R3] = R0
            self._emit('    RST_ADR_MODE')

    def _gen_binop(self, node: BinOp):
        op = node.op
        mnem = _REG_OP.get(op)
        if mnem:
            if op == '-':
                # SUB R0,R1 = R1-R0 (second arg - first arg).
                # To get left-right we need R1=left, R0=right before the instruction.
                self._gen_expr(node.right)         # R0 = right
                slot = self._push_tmp()            # save right
                self._gen_expr(node.left)          # R0 = left
                self._emit('    ADDI R1,R0,0')     # R1 = left
                self._emit(f'    LOAD R0,{slot}')  # R0 = right
                self._pop_tmp()
                self._emit('    SUB R0,R1')        # R0 = R1-R0 = left-right
            else:
                self._gen_expr(node.left)
                slot = self._push_tmp()             # save left
                self._gen_expr(node.right)
                self._emit('    ADDI R1,R0,0')      # R1 = right
                self._emit(f'    LOAD R0,{slot}')   # R0 = left
                self._pop_tmp()
                self._emit(f'    {mnem} R0,R1')     # R0 = left op right
        elif op in ('*', '/', '%'):
            raise CodeGenError(
                f"'{op}' not supported — implement multiply/divide as a function",
                node.line, node.col)
        else:
            raise CodeGenError(
                f"Operator '{op}' only supported inside if/while conditions, "
                f"not as an expression value",
                node.line, node.col)

    def _gen_unary(self, node: UnaryOp):
        self._gen_expr(node.operand)
        if node.op == '~':
            self._emit('    XORI R0,R0,0xFF')
        elif node.op == '-':
            self._emit('    XORI R0,R0,0xFF')   # ~x
            self._emit('    ADDI R0,R0,1')       # ~x + 1 = -x (two's complement)
        elif node.op == '!':
            t = self._lbl('not_true')
            e = self._lbl('not_end')
            self._emit('    ADDI R0,R0,0')       # set Z/NZ flags
            self._emit(f'    JMPZ {t}')          # zero → !0 = 1
            self._emit('    XOR R0,R0')           # non-zero → result = 0
            self._emit(f'    JMPNC {e}')
            self._emit(f'{t}: XOR R0,R0')
            self._emit('    ADDI R0,R0,1')        # result = 1
            self._emit(f'{e}: NOP')

    def _gen_postfix(self, node: PostfixOp):
        if not isinstance(node.operand, Var):
            raise CodeGenError(
                "Postfix ++ / -- only supported on simple variables",
                node.line, node.col)
        lbl  = self._vlabel(node.operand.name)
        self._emit(f'    LOAD R0,{lbl}')         # R0 = old value
        slot = self._push_tmp()                  # save old value
        if node.op == '++':
            self._emit('    ADDI R0,R0,1')
        else:
            self._emit('    SUBI R0,R0,1')
        self._emit(f'    STORE R0,{lbl}')        # write new value
        self._emit(f'    LOAD R0,{slot}')        # return old value
        self._pop_tmp()

    # ── condition helpers ─────────────────────────────────────────────────────

    def _cond_false(self, cond: Node, false_lbl: str):
        """Emit code that jumps to false_lbl when cond evaluates to false."""

        if isinstance(cond, BinOp) and cond.op in ('==', '!=', '<', '>', '<=', '>='):
            op = cond.op
            # For > and <=: swap operands so OVF logic still works.
            # After swap: R0 = right, R1 = left.  SUB R0,R1 = right - left.
            # OVF means right < left, i.e. left > right.
            # SUB R1,R0 writes to R1 (first arg) the value src0-src1 = R0-R1.
            # No-swap (<, ==, !=): R0=left, R1=right → R1=left-right, OVF=1 when left<right.
            # Swap (>, <=):        R0=right, R1=left → R1=right-left, OVF=1 when right<left
            #                      i.e. OVF=1 when left>right.
            if op in ('>', '<='):
                self._gen_expr(cond.right)
                slot = self._push_tmp()
                self._gen_expr(cond.left)
                self._emit('    ADDI R1,R0,0')
                self._emit(f'    LOAD R0,{slot}')
                self._pop_tmp()
            else:
                self._gen_expr(cond.left)
                slot = self._push_tmp()
                self._gen_expr(cond.right)
                self._emit('    ADDI R1,R0,0')
                self._emit(f'    LOAD R0,{slot}')
                self._pop_tmp()
            self._emit('    SUB R1,R0')

            if op == '==':
                self._emit(f'    JMPNZ {false_lbl}')
            elif op == '!=':
                self._emit(f'    JMPZ {false_lbl}')
            elif op == '<':
                # OVF=1 → left<right (TRUE) → skip exit; OVF=0 → exit
                skip = self._lbl('cmp_skip')
                self._emit(f'    JMPOVF {skip}')
                self._emit(f'    JMPNC {false_lbl}')
                self._emit(f'{skip}: NOP')
            elif op == '>=':
                # OVF=1 → left<right (FALSE) → exit
                self._emit(f'    JMPOVF {false_lbl}')
            elif op == '>':
                # swapped: OVF=1 → left>right (TRUE) → skip exit
                skip = self._lbl('cmp_skip')
                self._emit(f'    JMPOVF {skip}')
                self._emit(f'    JMPNC {false_lbl}')
                self._emit(f'{skip}: NOP')
            elif op == '<=':
                # swapped: OVF=1 → left>right (FALSE) → exit
                self._emit(f'    JMPOVF {false_lbl}')

        elif isinstance(cond, BinOp) and cond.op == '&&':
            # short-circuit: both must be true
            self._cond_false(cond.left,  false_lbl)
            self._cond_false(cond.right, false_lbl)

        elif isinstance(cond, BinOp) and cond.op == '||':
            # short-circuit: at least one must be true
            skip_right = self._lbl('or_skip')
            self._cond_true(cond.left, skip_right)
            self._cond_false(cond.right, false_lbl)
            self._emit(f'{skip_right}: NOP')

        elif isinstance(cond, UnaryOp) and cond.op == '!':
            # !expr is false when expr is true → jump if expr is true
            self._cond_true(cond.operand, false_lbl)

        else:
            # General expression: jump if result is zero (falsy)
            self._gen_expr(cond)
            self._emit('    ADDI R0,R0,0')      # force Z/NZ flag update
            self._emit(f'    JMPZ {false_lbl}')

    def _cond_true(self, cond: Node, true_lbl: str):
        """Emit code that jumps to true_lbl when cond evaluates to true."""
        skip = self._lbl('cond_skip')
        self._cond_false(cond, skip)
        self._emit(f'    JMPNC {true_lbl}')
        self._emit(f'{skip}: NOP')

    # ── helpers ───────────────────────────────────────────────────────────────

    def _vlabel(self, name: str) -> str:
        """Data label for a variable — prefixed if it is a local."""
        if self._cur_func and name in self._locals:
            return f'__{self._cur_func.name}_{name}'
        return name

    def _lbl(self, prefix: str) -> str:
        lbl = f'__{prefix}_{self._label_n}'
        self._label_n += 1
        return lbl

    def _push_tmp(self) -> str:
        if self._tmp_depth >= NUM_TMPS:
            raise CodeGenError("Expression too complex — nesting exceeds scratch temp limit")
        slot = f'__tmp{self._tmp_depth}'
        self._emit(f'    STORE R0,{slot}')
        self._tmp_depth += 1
        return slot

    def _pop_tmp(self):
        self._tmp_depth -= 1

    def _emit(self, line: str):
        self._out.append(line)
