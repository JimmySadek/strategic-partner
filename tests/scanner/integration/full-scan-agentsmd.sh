#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/agentsmd-clean.md" "$TMP/AGENTS.md"
result=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)
ec=$?
[ "$ec" = "0" ] && echo "✅ AGENTS.md auto-detected (exit 0)" || { echo "❌ exit $ec"; fail=1; }
primary=$(echo "$result" | jq -r '.scan_metadata.primary_file.path')
[ "$primary" = "AGENTS.md" ] && echo "✅ primary=AGENTS.md" || { echo "❌ primary=$primary"; fail=1; }
exit $fail
