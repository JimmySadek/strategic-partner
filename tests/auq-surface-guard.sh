#!/usr/bin/env bash
# Minimal regression check for the AUQ Surface Guard.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

json_payload() {
  printf '{"session_id":"%s","tool_name":"%s"}' "$1" "$2"
}

check_code() {
  label="$1"
  expected="$2"
  actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'PASS %s\n' "$label"
  else
    printf 'FAIL %s expected=%s actual=%s\n' "$label" "$expected" "$actual"
    fail=1
  fi
}

run_case() {
  hook_dir="$1"
  name="$2"
  sid="auq-surface-${name}-$$"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  rm -f "/tmp/sp-auq-surface-${safe_sid}.flag" "/tmp/sp-auq-surface-blocked-${safe_sid}.flag"

  payload=$(json_payload "$sid" "AskUserQuestion")

  printf '%s' "$payload" | bash "$hook_dir/auq-surface.sh" PostToolUse >/tmp/auq-surface-test.out 2>&1
  printf '%s' "$payload" | bash "$hook_dir/guard-impl.sh" >/tmp/auq-surface-test.out 2>&1
  check_code "$name blocks first no-text AUQ" "2" "$?"

  printf '%s' "$payload" | bash "$hook_dir/guard-impl.sh" >/tmp/auq-surface-test.out 2>&1
  check_code "$name loop breaker allows second no-text AUQ" "0" "$?"

  printf '%s' "$payload" | bash "$hook_dir/auq-surface.sh" PostToolUse >/tmp/auq-surface-test.out 2>&1
  printf '%s' "$payload" | bash "$hook_dir/auq-surface.sh" MessageDisplay >/tmp/auq-surface-test.out 2>&1
  printf '%s' "$payload" | bash "$hook_dir/guard-impl.sh" >/tmp/auq-surface-test.out 2>&1
  check_code "$name allows AUQ after displayed text" "0" "$?"

  rm -f "/tmp/sp-auq-surface-${safe_sid}.flag" "/tmp/sp-auq-surface-blocked-${safe_sid}.flag"
}

run_case "$ROOT/hooks" "skill"
run_case "$ROOT/plugin/strategic-partner/hooks" "plugin"

rm -f /tmp/auq-surface-test.out
exit "$fail"
