#!/usr/bin/env bash
# guard-regression.sh — regression fixtures for the PreToolUse source-edit guard
# (hooks/guard-impl.sh). Runs each fixture through the reference guard and
# asserts the expected exit code.
#
# Covers the v6.13.0 hardening (deliverable 1):
#   - LEAK #2 closed: a confirmed edit tool with an unreadable file_path BLOCKS.
#   - LEAK #1 still fail-open by design: an unreadable tool_name ALLOWS (a block
#     there would gate Bash and brick the session).
#   - PARSER hardened: arbitrary whitespace around the tool_name colon is read.
#
# Usage:  bash tests/guard-regression.sh
# Exit 0 = all fixtures passed. Exit 1 = at least one fixture failed.

GUARD="hooks/guard-impl.sh"
FAIL=0
TMP=$(mktemp -d)
WORK_TMP="$(pwd)/.tmp-guard-regression-$$"
trap 'rm -rf "$TMP" "$WORK_TMP"' EXIT

# run_case "label" expected_exit json_input
run_case() {
  label=$1
  expected=$2
  payload=$3
  printf '%s' "$payload" | bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

run_bash_case() {
  label=$1
  expected=$2
  command_text=$3
  payload=$(jq -n --arg cmd "$command_text" '{tool_name:"Bash", tool_input:{command:$cmd}}')
  run_case "$label" "$expected" "$payload"
}

run_bash_case_with_trust() {
  label=$1
  expected=$2
  command_text=$3
  trust_dir=$4
  payload=$(jq -n --arg cmd "$command_text" '{tool_name:"Bash", tool_input:{command:$cmd}}')
  printf '%s' "$payload" | SP_TRUST_DIR="$trust_dir" bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

run_bash_case_no_jq() {
  label=$1
  expected=$2
  command_text=$3
  payload=$(jq -n --arg cmd "$command_text" '{tool_name:"Bash", tool_input:{command:$cmd}}')
  shadow="$TMP/shadow-jq-${label//[^A-Za-z0-9]/_}"
  mkdir -p "$shadow"
  printf '#!/bin/sh\nexit 127\n' > "$shadow/jq"
  chmod +x "$shadow/jq"
  printf '%s' "$payload" | PATH="$shadow:$PATH" bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

run_case_no_jq() {
  label=$1
  expected=$2
  payload=$3
  shadow="$TMP/shadow-jq-${label//[^A-Za-z0-9]/_}"
  mkdir -p "$shadow"
  printf '#!/bin/sh\nexit 127\n' > "$shadow/jq"
  chmod +x "$shadow/jq"
  printf '%s' "$payload" | PATH="$shadow:$PATH" bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

run_case_stderr_contains() {
  label=$1
  expected=$2
  payload=$3
  needle=$4
  out_file="$TMP/stderr-${label//[^A-Za-z0-9]/_}.txt"
  printf '%s' "$payload" | bash "$GUARD" >/dev/null 2>"$out_file"
  actual=$?
  if [ "$actual" -eq "$expected" ] && grep -qF "$needle" "$out_file"; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected exit $expected and stderr containing: $needle"
    echo "      got exit $actual; stderr:"
    sed -n '1,4p' "$out_file"
    FAIL=1
  fi
}

run_case_with_trust() {
  label=$1
  expected=$2
  payload=$3
  trust_dir=$4
  printf '%s' "$payload" | SP_TRUST_DIR="$trust_dir" bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

run_case_with_trust_stderr_contains() {
  label=$1
  expected=$2
  payload=$3
  trust_dir=$4
  needle=$5
  out_file="$TMP/stderr-${label//[^A-Za-z0-9]/_}.txt"
  printf '%s' "$payload" | SP_TRUST_DIR="$trust_dir" bash "$GUARD" >/dev/null 2>"$out_file"
  actual=$?
  if [ "$actual" -eq "$expected" ] && grep -qF "$needle" "$out_file"; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected exit $expected and stderr containing: $needle"
    echo "      got exit $actual; stderr:"
    sed -n '1,4p' "$out_file"
    FAIL=1
  fi
}

hash_text_fixture() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  fi
}

hash_file_fixture() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# --- Baseline (sanity) ---
run_case "edit on source file blocks"        2 '{"tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}'
run_case "edit on allow-listed path allows"  0 '{"tool_name":"Edit","tool_input":{"file_path":".handoffs/x.md"}}'
run_case "memory tool untouched"             0 '{"tool_name":"mcp__plugin_serena_serena__write_memory"}'

# --- Built-in SP artifact paths ---
run_case "built-in: specs html plan allows" 0 '{"tool_name":"Write","tool_input":{"file_path":"specs/guard-allowlist-gap-and-dispatch-confirmation-race.html"}}'
run_case "built-in: specs code-shaped file blocks" 2 '{"tool_name":"Write","tool_input":{"file_path":"specs/runner.ts"}}'
run_case "built-in: plugin manifest allows" 0 '{"tool_name":"Edit","tool_input":{"file_path":"plugin/strategic-partner/.claude-plugin/plugin.json"}}'
run_case "built-in: root voice file allows" 0 '{"tool_name":"Edit","tool_input":{"file_path":"output-styles/strategic-partner-voice.md"}}'
run_case "built-in: plugin voice file allows" 0 '{"tool_name":"Edit","tool_input":{"file_path":"plugin/strategic-partner/output-styles/strategic-partner-voice.md"}}'

# --- Repo-local stewardship contract (.sp-managed) ---
contract_repo="$WORK_TMP/contract-repo"
trust_dir="$WORK_TMP/trusted-contracts"
mkdir -p "$contract_repo/workspace/decisions" "$contract_repo/workspace/interviews" "$trust_dir"
printf '%s\n' \
  '# Strategic Partner stewardship contract' \
  'workspace/decisions/*.md | decisions | manage' \
  'workspace/interviews/*.md | interviews | manage' \
  'workspace/decisions/*.py | invalid-code | manage' \
  '*.md | root-wide-markdown | manage' \
  '*/*.md | wildcard-leading-segment | manage' \
  > "$contract_repo/.sp-managed"

decision_path="$contract_repo/workspace/decisions/036-near-real-time-delivery-live-first.md"
interview_path="$contract_repo/workspace/interviews/customer-call.md"
code_path="$contract_repo/workspace/decisions/engine.py"
root_wildcard_path="$contract_repo/root-note.md"
leading_wildcard_path="$contract_repo/random/note.md"
mkdir -p "$contract_repo/random"
contract_payload=$(jq -n --arg cwd "$contract_repo" --arg path "$decision_path" '{tool_name:"Edit", cwd:$cwd, tool_input:{file_path:$path}}')
interview_payload=$(jq -n --arg cwd "$contract_repo" --arg path "$interview_path" '{tool_name:"Write", cwd:$cwd, tool_input:{file_path:$path}}')
code_payload=$(jq -n --arg cwd "$contract_repo" --arg path "$code_path" '{tool_name:"Edit", cwd:$cwd, tool_input:{file_path:$path}}')
root_wildcard_payload=$(jq -n --arg cwd "$contract_repo" --arg path "$root_wildcard_path" '{tool_name:"Edit", cwd:$cwd, tool_input:{file_path:$path}}')
leading_wildcard_payload=$(jq -n --arg cwd "$contract_repo" --arg path "$leading_wildcard_path" '{tool_name:"Edit", cwd:$cwd, tool_input:{file_path:$path}}')
relative_payload=$(jq -n --arg cwd "$contract_repo" '{tool_name:"Edit", cwd:$cwd, tool_input:{file_path:"workspace/decisions/037-local-decision.md"}}')
contract_file_payload=$(jq -n --arg path "$contract_repo/.sp-managed" '{tool_name:"Write", tool_input:{file_path:$path}}')

run_case_with_trust_stderr_contains "contract: matching path without activation blocks helpfully" 2 "$contract_payload" "$trust_dir" "not locally activated"
run_case "contract: .sp-managed file itself allows" 0 "$contract_file_payload"

root_hash=$(hash_text_fixture "$contract_repo")
contract_hash=$(hash_file_fixture "$contract_repo/.sp-managed")
trust_marker="$trust_dir/$root_hash-$contract_hash.trusted"
marker_payload=$(jq -n --arg path "$trust_marker" '{tool_name:"Write", tool_input:{file_path:$path}}')

run_case_with_trust_stderr_contains "contract: trust marker write without confirmation blocks" 2 "$marker_payload" "$trust_dir" "fresh AskUserQuestion confirmation"
run_bash_case_with_trust "contract: shell redirect to trust marker blocks" 2 "echo activated > $trust_marker" "$trust_dir"

trust_marker_ok="$TMP/trust-marker-ok.jsonl"
printf '%s\n' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_ok_question",name:"AskUserQuestion",input:{questions:[{question:("Activate .sp-managed stewardship contract by writing this exact local marker? " + $marker),options:[{label:"Activate stewardship contract",description:("Create the exact .sp-managed trust marker: " + $marker)},{label:"Hold - review contract first",description:"Do not create the marker."}]}]}}]}}')" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_trust_ok_question","content":"Activate stewardship contract"}]}}' \
  > "$trust_marker_ok"
marker_confirmed_payload=$(jq -n --arg path "$trust_marker" --arg t "$trust_marker_ok" '{tool_name:"Write", tool_use_id:"toolu_trust_ok_write", transcript_path:$t, tool_input:{file_path:$path}}')
run_case_with_trust "contract: trust marker write with exact confirmation allows" 0 "$marker_confirmed_payload" "$trust_dir"

marker_missing_action_id_payload=$(jq -n --arg path "$trust_marker" --arg t "$trust_marker_ok" '{tool_name:"Write", transcript_path:$t, tool_input:{file_path:$path}}')
run_case_with_trust_stderr_contains "contract: trust confirmation without current action id blocks" 2 "$marker_missing_action_id_payload" "$trust_dir" "current protected action"

trust_marker_interleaved="$TMP/trust-marker-interleaved.jsonl"
printf '%s\n' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_question",name:"AskUserQuestion",input:{questions:[{question:("Activate .sp-managed stewardship contract by writing this exact local marker? " + $marker),options:[{label:"Activate stewardship contract",description:("Create the exact .sp-managed trust marker: " + $marker)},{label:"Hold - review contract first",description:"Do not create the marker."}]}]}}]}}')" \
  '{"type":"last-prompt"}' \
  '{"type":"ai-title"}' \
  '{"type":"mode"}' \
  '{"type":"permission-mode"}' \
  '{"type":"bridge-session"}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_trust_question","content":"Activate stewardship contract"}]}}' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_write",name:"Write",input:{file_path:$marker}}]}}')" \
  > "$trust_marker_interleaved"
marker_interleaved_payload=$(jq -n --arg path "$trust_marker" --arg t "$trust_marker_interleaved" '{tool_name:"Write", tool_use_id:"toolu_trust_write", transcript_path:$t, tool_input:{file_path:$path}}')
run_case_with_trust "contract: metadata between question and correlated answer still allows" 0 "$marker_interleaved_payload" "$trust_dir"

trust_marker_replay="$TMP/trust-marker-replay.jsonl"
printf '%s\n' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_replay_question",name:"AskUserQuestion",input:{questions:[{question:("Activate .sp-managed stewardship contract by writing this exact local marker? " + $marker),options:[{label:"Activate stewardship contract",description:("Create the exact .sp-managed trust marker: " + $marker)},{label:"Hold - review contract first",description:"Do not create the marker."}]}]}}]}}')" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_trust_replay_question","content":"Activate stewardship contract"}]}}' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_first_write",name:"Write",input:{file_path:$marker}}]}}')" \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_second_write",name:"Write",input:{file_path:$marker}}]}}')" \
  > "$trust_marker_replay"
