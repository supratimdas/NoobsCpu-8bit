"""
parser.py — Phase 2 of the NoobsC compiler: Recursive Descent Parser.

═══════════════════════════════════════════════════════════════
FULL GRAMMAR (EBNF notation)
═══════════════════════════════════════════════════════════════

Notation:
    'x'      literal token
    A B      A followed by B
    A | B    A or B
    A?       zero or one A
    A*       zero or more A
    A+       one or more A
    ( A )    grouping

── Top level ───────────────────────────────────────────────────

    program     → declaration*

    declaration → var_decl
                | func_decl

── Declarations ────────────────────────────────────────────────

    var_decl    → 'char' IDENT ('[' INT_LIT ']')? ('=' expr)? ';'

    func_decl   → ('char' | 'void') IDENT '(' param_list? ')' block

    param_list  → param (',' param)*

    param       → 'char' IDENT

── Statements ──────────────────────────────────────────────────

    block       → '{' statement* '}'

    statement   → var_decl
                | if_stmt
                | while_stmt
                | for_stmt
                | return_stmt
                | break_stmt
                | expr_stmt

    if_stmt     → 'if' '(' expr ')' block ('else' block)?

    while_stmt  → 'while' '(' expr ')' block

    for_stmt    → 'for' '(' for_init expr? ';' expr? ')' block

    for_init    → var_decl        (consumes its own ';')
                | expr_stmt       (consumes its own ';')
                | ';'             (empty init)

    return_stmt → 'return' expr? ';'

    break_stmt  → 'break' ';'

    expr_stmt   → expr ';'

── Expressions (low → high precedence) ─────────────────────────

    expr        → assign

    assign      → logical_or (assign_op assign)?   (right-associative)

    assign_op   → '=' | '+=' | '-=' | '&=' | '|=' | '^='

    logical_or  → logical_and ('||' logical_and)*

    logical_and → bitwise_or  ('&&' bitwise_or)*

    bitwise_or  → bitwise_xor ('|'  bitwise_xor)*

    bitwise_xor → bitwise_and ('^'  bitwise_and)*

    bitwise_and → equality    ('&'  equality)*

    equality    → relational  (('==' | '!=') relational)*

    relational  → additive    (('<' | '>' | '<=' | '>=') additive)*

    additive    → multiply    (('+' | '-') multiply)*

    multiply    → unary       (('*' | '/' | '%') unary)*

    unary       → ('!' | '~' | '-') unary
                | postfix

    postfix     → primary '++'
                | primary '--'
                | primary

    primary     → INT_LIT
                | CHAR_LIT
                | IDENT '[' expr ']'
                | IDENT '(' arg_list? ')'
                | IDENT
                | '(' expr ')'

    arg_list    → expr (',' expr)*

═══════════════════════════════════════════════════════════════
THEORY: Recursive Descent Parsing
═══════════════════════════════════════════════════════════════

Every rule in the grammar becomes exactly one method in this class.
The structure of the method mirrors the structure of the rule.

Grammar rule:
    if_stmt → 'if' '(' expr ')' block ('else' block)?

Corresponding method:
    def _parse_if_stmt(self):
        self._expect(KW_IF)       # consume 'if'
        self._expect(LPAREN)      # consume '('
        cond = self._parse_expr() # recurse → expr rule
        self._expect(RPAREN)      # consume ')'
        then = self._parse_block()
        else_ = None
        if self._check(KW_ELSE):  # optional part
            self._advance()
            else_ = self._parse_block()
        return IfStmt(cond, then, else_)

THEORY: Operator Precedence
────────────────────────────
In a recursive descent parser, precedence is encoded by the call chain.
The rule with the LOWEST precedence calls the rule one step HIGHER, which
calls the next, and so on.  At the bottom are atoms (literals, identifiers).

    _parse_expr          (entry point)
         │
    _parse_assign        lowest  — =  +=  -=  etc.
         │
    _parse_logical_or    ——————  ||
         │
    _parse_logical_and   ——————  &&
         │
    _parse_bitwise_or    ——————  |
         │
    _parse_bitwise_xor   ——————  ^
         │
    _parse_bitwise_and   ——————  &
         │
    _parse_equality      ——————  ==  !=
         │
    _parse_relational    ——————  <  >  <=  >=
         │
    _parse_additive      ——————  +  -
         │
    _parse_multiply      ——————  *  /  %
         │
    _parse_unary         ——————  !  ~  - (prefix)
         │
    _parse_postfix       highest — ++  --  arr[i]  foo()
         │
    _parse_primary       atoms  — literals, identifiers, (expr)

To verify: "1 + 2 * 3" must parse as 1 + (2 * 3), not (1 + 2) * 3.
    _parse_additive calls _parse_multiply for each operand.
    So when it sees "1", it calls _parse_multiply → returns IntLit(1).
    Then it sees "+", so it calls _parse_multiply again.
    _parse_multiply now sees "2 * 3" and returns BinOp('*', 2, 3).
    Result: BinOp('+', IntLit(1), BinOp('*', IntLit(2), IntLit(3)))  ✓

THEORY: Three primitives
─────────────────────────
The parser only needs three operations on its token list:
    _peek()     look at the next token without consuming it
    _advance()  consume and return the next token
    _expect(t)  consume next token; raise error if it is not type t
═══════════════════════════════════════════════════════════════
"""

