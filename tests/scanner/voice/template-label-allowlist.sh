#!/usr/bin/env bash
# Verify the locked C6 title field can contain otherwise-banned words
# without breaking the voice lint. Specifically: "Layer violation" is
# the canonical S2 title.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

# The S2 finding's title must be "Layer violation"
s2_title=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S2")][0].title // ""')
[ "$s2_title" = "Layer violation" ] && echo "✅ S2 title is locked 'Layer violation' (allowlisted)" || { echo "❌ S2 title='$s2_title'"; exit 1; }

# Verify that the title itself is the only place banned words appear
title_with_banned=$(echo "$out" | jq -r '[.findings[] | select(.title | test("[Vv]iolation|[Ww]rong|[Nn]oncompliant"))] | length')
echo "Findings with banned words in title (allowlist): $title_with_banned"

# And no banned words elsewhere
elsewhere=$(echo "$out" | jq -r '
  .findings[] |
  [.severity, .source_file, .section_anchor, .normalized_subject, .exception_label, (.template_substitutions | tostring), (.suggested_action | tostring)] |
  join(" ")
' | grep -iE 'noncompliant|\bwrong\b|\bviolation\b' || true)
[ -z "$elsewhere" ] && echo "✅ banned words confined to the locked title field" || { echo "❌ banned words leaked outside title"; echo "$elsewhere" | head -3; exit 1; }
