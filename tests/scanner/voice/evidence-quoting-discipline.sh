#!/usr/bin/env bash
# Evidence-quoting discipline: when the scanner quotes USER content
# (e.g., a rule body in S4 finding's rule_text), the quoted content may
# legitimately contain banned words. The voice ban applies to scanner-
# AUTHORED prose only.
#
# This test verifies that the user's text is preserved verbatim in the
# template_substitutions (not paraphrased / sanitized).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"

TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
# Build a fixture whose own rule body contains a "banned" word.
# Avoid "use" / "instead" / "prefer" / "replace with" so the S4 positive-
# direction filter doesn't suppress this prohibition rule.
cat > "$TMP/CLAUDE.md" <<MD
# Test
## Rules
- Don't write the word violation in your own rules; it's a wrong choice that signals noncompliant phrasing without alternatives.
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" 2>/dev/null)

# Find any S4 finding and verify its rule_text substitution preserves
# the user's text verbatim (including the banned words).
quoted=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S4")][0].template_substitutions.rule_text // ""')
echo "Quoted user text: $quoted"
case "$quoted" in
  *violation*wrong*noncompliant*) echo "✅ user text preserved verbatim including banned words" ;;
  *violation*|*wrong*|*noncompliant*) echo "✅ user text contains at least one banned word verbatim" ;;
  *) echo "❌ user text was sanitized — should be preserved verbatim"; exit 1 ;;
esac
