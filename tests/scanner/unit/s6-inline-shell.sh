#!/usr/bin/env bash
# tests/scanner/unit/s6-inline-shell.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0
out=$(scan_isolated "$FIXTURES/inline-shell-heavy.md")
# Expect 2 findings (Setup + Tear-down); the annotated example must NOT fire
count=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S6")] | length')
[ "$count" -eq 2 ] && echo "✅ S6: 2 findings (annotated example skipped)" || { echo "❌ S6: expected 2, got $count"; fail=1; }
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S6 || fail=1
exit $fail