marker_replay_payload=$(jq -n --arg path "$trust_marker" --arg t "$trust_marker_replay" '{tool_name:"Write", tool_use_id:"toolu_trust_second_write", transcript_path:$t, tool_input:{file_path:$path}}')
run_case_with_trust_stderr_contains "contract: one confirmation cannot authorize a second marker write" 2 "$marker_replay_payload" "$trust_dir" "already used"

trust_marker_answer_outside_window="$TMP/trust-marker-answer-outside-window.jsonl"
printf '%s\n' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_window_question",name:"AskUserQuestion",input:{questions:[{question:("Activate .sp-managed stewardship contract by writing this exact local marker? " + $marker),options:[{label:"Activate stewardship contract",description:("Create the exact .sp-managed trust marker: " + $marker)},{label:"Hold - review contract first",description:"Do not create the marker."}]}]}}]}}')" \
  '{"type":"future-metadata"}' \
  "$(jq -nc --arg marker "$trust_marker" '{message:{role:"assistant",content:[{type:"tool_use",id:"toolu_trust_window_write",name:"Write",input:{file_path:$marker}}]}}')" \
  > "$trust_marker_answer_outside_window"
marker_answer_outside_window_payload=$(jq -n --arg path "$trust_marker" --arg t "$trust_marker_answer_outside_window" '{tool_name:"Write", tool_use_id:"toolu_trust_window_write", transcript_path:$t, tool_input:{file_path:$path}}')
run_case_with_trust_stderr_contains "contract: unavailable correlated answer names transcript window" 2 "$marker_answer_outside_window_payload" "$trust_dir" "outside the recent transcript window"

