#!/usr/bin/env bash
# tests/scanner/unit/b2-stub-without-rules.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: hybrid-broken-stub-only fixture (stub exists, file does not)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp "$FIXTURES/hybrid-broken-stub-only.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" B2 || fail=1

# Negative: hybrid-clean-pair → no B2 (both stub + companion present)
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
assert_finding_silent "$out" B2 || fail=1

exit $fail
