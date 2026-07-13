#!/usr/bin/env bash
# Regression harness for truthful floor memory/output-style status and demand-driven routing.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/sp-floor-startup.XXXXXX")
ORIGINAL_HOME=${HOME:-}

cleanup() {
  HOME="$ORIGINAL_HOME"
  export HOME
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

HOME="$TMP_ROOT/home"
export HOME
mkdir -p "$HOME/.claude/agents"
printf '%s\n' '# test agent' > "$HOME/.claude/agents/test-agent.md"

curl() { return 1; }
export -f curl

record_pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

record_fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$1"
}

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

assert_not_contains() {
  name="$1"
  actual="$2"
  unexpected="$3"
  if printf '%s' "$actual" | grep -F "$unexpected" >/dev/null; then
    record_fail "$name (unexpected: $unexpected)"
  else
    record_pass "$name"
  fi
}

run_floor() {
  script="$1"
  project="$2"
  sid="$3"
  payload=$(jq -cn --arg sid "$sid" --arg cwd "$project" \
    '{session_id:$sid,cwd:$cwd,prompt:"/strategic-partner"}')
  printf '%s' "$payload" | bash "$script" 2>&1
}

run_floor_with_transcript() {
  script="$1"
  project="$2"
  sid="$3"
  transcript="$4"
  payload=$(jq -cn --arg sid "$sid" --arg cwd "$project" --arg transcript "$transcript" \
    '{session_id:$sid,cwd:$cwd,transcript_path:$transcript,prompt:"/strategic-partner"}')
  printf '%s' "$payload" | bash "$script" 2>&1
}

runtime_style_transcript="$TMP_ROOT/runtime-output-style.jsonl"
printf '%s\n' '{"type":"attachment","attachment":{"type":"output_style","style":"strategic-partner-voice"}}' > "$runtime_style_transcript"

for floor_script in "$ROOT/hooks/floor-check.sh" "$ROOT/plugin/strategic-partner/hooks/floor-check.sh"; do
  surface=skill
  case "$floor_script" in */plugin/*) surface=plugin ;; esac

  empty_project="$TMP_ROOT/${surface}-empty"
  mkdir -p "$empty_project/.serena/memories"
  empty_output=$(run_floor "$floor_script" "$empty_project" "floor-${surface}-empty-$$")
  assert_contains "$surface empty memory directory reports missing" "$empty_output" "memory=missing"
  assert_not_contains "$surface empty memory directory never reports healthy" "$empty_output" "memory=ok"

  partial_project="$TMP_ROOT/${surface}-partial"
  mkdir -p "$partial_project/.serena/memories"
  printf '%s\n' '# Project' > "$partial_project/.serena/memories/project_overview.md"
  partial_output=$(run_floor "$floor_script" "$partial_project" "floor-${surface}-partial-$$")
  assert_contains "$surface missing decision log reports missing" "$partial_output" "memory=missing"

  healthy_project="$TMP_ROOT/${surface}-healthy"
  mkdir -p "$healthy_project/.serena/memories"
  printf '%s\n' '# Project' > "$healthy_project/.serena/memories/project_overview.md"
  printf '%s\n' '# Decisions' > "$healthy_project/.serena/memories/decision_log.md"
  healthy_output=$(run_floor "$floor_script" "$healthy_project" "floor-${surface}-healthy-$$")
  assert_contains "$surface required project memories report healthy" "$healthy_output" "memory=ok"

  runtime_style_output=$(run_floor_with_transcript "$floor_script" "$healthy_project" \
    "floor-${surface}-runtime-style-$$" "$runtime_style_transcript")
  assert_contains "$surface runtime output style overrides absent persistent setting" \
    "$runtime_style_output" "output_style=strategic-partner-voice"
done

for policy_file in \
  "$ROOT/SKILL.md" \
  "$ROOT/plugin/strategic-partner/skills/strategic-partner/SKILL.md"
do
  policy=$(cat "$policy_file")
  assert_contains "$(basename "$policy_file") makes routing demand-driven" "$policy" "Routing maintenance never gates startup orientation."
  assert_not_contains "$(basename "$policy_file") removes mandatory startup routing" "$policy" "routing matrix MUST be built at startup"
done

for routing_file in \
  "$ROOT/references/startup-checklist.md" \
  "$ROOT/plugin/strategic-partner/skills/strategic-partner/references/startup-checklist.md"
do
  routing_policy=$(cat "$routing_file")
  assert_contains "$(basename "$routing_file") keeps Agent D off the startup path" "$routing_policy" "Agent D is not a startup prerequisite."
  assert_not_contains "$(basename "$routing_file") removes floor-triggered startup dispatch" "$routing_policy" "DISPATCHED ONLY ON FLOOR-SIGNAL"
done

for signal_file in \
  "$ROOT/references/floor-signal-handling.md" \
  "$ROOT/plugin/strategic-partner/skills/strategic-partner/references/floor-signal-handling.md"
do
  signal_policy=$(cat "$signal_file")
  assert_contains "$(basename "$signal_file") protects read-only startup" "$signal_policy" "Read-only requests never dispatch routing maintenance"
done

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
