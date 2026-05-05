#!/usr/bin/env bash
# tests/scanner/unit/s1-size-breach.sh
# S1 — Size breach. Positive: bloated fixture (~30K) → warn band.
# Negative: clean-minimal fixture → no S1.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: bloated >24K → warn band
out=$(scan_isolated "$FIXTURES/bloated-no-sections.md")
assert_finding_fires "$out" S1 size- || fail=1

# Negative: small file → no S1
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S1 || fail=1

# Edge: build a fixture exactly at the soft-warn boundary
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
yes 'A' | head -c 16384 > "$TMP/edge.md"
out=$(scan_isolated "$TMP/edge.md")
sev=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S1")][0].severity // ""')
[ "$sev" = "info" ] && echo "✅ S1 edge (16384) → info" || { echo "❌ S1 edge: severity=$sev"; fail=1; }

exit $fail
