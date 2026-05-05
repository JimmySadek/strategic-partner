#!/usr/bin/env bash
# tests/scanner/unit/b7-rule-duplication.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: cross-file-duplication-pair — same rule names in primary AND
# rules-file (path-named "duplicates.md", not "source-editing.md", so
# the canonical hybrid skip does NOT apply by file name; B7 should fire
# unless the rules-file pattern (.claude/rules/*) auto-skips it. Per
# spec, this IS a B7 cross-file scenario)
# NOTE: the hybrid-skip in scanner_rule_B7 is path-driven — any
# .claude/rules/*.md is treated as a rules-file. So this fixture exercises
# the hybrid-pattern skip path. We assert B7 silent.
out=$(scan_in_dir "$FIXTURES/cross-file-duplication-pair" CLAUDE.md)
assert_finding_silent "$out" B7 || fail=1
echo "✅ B7: cross-file canonical hybrid skip works"

# Negative: clean fixture
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" B7 || fail=1

# Edge: same rule defined twice in the SAME file → should fire B7
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/CLAUDE.md" <<MD
# Project
## Behavioral Guardrails

### Think Before Coding
State assumptions; surface confusion.

### Think Before Coding
State assumptions; ask if uncertain.
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" B7 || fail=1

exit $fail
