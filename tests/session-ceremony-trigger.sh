#!/usr/bin/env bash
# Focused regression harness for Strategic Partner startup and closure ceremonies.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENTRY="$ROOT/plugin/strategic-partner/hooks/entry.sh"
LIB="$ROOT/plugin/strategic-partner/hooks/lib/session-ceremony.sh"
FIXTURES="$ROOT/tests/fixtures/session-ceremony"
MODE="${1:-all}"
PASS=0
FAIL=0

# Keep the floor probe deterministic and offline in the focused harness.
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
  if printf '%s' "$actual" | grep -qF "$expected"; then
    record_pass "$name"
  else
    record_fail "$name (missing: $expected)"
  fi
}

assert_not_contains() {
  name="$1"
  actual="$2"
  unexpected="$3"
  if printf '%s' "$actual" | grep -qF "$unexpected"; then
    record_fail "$name (unexpected: $unexpected)"
  else
    record_pass "$name"
  fi
}

assert_block_json() {
  name="$1"
  actual="$2"
  if printf '%s' "$actual" | jq -e '.decision == "block" and ((.reason // "") | length > 0)' >/dev/null 2>&1; then
    record_pass "$name"
  else
    record_fail "$name (invalid Stop block JSON)"
  fi
}

assert_startup_pending() {
  name="$1"
  sid="$2"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  if [ -f "/tmp/sp-plugin-startup-pending-${safe_sid}" ]; then
    record_pass "$name"
  else
    record_fail "$name (startup-pending marker missing)"
  fi
}

assert_startup_cleared() {
  name="$1"
  sid="$2"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  if [ ! -e "/tmp/sp-plugin-startup-pending-${safe_sid}" ]; then
    record_pass "$name"
  else
    record_fail "$name (startup-pending marker still present)"
  fi
}

assert_session_unarmed() {
  name="$1"
  sid="$2"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  if [ ! -e "/tmp/sp-plugin-active-${safe_sid}" ] && [ ! -e "/tmp/sp-plugin-startup-pending-${safe_sid}" ]; then
    record_pass "$name"
  else
    record_fail "$name (utility command armed advisory markers)"
  fi
}

assert_utility_guard_armed() {
  name="$1"
  sid="$2"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  if [ -e "/tmp/sp-plugin-utility-guard-${safe_sid}" ]; then
    record_pass "$name"
  else
    record_fail "$name (utility guard marker missing)"
  fi
}

payload() {
  sid="$1"
  transcript="$2"
  last_message="$3"
  stop_active="${4:-false}"
  jq -cn \
    --arg session_id "$sid" \
    --arg cwd "$ROOT" \
    --arg transcript_path "$transcript" \
    --arg last_assistant_message "$last_message" \
    --argjson stop_hook_active "$stop_active" \
    '{session_id:$session_id,cwd:$cwd,transcript_path:$transcript_path,last_assistant_message:$last_assistant_message,stop_hook_active:$stop_hook_active}'
}

run_entry() {
  event="$1"
  data="$2"
  printf '%s' "$data" | bash "$ENTRY" "$event" 2>&1
}