from __future__ import annotations
from typing import List, Optional

from lexer import Token, TokenType
from ast_nodes import (
    Node, Program,
    VarDecl, Param, FuncDecl,
    Block, IfStmt, WhileStmt, ForStmt, ReturnStmt, BreakStmt, ExprStmt,
    Assign, BinOp, UnaryOp, PostfixOp,
    IntLit, CharLit, Var, ArrayIndex, FuncCall,
)


# ── Error type ─────────────────────────────────────────────────────────────────

class ParseError(Exception):
    def __init__(self, msg: str, line: int, col: int):
        super().__init__(f"Parse error at {line}:{col}: {msg}")
        self.line = line
        self.col  = col


# ── Operator maps ──────────────────────────────────────────────────────────────
# Map TokenType → the string we store in AST nodes.

_ASSIGN_OPS = {
    TokenType.EQ:       '=',
    TokenType.PLUS_EQ:  '+=',
    TokenType.MINUS_EQ: '-=',
    TokenType.AMP_EQ:   '&=',
    TokenType.PIPE_EQ:  '|=',
    TokenType.CARET_EQ: '^=',
}

_RELATIONAL_OPS = {
    TokenType.LT:    '<',
    TokenType.GT:    '>',
    TokenType.LT_EQ: '<=',
    TokenType.GT_EQ: '>=',
}

_UNARY_OPS = {
    TokenType.BANG:  '!',
    TokenType.TILDE: '~',
    TokenType.MINUS: '-',
}

_MULTIPLY_OPS = {
    TokenType.STAR:    '*',
    TokenType.SLASH:   '/',
    TokenType.PERCENT: '%',
}


# ── Parser ─────────────────────────────────────────────────────────────────────

