#!/usr/bin/env bash
# Regression test for the floor sentinel's tri-state version field (g6.diff).
# Guards against .backlog/fix-floor-sentinel-version-label-tristate.md: a
# local version AHEAD of the latest published release was mislabeled as
# "behind", producing a false "update available" notice.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

record_pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

assert_contains() {
  name="$1"
  actual="$2"
  expected="$3"
  if printf '%s' "$actual" | grep -F "$expected" >/dev/null; then
    record_pass "$name"
  else
    record_fail "$name (missing: $expected)"
  fi
}

# Stubs `curl` to return a crafted GitHub "latest release" response so the
# hook's remote-version lookup is deterministic regardless of network state.
curl() {
  printf '{"tag_name": "v%s"}' "$__SP_TEST_REMOTE"
}
export -f curl

run_floor() {
  script="$1"
  sid="$2"
  remote="$3"
  __SP_TEST_REMOTE="$remote"
  export __SP_TEST_REMOTE
  payload=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,prompt:"/strategic-partner"}')
  printf '%s' "$payload" | bash "$script" 2>&1
}

for target in "hooks/floor-check.sh:root" "plugin/strategic-partner/hooks/floor-check.sh:plugin"; do
  script_rel="${target%%:*}"
  label="${target##*:}"
  script="$ROOT/$script_rel"

  if [ "$label" = "plugin" ]; then
    skill_path="$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"
  else
    skill_path="$ROOT/SKILL.md"
  fi
  local_version=$(grep '^version:' "$skill_path" 2>/dev/null | head -1 | awk '{print $2}')

  out=$(run_floor "$script" "test-version-current-$label-$$" "$local_version")
  assert_contains "$label: current (remote == local)" "$out" "version=current"

  out=$(run_floor "$script" "test-version-ahead-$label-$$" "0.0.1")
  assert_contains "$label: ahead (remote < local)" "$out" "version=ahead"

  out=$(run_floor "$script" "test-version-behind-$label-$$" "999.0.0")
  assert_contains "$label: behind (remote > local)" "$out" "version=behind"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
