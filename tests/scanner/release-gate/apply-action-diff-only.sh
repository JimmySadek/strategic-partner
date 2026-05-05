#!/usr/bin/env bash
# Verify the scanner does NOT mutate files (apply action is diff-only
# in v1 per locked mini-decision 13). Check file mtime unchanged after
# scan.
#
# Codex finding #8: ALSO verify each finding's suggested_action carries
# a non-null preview_command — the diff/snippet the user pastes manually.
# The previous test only verified mtime; this addition confirms the
# Apply-suggestion action actually has something actionable.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"

TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
mtime_before=$(stat -f %m "$TMP/CLAUDE.md" 2>/dev/null || stat -c %Y "$TMP/CLAUDE.md")

# Run a regular scan (not --release-gate) to capture full JSON output.
out=$( cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null )

mtime_after=$(stat -f %m "$TMP/CLAUDE.md" 2>/dev/null || stat -c %Y "$TMP/CLAUDE.md")
if [ "$mtime_before" != "$mtime_after" ]; then
  echo "❌ mtime changed ($mtime_before → $mtime_after)"
  exit 1
fi
echo "✅ scan did not mutate the target file"

# Codex finding #8: every suggested_action must have a non-null
# preview_command (the diff/snippet for manual application).
total=$(echo "$out" | jq -r '.findings | length')
if [ "$total" -eq 0 ]; then
  echo "❌ no findings produced — fixture should fire multiple rules"
  exit 1
fi

null_previews=$(echo "$out" | jq -r '[.findings[] | select(.suggested_action.preview_command == null)] | length')
if [ "$null_previews" -gt 0 ]; then
  echo "❌ $null_previews of $total findings have null preview_command"
  echo "$out" | jq -r '.findings[] | select(.suggested_action.preview_command == null) | "    \(.rule_id) at \(.section_anchor)"'
  exit 1
fi
echo "✅ all $total findings carry a non-null preview_command"

# Spot-check a few rules: the snippet should mention something
# rule-specific (the rule_id, the source file, or a substitution value).
spot_check_rule() {
  local rid="$1" needle="$2"
  local pv
  pv=$(echo "$out" | jq -r --arg r "$rid" \
    '[.findings[] | select(.rule_id == $r)] | .[0].suggested_action.preview_command // ""')
  if [ -z "$pv" ]; then
    return 0  # rule didn't fire on this fixture; skip
  fi
  if echo "$pv" | grep -qF "$needle"; then
    echo "✅ $rid preview contains '$needle'"
  else
    echo "❌ $rid preview missing '$needle' — got: ${pv:0:120}"
    return 1
  fi
}

fail=0
spot_check_rule S1 "claudedocs"  || fail=1
spot_check_rule S2 "Move"        || fail=1
spot_check_rule B1 "Behavioral Guardrails"  || fail=1
exit "$fail"
