#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
echo '{"schema_version":"v2","exceptions":[]}' > "$TMP/.scanner-exceptions.json"
cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
ec=$?
[ "$ec" = "5" ] && echo "✅ schema_version mismatch → exit 5" || { echo "❌ exit $ec"; exit 1; }
