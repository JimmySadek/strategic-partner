#!/usr/bin/env bash
# Both --release-gate and --report-only set → both apply
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
cd "$TMP"
out=$(bash "$SCAN_SCRIPT" --release-gate --report-only 2>/dev/null)
ec=$?
[ "$ec" = "4" ] && echo "✅ both flags → exit 4 from gate" || { echo "❌ exit $ec"; exit 1; }
ro_flag=$(echo "$out" | jq -r '.scan_metadata.flags.report_only')
[ "$ro_flag" = "true" ] && echo "✅ report_only=true in metadata" || { echo "❌ ro_flag=$ro_flag"; exit 1; }
