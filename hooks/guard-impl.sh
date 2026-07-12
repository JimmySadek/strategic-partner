#!/usr/bin/env bash
# guard-impl.sh — PreToolUse hook that blocks implementation tools
# on source files during Strategic Partner sessions.
#
# Exit 0 = allow the tool call
# Exit 2 = block the tool call (harness-enforced, not honor-system)
#
# This hook is registered via SKILL.md frontmatter and is therefore
# session-scoped — active only when the SP skill is loaded.
# No flag file needed.

# NOTE (v5.4.1): This script is the reference implementation.
# The active guard logic is inlined directly in SKILL.md frontmatter
# to eliminate external file path dependencies for distributed installs.
# Use SP_HOOK_DEBUG=1 with this script for local debugging:
#   echo '{"tool_name":"Edit","tool_input":{"file_path":"/foo/bar.py"}}' | SP_HOOK_DEBUG=1 bash hooks/guard-impl.sh

# Read the tool input JSON from stdin
INPUT=$(cat)

# Extract tool name from stdin JSON (Claude Code passes tool_name in the JSON payload).
# Tolerate arbitrary whitespace around the colon, e.g. '"tool_name" : "Edit"'.
TOOL_NAME=$(echo "$INPUT" | grep -Eo '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)

# Debug mode: set SP_HOOK_DEBUG=1 to log decisions to /tmp/sp-hook-debug.log
debug_log() {
  [ "${SP_HOOK_DEBUG:-0}" = "1" ] && echo "[$(date '+%H:%M:%S')] $*" >> /tmp/sp-hook-debug.log
}

debug_log "tool=$TOOL_NAME input=$INPUT"

# If we couldn't parse a tool name, allow (fail open to avoid breaking the session)
if [ -z "$TOOL_NAME" ]; then
  debug_log "decision=allow reason='no tool name parsed'"
  exit 0
fi

json_field() {
  key="$1"
  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r --arg k "$key" '.[$k] // ""' 2>/dev/null
  else
    printf '%s' "$INPUT" | grep -Eo "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | cut -d'"' -f4
  fi
}

PAYLOAD_CWD=$(json_field cwd)
PAYLOAD_TRANSCRIPT_PATH=$(json_field transcript_path)
PAYLOAD_TOOL_USE_ID=$(json_field tool_use_id)

hash_text() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    return 1
  fi
}

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  else
    return 1
  fi
}

sp_trust_dir() {
  printf '%s' "${SP_TRUST_DIR:-$HOME/.claude/strategic-partner/trusted-contracts}"
}

sp_trust_marker_path_allowed() {
  trust_dir=$(sp_trust_dir)
  [ -n "$trust_dir" ] || return 1
  case "$1" in
    "$trust_dir"/*) return 0 ;;
  esac
  return 1
}

builtin_managed_path_allowed() {
  path="$1"
  tmp_base="${TMPDIR:-}"
  tmp_base="${tmp_base%/}"

  if [ -n "$tmp_base" ]; then
    case "$path" in
      "$tmp_base"|"$tmp_base"/*) return 0 ;;
    esac
  fi

  case "$path" in
    /dev/null|/tmp|/tmp/*|/private/tmp|/private/tmp/*|\$TMPDIR|\$TMPDIR/*|\${TMPDIR}|\${TMPDIR}/*) return 0 ;;
    .prompts/*|.prompts|*/.prompts/*|*/.prompts) return 0 ;;
    .handoffs/*|.handoffs|*/.handoffs/*|*/.handoffs) return 0 ;;
    .scripts/*|.scripts|*/.scripts/*|*/.scripts) return 0 ;;
    .backlog/*|.backlog|*/.backlog/*|*/.backlog) return 0 ;;
    specs|*/specs) return 0 ;;
    specs/*|*/specs/*) managed_extension_allowed "$path" && return 0 ;;
    CLAUDE.md|*/CLAUDE.md|AGENTS.md|*/AGENTS.md|GEMINI.md|*/GEMINI.md) return 0 ;;
    CHANGELOG.md|*/CHANGELOG.md|README.md|*/README.md|SKILL.md|*/SKILL.md) return 0 ;;
    .claude/*|*/.claude/*) return 0 ;;
    .gitignore|*/.gitignore) return 0 ;;
    .sp-managed|*/.sp-managed) return 0 ;;
    .claude-plugin/plugin.json|*/.claude-plugin/plugin.json) return 0 ;;
    output-styles/strategic-partner-voice.md|*/output-styles/strategic-partner-voice.md) return 0 ;;
  esac

  return 1
}

