#!/usr/bin/env bash
# tests/scanner/integration/full-scan-agentsmd-broken-stub.sh
# Codex finding #5: B2 must follow non-Claude stub pointers (e.g.
# `.codex/rules/source-editing.md`) — not only `.claude/rules/*.md`.
# Asserts:
#   - Working hybrid: 0 B2 findings on agentsmd-with-stub-pointer/.
#   - Broken hybrid:  1 B2 finding on agentsmd-with-broken-stub/.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"

fail=0
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT

# Working hybrid (companion present at .codex/rules/source-editing.md).
# Copy fixture pair to a tmp dir outside SP repo so scanner_project_root
# resolves to the fixture root (per Finding #7's isolation requirement).
cp -R "$FIXTURES/agentsmd-with-stub-pointer" "$TMP/working"
cp "$TMP/working/AGENTS.md" "$TMP/working/AGENTS.md.bak"  # touch to confirm
working_out=$(cd "$TMP/working" && bash "$SCAN_SCRIPT" --file AGENTS.md 2>/dev/null)
working_b2=$(echo "$working_out" | jq -r '[.findings[] | select(.rule_id=="B2")] | length')
if [ "$working_b2" = "0" ]; then
  echo "✅ working AGENTS.md hybrid: 0 B2 findings"
else
  echo "❌ working AGENTS.md hybrid: expected 0 B2, got $working_b2"
  echo "$working_out" | jq '.findings | map(select(.rule_id=="B2"))'
  fail=1
fi

# Broken hybrid (stub pointer to .codex/rules/, no companion file).
cp -R "$FIXTURES/agentsmd-with-broken-stub" "$TMP/broken"
broken_out=$(cd "$TMP/broken" && bash "$SCAN_SCRIPT" --file AGENTS.md 2>/dev/null)
broken_b2=$(echo "$broken_out" | jq -r '[.findings[] | select(.rule_id=="B2")] | length')
if [ "$broken_b2" = "1" ]; then
  echo "✅ broken AGENTS.md hybrid: 1 B2 finding"
else
  echo "❌ broken AGENTS.md hybrid: expected 1 B2, got $broken_b2"
  echo "$broken_out" | jq '.findings | map(select(.rule_id=="B2"))'
  fail=1
fi

# Sanity: broken stub points at .codex/rules/source-editing.md (not .claude/).
broken_stub=$(echo "$broken_out" | jq -r '[.findings[] | select(.rule_id=="B2") | .template_substitutions.stub_target] | .[0] // ""')
case "$broken_stub" in
  *.codex/rules/source-editing.md)
    echo "✅ broken stub target captured correctly: $broken_stub" ;;
  "")
    : ;;  # already failed above
  *)
    echo "❌ broken stub target wrong: $broken_stub"; fail=1 ;;
esac

exit $fail
