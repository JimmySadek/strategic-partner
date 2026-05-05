#!/usr/bin/env bash
# tests/scanner/unit/s5-provisional-guard-expiry.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0
out=$(scan_isolated "$FIXTURES/provisional-guards-expired.md")
assert_finding_fires "$out" S5 expired-guard-a || fail=1
# Far-future guard should NOT fire
near_count=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S5" and (.normalized_subject | contains("future-guard-c")))] | length')
[ "$near_count" -eq 0 ] && echo "✅ S5: future-guard-c silent" || { echo "❌ S5 fired on far-future"; fail=1; }
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S5 || fail=1
exit $fail
