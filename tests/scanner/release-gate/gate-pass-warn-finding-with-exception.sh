#!/usr/bin/env bash
# Bloated fixture warn finding covered by an exception → exit 0
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"

# First, learn the actual fingerprints of the warn findings the bloated
# fixture produces. Then build a complete coverage exception file.
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
scan_json=$(cd "$TMP" && bash "$SCAN_SCRIPT" --release-gate 2>/dev/null || true)
warn_findings=$(echo "$scan_json" | jq -c '[.findings[] | select(.severity == "warn" or .severity == "surface-loudly")]')
exceptions=$(echo "$warn_findings" | jq '[.[] | {
  fingerprint: .fingerprint,
  rule_id: .rule_id,
  source_file: .source_file,
  section_anchor: .section_anchor,
  normalized_subject: .normalized_subject,
  subject: .normalized_subject,
  reason: "covered for the gate test",
  accepted_at: "2026-05-05"
}]')
echo "{\"schema_version\":\"v1\",\"exceptions\":$exceptions}" > "$TMP/.scanner-exceptions.json"

cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "0" ] && echo "✅ warn covered by exception → exit 0" || { echo "❌ exit $ec"; exit 1; }