last_assistant_text() {
  jq -sr '
    map(select((.message.role // .role // "") == "assistant"))
    | last
    | (.message.content // .content // [])
    | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end
  ' "$1"
}

activate_with_prompt() {
  sid="$1"
  prompt="$2"
  transcript="$3"
  data=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" --arg transcript "$transcript" --arg prompt "$prompt" \
    '{session_id:$sid,cwd:$cwd,transcript_path:$transcript,prompt:$prompt}')
  run_entry UserPromptSubmit "$data"
}

mark_active() {
  sid="$1"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  : > "/tmp/sp-plugin-active-${safe_sid}"
}

cleanup_session() {
  sid="$1"
  safe_sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
  rm -f "/tmp/sp-plugin-active-${safe_sid}" "/tmp/sp-plugin-startup-pending-${safe_sid}" "/tmp/sp-plugin-utility-guard-${safe_sid}"
}

run_activation_tests() {
  utility_payload=$(jq -cn --arg sid "ceremony-floor-utility-$$" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,prompt:"/strategic-partner:serena"}')
  for floor_script in "$ROOT/hooks/floor-check.sh" "$ROOT/plugin/strategic-partner/hooks/floor-check.sh"; do
    floor_surface=skill
    case "$floor_script" in */plugin/*) floor_surface=plugin ;; esac
    output=$(printf '%s' "$utility_payload" | bash "$floor_script" 2>&1)
    assert_not_contains "Serena utility skips $floor_surface floor" "$output" "SP-FLOOR-COMPLETE"
  done

  sid="ceremony-expansion-$$"
  cleanup_session "$sid"
  data=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,command_name:"strategic-partner-plugin:strategic-partner",command_args:""}')
  output=$(run_entry UserPromptExpansion "$data")
  assert_contains "typed command expansion emits startup floor" "$output" "SP-FLOOR-COMPLETE"
  assert_startup_pending "typed command expansion marks startup pending" "$sid"

  sid="ceremony-compat-$$"
  cleanup_session "$sid"
  output=$(activate_with_prompt "$sid" "/strategic-partner-plugin:strategic-partner" "$FIXTURES/startup-complete.jsonl")
  assert_contains "UserPromptSubmit compatibility path emits startup floor" "$output" "SP-FLOOR-COMPLETE"

  sid="ceremony-serena-utility-$$"
  cleanup_session "$sid"
  output=$(activate_with_prompt "$sid" "/strategic-partner-plugin:serena" "$FIXTURES/serena-utility-wait.jsonl")
  assert_not_contains "Serena utility compatibility path skips startup floor" "$output" "SP-FLOOR-COMPLETE"
  assert_session_unarmed "Serena utility compatibility path stays unarmed" "$sid"
  assert_utility_guard_armed "Serena utility keeps the source guard active" "$sid"
  guard_payload=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,tool_name:"Edit",tool_input:{file_path:($cwd + "/src/app.py")}}')
  output=$(run_entry PreToolUse "$guard_payload")
  guard_status=$?
  if [ "$guard_status" -eq 2 ] && printf '%s' "$output" | grep -q 'BLOCKED'; then
    record_pass "Serena utility source mutation remains guarded"
  else
    record_fail "Serena utility source mutation remains guarded (status=$guard_status)"
  fi
  transcript="$FIXTURES/serena-utility-wait.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "Serena utility wait does not trigger startup ceremony" "$output" '"decision":"block"'

  sid="ceremony-skill-$$"
  cleanup_session "$sid"
  data=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,tool_name:"Skill",tool_input:{skill:"strategic-partner-plugin:strategic-partner"}}')
  output=$(run_entry PreToolUse "$data")
  assert_contains "natural Skill activation emits startup floor" "$output" "SP-FLOOR-COMPLETE"
  assert_startup_pending "natural Skill activation marks startup pending" "$sid"

  sid="ceremony-resident-$$"
  cleanup_session "$sid"
  data=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,source:"startup",agent_type:"sp-advisor"}')
  output=$(run_entry SessionStart "$data")
  assert_contains "resident agent_type startup emits startup floor" "$output" "SP-FLOOR-COMPLETE"
  assert_startup_pending "resident agent_type marks startup pending" "$sid"
}

run_stop_tests() {
  sid="ceremony-startup-missing-$$"
  cleanup_session "$sid"
  activate_with_prompt "$sid" "/strategic-partner-plugin:strategic-partner" "$FIXTURES/startup-missing-auq.jsonl" >/dev/null
  transcript="$FIXTURES/startup-missing-auq.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "startup without AskUserQuestion stays non-blocking" "$output" '"decision":"block"'
  assert_startup_cleared "startup gap clears its pending marker" "$sid"

  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "repeated startup Stop evaluation stays non-blocking" "$output" '"decision":"block"'

  sid="ceremony-startup-complete-$$"
  cleanup_session "$sid"
  activate_with_prompt "$sid" "/strategic-partner-plugin:strategic-partner" "$FIXTURES/startup-complete.jsonl" >/dev/null
  transcript="$FIXTURES/startup-complete.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "complete startup passes Stop" "$output" '"decision":"block"'

  sid="ceremony-continuation-$$"
  cleanup_session "$sid"
  data=$(jq -cn --arg sid "$sid" --arg cwd "$ROOT" \
    '{session_id:$sid,cwd:$cwd,command_name:"strategic-partner-plugin:strategic-partner",command_args:".handoffs/session-wrap-0709-1200.md"}')
  output=$(run_entry UserPromptExpansion "$data")
  assert_contains "explicit continuation emits startup floor" "$output" "SP-FLOOR-COMPLETE"
  transcript="$FIXTURES/continuation-complete.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "loaded continuation with AUQ passes Stop" "$output" '"decision":"block"'

  sid="ceremony-closure-missing-$$"
  cleanup_session "$sid"
  mark_active "$sid"
  transcript="$FIXTURES/closure-recap-only.jsonl"
  stop_data=$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")
  output=$(run_entry Stop "$stop_data")
  assert_contains "recap-only closeout blocks" "$output" '"decision":"block"'
  assert_contains "closeout block names the missing ceremony" "$output" "closure ceremony"
  assert_block_json "closeout block is valid structured JSON" "$output"

  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")" true)")
  assert_not_contains "corrective Stop pass cannot loop" "$output" '"decision":"block"'

  sid="ceremony-closure-complete-$$"
  cleanup_session "$sid"
  mark_active "$sid"
  transcript="$FIXTURES/closure-complete.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "complete closure passes Stop" "$output" '"decision":"block"'

  sid="ceremony-closure-override-$$"
  cleanup_session "$sid"
  mark_active "$sid"
  transcript="$FIXTURES/closure-override.jsonl"
  output=$(run_entry Stop "$(payload "$sid" "$transcript" "$(last_assistant_text "$transcript")")")
  assert_not_contains "explicit keep-open override bypasses closure" "$output" '"decision":"block"'
}

assert_classifier_true() {
  name="$1"
  shift
  if "$@"; then record_pass "$name"; else record_fail "$name"; fi
}

assert_classifier_false() {
  name="$1"
  shift
  if "$@"; then record_fail "$name"; else record_pass "$name"; fi
}

assert_equal() {
  name="$1"
  actual="$2"
  expected="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$name"
  else
    record_fail "$name (expected: $expected; actual: $actual)"
  fi
}

run_classifier_tests() {
  if [ ! -f "$LIB" ]; then
    record_fail "classifier library exists"
    return
  fi
  # shellcheck source=/dev/null
  . "$LIB"

  assert_classifier_true "plugin command is an activation" sp_is_command_activation "strategic-partner-plugin:strategic-partner" ""
  assert_classifier_false "utility command is not an activation" sp_is_command_activation "strategic-partner-plugin:help" ""
  assert_classifier_false "legacy utility argument is not an activation" sp_is_command_activation "strategic-partner" ":help"
  assert_classifier_false "Serena utility command is not an activation" sp_is_command_activation "strategic-partner-plugin:serena" ""
  assert_classifier_false "legacy Serena utility argument is not an activation" sp_is_command_activation "strategic-partner" ":serena"
  assert_classifier_false "typed Serena utility prompt is not an activation" sp_is_prompt_activation "/strategic-partner-plugin:serena"
  assert_classifier_false "legacy typed Serena utility prompt is not an activation" sp_is_prompt_activation "/strategic-partner:serena"
  assert_classifier_false "unrelated command is not an activation" sp_is_command_activation "review-pr" ""
  assert_classifier_true "typed stop phrase is closure intent" sp_is_session_end_intent "Let's stop here for now."
  assert_classifier_true "stop sentence with trailing instructions is closure intent" sp_is_session_end_intent "Stop here for now. Give only a brief recap and do not write files."
  assert_classifier_true "AUQ answer carrier is closure intent" sp_is_session_end_intent "User answered Claude's questions: What's next? -> Stop here for now"
  assert_classifier_false "keep-open override is not closure intent" sp_is_session_end_intent "Stop, don't close yet; keep the session open."
  assert_classifier_false "quoted stop example is not closure intent" sp_is_session_end_intent 'We discussed the phrase "stop here for now" as an example.'

  last_text=$(last_assistant_text "$FIXTURES/startup-complete.jsonl")
  assert_classifier_true "complete startup evidence is accepted" sp_startup_evidence_complete "$FIXTURES/startup-complete.jsonl" "$last_text" "" "yes"
  assert_classifier_true "current direct invocation is a startup candidate" sp_transcript_has_current_startup_activation "$FIXTURES/startup-missing-auq.jsonl"
  last_text=$(last_assistant_text "$FIXTURES/startup-missing-auq.jsonl")
  assert_classifier_true "visible startup recenter without AUQ is accepted" sp_startup_evidence_complete "$FIXTURES/startup-missing-auq.jsonl" "$last_text" "" "yes"
  last_text=$(last_assistant_text "$FIXTURES/startup-real-recenter-no-auq.jsonl")
  missing=$(sp_startup_missing_evidence "$FIXTURES/startup-real-recenter-no-auq.jsonl" "$last_text" "" "yes")
  assert_equal "real repo status needs no ceremonial question" "$missing" ""
  last_text=$(last_assistant_text "$FIXTURES/continuation-complete.jsonl")
  assert_classifier_true "loaded continuation evidence is accepted" sp_startup_evidence_complete "$FIXTURES/continuation-complete.jsonl" "$last_text" ".handoffs/session-wrap-0709-1200.md" "yes"
  assert_classifier_true "complete closure evidence is accepted" sp_closure_evidence_complete "$FIXTURES/closure-complete.jsonl"
  assert_classifier_false "recap-only closure evidence is rejected" sp_closure_evidence_complete "$FIXTURES/closure-recap-only.jsonl"
  missing=$(sp_closure_missing_evidence "$FIXTURES/closure-hook-reason-is-not-insights.jsonl")
  assert_equal "Stop hook reason is not insights evidence" "$missing" "insights result or fallback"
  assert_classifier_false "new user work cancels stale closure intent" sp_transcript_has_session_end_intent "$FIXTURES/closure-intent-then-continue.jsonl"
  assert_classifier_false "specialist tool result is not session-end intent" sp_transcript_has_session_end_intent "$FIXTURES/closure-toolresult-not-intent.jsonl"
  assert_classifier_true "typed intent survives a later tool result" sp_transcript_has_session_end_intent "$FIXTURES/closure-typed-intent-then-toolresult.jsonl"
}

case "$MODE" in
  --hooks) run_activation_tests ;;
  --stop) run_stop_tests ;;
  --classifiers) run_classifier_tests ;;
  all)
    run_activation_tests
    run_stop_tests
    if [ -f "$LIB" ]; then
      run_classifier_tests
    else
      printf 'SKIP: classifier suite waits for Phase 2 library\n'
    fi
    ;;
  *)
    printf 'Usage: %s [--hooks|--stop|--classifiers]\n' "$0" >&2
    exit 2
    ;;
esac

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
