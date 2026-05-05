#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
cat > "$TMP/.scanner-exceptions.json" <<EOF
{"schema_version":"v1","exceptions":[{
  "fingerprint":"abcdef0123456789",
  "rule_id":"S1",
  "source_file":"CLAUDE.md"
}]}
EOF
cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "5" ] && echo "✅ missing required field → exit 5" || { echo "❌ exit $ec"; exit 1; }
