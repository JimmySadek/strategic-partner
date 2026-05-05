#!/usr/bin/env bash
# C4 show-don't-tell: each suggested_action carries enough structure for
# the agent to compose show-don't-tell rendering. Verify the
# suggested_action object always has type + correct enum-shape.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

# Every finding has suggested_action.type set
empty_types=$(echo "$out" | jq '[.findings[] | select(.suggested_action.type == null or .suggested_action.type == "")] | length')
[ "$empty_types" = "0" ] && echo "✅ all findings have suggested_action.type" || { echo "❌ $empty_types findings missing type"; exit 1; }

# Verify every layer-routing finding records layer_target_available and fallback_used flags
flags_missing=$(echo "$out" | jq '[.findings[] | select(.suggested_action.type == "move_to_layer") | select(.suggested_action.layer_target_available == null or .suggested_action.fallback_used == null)] | length')
[ "$flags_missing" = "0" ] && echo "✅ layer-routing actions carry availability/fallback flags" || { echo "❌ $flags_missing missing flags"; exit 1; }
