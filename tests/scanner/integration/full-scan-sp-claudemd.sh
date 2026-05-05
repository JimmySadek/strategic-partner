#!/usr/bin/env bash
# Integration: scan SP's own CLAUDE.md (post-v5.18.0 baseline).
# Self-binding-gate baseline reference. Asserts exit 0 from a default
# scan (Mode A JSON) and 4 warn-level findings count (the S2 table-heavy
# sections — expected baseline addressed via .scanner-exceptions.json).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
result=$(cd "$PROJECT_ROOT" && bash "$SCAN_SCRIPT" 2>/dev/null)
ec=$?
[ "$ec" = "0" ] && echo "✅ default scan exit 0" || { echo "❌ exit $ec"; fail=1; }
warn_count=$(echo "$result" | jq '[.findings[] | select(.severity == "warn" or .severity == "surface-loudly")] | length')
echo "warn+ findings: $warn_count"
exit $fail
