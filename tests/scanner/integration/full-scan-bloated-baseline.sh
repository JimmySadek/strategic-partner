#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
result=$(scan_isolated "$FIXTURES/bloated-no-sections.md")
total=$(echo "$result" | jq '.findings | length')
[ "$total" -ge 5 ] && echo "✅ bloated-baseline: $total findings (≥5)" || { echo "❌ expected ≥5, got $total"; fail=1; }
# Multiple rule classes
classes=$(echo "$result" | jq -r '[.findings[] | .rule_id] | unique | length')
[ "$classes" -ge 2 ] && echo "✅ findings span ≥2 rule classes ($classes distinct rule_ids)" || fail=1
exit $fail
