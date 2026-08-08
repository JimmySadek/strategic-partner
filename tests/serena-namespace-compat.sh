#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
GUARD="$ROOT/hooks/guard-impl.sh"
PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s — %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

run_guard() {
  tool="$1"
  path="$2"
  payload=$(printf '{"tool_name":"%s","tool_input":{"relative_path":"%s"}}' "$tool" "$path")
  printf '%s' "$payload" | bash "$GUARD" >/dev/null 2>&1
}

run_guard mcp__serena__replace_symbol_body src/app.py
status=$?
[ "$status" -eq 2 ] && pass "user namespace source mutation blocks" || fail "user namespace source mutation" "exit=$status"

run_guard mcp__serena__replace_symbol_body specs/plan.html
status=$?
[ "$status" -eq 0 ] && pass "user namespace managed plan allows" || fail "user namespace managed plan" "exit=$status"

run_guard mcp__plugin_serena_serena__replace_symbol_body src/app.py
status=$?
[ "$status" -eq 2 ] && pass "legacy plugin namespace still blocks" || fail "legacy plugin namespace" "exit=$status"

if grep -q 'mcp__serena__' "$ROOT/SKILL.md" && grep -q 'mcp__serena__' "$ROOT/plugin/strategic-partner/hooks/hooks.json"; then
  pass "frontmatter and plugin hook discover user namespace"
else
  fail "hook namespace matchers" "user namespace missing"
fi

plugin_serena_command="$ROOT/plugin/strategic-partner/commands/serena.md"
if grep -Fq '${CLAUDE_PLUGIN_ROOT}' "$plugin_serena_command" \
  && ! grep -q "Find this plugin's root directory from the command location" "$plugin_serena_command"; then
  pass "plugin Serena command pins its active plugin root"
else
  fail "plugin root resolution" "command can substitute another installed SP copy"
fi

root_serena_command="$ROOT/commands/serena.md"
repair_contract_ok=true
for command_file in "$root_serena_command" "$plugin_serena_command"; do
  normalized=$(tr '\n' ' ' < "$command_file" | tr -s ' ')
  printf '%s' "$normalized" | grep -Fq 'Apply machine-wide Serena repair (Recommended)' || repair_contract_ok=false
  printf '%s' "$normalized" | grep -Fq 'user-scope Serena MCP registration' || repair_contract_ok=false
  printf '%s' "$normalized" | grep -Fq 'directly in this same Claude session' || repair_contract_ok=false
  grep -Eq -- '--apply --yes && .*--verify' "$command_file" || repair_contract_ok=false
  grep -Fq 'Never retry' "$command_file" || repair_contract_ok=false
  grep -Fq 'general-purpose' "$command_file" && repair_contract_ok=false
  grep -Fq 'subagent_type' "$command_file" && repair_contract_ok=false
done
if [ "$repair_contract_ok" = true ]; then
  pass "Serena commands keep direct consent and repair in one session"
else
  fail "Serena repair trust boundary" "direct consent, machine-wide scope, same-session execution, or no-retry rule missing"
fi

active_deleted=$(rg -n 'check_onboarding_performed' \
  "$ROOT/SKILL.md" \
  "$ROOT/commands" \
  "$ROOT/references" \
  "$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md" \
  "$ROOT/plugin/strategic-partner/commands" \
  "$ROOT/plugin/strategic-partner/skills/strategic-partner/references" 2>/dev/null || true)
if [ -z "$active_deleted" ]; then
  pass "active workflows avoid deleted onboarding tool"
else
  fail "deleted onboarding tool" "$active_deleted"
fi

temp_home=$(mktemp -d "${TMPDIR:-/tmp}/sp-permission-test.XXXXXX")
mkdir -p "$temp_home/.claude"
printf '%s\n' '{"permissions":{"allow":["Read(*)","mcp__serena__*","mcp__plugin_context7_context7__*"]}}' > "$temp_home/.claude/settings.json"
audit_output=$(HOME="$temp_home" python3 "$ROOT/audit-permissions" --dry-run 2>&1)
if printf '%s' "$audit_output" | grep -q 'Serena permission safety.*broad static approval' && ! printf '%s' "$audit_output" | grep -q 'Serena MCP permission.*MISSING'; then
  pass "permission audit flags unconditional Serena approval"
else
  fail "permission audit safety" "$audit_output"
fi

printf '\nSerena namespace compatibility: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
