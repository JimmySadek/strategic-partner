#!/usr/bin/env bash
# Two warn findings of the same rule, exception covers one → exit 4
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
# Use stale-entries-paths fixture (3 broken paths → 3 warn findings)
cp "$FIXTURES/stale-entries-paths.md" "$TMP/CLAUDE.md"
cd "$TMP"
all=$(bash "$SCAN_SCRIPT" --release-gate 2>/dev/null || true)
fp=$(echo "$all" | jq -r '[.findings[] | select(.severity == "warn")][0].fingerprint')
rid=$(echo "$all" | jq -r '[.findings[] | select(.severity == "warn")][0].rule_id')
src=$(echo "$all" | jq -r '[.findings[] | select(.severity == "warn")][0].source_file')
anc=$(echo "$all" | jq -r '[.findings[] | select(.severity == "warn")][0].section_anchor')
ns=$(echo "$all" | jq -r '[.findings[] | select(.severity == "warn")][0].normalized_subject')
cat > "$TMP/.scanner-exceptions.json" <<EOF
{"schema_version":"v1","exceptions":[{
  "fingerprint":"$fp","rule_id":"$rid","source_file":"$src",
  "section_anchor":"$anc","normalized_subject":"$ns",
  "subject":"x","reason":"covers one","accepted_at":"2026-05-05"
}]}
EOF
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "4" ] && echo "✅ partial coverage → exit 4 (others uncovered)" || { echo "❌ exit $ec"; exit 1; }
