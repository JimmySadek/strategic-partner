#!/usr/bin/env bash
# Contract for the disposable Claude launcher. Reads configuration only.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
LAUNCHER=${SP_VALIDATION_LAUNCHER:-/Users/OldJimmy/Developer/Personal/Codex_Work/SP_Serena_Validation/START_CLAUDE.command}
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

require_text() {
  label=$1
  text=$2
  if grep -F -- "$text" "$LAUNCHER" >/dev/null; then pass "$label"; else fail "$label (missing: $text)"; fi
}

for fixture in "$ROOT/tests/fixtures/validation-launcher/installed-floor.txt" "$ROOT/tests/fixtures/validation-launcher/candidate-floor.txt"; do
  [ -s "$fixture" ] && pass "$(basename "$fixture") is populated" || fail "$(basename "$fixture") is populated"
done

require_text "user settings are excluded" "--setting-sources project,local"
require_text "candidate plugin is explicit" '--plugin-dir "$PLUGIN_DIR"'
require_text "Serena config is explicit" '--mcp-config "$MCP_CONFIG"'
require_text "only the explicit MCP config is accepted" "--strict-mcp-config"
require_text "SP voice is session-only" '--settings "$SESSION_SETTINGS"'
require_text "floor receives the same session-only voice" 'SP_SESSION_OUTPUT_STYLE="$SESSION_OUTPUT_STYLE"'
require_text "preflight mode is available" "SP_VALIDATION_PREFLIGHT_ONLY"

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