class Parser:
    """
    Recursive descent parser for NoobsC.

    Public interface:
        ast = Parser(tokens).parse()          # parse a full program
        expr = Parser(tokens).parse_expr()    # parse a single expression
    """

    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.pos    = 0

    # ── token stream primitives ───────────────────────────────────────────────

    def _peek(self, offset: int = 0) -> Token:
        """Return token at pos+offset without consuming. Returns EOF at the end."""
        idx = self.pos + offset
        # always safe: tokens list always ends with at least one EOF
        return self.tokens[min(idx, len(self.tokens) - 1)]

    def _advance(self) -> Token:
        """Consume and return the current token."""
        tok = self.tokens[self.pos]
        if self.pos < len(self.tokens) - 1:
            self.pos += 1
        return tok

    def _check(self, *types: TokenType) -> bool:
        """Return True if the current token's type is one of `types`."""
        return self._peek().type in types

    def _match(self, *types: TokenType) -> Optional[Token]:
        """Consume and return the current token if its type is in `types`, else None."""
        if self._check(*types):
            return self._advance()
        return None

    def _expect(self, tt: TokenType) -> Token:
        """Consume the current token; raise ParseError if it is not type `tt`."""
        tok = self._peek()
        if tok.type is not tt:
            raise ParseError(
                f"Expected {tt.name}, got {tok.type.name!r}",
                tok.line, tok.col,
            )
        return self._advance()

    # ── public entry points ───────────────────────────────────────────────────

    def parse(self) -> Program:
        """Parse a complete NoobsC program → Program node."""
        decls: List[Node] = []
        while not self._check(TokenType.EOF):
            decls.append(self._parse_declaration())
        return Program(decls)

    def parse_expr(self) -> Node:
        """Parse a single expression (convenience entry point for tests)."""
        return self._parse_expr()

    # ── declarations ──────────────────────────────────────────────────────────

    def _parse_declaration(self) -> Node:
        """
        declaration → var_decl | func_decl

        Both start with a type keyword (char / void) and then an identifier.
        We distinguish them by peeking two tokens ahead:
            char  IDENT  (   → function declaration
            char  IDENT  ;   → variable declaration
            char  IDENT  [   → variable declaration (array)
            void  ...        → always a function declaration
        """
        tok = self._peek()
        if not self._check(TokenType.KW_CHAR, TokenType.KW_VOID):
            raise ParseError(
                f"Expected a declaration, got {tok.type.name!r}",
                tok.line, tok.col,
            )
        # void can only introduce a function
        if self._check(TokenType.KW_VOID):
            return self._parse_func_decl()
        # char: look at the token two positions ahead
        if self._peek(2).type is TokenType.LPAREN:
            return self._parse_func_decl()
        return self._parse_var_decl()

    def _parse_var_decl(self) -> VarDecl:
        """
        var_decl → 'char' IDENT ('[' INT_LIT ']')? ('=' expr)? ';'
        """
        self._expect(TokenType.KW_CHAR)
        name_tok = self._expect(TokenType.IDENT)

        size: Optional[int] = None
        if self._match(TokenType.LBRACKET):
            size_tok = self._expect(TokenType.INT_LIT)
            if size_tok.value <= 0:
                raise ParseError("Array size must be positive", size_tok.line, size_tok.col)
            size = size_tok.value
            self._expect(TokenType.RBRACKET)

        init: Optional[Node] = None
        if size is None and self._match(TokenType.EQ):
            init = self._parse_expr()

        self._expect(TokenType.SEMI)
        return VarDecl(name_tok.value, size, init, name_tok.line, name_tok.col)

    def _parse_func_decl(self) -> FuncDecl:
        """
        func_decl → ('char' | 'void') IDENT '(' param_list? ')' block
        """
        type_tok    = self._advance()   # KW_CHAR or KW_VOID
        return_type = 'char' if type_tok.type is TokenType.KW_CHAR else 'void'

        name_tok = self._expect(TokenType.IDENT)
        self._expect(TokenType.LPAREN)

        params: List[Param] = []
        if not self._check(TokenType.RPAREN):
            params = self._parse_param_list()

        self._expect(TokenType.RPAREN)
        body = self._parse_block()
        return FuncDecl(return_type, name_tok.value, params, body,
                        name_tok.line, name_tok.col)

    def _parse_param_list(self) -> List[Param]:
        """param_list → param (',' param)*"""
        params = [self._parse_param()]
        while self._match(TokenType.COMMA):
            params.append(self._parse_param())
        return params

    def _parse_param(self) -> Param:
        """param → 'char' IDENT"""
        self._expect(TokenType.KW_CHAR)
        name_tok = self._expect(TokenType.IDENT)
        return Param(name_tok.value, name_tok.line, name_tok.col)

    # ── block and statements ──────────────────────────────────────────────────

    def _parse_block(self) -> Block:
        """block → '{' statement* '}'"""
        tok = self._expect(TokenType.LBRACE)
        stmts: List[Node] = []
        while not self._check(TokenType.RBRACE, TokenType.EOF):
            stmts.append(self._parse_statement())
        self._expect(TokenType.RBRACE)
        return Block(stmts, tok.line, tok.col)

    def _parse_statement(self) -> Node:
        """
        statement → var_decl | if_stmt | while_stmt | for_stmt
                  | return_stmt | break_stmt | expr_stmt
        """
        if self._check(TokenType.KW_CHAR):
            return self._parse_var_decl()
        if self._check(TokenType.KW_IF):
            return self._parse_if_stmt()
        if self._check(TokenType.KW_WHILE):
            return self._parse_while_stmt()
        if self._check(TokenType.KW_FOR):
            return self._parse_for_stmt()
        if self._check(TokenType.KW_RETURN):
            return self._parse_return_stmt()
        if self._check(TokenType.KW_BREAK):
            return self._parse_break_stmt()
        return self._parse_expr_stmt()

    def _parse_if_stmt(self) -> IfStmt:
        """if_stmt → 'if' '(' expr ')' block ('else' block)?"""
        tok = self._expect(TokenType.KW_IF)
        self._expect(TokenType.LPAREN)
        cond = self._parse_expr()
        self._expect(TokenType.RPAREN)
        then_block = self._parse_block()

        else_block: Optional[Block] = None
        if self._match(TokenType.KW_ELSE):
            else_block = self._parse_block()

        return IfStmt(cond, then_block, else_block, tok.line, tok.col)

    def _parse_while_stmt(self) -> WhileStmt:
        """while_stmt → 'while' '(' expr ')' block"""
        tok = self._expect(TokenType.KW_WHILE)
        self._expect(TokenType.LPAREN)
        cond = self._parse_expr()
        self._expect(TokenType.RPAREN)
        body = self._parse_block()
        return WhileStmt(cond, body, tok.line, tok.col)

    def _parse_for_stmt(self) -> ForStmt:
        """
        for_stmt → 'for' '(' for_init expr? ';' expr? ')' block
        for_init → var_decl | expr_stmt | ';'
        """
        tok = self._expect(TokenType.KW_FOR)
        self._expect(TokenType.LPAREN)

        # --- init ---
        # var_decl and expr_stmt both consume their own ';'.
        # The bare ';' case (no init) is handled explicitly.
        init: Optional[Node] = None
        if self._check(TokenType.KW_CHAR):
            init = self._parse_var_decl()        # consumes its own ';'
        elif self._check(TokenType.SEMI):
            self._advance()                       # consume ';', no init
        else:
            init = self._parse_expr_stmt()        # consumes its own ';'

        # --- condition ---
        cond: Optional[Node] = None
        if not self._check(TokenType.SEMI):
            cond = self._parse_expr()
        self._expect(TokenType.SEMI)

        # --- update ---
        update: Optional[Node] = None
        if not self._check(TokenType.RPAREN):
            update = self._parse_expr()
        self._expect(TokenType.RPAREN)

        body = self._parse_block()
        return ForStmt(init, cond, update, body, tok.line, tok.col)

    def _parse_return_stmt(self) -> ReturnStmt:
        """return_stmt → 'return' expr? ';'"""
        tok = self._expect(TokenType.KW_RETURN)
        expr: Optional[Node] = None
        if not self._check(TokenType.SEMI):
            expr = self._parse_expr()
        self._expect(TokenType.SEMI)
        return ReturnStmt(expr, tok.line, tok.col)

    def _parse_break_stmt(self) -> BreakStmt:
        """break_stmt → 'break' ';'"""
        tok = self._expect(TokenType.KW_BREAK)
        self._expect(TokenType.SEMI)
        return BreakStmt(tok.line, tok.col)

    def _parse_expr_stmt(self) -> ExprStmt:
        """expr_stmt → expr ';'"""
        tok  = self._peek()
        expr = self._parse_expr()
        self._expect(TokenType.SEMI)
        return ExprStmt(expr, tok.line, tok.col)

    # ── expressions (lowest → highest precedence) ─────────────────────────────

    def _parse_expr(self) -> Node:
        """Entry point for expression parsing."""
        return self._parse_assign()

    def _parse_assign(self) -> Node:
        """
        assign → (Var | ArrayIndex) assign_op assign   (right-associative)
               | logical_or

        We parse the left side as logical_or first.  If the next token
        is an assignment operator we know the left side must be an lvalue.
        """
        left = self._parse_logical_or()

        if self._peek().type in _ASSIGN_OPS:
            op_tok = self._advance()
            # Validate: only Var and ArrayIndex are valid assignment targets.
            if not isinstance(left, (Var, ArrayIndex)):
                raise ParseError(
                    "Invalid assignment target — must be a variable or array element",
                    op_tok.line, op_tok.col,
                )
            op    = _ASSIGN_OPS[op_tok.type]
            value = self._parse_assign()          # right-associative recursion
            return Assign(op, left, value, op_tok.line, op_tok.col)

        return left

    def _parse_logical_or(self) -> Node:
        """logical_or → logical_and ('||' logical_and)*"""
        left = self._parse_logical_and()
        while self._check(TokenType.PIPE_PIPE):
            op_tok = self._advance()
            right  = self._parse_logical_and()
            left   = BinOp('||', left, right, op_tok.line, op_tok.col)
        return left

    def _parse_logical_and(self) -> Node:
        """logical_and → bitwise_or ('&&' bitwise_or)*"""
        left = self._parse_bitwise_or()
        while self._check(TokenType.AMP_AMP):
            op_tok = self._advance()
            right  = self._parse_bitwise_or()
            left   = BinOp('&&', left, right, op_tok.line, op_tok.col)
        return left

    def _parse_bitwise_or(self) -> Node:
        """bitwise_or → bitwise_xor ('|' bitwise_xor)*"""
        left = self._parse_bitwise_xor()
        while self._check(TokenType.PIPE):
            op_tok = self._advance()
            right  = self._parse_bitwise_xor()
            left   = BinOp('|', left, right, op_tok.line, op_tok.col)
        return left

    def _parse_bitwise_xor(self) -> Node:
        """bitwise_xor → bitwise_and ('^' bitwise_and)*"""
        left = self._parse_bitwise_and()
        while self._check(TokenType.CARET):
            op_tok = self._advance()
            right  = self._parse_bitwise_and()
            left   = BinOp('^', left, right, op_tok.line, op_tok.col)
        return left

    def _parse_bitwise_and(self) -> Node:
        """bitwise_and → equality ('&' equality)*"""
        left = self._parse_equality()
        while self._check(TokenType.AMP):
            op_tok = self._advance()
            right  = self._parse_equality()
            left   = BinOp('&', left, right, op_tok.line, op_tok.col)
        return left

    def _parse_equality(self) -> Node:
        """equality → relational (('==' | '!=') relational)*"""
        left = self._parse_relational()
        while self._check(TokenType.EQ_EQ, TokenType.BANG_EQ):
            op_tok = self._advance()
            right  = self._parse_relational()
            op     = '==' if op_tok.type is TokenType.EQ_EQ else '!='
            left   = BinOp(op, left, right, op_tok.line, op_tok.col)
        return left

    def _parse_relational(self) -> Node:
        """relational → additive (('<' | '>' | '<=' | '>=') additive)*"""
        left = self._parse_additive()
        while self._peek().type in _RELATIONAL_OPS:
            op_tok = self._advance()
            right  = self._parse_additive()
            left   = BinOp(_RELATIONAL_OPS[op_tok.type], left, right,
                           op_tok.line, op_tok.col)
        return left

    def _parse_additive(self) -> Node:
        """additive → multiply (('+' | '-') multiply)*"""
        left = self._parse_multiply()
        while self._check(TokenType.PLUS, TokenType.MINUS):
            op_tok = self._advance()
            right  = self._parse_multiply()
            op     = '+' if op_tok.type is TokenType.PLUS else '-'
            left   = BinOp(op, left, right, op_tok.line, op_tok.col)
        return left

    def _parse_multiply(self) -> Node:
        """multiply → unary (('*' | '/' | '%') unary)*"""
        left = self._parse_unary()
        while self._peek().type in _MULTIPLY_OPS:
            op_tok = self._advance()
            right  = self._parse_unary()
            left   = BinOp(_MULTIPLY_OPS[op_tok.type], left, right,
                           op_tok.line, op_tok.col)
        return left

    def _parse_unary(self) -> Node:
        """unary → ('!' | '~' | '-') unary  |  postfix"""
        if self._peek().type in _UNARY_OPS:
            op_tok  = self._advance()
            operand = self._parse_unary()        # right-recursive
            return UnaryOp(_UNARY_OPS[op_tok.type], operand,
                           op_tok.line, op_tok.col)
        return self._parse_postfix()

    def _parse_postfix(self) -> Node:
        """
        postfix → primary '++'
                | primary '--'
                | IDENT '[' expr ']'
                | IDENT '(' arg_list? ')'
                | primary
        """
        node = self._parse_primary()

        if self._check(TokenType.PLUS_PLUS, TokenType.MINUS_MINUS):
            op_tok = self._advance()
            op     = '++' if op_tok.type is TokenType.PLUS_PLUS else '--'
            return PostfixOp(op, node, op_tok.line, op_tok.col)

        return node

    def _parse_primary(self) -> Node:
        """
        primary → INT_LIT | CHAR_LIT
                | IDENT '[' expr ']'      (array index)
                | IDENT '(' arg_list? ')' (function call)
                | IDENT                   (plain variable)
                | '(' expr ')'            (parenthesised expression)
        """
        tok = self._peek()

        if self._check(TokenType.INT_LIT):
            self._advance()
            return IntLit(tok.value, tok.line, tok.col)

        if self._check(TokenType.CHAR_LIT):
            self._advance()
            return CharLit(tok.value, tok.line, tok.col)

        if self._check(TokenType.IDENT):
            self._advance()
            # array index: name[expr]
            if self._check(TokenType.LBRACKET):
                self._advance()
                index = self._parse_expr()
                self._expect(TokenType.RBRACKET)
                return ArrayIndex(tok.value, index, tok.line, tok.col)
            # function call: name(args)
            if self._check(TokenType.LPAREN):
                self._advance()
                args: List[Node] = []
                if not self._check(TokenType.RPAREN):
                    args = self._parse_arg_list()
                self._expect(TokenType.RPAREN)
                return FuncCall(tok.value, args, tok.line, tok.col)
            # plain variable
            return Var(tok.value, tok.line, tok.col)

        if self._check(TokenType.LPAREN):
            self._advance()
            expr = self._parse_expr()
            self._expect(TokenType.RPAREN)
            return expr

        raise ParseError(
            f"Expected an expression, got {tok.type.name!r}",
            tok.line, tok.col,
        )

    def _parse_arg_list(self) -> List[Node]:
        """arg_list → expr (',' expr)*"""
        args = [self._parse_expr()]
        while self._match(TokenType.COMMA):
            args.append(self._parse_expr())
        return args
