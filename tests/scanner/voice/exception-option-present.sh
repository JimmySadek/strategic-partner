#!/usr/bin/env bash
# Every finding must carry a non-empty exception_label per locked C6.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

empty_labels=$(echo "$out" | jq '[.findings[] | select(.exception_label == null or .exception_label == "")] | length')
[ "$empty_labels" = "0" ] && echo "✅ all findings carry an exception_label" || { echo "❌ $empty_labels missing"; exit 1; }

# Each label opens with "[" and closes with "]" — locked option-style
malformed=$(echo "$out" | jq -r '[.findings[] | select(.exception_label | test("^\\[.*\\]$") | not)] | length')
[ "$malformed" = "0" ] && echo "✅ all exception_labels are bracketed option text" || { echo "❌ $malformed malformed"; exit 1; }
