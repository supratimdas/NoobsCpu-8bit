#!/usr/bin/env python3
"""
noobsc.py — NoobsC compiler driver.

Phases:
  [1] Lexer    lexer.py
  [2] Parser   parser.py
  [3] Sema     semantic.py
  [4] Codegen  codegen.py   → produces a .asm file
  [5] Assemble noobsASM.pl  → produces code.txt / data.txt

Usage:
    python noobsc.py <input.nc>              # full compile → <input>.asm
    python noobsc.py --lex  <input.nc>       # dump tokens and exit
    python noobsc.py --ast  <input.nc>       # dump AST and exit
    python noobsc.py --asm  <input.nc>       # emit assembly, don't assemble
"""

import sys
import os
import subprocess

def _setup_path():
    here = os.path.dirname(os.path.abspath(__file__))
    if here not in sys.path:
        sys.path.insert(0, here)

_setup_path()

from lexer    import Lexer,   LexError
from parser   import Parser,  ParseError
from semantic import Analyser, SemanticError
from codegen  import CodeGen,  CodeGenError
from ast_nodes import pretty


def _die(msg: str):
    print(f"Error: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    argv = sys.argv[1:]

    # flags
    lex_only = '--lex' in argv
    ast_only = '--ast' in argv
    asm_only = '--asm' in argv
    for flag in ('--lex', '--ast', '--asm'):
        if flag in argv:
            argv.remove(flag)

    if not argv:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    src_path = argv[0]
    if not os.path.exists(src_path):
        _die(f"file not found: {src_path}")

    with open(src_path) as f:
        source = f.read()

    # ── Phase 1: Lex ─────────────────────────────────────────────────────────
    try:
        tokens = Lexer(source).tokenize()
    except LexError as e:
        _die(str(e))

    if lex_only:
        for tok in tokens:
            print(tok)
        return

    # ── Phase 2: Parse ───────────────────────────────────────────────────────
    try:
        ast = Parser(tokens).parse()
    except ParseError as e:
        _die(str(e))

    if ast_only:
        print(pretty(ast))
        return

    # ── Phase 3: Semantic analysis ───────────────────────────────────────────
    try:
        symbols = Analyser(ast).analyse()
    except SemanticError as e:
        _die(str(e))

    # ── Phase 4: Code generation ─────────────────────────────────────────────
    try:
        asm_text = CodeGen(ast, symbols).generate()
    except CodeGenError as e:
        _die(str(e))

    # Write .asm file in the current working directory
    stem     = os.path.splitext(os.path.basename(src_path))[0]
    asm_path = os.path.join(os.getcwd(), stem + '.asm')
    with open(asm_path, 'w') as f:
        f.write(asm_text)
    print(f"Assembly written to: {asm_path}")

    if asm_only:
        return

    # ── Phase 5: Assemble ────────────────────────────────────────────────────
    assembler = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                             '..', 'noobsASM.pl')
    if not os.path.exists(assembler):
        print(f"Assembler not found at {assembler} — skipping.")
        return

    result = subprocess.run(
        ['perl', assembler, asm_path],
        cwd=os.path.dirname(asm_path),
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        _die("Assembler failed.")

    print("Assembled successfully → code.txt / data.txt")


if __name__ == '__main__':
    main()
