#!/usr/bin/env bash
# Defensive (unused) exception with valid fingerprint, no findings to cover.
# Should pass (exit 0) and surface unused_exceptions in coverage.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
fp=$(bash -c "
  . '$PROJECT_ROOT/.scripts/context-file-scan/lib/utils.sh'
  scanner_fingerprint S3 CLAUDE.md '<root>' 'future-broken-path-md'
")
cat > "$TMP/.scanner-exceptions.json" <<EOF
{"schema_version":"v1","exceptions":[{
  "fingerprint":"$fp",
  "rule_id":"S3",
  "source_file":"CLAUDE.md",
  "section_anchor":"<root>",
  "normalized_subject":"future-broken-path-md",
  "subject":"x", "reason":"defensive", "accepted_at":"2026-05-05"
}]}
EOF
cd "$TMP"
out=$(bash "$SCAN_SCRIPT" --release-gate 2>/dev/null)
ec=$?
[ "$ec" = "0" ] && echo "✅ defensive (unused) → exit 0" || { echo "❌ exit $ec"; exit 1; }
unused=$(echo "$out" | jq '.release_gate.coverage.unused_exceptions | length')
[ "$unused" = "1" ] && echo "✅ defensive listed in unused_exceptions" || { echo "❌ unused=$unused"; exit 1; }
