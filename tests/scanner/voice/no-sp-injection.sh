#!/usr/bin/env bash
# Voice test: scanner output for non-SP target files must not mention
# "Strategic Partner" or "/strategic-partner:" in finding bodies. The
# scanner improves the user's project, not SP's brand.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

inject=$(echo "$out" | jq -r '
  .findings[] |
  [.template_substitutions, .suggested_action, .normalized_subject, .exception_label] |
  tostring
' | grep -iE 'strategic.partner|strategic_partner' || true)

if [ -n "$inject" ]; then
  echo "❌ Strategic Partner mentioned in finding bodies (non-SP target):"
  echo "$inject" | head -5
  exit 1
fi
echo "✅ no Strategic Partner injection in finding bodies"
