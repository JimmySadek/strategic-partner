#!/usr/bin/env bash
# tests/scanner/unit/b6-wrong-layer.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: enforceable-rules fixture has lint/pre-commit/format catalog
# matches across several rules
out=$(scan_isolated "$FIXTURES/enforceable-rules.md")
assert_finding_fires "$out" B6 || fail=1

# Negative: clean-minimal — no rules, silent
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" B6 || fail=1

exit $fail