touch "$trust_marker"
run_case_with_trust "contract: activated decision path allows" 0 "$contract_payload" "$trust_dir"
run_case_with_trust "contract: activated interview path allows" 0 "$interview_payload" "$trust_dir"
run_case_with_trust "contract: relative managed path uses payload cwd" 0 "$relative_payload" "$trust_dir"
run_case_with_trust "contract: code-shaped path remains blocked" 2 "$code_payload" "$trust_dir"
run_case_with_trust "contract: bare wildcard pattern remains blocked" 2 "$root_wildcard_payload" "$trust_dir"
run_case_with_trust "contract: wildcard leading segment remains blocked" 2 "$leading_wildcard_payload" "$trust_dir"

# --- LEAK #2 closed (case 3): confirmed edit tool, missing file_path → BLOCK ---
run_case "leak#2: edit tool, no file_path blocks" 2 '{"tool_name":"Edit","tool_input":{}}'

# --- LEAK #1 fail-open by design (case 4): unreadable tool_name → ALLOW ---
run_case "leak#1: unreadable tool_name allows"    0 'not json at all'

# --- PARSER hardened (case 5): whitespace around colon → name still read ---
run_case "parser: whitespace around colon blocks" 2 '{"tool_name" : "Edit", "tool_input": {"file_path": "/foo/bar.py"}}'

# --- Agent dispatch confirmation guard ---
dispatch_ok="$TMP/dispatch-ok.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"text","text":"Routing: frontend-architect — React component polish."},{"type":"tool_use","id":"toolu_dispatch_ok_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — frontend-architect","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_dispatch_ok_question","content":"Dispatch now — frontend-architect"}]}}' \
  > "$dispatch_ok"
dispatch_ok_payload=$(jq -n --arg t "$dispatch_ok" '{tool_name:"Agent", tool_use_id:"toolu_dispatch_ok_agent", transcript_path:$t, tool_input:{subagent_type:"frontend-architect"}}')
run_case "dispatch guard: exact confirmation allows" 0 "$dispatch_ok_payload"

