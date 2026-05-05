#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
cat > "$TMP/.scanner-exceptions.json" <<EOF
{"schema_version":"v1","exceptions":[{
  "fingerprint":"0000000000000000",
  "rule_id":"S1",
  "source_file":"CLAUDE.md",
  "section_anchor":"<root>",
  "normalized_subject":"size-99999",
  "subject":"x", "reason":"y", "accepted_at":"2026-05-05"
}]}
EOF
cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "5" ] && echo "✅ wrong fingerprint → exit 5" || { echo "❌ exit $ec"; exit 1; }
