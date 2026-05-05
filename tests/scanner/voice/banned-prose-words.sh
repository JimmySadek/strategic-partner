#!/usr/bin/env bash
# Voice test: banned words ("noncompliant", "wrong", "violation") must
# not appear in finding fields OUTSIDE the locked C6 title field. The
# template-label allowlist preserves "Layer violation" as a canonical
# title.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"

# Run scanner against bloated fixture — has S2 warn findings whose title
# is "Layer violation" (allowlisted).
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

# Inspect every finding's non-title fields for banned words
banned=$(echo "$out" | jq -r '
  .findings[] |
  [.severity, .source_file, .section_anchor, .normalized_subject, .exception_label, (.template_substitutions | tostring), (.suggested_action | tostring)] |
  join(" ")
' | grep -iE 'noncompliant|wrong|\bviolation\b' || true)

if [ -n "$banned" ]; then
  echo "❌ banned word in non-title fields:"
  echo "$banned"
  exit 1
fi
echo "✅ no banned words in non-title fields"

# Verify the title field IS allowed to contain 'violation' (template-label allowlist)
title_violations=$(echo "$out" | jq -r '[.findings[] | select(.title | test("[Vv]iolation"))] | length')
if [ "$title_violations" -gt 0 ]; then
  echo "✅ allowlist: '$title_violations' finding(s) carry 'violation' in title (locked C6 label)"
fi