dispatch_run_now="$TMP/dispatch-run-now.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_run_now_question","name":"AskUserQuestion","input":{"questions":[{"question":"How should we proceed with Serena?","options":[{"label":"Fix Serena for me (Recommended)","description":"Approve the repair outcome."},{"label":"Not now","description":"Leave Serena unchanged."}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_run_now_question","content":"Fix Serena for me (Recommended)"}]}}' \
  > "$dispatch_run_now"
dispatch_run_now_payload=$(jq -n --arg t "$dispatch_run_now" '{tool_name:"Agent", tool_use_id:"toolu_run_now_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: Serena repair approval is not worker confirmation" 2 "$dispatch_run_now_payload"

dispatch_old_label="$TMP/dispatch-old-label.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_old_label_question","name":"AskUserQuestion","input":{"questions":[{"question":"How should I deliver this?","options":[{"label":"Dispatch via agent — frontend-architect","description":"SP spawns the agent."},{"label":"Give me the prompt","description":"Standard fence delivery."}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_old_label_question","content":"Dispatch via agent — frontend-architect"}]}}' \
  > "$dispatch_old_label"
dispatch_old_label_payload=$(jq -n --arg t "$dispatch_old_label" '{tool_name:"Agent", tool_use_id:"toolu_old_label_agent", transcript_path:$t, tool_input:{subagent_type:"frontend-architect"}}')
run_case "dispatch guard: old delivery label blocks" 2 "$dispatch_old_label_payload"

dispatch_wrong_agent_payload=$(jq -n --arg t "$dispatch_ok" '{tool_name:"Agent", tool_use_id:"toolu_wrong_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: wrong subagent blocks" 2 "$dispatch_wrong_agent_payload"

# GAP 2 fix (post-b8bb005): an unverifiable transcript must fail CLOSED,
# matching Guard 1 (unreadable file_path on a confirmed edit tool) and
# Guard 3 (unreadable Serena path) elsewhere in this file.
run_case "dispatch guard: missing transcript fails closed" 2 '{"tool_name":"Agent","tool_use_id":"toolu_missing_transcript","tool_input":{"subagent_type":"frontend-architect"}}'

dispatch_unreadable_payload=$(jq -n --arg t "$TMP/does-not-exist.jsonl" '{tool_name:"Agent", tool_use_id:"toolu_unreadable_transcript", transcript_path:$t, tool_input:{subagent_type:"frontend-architect"}}')
run_case "dispatch guard: unreadable transcript fails closed" 2 "$dispatch_unreadable_payload"

# --- Agent dispatch confirmation guard: the SELECTED answer, not just the
# offered options, must gate the dispatch. All four fixtures below offer the
# same compliant three-option AUQ; only the tool_result that follows it
# (the user's actual answer) differs. The wrapper format below —
# `Your questions have been answered: "<question>"="<answer>". You can now
# continue with these answers in mind.` — mirrors real Claude Code
# transcripts (verified against ~/.claude/projects/*/*.jsonl), distinct from
# the plain unwrapped tool_result content used by the fixtures above.
dispatch_gp_offer='{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_gp_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."}]}]}}]}}'

dispatch_answer_hold="$TMP/dispatch-answer-hold.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Hold — let me review the brief first\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_answer_hold"
dispatch_answer_hold_payload=$(jq -n --arg t "$dispatch_answer_hold" '{tool_name:"Agent", tool_use_id:"toolu_answer_hold_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: answer=Hold blocks despite offered options" 2 "$dispatch_answer_hold_payload"

dispatch_answer_wrong_agent="$TMP/dispatch-answer-wrong-agent.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Wrong agent — let me pick\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_answer_wrong_agent"
dispatch_answer_wrong_agent_payload=$(jq -n --arg t "$dispatch_answer_wrong_agent" '{tool_name:"Agent", tool_use_id:"toolu_answer_wrong_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: answer=Wrong-agent blocks despite offered options" 2 "$dispatch_answer_wrong_agent_payload"

dispatch_answer_exact="$TMP/dispatch-answer-exact.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_answer_exact"
dispatch_answer_exact_payload=$(jq -n --arg t "$dispatch_answer_exact" '{tool_name:"Agent", tool_use_id:"toolu_answer_exact_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: answer=exact-match allows" 0 "$dispatch_answer_exact_payload"

dispatch_structured_quoted="$TMP/dispatch-structured-quoted.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_structured_quoted_question","name":"AskUserQuestion","input":{"questions":[{"question":"A worker will run \"serena-repair.sh\" --apply, then \"serena-repair.sh\" --verify. How do you want to proceed?","options":[{"label":"Dispatch now — general-purpose","description":"Run the approved repair."},{"label":"Hold — let me review the brief first","description":"Show the brief."},{"label":"Wrong agent — let me pick","description":"Reopen worker selection."}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_structured_quoted_question","content":"Your questions have been answered: \"A worker will run \"serena-repair.sh\" --apply, then \"serena-repair.sh\" --verify. How do you want to proceed?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]},"toolUseResult":{"answers":{"A worker will run \"serena-repair.sh\" --apply, then \"serena-repair.sh\" --verify. How do you want to proceed?":"Dispatch now — general-purpose"}}}' \
  > "$dispatch_structured_quoted"
dispatch_structured_quoted_payload=$(jq -n --arg t "$dispatch_structured_quoted" '{tool_name:"Agent", tool_use_id:"toolu_structured_quoted_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: structured answer survives quoted question text" 0 "$dispatch_structured_quoted_payload"

dispatch_structured_wrong_key="$TMP/dispatch-structured-wrong-key.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_structured_wrong_key_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"Run it."},{"label":"Hold — let me review the brief first","description":"Review it."},{"label":"Wrong agent — let me pick","description":"Choose again."}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_structured_wrong_key_question","content":"Dispatch now — general-purpose"}]},"toolUseResult":{"answers":{"A different question":"Dispatch now — general-purpose"}}}' \
  > "$dispatch_structured_wrong_key"
dispatch_structured_wrong_key_payload=$(jq -n --arg t "$dispatch_structured_wrong_key" '{tool_name:"Agent", tool_use_id:"toolu_structured_wrong_key_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: structured answer requires exact question key" 2 "$dispatch_structured_wrong_key_payload" "safely correlate"

dispatch_structured_unoffered="$TMP/dispatch-structured-unoffered.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Run the approved repair."}]},"toolUseResult":{"answers":{"Confirm this exact dispatch?":"Run the approved repair."}}}' \
  > "$dispatch_structured_unoffered"
dispatch_structured_unoffered_payload=$(jq -n --arg t "$dispatch_structured_unoffered" '{tool_name:"Agent", tool_use_id:"toolu_structured_unoffered_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: structured description is not an offered label" 2 "$dispatch_structured_unoffered_payload"

dispatch_structured_nonstring="$TMP/dispatch-structured-nonstring.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Dispatch now — general-purpose"}]},"toolUseResult":{"answers":{"Confirm this exact dispatch?":["Dispatch now — general-purpose"]}}}' \
  > "$dispatch_structured_nonstring"
dispatch_structured_nonstring_payload=$(jq -n --arg t "$dispatch_structured_nonstring" '{tool_name:"Agent", tool_use_id:"toolu_structured_nonstring_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: structured answer must be one string" 2 "$dispatch_structured_nonstring_payload" "safely correlate"

dispatch_structured_multiple="$TMP/dispatch-structured-multiple.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Dispatch now — general-purpose"}]},"toolUseResult":{"answers":{"Confirm this exact dispatch?":"Dispatch now — general-purpose","Unexpected question":"Dispatch now — general-purpose"}}}' \
  > "$dispatch_structured_multiple"
dispatch_structured_multiple_payload=$(jq -n --arg t "$dispatch_structured_multiple" '{tool_name:"Agent", tool_use_id:"toolu_structured_multiple_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: structured answer rejects extra values" 2 "$dispatch_structured_multiple_payload" "safely correlate"

dispatch_structured_disagree="$TMP/dispatch-structured-disagree.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]},"toolUseResult":{"answers":{"Confirm this exact dispatch?":"Hold — let me review the brief first"}}}' \
  > "$dispatch_structured_disagree"
dispatch_structured_disagree_payload=$(jq -n --arg t "$dispatch_structured_disagree" '{tool_name:"Agent", tool_use_id:"toolu_structured_disagree_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: structured and display disagreement blocks" 2 "$dispatch_structured_disagree_payload" "safely correlate"

dispatch_missing_action_id_payload=$(jq -n --arg t "$dispatch_answer_exact" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: exact answer without current action id blocks" 2 "$dispatch_missing_action_id_payload" "current protected action"

dispatch_answer_en_dash="$TMP/dispatch-answer-en-dash.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now – general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_answer_en_dash"
dispatch_answer_en_dash_payload=$(jq -n --arg t "$dispatch_answer_en_dash" '{tool_name:"Agent", tool_use_id:"toolu_en_dash_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: en-dash answer matches em-dash option" 0 "$dispatch_answer_en_dash_payload"

dispatch_answer_other_agent="$TMP/dispatch-answer-other-agent.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — frontend-architect\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_answer_other_agent"
dispatch_answer_other_agent_payload=$(jq -n --arg t "$dispatch_answer_other_agent" '{tool_name:"Agent", tool_use_id:"toolu_other_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: answer confirms a different agent than dispatched blocks" 2 "$dispatch_answer_other_agent_payload"

dispatch_hidden_description="$TMP/dispatch-hidden-description.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_hidden_description_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Option A","description":"Dispatch now — general-purpose"},{"label":"Option B","description":"Hold — let me review the brief first"},{"label":"Option C","description":"Wrong agent — let me pick"}]}]}}]}}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_hidden_description_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_hidden_description"
dispatch_hidden_description_payload=$(jq -n --arg t "$dispatch_hidden_description" '{tool_name:"Agent", tool_use_id:"toolu_hidden_description_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: hidden description labels do not authorize dispatch" 2 "$dispatch_hidden_description_payload" "selected option label"

# --- A sibling-label failure must name the sibling, not the selection. In the
# first two fixtures below the user selected the correct dispatch label and only
# a NON-selected option was reworded; the block message must point at the
# reworded option rather than at the choice that was already correct. The third
# fixture is the control: an off-menu selection still gets the original
# selected-label message, proving the split left that path intact.
dispatch_hold_reworded_offer='{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_hold_reworded_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — show me the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."}]}]}}]}}'

dispatch_hold_reworded="$TMP/dispatch-hold-reworded.jsonl"
printf '%s\n' \
  "$dispatch_hold_reworded_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_hold_reworded_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_hold_reworded"
dispatch_hold_reworded_payload=$(jq -n --arg t "$dispatch_hold_reworded" '{tool_name:"Agent", tool_use_id:"toolu_hold_reworded_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: reworded Hold option names the review option" 2 "$dispatch_hold_reworded_payload" "required review option was missing or reworded"

dispatch_wrong_agent_reworded_offer='{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_wrong_agent_reworded_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — choose another","description":"SP reopens agent selection."}]}]}}]}}'

dispatch_wrong_agent_reworded="$TMP/dispatch-wrong-agent-reworded.jsonl"
printf '%s\n' \
  "$dispatch_wrong_agent_reworded_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_wrong_agent_reworded_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_wrong_agent_reworded"
dispatch_wrong_agent_reworded_payload=$(jq -n --arg t "$dispatch_wrong_agent_reworded" '{tool_name:"Agent", tool_use_id:"toolu_wrong_agent_reworded_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: reworded Wrong-agent option names the reselection option" 2 "$dispatch_wrong_agent_reworded_payload" "required agent-reselection option"

dispatch_offmenu_selection_offer='{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_offmenu_selection_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."},{"label":"Something else entirely","description":"An unrelated fourth option."}]}]}}]}}'

dispatch_offmenu_selection="$TMP/dispatch-offmenu-selection.jsonl"
printf '%s\n' \
  "$dispatch_offmenu_selection_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_offmenu_selection_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Something else entirely\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_offmenu_selection"
dispatch_offmenu_selection_payload=$(jq -n --arg t "$dispatch_offmenu_selection" '{tool_name:"Agent", tool_use_id:"toolu_offmenu_selection_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: off-menu selection keeps the selected-label message" 2 "$dispatch_offmenu_selection_payload" "selected option label exactly matching"

# --- GAP 1 fix (post-b8bb005): a confirmation only authorizes the
# immediately-following dispatch attempt. Reproduces Codex's exploit: an
# earlier qualifying "Dispatch now — general-purpose" answer stays inside
# the tail-160 window, but unrelated turns happened after it and the user
# was never asked again — that stale confirmation must not authorize a
# later dispatch.
dispatch_stale="$TMP/dispatch-stale.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"user","content":[{"type":"text","text":"Actually, can you also check something unrelated first?"}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"text","text":"Sure — here is the unrelated answer, no dispatch involved."}]}}' \
  > "$dispatch_stale"
dispatch_stale_payload=$(jq -n --arg t "$dispatch_stale" '{tool_name:"Agent", tool_use_id:"toolu_stale_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: stale confirmation (unrelated turns after answer) blocks" 2 "$dispatch_stale_payload"

# Non-stale control: the same exact-match answer with NOTHING after it must
# still allow — this is the legitimate, immediately-following confirmation.
dispatch_fresh="$TMP/dispatch-fresh.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  > "$dispatch_fresh"
dispatch_fresh_payload=$(jq -n --arg t "$dispatch_fresh" '{tool_name:"Agent", tool_use_id:"toolu_fresh_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: fresh confirmation (nothing after answer) allows" 0 "$dispatch_fresh_payload"

dispatch_interleaved="$TMP/dispatch-interleaved.jsonl"
printf '%s\n' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_dispatch_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm this exact dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."}]}]}}]}}' \
  '{"type":"last-prompt"}' \
  '{"type":"ai-title"}' \
  '{"type":"mode"}' \
  '{"type":"permission-mode"}' \
  '{"type":"bridge-session"}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_dispatch_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_dispatch_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_interleaved"
dispatch_interleaved_payload=$(jq -n --arg t "$dispatch_interleaved" '{tool_name:"Agent", tool_use_id:"toolu_dispatch_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: metadata between question and correlated answer still allows" 0 "$dispatch_interleaved_payload"

dispatch_unknown_metadata="$TMP/dispatch-unknown-metadata.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"type":"future-metadata"}' \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_unknown_metadata_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_unknown_metadata"
dispatch_unknown_metadata_payload=$(jq -n --arg t "$dispatch_unknown_metadata" '{tool_name:"Agent", tool_use_id:"toolu_unknown_metadata_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: unknown metadata between correlated events still allows" 0 "$dispatch_unknown_metadata_payload"

dispatch_replay="$TMP/dispatch-replay.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_dispatch_first_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_dispatch_second_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_replay"
dispatch_replay_payload=$(jq -n --arg t "$dispatch_replay" '{tool_name:"Agent", tool_use_id:"toolu_dispatch_second_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: one confirmation cannot authorize a second dispatch" 2 "$dispatch_replay_payload" "already used"

dispatch_answer_outside_window="$TMP/dispatch-answer-outside-window.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"type":"bridge-session"}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_window_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_answer_outside_window"
dispatch_answer_outside_window_payload=$(jq -n --arg t "$dispatch_answer_outside_window" '{tool_name:"Agent", tool_use_id:"toolu_window_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: unavailable correlated answer names transcript window" 2 "$dispatch_answer_outside_window_payload" "outside the recent transcript window"

dispatch_ordinary_missing_answer="$TMP/dispatch-ordinary-missing-answer.jsonl"
printf '%s\n' "$dispatch_gp_offer" > "$dispatch_ordinary_missing_answer"
dispatch_ordinary_missing_answer_payload=$(jq -n --arg t "$dispatch_ordinary_missing_answer" '{tool_name:"Agent", tool_use_id:"toolu_ordinary_missing_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: ordinary missing answer keeps normal confirmation guidance" 2 "$dispatch_ordinary_missing_answer_payload" "must confirm the exact agent"

dispatch_wrong_answer_id="$TMP/dispatch-wrong-answer-id.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_different_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_wrong_answer_id_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_wrong_answer_id"
dispatch_wrong_answer_id_payload=$(jq -n --arg t "$dispatch_wrong_answer_id" '{tool_name:"Agent", tool_use_id:"toolu_wrong_answer_id_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: answer for a different question cannot authorize" 2 "$dispatch_wrong_answer_id_payload" "outside the recent transcript window"

dispatch_latest_unanswered="$TMP/dispatch-latest-unanswered.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_newer_question","name":"AskUserQuestion","input":{"questions":[{"question":"Confirm the newer dispatch?","options":[{"label":"Dispatch now — general-purpose","description":"SP spawns this exact agent."},{"label":"Hold — let me review the brief first","description":"SP shows the brief first."},{"label":"Wrong agent — let me pick","description":"SP reopens agent selection."}]}]}}]}}' \
  '{"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_latest_unanswered_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_latest_unanswered"
dispatch_latest_unanswered_payload=$(jq -n --arg t "$dispatch_latest_unanswered" '{tool_name:"Agent", tool_use_id:"toolu_latest_unanswered_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_stderr_contains "dispatch guard: older answer cannot authorize newer unanswered question" 2 "$dispatch_latest_unanswered_payload" "outside the recent transcript window"

dispatch_structural_noise="$TMP/dispatch-structural-noise.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"system","content":[{"type":"text","text":"Internal reminder added by the harness."}]}}' \
  '{"type":"attachment","content":[{"type":"text","text":"clipboard metadata"}]}' \
  '{"message":{"role":"assistant","content":[{"type":"text","text":"Dispatching now."},{"type":"tool_use","id":"toolu_structural_agent","name":"Agent","input":{"subagent_type":"general-purpose"}}]}}' \
  > "$dispatch_structural_noise"
dispatch_structural_noise_payload=$(jq -n --arg t "$dispatch_structural_noise" '{tool_name:"Agent", tool_use_id:"toolu_structural_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: structural/in-flight rows after answer still allow" 0 "$dispatch_structural_noise_payload"

dispatch_missing_agent_payload=$(jq -n --arg t "$dispatch_answer_exact" '{tool_name:"Agent", tool_use_id:"toolu_missing_agent_type", transcript_path:$t, tool_input:{}}')
run_case "dispatch guard: missing agent type blocks despite exact-looking answer" 2 "$dispatch_missing_agent_payload"

dispatch_nojq_fresh_payload=$(jq -n --arg t "$dispatch_answer_exact" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: exact answer blocks" 2 "$dispatch_nojq_fresh_payload"

dispatch_nojq_stale_payload=$(jq -n --arg t "$dispatch_stale" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: later user text blocks" 2 "$dispatch_nojq_stale_payload"

dispatch_nojq_missing_agent_payload=$(jq -n --arg t "$dispatch_answer_exact" '{tool_name:"Agent", transcript_path:$t, tool_input:{}}')
run_case_no_jq "dispatch guard no-jq: missing agent type blocks" 2 "$dispatch_nojq_missing_agent_payload"

# --- No-jq dispatch behavior: without jq, Agent/Task dispatch fails closed.
# Prompt delivery still works; this avoids maintaining a second brittle
# transcript parser for a safety-sensitive confirmation.
dispatch_nojq_structural_payload=$(jq -n --arg t "$dispatch_structural_noise" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: structural/in-flight rows after answer still block" 2 "$dispatch_nojq_structural_payload"

dispatch_nojq_wrong_agent_answer_payload=$(jq -n --arg t "$dispatch_answer_other_agent" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: answer confirms a different agent than dispatched blocks" 2 "$dispatch_nojq_wrong_agent_answer_payload"

dispatch_nojq_hold_payload=$(jq -n --arg t "$dispatch_answer_hold" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: answer=Hold blocks despite offered options" 2 "$dispatch_nojq_hold_payload"

dispatch_nojq_wrong_opt_payload=$(jq -n --arg t "$dispatch_answer_wrong_agent" '{tool_name:"Agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case_no_jq "dispatch guard no-jq: answer=Wrong-agent blocks despite offered options" 2 "$dispatch_nojq_wrong_opt_payload"

run_case_no_jq "dispatch guard no-jq: missing transcript fails closed" 2 '{"tool_name":"Agent","tool_input":{"subagent_type":"general-purpose"}}'
run_case_no_jq "dispatch guard no-jq: unreadable transcript fails closed" 2 "$dispatch_unreadable_payload"

# Genuine-user-text staleness must also be detected when the transcript stores
# the later user turn as a direct string `content` value rather than an array of
# typed blocks. The jq path checks both shapes; the no-jq path now fails closed
# for Agent/Task dispatch instead of trying to maintain a second parser.
dispatch_stale_string_content="$TMP/dispatch-stale-string-content.jsonl"
printf '%s\n' \
  "$dispatch_gp_offer" \
  '{"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_gp_question","content":"Your questions have been answered: \"Confirm this exact dispatch?\"=\"Dispatch now — general-purpose\". You can now continue with these answers in mind."}]}}' \
  '{"message":{"role":"user","content":"Actually, check something else first"}}' \
  > "$dispatch_stale_string_content"
dispatch_stale_string_content_payload=$(jq -n --arg t "$dispatch_stale_string_content" '{tool_name:"Agent", tool_use_id:"toolu_stale_string_agent", transcript_path:$t, tool_input:{subagent_type:"general-purpose"}}')
run_case "dispatch guard: stale via direct-string user content blocks (jq path)" 2 "$dispatch_stale_string_content_payload"
run_case_no_jq "dispatch guard no-jq: stale via direct-string user content blocks" 2 "$dispatch_stale_string_content_payload"

# --- Context-file stewardship guard ---
journey='## #5177 Data Upload page - locked 2026-06-19
SHIPPED (local, unpushed) - 5 commits, browser-verified both tenants.
Commit `5f953ca`. Files: `DataUpload.tsx`, `UploadModal.tsx`, `UploadChoiceModal.tsx`, `ManualEntryModal.tsx`.'
payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg content "$journey" \
  '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
run_case "context guard: journey dump blocks" 2 "$payload"

shadow="$TMP/shadow-jq"
mkdir -p "$shadow"
printf '#!/bin/sh\nexit 127\n' > "$shadow/jq"
chmod +x "$shadow/jq"
printf '%s' "$payload" | PATH="$shadow:/usr/bin:/bin" bash "$GUARD" >/dev/null 2>&1
actual=$?
if [ "$actual" -eq 2 ]; then
  echo "PASS  context guard: jq outage blocks context write (exit $actual)"
else
  echo "FAIL  context guard: jq outage should block context write — expected 2, got $actual"
  FAIL=1
fi

serena_payload='{"tool_name":"mcp__plugin_serena_serena__create_text_file","tool_input":{"relative_path":"CLAUDE.md","content":"- Rule."}}'
run_case "context guard: serena CLAUDE write blocks" 2 "$serena_payload"

# --- Shell branch: high-confidence context-file mutations only ---
run_bash_case "context shell: read-only grep redirect allows" 0 "grep -n Project CLAUDE.md >/dev/null"
run_bash_case "context shell: read-only stderr redirect allows" 0 "sed -n '1,5p' CLAUDE.md 2>&1"
run_bash_case "source shell: read-only sed path with i allows" 0 "sed -n '95,175p' hooks/guard-impl.sh"
run_bash_case "source shell: read-only perl path with i allows" 0 "perl -ne 'print' hooks/guard-impl.sh"
run_bash_case "context shell: cp to CLAUDE blocks" 2 "cp /tmp/x CLAUDE.md"
run_bash_case "context shell: mv to quoted CLAUDE blocks" 2 "mv /tmp/x 'CLAUDE.md'"
run_bash_case "context shell: install to CLAUDE blocks" 2 "install /tmp/x CLAUDE.md"
run_bash_case "context shell: dd of=CLAUDE blocks" 2 "dd if=/tmp/x of=CLAUDE.md"
run_bash_case "context shell: sed -i to CLAUDE blocks" 2 "sed -i 's/x/y/' CLAUDE.md"
run_bash_case "context shell: perl -pi to CLAUDE blocks" 2 "perl -pi -e 's/x/y/' CLAUDE.md"
run_bash_case "context shell: variable redirect blocks" 2 'f=CLAUDE.md; echo junk > "$f"'
run_bash_case "context shell: lowercase macOS path blocks" 2 "cp /tmp/x claude.md"
run_bash_case "context shell: absolute path blocks" 2 "cp /tmp/x $TMP/CLAUDE.md"

nojq_awk_cmd="awk '\$1 > 3 {print}' sample.tsv"
run_bash_case_no_jq "source shell no-jq: git status allows" 0 "git status"
run_bash_case_no_jq "source shell no-jq: jq comparison allows" 0 "jq '.value > 3' sample.json"
run_bash_case_no_jq "source shell no-jq: awk comparison allows" 0 "$nojq_awk_cmd"
run_bash_case_no_jq "source shell no-jq: quoted source redirect blocks" 2 'echo "note" > SKILL.md'
run_bash_case_no_jq "source shell no-jq: quoted allowed redirect allows" 0 'echo "note" >> .handoffs/test-allowed.md'

printf '# Project\n\n' > "$TMP/CLAUDE.md"
path_rule_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg old "$(cat "$TMP/CLAUDE.md")" --arg new '# Project

- All files under `src/api/` must use the shared request validator.
' '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
run_case "context guard: path-scoped CLAUDE append blocks" 2 "$path_rule_payload"

shrink_old='# Project

- See src/api/foo.ts for API patterns.
- Delete this line.
'
shrink_new='# Project

- See src/api/foo.ts for API patterns.
'
printf '%s' "$shrink_old" > "$TMP/CLAUDE.md"
shrink_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg old "$shrink_old" --arg new "$shrink_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
run_case "context guard: pure shrink with retained path allows" 0 "$shrink_payload"

# --- Executor escape ---
# A genuine harness-dispatched subagent runs outside the broad source guard.
# agent_id is read STRICTLY from the top level, so a model-authored
# tool_input.agent_id cannot forge it; without jq the escape fails closed.
#
# The "allows" case below is load-bearing: the three blocking cases pass
# identically when the escape is absent, so only that one detects its removal.
run_case "escape: main thread (no top-level agent_id) blocks" 2 \
  '{"tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}'
run_case "escape: forged tool_input.agent_id does not escape" 2 \
  '{"tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py","agent_id":"FORGED"}}'
run_case_no_jq "escape: no jq means no escape (fails closed)" 2 \
  '{"agent_id":"a0d1be4d4d81ebccf","tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}'
run_case "escape: genuine top-level agent_id allows" 0 \
  '{"agent_id":"a0d1be4d4d81ebccf","tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}'

# Ordering. Both cases below flip to exit 0 if the escape is ever hoisted above
# Guard 0 or the context-file preflight, so they fail loudly on that drift.
run_case "escape stays below Guard 0: nested dispatch blocks" 2 \
  '{"agent_id":"a0d1be4d4d81ebccf","tool_name":"Agent","tool_input":{"subagent_type":"technical-writer","prompt":"x"}}'

mkdir -p "$TMP/escape"
escape_ctx_old='# Project

- A rule.
'
escape_ctx_new='# Project

- A rule.

## Decisions Log

A long decision-log shape section that fires S2 layer-violation
detection because of dated entries with `**Decision N:**` headers.

### **Decision 1: Adopt YAML configs**

[2025-01-15] Decided to migrate from XML to YAML. Rationale: YAML is
easier for engineers to read and write, and the existing parser
ecosystem in our stack is more mature for it.
'
printf '%s' "$escape_ctx_old" > "$TMP/escape/CLAUDE.md"
escape_ctx_payload=$(jq -n --arg path "$TMP/escape/CLAUDE.md" \
  --arg old "$escape_ctx_old" --arg new "$escape_ctx_new" \
  '{agent_id:"a0d1be4d4d81ebccf", tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
run_case "escape stays below preflight: context file blocks" 2 "$escape_ctx_payload"

if [ "$FAIL" -eq 0 ]; then
  echo "All guard regression fixtures passed."
  exit 0
fi
echo "Guard regression fixtures FAILED."
exit 1
