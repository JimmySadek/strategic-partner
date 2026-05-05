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

# Codex finding #6: canonical phrases with inline-code backticks must
# trigger. Each rule in the canonical fixture uses one canonical phrase
# verbatim from spec § 4.B6 — `No \`console.log\``, `No \`print()\``,
# `No \`debugger\``, `No \`.env\` files in commits`, `Always use prettier`.
out=$(scan_isolated "$FIXTURES/enforceable-rules-canonical.md")
assert_finding_fires "$out" B6 console-log         || fail=1
assert_finding_fires "$out" B6 print               || fail=1
assert_finding_fires "$out" B6 debugger            || fail=1
assert_finding_fires "$out" B6 env-files-in-commits || fail=1
assert_finding_fires "$out" B6 always-use-prettier || fail=1

exit $fail
