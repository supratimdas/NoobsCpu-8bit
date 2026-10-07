#!/usr/bin/env bash
# Run all NoobsC compiler unit tests.
# Usage: bash utils/NoobsC/tests/run_tests.sh
set -e
cd "$(dirname "$0")/.."
python -m pytest tests/ -v "$@"
