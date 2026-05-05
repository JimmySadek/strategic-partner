#!/usr/bin/env bash
# B7 cross-file dedup test — same rule defined in primary + companion
# rules-file. The canonical-hybrid-skip kicks in (rules-file path
# .claude/rules/duplicates.md is recognized as a rules-file even though
# the basename isn't source-editing.md), so B7 silent.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
out=$(scan_in_dir "$FIXTURES/cross-file-duplication-pair" CLAUDE.md)
companions=$(echo "$out" | jq '.scan_metadata.companion_files | length')
echo "Companions discovered: $companions"
b7=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B7")] | length')
[ "$b7" = "0" ] && echo "✅ B7 silent (canonical hybrid skip)" || { echo "❌ B7=$b7"; fail=1; }
exit $fail