find_contract_root() {
  target="$1"
  start="${PAYLOAD_CWD:-}"

  case "$target" in
    /*)
      if [ -d "$target" ]; then
        start="$target"
      else
        start=$(dirname "$target")
      fi
      ;;
  esac

  [ -n "$start" ] || return 1
  [ -d "$start" ] || start=$(dirname "$start")

  while [ -n "$start" ] && [ "$start" != "/" ]; do
    if [ -f "$start/.sp-managed" ]; then
      printf '%s' "$start"
      return 0
    fi
    start=$(dirname "$start")
  done

  return 1
}

repo_relative_path() {
  target="$1"
  root="$2"
  case "$target" in
    "$root"/*) printf '%s' "${target#$root/}" ;;
    /*) return 1 ;;
    ./*) printf '%s' "${target#./}" ;;
    *) printf '%s' "$target" ;;
  esac
}

safe_contract_pattern() {
  pattern="$1"
  [ -n "$pattern" ] || return 1
  case "$pattern" in
    /*|../*|*/../*|*'..'*|*'//'*) return 1 ;;
    '*'|'**'|'*/'|'**/') return 1 ;;
  esac

  case "$pattern" in
    *'*'*|*'?'*)
      first_segment=${pattern%%/*}
      case "$first_segment" in
        ""|*'*'*|*'?'*) return 1 ;;
      esac
      case "$pattern" in
        */*) ;;
        *) return 1 ;;
      esac
      ;;
  esac

  printf '%s' "$pattern" | grep -Eq '^[-A-Za-z0-9_./*?+@]+$'
}

managed_extension_allowed() {
  rel=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$rel" in
    *.md|*.txt|*.jsonl|*.csv|*.html) return 0 ;;
  esac
  return 1
}

contract_is_trusted() {
  root="$1"
  contract="$root/.sp-managed"
  root_hash=$(hash_text "$root") || return 1
  contract_hash=$(hash_file "$contract") || return 1
  trust_dir=$(sp_trust_dir)
  [ -f "$trust_dir/$root_hash-$contract_hash.trusted" ]
}

contract_marker_path() {
  root="$1"
  contract="$root/.sp-managed"
  root_hash=$(hash_text "$root") || return 1
  contract_hash=$(hash_file "$contract") || return 1
  trust_dir=$(sp_trust_dir)
  printf '%s/%s-%s.trusted' "$trust_dir" "$root_hash" "$contract_hash"
}

managed_contract_path_allowed() {
  target="$1"
  MANAGED_CONTRACT_ROOT=""
  MANAGED_CONTRACT_HASH=""
  MANAGED_CONTRACT_MARKER=""

  root=$(find_contract_root "$target") || return 1
  contract="$root/.sp-managed"
  rel=$(repo_relative_path "$target" "$root") || return 1
  managed_extension_allowed "$rel" || return 1

  matched=1
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    pattern=${line%%|*}
    pattern=$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    safe_contract_pattern "$pattern" || continue
    case "$rel" in
      $pattern) matched=0; break ;;
    esac
  done < "$contract"

  [ "$matched" -eq 0 ] || return 1

  if ! contract_is_trusted "$root"; then
    MANAGED_CONTRACT_ROOT="$root"
    MANAGED_CONTRACT_HASH=$(hash_file "$contract" 2>/dev/null)
    MANAGED_CONTRACT_MARKER=$(contract_marker_path "$root" 2>/dev/null)
    return 2
  fi

  return 0
}

