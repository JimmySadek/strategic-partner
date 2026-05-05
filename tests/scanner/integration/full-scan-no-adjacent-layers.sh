#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
# Run from tmp dir with no adjacent layers — scan finds nothing or
# uses fallback routing
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
result=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
present=$(echo "$result" | jq -r '.layer_probe.layers_present | length')
absent=$(echo "$result" | jq -r '.layer_probe.layers_absent | length')
echo "Layers present: $present, absent: $absent"
[ "$present" -le 1 ] && echo "✅ tmp project: ≤1 layer detected" || { echo "❌ expected ≤1 present in tmp, got $present"; fail=1; }
exit $fail