stewardship_candidate_path() {
  path=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$path" in
    *.md|*.txt|*.jsonl|*.csv|*.html) ;;
    *) return 1 ;;
  esac

  case "$path" in
    */specs/*|specs/*|*/plans/*|plans/*|*/decisions/*|decisions/*|*/interviews/*|interviews/*|*/research/*|research/*|*/benchmarks/*|benchmarks/*|*/audits/*|audits/*|*/notes/*|notes/*) return 0 ;;
  esac

  return 1
}

confirmation_decision() {
  transcript_path="$1"
  confirmation_mode="$2"
  confirmation_subject="$3"
  current_action_id="$4"

  CONFIRMATION_BLOCK_REASON=""

  if [ -z "$transcript_path" ] || [ ! -r "$transcript_path" ]; then
    CONFIRMATION_BLOCK_REASON="transcript_unreadable"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1 || ! printf '{}' | jq -e type >/dev/null 2>&1; then
    CONFIRMATION_BLOCK_REASON="jq_unavailable"
    return 1
  fi

  if [ -z "$current_action_id" ]; then
    CONFIRMATION_BLOCK_REASON="missing_current_action_id"
    return 1
  fi

  decision=$(tail -160 "$transcript_path" 2>/dev/null | jq -sr \
    --arg mode "$confirmation_mode" \
    --arg subject "$confirmation_subject" \
    --arg current_action_id "$current_action_id" '
    def norm: gsub("[—–]"; "-") | gsub("[[:space:]]+"; " ") | gsub("^\\s+|\\s+$"; "");
    def role: (.message.role // .role // "");
    def content: (.message.content // .content // []);
    def nonempty_text:
      if (content | type) == "array" then any(content[]?; .type == "text" and ((.text // "") | length > 0))
      elif (content | type) == "string" then ((content // "") | length > 0)
      else false end;
    def genuine_user_text: role == "user" and nonempty_text;
    def has_auq:
      ([ .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | length) > 0;
    def text_from_content($value):
      if ($value | type) == "array" then
        ([ $value[]?
          | if .type? == "tool_result" then (.content // "")
            elif .type? == "text" then (.text // "")
            else empty end
          | if type == "array" then ([ .[]? | select(.type? == "text") | .text ] | join(" "))
            else tostring end
        ] | join(" "))
      elif ($value | type) == "string" then $value
      else "" end;
    def parsed_answer($raw):
      ($raw // "") as $safe
      | if ($safe | test("Your questions have been answered:\\s*\"[^\"]+\"\\s*=\\s*\"[^\"]+\"")) then
          ($safe | capture("Your questions have been answered:\\s*\"(?<question>[^\"]+)\"\\s*=\\s*\"(?<answer>[^\"]+)\""))
          | {question: (.question // ""), answer: (.answer // ""), kind: "wrapped"}
        elif ($safe | startswith("Your questions have been answered:")) then
          {question: "", answer: "", kind: "malformed_wrapper"}
        else {question: "", answer: $safe, kind: "direct"}
        end;
    def question_text($q):
      (($q.question // "") + " " + ($q.header // "") + " " +
      (($q.options // []) | map((.label // "") + " " + (.description // "")) | join(" ")));
    def block($reason): "BLOCK " + $reason;

    (map(select(type == "object"))) as $rows
    | ([ $rows | to_entries[] | select((.value | role) == "assistant" and (.value | has_auq)) | .key ] | last // -1) as $question_idx
    | if $question_idx == -1 then block("no_question")
      else
        ([ $rows[$question_idx] | .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | last) as $auq
        | ($auq.id // "") as $question_id
        | if ($question_id | length) == 0 then block("question_id_missing")
          else
            ([ $rows | to_entries[] as $entry
              | $entry.value | .. | objects
              | select(.type? == "tool_result" and ((.tool_use_id? // "") == $question_id))
              | {idx: $entry.key, result: ., row: $entry.value}
            ]) as $answers
            | if ($answers | length) == 0 then
                if (($rows | length) > ($question_idx + 1)) then block("answer_not_found_in_window")
                else block("missing_answer") end
              elif ($answers | length) != 1 then block("duplicate_answer")
              else
                ($answers[0]) as $answer_event
                | if ($answer_event.idx <= $question_idx) then block("answer_before_question")
                  elif (($rows[$answer_event.idx + 1:] | map(select(genuine_user_text)) | length) > 0) then block("stale")
                  else
                    ([ $rows[$answer_event.idx + 1:][]?
                      | .. | objects
                      | select(.type? == "tool_use")
                      | select(
                          if $mode == "dispatch" then
                            (.name? == "Agent" or .name? == "Task")
                          elif $mode == "trust_marker" then
                            ((.name? == "Edit" or .name? == "Write" or .name? == "MultiEdit" or .name? == "NotebookEdit") and
                             ((.input.file_path? // .input.relative_path? // "") == $subject))
                          else false end
                        )
                      | {id: (.id // "")}
                    ]) as $protected_actions
                    | if ([ $protected_actions[]? | select(.id != $current_action_id) ] | length) > 0 then block("confirmation_replayed")
                      else
                        (text_from_content($answer_event.result.content // "")) as $raw_answer
                        | (parsed_answer($raw_answer)) as $display_selected
                        | ($auq.input.questions // []) as $questions
                        | ($answer_event.row.toolUseResult? // null) as $tool_use_result
                        | ((($tool_use_result | type) == "object") and ($tool_use_result | has("answers"))) as $has_structured_answers
                        | (if $has_structured_answers then $tool_use_result.answers else null end) as $structured_answers
                        | (if $has_structured_answers and (($structured_answers | type) == "object") then
                            [ $questions[]? as $q
                              | select($structured_answers | has($q.question // ""))
                              | {question: ($q.question // ""), answer: $structured_answers[$q.question]}
                            ]
                          else [] end) as $structured_matches
                        | if $has_structured_answers and
                             ((($structured_answers | type) != "object") or
                              (($structured_answers | length) != 1) or
                              (($structured_matches | length) != 1) or
                              (($structured_matches[0].answer | type) != "string")) then
                            block("structured_answers_invalid")
                          else
                            (if $has_structured_answers then $structured_matches[0] else $display_selected end) as $selected
                            | if $has_structured_answers and ($display_selected.kind == "wrapped") and
                                 ((($display_selected.question // "") != ($selected.question // "")) or
                                  (($display_selected.answer | norm) != ($selected.answer | norm))) then
                                block("structured_display_disagree")
                              elif ($has_structured_answers | not) and ($display_selected.kind == "malformed_wrapper") then
                                block("display_answer_parse_error")
                              else
                                ($selected.answer | norm) as $answer
                                | if ($answer | length) == 0 then block("missing_answer")
                                  else
                                    (if (($selected.question // "") | length) > 0 then
                                       [ $questions[]? | select((.question // "") == $selected.question) ]
                                     elif ($questions | length) == 1 then
                                       [ $questions[0] ]
                                     else [] end) as $matched_questions
                                    | if ($matched_questions | length) != 1 then block("question_mismatch")
                                      else
                                        ($matched_questions[0]) as $question
                                        | ($question.options // []) as $options
                                        | ([ $options[]? | {label: ((.label // "") | norm)} | select(.label == $answer) ] | .[0] // null) as $selected_option
                                        | if $selected_option == null then block("selected_option_label")
                                          elif $mode == "dispatch" then
                                            ([ $options[]? | ((.label // "") | norm) ]) as $labels
                                            | ("Dispatch now - " + $subject) as $expected_dispatch
                                            | if ($selected_option.label != $expected_dispatch) then block("selected_option_label")
                                              elif (($labels | index("Hold - let me review the brief first")) == null) then block("missing_hold_label")
                                              elif (($labels | index("Wrong agent - let me pick")) == null) then block("missing_wrong_agent_label")
                                              else "ALLOW" end
                                          elif $mode == "trust_marker" then
                                            (question_text($question)) as $visible_text
                                            | if ($selected_option.label != "Activate stewardship contract") then block("selected_option_label")
                                              elif (($visible_text | index($subject)) == null) then block("missing_marker_path")
                                              elif (($visible_text | index(".sp-managed")) == null) then block("missing_contract_name")
                                              else "ALLOW" end
                                          else block("unknown_confirmation_mode") end
                                      end
                                  end
                              end
                          end
                      end
                  end
              end
          end
      end
  ' 2>/dev/null)

  case "$decision" in
    ALLOW)
      return 0
      ;;
    BLOCK\ *)
      CONFIRMATION_BLOCK_REASON=${decision#BLOCK }
      return 1
      ;;
    *)
      CONFIRMATION_BLOCK_REASON="parse_error"
      return 1
      ;;
  esac
}

trust_marker_confirmation_present() {
  marker_path="$1"
  TRUST_MARKER_BLOCK_REASON=""

  [ -n "$marker_path" ] || return 1

  if confirmation_decision "$PAYLOAD_TRANSCRIPT_PATH" "trust_marker" "$marker_path" "$PAYLOAD_TOOL_USE_ID"; then
    return 0
  fi

  TRUST_MARKER_BLOCK_REASON="$CONFIRMATION_BLOCK_REASON"
  return 1
}

dispatch_confirmation_present() {
  transcript_path="$1"
  subagent_type="$2"
  DISPATCH_BLOCK_REASON=""

  [ -n "$subagent_type" ] || return 1

  if confirmation_decision "$transcript_path" "dispatch" "$subagent_type" "$PAYLOAD_TOOL_USE_ID"; then
    return 0
  fi

  DISPATCH_BLOCK_REASON="$CONFIRMATION_BLOCK_REASON"
  return 1
}

# Context-file stewardship guard. This is intentionally factored out of the
# broad source-editing guard so CLAUDE.md / AGENTS.md / GEMINI.md and
# .claude/rules writes are checked by content, not merely by path.
CONTEXT_GUARD="$(cd "$(dirname "$0")" && pwd)/context-file-guard.sh"
if [ -r "$CONTEXT_GUARD" ]; then
  guard_out=$(printf '%s' "$INPUT" | bash "$CONTEXT_GUARD" 2>&1)
  guard_code=$?
  if [ "$guard_code" -ne 0 ]; then
    debug_log "decision=BLOCK context_guard output=$guard_out"
    printf '%s\n' "$guard_out" >&2
    exit "$guard_code"
  fi
else
  if printf '%s' "$INPUT" | grep -qE '"(file_path|relative_path)"[[:space:]]*:[[:space:]]*"[^"]*((CLAUDE|AGENTS|GEMINI)\.md|\.claude/rules/[^"]+\.md)' ||
     printf '%s' "$INPUT" | grep -qE '"command"[[:space:]]*:[[:space:]]*"[^"]*((CLAUDE|AGENTS|GEMINI)\.md|\.claude/rules/[^"]+\.md)'; then
    debug_log "decision=BLOCK reason='context guard missing for context-file mutation'"
    echo "BLOCKED: context-file write guard is unavailable; refusing context-file mutation." >&2
    exit 2
  fi
fi

# --- Guard 0: Block agent dispatch without exact dispatch confirmation ---
if [ "$TOOL_NAME" = "Agent" ] || [ "$TOOL_NAME" = "Task" ]; then
  TRANSCRIPT_PATH=""
  SUBAGENT_TYPE=""
  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
    TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""' 2>/dev/null)
    SUBAGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // .tool_input.agent_type // .tool_input.agent // ""' 2>/dev/null)
  else
    TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | grep -Eo '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
    SUBAGENT_TYPE=$(printf '%s' "$INPUT" | grep -Eo '"(subagent_type|agent_type|agent)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
  fi

  if [ -z "$SUBAGENT_TYPE" ]; then
    debug_log "decision=BLOCK tool=$TOOL_NAME reason='missing agent type in dispatch payload'"
    echo "BLOCKED: Strategic Partner could not read the exact agent type for this dispatch. Ask again with the exact agent named before dispatch." >&2
    exit 2
  fi

  if dispatch_confirmation_present "$TRANSCRIPT_PATH" "$SUBAGENT_TYPE"; then
    debug_log "decision=allow tool=$TOOL_NAME subagent=$SUBAGENT_TYPE reason='dispatch confirmation present'"
    exit 0
  fi

  debug_log "decision=BLOCK tool=$TOOL_NAME subagent=$SUBAGENT_TYPE reason='missing exact dispatch confirmation'"
  case "${DISPATCH_BLOCK_REASON:-}" in
    jq_unavailable)
      echo "BLOCKED: Strategic Partner could not verify the dispatch confirmation because jq is unavailable. Use prompt delivery, or install jq and ask again." >&2
      ;;
    selected_option_label|missing_hold_label|missing_wrong_agent_label|question_mismatch)
      echo "BLOCKED: Strategic Partner must confirm dispatch with a selected option label exactly matching: [Dispatch now — $SUBAGENT_TYPE]. Descriptions do not authorize dispatch; ask again with the exact labels." >&2
      ;;
    structured_answers_invalid|structured_display_disagree|display_answer_parse_error)
      echo "BLOCKED: Strategic Partner could not safely correlate the selected answer with the exact confirmation question. Ask again with a fresh structured confirmation before dispatching." >&2
      ;;
    stale)
      echo "BLOCKED: Strategic Partner found an older dispatch confirmation, but a later user message made it stale. Ask again before dispatching." >&2
      ;;
    answer_not_found_in_window)
      echo "BLOCKED: Strategic Partner found the confirmation question, but its answer is outside the recent transcript window. Please confirm once more before dispatching." >&2
      ;;
    missing_current_action_id)
      echo "BLOCKED: Strategic Partner could not verify the current protected action identity. Please confirm once more before dispatching." >&2
      ;;
    confirmation_replayed)
      echo "BLOCKED: Strategic Partner found that this dispatch confirmation was already used by an earlier protected action. Please confirm once more before dispatching again." >&2
      ;;
    *)
      echo "BLOCKED: Strategic Partner must confirm the exact agent before dispatch. Ask via AskUserQuestion with: [Dispatch now — $SUBAGENT_TYPE] [Hold — let me review the brief first] [Wrong agent — let me pick]." >&2
      ;;
  esac
  exit 2
fi

# --- Guard 1: Block Edit/Write/MultiEdit on disallowed paths ---
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
  # Tolerate arbitrary whitespace around the colon, e.g. '"file_path" : "..."'.
  FILE_PATH=$(echo "$INPUT" | grep -Eo '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
  # No file_path on a confirmed edit tool — fail CLOSED. We already know the
  # tool is one that edits files (the branch above); an unreadable path means
  # we can't prove it targets an allow-listed location, so block to be safe.
  # Mirrors Guard 3 (Serena), which already blocks on an unreadable path.
  if [ -z "$FILE_PATH" ]; then
    debug_log "decision=BLOCK reason='no file_path parsed on edit tool'"
    echo "BLOCKED: Strategic Partner could not read the file path for a source-editing tool — blocking to be safe. Craft a prompt instead." >&2
    exit 2
  fi
	  case "$FILE_PATH" in
	    [A-Za-z]:\\*|\\\\*)  FILE_PATH_NORM=$(echo "$FILE_PATH" | tr '\\' '/') ;;
	    *)                   FILE_PATH_NORM="$FILE_PATH" ;;
	  esac

  if sp_trust_marker_path_allowed "$FILE_PATH_NORM"; then
    if trust_marker_confirmation_present "$FILE_PATH_NORM"; then
      debug_log "decision=allow path=$FILE_PATH reason='confirmed .sp-managed trust marker activation'"
      exit 0
    fi

    debug_log "decision=BLOCK path=$FILE_PATH reason='trust marker activation lacks confirmation'"
    case "${TRUST_MARKER_BLOCK_REASON:-}" in
      jq_unavailable)
        echo "BLOCKED: Strategic Partner could not verify .sp-managed activation because jq is unavailable. Ask again after jq is available; trust markers require transcript-confirmed approval." >&2
        ;;
      answer_not_found_in_window)
        echo "BLOCKED: Strategic Partner found the .sp-managed activation question, but its answer is outside the recent transcript window. Please confirm once more before creating the trust marker." >&2
        ;;
      missing_current_action_id)
        echo "BLOCKED: Strategic Partner could not verify the current protected action identity. Please confirm .sp-managed activation once more." >&2
        ;;
      confirmation_replayed)
        echo "BLOCKED: Strategic Partner found that this .sp-managed confirmation was already used by an earlier protected action. Please confirm activation once more." >&2
        ;;
      *)
        echo "BLOCKED: Strategic Partner cannot write a .sp-managed trust marker without a fresh AskUserQuestion confirmation. Ask with option [Activate stewardship contract] and include the exact marker path in the question: $FILE_PATH" >&2
        ;;
    esac
    exit 2
  fi

  if builtin_managed_path_allowed "$FILE_PATH_NORM"; then
    debug_log "decision=allow path=$FILE_PATH reason='built-in managed path'"
    exit 0
  fi

  managed_contract_path_allowed "$FILE_PATH_NORM"
  managed_status=$?
  if [ "$managed_status" -eq 0 ]; then
    debug_log "decision=allow path=$FILE_PATH reason='activated .sp-managed contract'"
    exit 0
  elif [ "$managed_status" -eq 2 ]; then
    debug_log "decision=BLOCK path=$FILE_PATH reason='matching .sp-managed contract not activated'"
    echo "BLOCKED: Strategic Partner found .sp-managed coverage for this path, but that contract is not locally activated yet. Review $MANAGED_CONTRACT_ROOT/.sp-managed; if you approve it, create this local activation marker: $MANAGED_CONTRACT_MARKER (contract hash: $MANAGED_CONTRACT_HASH)." >&2
    exit 2
  fi

  # Everything else is blocked
  debug_log "decision=BLOCK tool=$TOOL_NAME path=$FILE_PATH"
  if stewardship_candidate_path "$FILE_PATH_NORM"; then
    echo "BLOCKED: Strategic Partner does not manage this repo artifact yet. If this is a strategic/planning artifact, ask to add a narrow pattern for it to .sp-managed and activate that contract. (Tool: $TOOL_NAME, Path: $FILE_PATH)" >&2
  else
    echo "BLOCKED: Strategic Partner does not edit implementation source files. Craft a prompt instead, dispatch an agent, or add a narrow non-code stewardship contract in .sp-managed. (Tool: $TOOL_NAME, Path: $FILE_PATH)" >&2
  fi
  exit 2
fi

command_without_quoted_strings() {
  printf '%s' "$1" | perl -0pe "s/'[^']*'/Q/g; s/\"([^\"\\\\]|\\\\.)*\"/Q/g"
}

redirect_target_allowed() {
  target="$1"

  tmp_base="${TMPDIR:-}"
  tmp_base="${tmp_base%/}"
  if [ -n "$tmp_base" ]; then
    case "$target" in
      "$tmp_base"|"$tmp_base"/*) return 0 ;;
    esac
  fi

  sp_trust_marker_path_allowed "$target" && return 1

  case "$target" in
    /dev/null|/tmp|/tmp/*|/private/tmp|/private/tmp/*|\$TMPDIR|\$TMPDIR/*|\${TMPDIR}|\${TMPDIR}/*) return 0 ;;
    .prompts/*|.handoffs/*|.scripts/*|.backlog/*|.sp-managed) return 0 ;;
    */.prompts/*|*/.handoffs/*|*/.scripts/*|*/.backlog/*|*/.sp-managed) return 0 ;;
    specs/*|*/specs/*) managed_extension_allowed "$target" && return 0 ;;
  esac

  managed_contract_path_allowed "$target"
  [ "$?" -eq 0 ]
}

bash_command_has_blocked_mutation() {
  stripped=$(command_without_quoted_strings "$1")

  redirect_targets=$(printf '%s' "$stripped" | perl -ne 'while (/(?:^|[^0-9])(?:[0-9]?>|[0-9]?>>|&>|>\|)\s*([^\s;|&<>)`]+)/g) { print "$1\n"; }')
  if [ -n "$redirect_targets" ]; then
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      redirect_target_allowed "$target" || return 0
    done <<EOF
$redirect_targets
EOF
  fi

  if printf '%s' "$stripped" | grep -qE '(sed([[:space:]]+(-[^-[:space:];&|]*|--[^[:space:];&|]*))*[[:space:]]+(-[^-[:space:];&|]*i[^[:space:];&|]*|--in-place(=[^[:space:];&|]*)?)|tee[[:space:]]|perl([[:space:]]+(-[^-[:space:];&|]*|--[^[:space:];&|]*))*[[:space:]]+-[^-[:space:];&|]*i[^[:space:];&|]*|git[[:space:]]+apply|git[[:space:]]+cherry-pick)'; then
    return 0
  fi

  return 1
}

raw_bash_payload_has_blocked_mutation() {
  raw="$1"
  raw_stripped=$(printf '%s' "$raw" | perl -0pe "s/'[^']*'/Q/g; s/\\\\\"([^\\\\]|\\\\.)*\\\\\"/Q/g")

  redirect_targets=$(printf '%s' "$raw_stripped" | perl -ne 'while (/(?:^|[^0-9])(?:[0-9]?>|[0-9]?>>|&>|>\|)\s*([^\\",[:space:];|&<>}`)]+)/g) { print "$1\n"; }')
  if [ -n "$redirect_targets" ]; then
    while IFS= read -r target; do
      [ -z "$target" ] && continue
      redirect_target_allowed "$target" || return 0
    done <<EOF
$redirect_targets
EOF
  fi

  if printf '%s' "$raw_stripped" | grep -qE '(sed([[:space:]]+(-[^-[:space:];&|]*|--[^[:space:];&|]*))*[[:space:]]+(-[^-[:space:];&|]*i[^[:space:];&|]*|--in-place(=[^[:space:];&|]*)?)|tee[[:space:]]|perl([[:space:]]+(-[^-[:space:];&|]*|--[^[:space:];&|]*))*[[:space:]]+-[^-[:space:];&|]*i[^[:space:];&|]*|git[[:space:]]+apply|git[[:space:]]+cherry-pick)'; then
    return 0
  fi

  return 1
}

# --- Guard 2: Block Bash commands with obvious file-mutation patterns ---
if [ "$TOOL_NAME" = "Bash" ]; then
  JQ_AVAILABLE=false
  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
    JQ_AVAILABLE=true
  fi

  if [ "$JQ_AVAILABLE" = true ]; then
    COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
    if [ -z "$COMMAND" ]; then
      debug_log "decision=BLOCK tool=Bash reason='no command parsed'"
      echo "BLOCKED: Strategic Partner could not read the Bash command — blocking to be safe." >&2
      exit 2
    fi

    if bash_command_has_blocked_mutation "$COMMAND"; then
      debug_log "decision=BLOCK tool=Bash command=$COMMAND"
      echo "BLOCKED: Strategic Partner does not mutate source files via shell. Craft a prompt instead. (Command pattern detected)" >&2
      exit 2
    fi
  elif raw_bash_payload_has_blocked_mutation "$INPUT"; then
    debug_log "decision=BLOCK tool=Bash reason='jq unavailable and raw mutation marker detected'"
    echo "BLOCKED: Strategic Partner could not safely parse a mutation-looking Bash command because jq is unavailable — blocking to be safe." >&2
    exit 2
  fi
fi

# --- Guard 3: Block Serena write tools on source files ---
if echo "$TOOL_NAME" | grep -Eq '^mcp__(plugin_serena_serena|serena)__'; then
  case "$TOOL_NAME" in
    *replace_content|*replace_symbol_body|*insert_after_symbol|*insert_before_symbol|*create_text_file|*rename_symbol|*execute_shell_command)
      # Tolerate arbitrary whitespace around the colon, e.g. '"relative_path" : "..."'.
      REL_PATH=$(echo "$INPUT" | grep -Eo '"relative_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
      case "$REL_PATH" in
        CLAUDE.md|AGENTS.md|GEMINI.md|.claude/rules/*.md)
          debug_log "decision=BLOCK tool=$TOOL_NAME path=$REL_PATH reason='context file via Serena'"
          echo "BLOCKED: Context-file mutations must use Edit/Write so the stewardship guard can preflight the full proposed file. (Tool: $TOOL_NAME, Path: $REL_PATH)" >&2
          exit 2
          ;;
        *)
          if builtin_managed_path_allowed "$REL_PATH"; then
            debug_log "decision=allow tool=$TOOL_NAME path=$REL_PATH"
            exit 0
          fi

          managed_contract_path_allowed "$REL_PATH"
          managed_status=$?
          if [ "$managed_status" -eq 0 ]; then
            debug_log "decision=allow tool=$TOOL_NAME path=$REL_PATH reason='activated .sp-managed contract'"
            exit 0
          elif [ "$managed_status" -eq 2 ]; then
            debug_log "decision=BLOCK tool=$TOOL_NAME path=$REL_PATH reason='matching .sp-managed contract not activated'"
            echo "BLOCKED: Strategic Partner found .sp-managed coverage for this Serena path, but that contract is not locally activated yet. Review $MANAGED_CONTRACT_ROOT/.sp-managed; if you approve it, create this local activation marker: $MANAGED_CONTRACT_MARKER (contract hash: $MANAGED_CONTRACT_HASH)." >&2
            exit 2
          fi

          debug_log "decision=BLOCK tool=$TOOL_NAME path=$REL_PATH"
          echo "BLOCKED: Strategic Partner does not modify implementation source code via Serena. Craft a prompt instead. (Tool: $TOOL_NAME, Path: $REL_PATH)" >&2
          exit 2
          ;;
      esac
      ;;
  esac
fi

# All other tools — allow
debug_log "decision=allow tool=$TOOL_NAME (no guard matched)"
exit 0
