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

dispatch_confirmation_present() {
  transcript_path="$1"
  subagent_type="$2"

  # A missing/unreadable transcript means we can't verify a confirmation
  # exists — fail CLOSED. Mirrors Guard 1 (unreadable file_path on a
  # confirmed edit tool) and Guard 3 (unreadable Serena path) below: an
  # unverifiable state blocks rather than allows.
  [ -n "$transcript_path" ] && [ -r "$transcript_path" ] || return 1

  if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
    auq_payload=$(tail -160 "$transcript_path" 2>/dev/null | jq -sr '
      def role: (.message.role // .role // "");
      def has_auq:
        ([ .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | length) > 0;
      [ .[] | select(type == "object") | select((role == "assistant") and has_auq) ] | last as $turn
      | if $turn == null then ""
        else
          ([ $turn | .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | last) as $auq
          | (($auq.input.questions // []) | map(
              (.question // "") + " " +
              (.header // "") + " " +
              (((.options // []) | map((.label // "") + " " + (.description // "")) | join(" ")))
            ) | join(" "))
        end
    ' 2>/dev/null)

    # The offered-options check below is necessary but not sufficient: all
    # three labels are always offered together regardless of which one the
    # user picks. Pull the answer out of the transcript entry immediately
    # after the qualifying AUQ turn — the user's tool_result. Real
    # transcripts wrap the answer as `Your questions have been answered:
    # "<question>"="<answer>". You can now continue with these answers in
    # mind.`; the wrapper is stripped below.
    answer_raw=$(tail -160 "$transcript_path" 2>/dev/null | jq -sr '
      def role: (.message.role // .role // "");
      def has_auq:
        ([ .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | length) > 0;
      (map(select(type == "object"))) as $rows
      | ([ $rows | to_entries[] | select((.value | role) == "assistant" and (.value | has_auq)) | .key ] | last // -1) as $idx
      | if $idx == -1 then ""
        else
          # The confirmation only authorizes the immediately-following
          # exchange. Any further user/assistant turn after the answer
          # stales it — a later, unrelated dispatch attempt must not be
          # able to replay an old confirmation.
          (($rows[$idx + 2:]) | map(select((role == "user") or (role == "assistant"))) | length) as $later_turns
          | if $later_turns > 0 then ""
            else
              ($rows[$idx + 1].message.content // $rows[$idx + 1].content // "") as $next
              | if ($next | type) == "array" then
                  (([ $next[] | select(.type? == "tool_result") | .content ] | last // "")) as $raw
                  | if ($raw | type) == "array" then
                      ([ $raw[] | select(.type? == "text") | .text ] | join(" "))
                    else ($raw // "")
                    end
                elif ($next | type) == "string" then $next
                else "" end
            end
        end
    ' 2>/dev/null)
  else
    auq_payload=$(tail -160 "$transcript_path" 2>/dev/null | tr '\n' ' ')
    answer_raw=""
  fi

  [ -n "$auq_payload" ] || return 1

  # Minor punctuation drift (a plain hyphen instead of an em dash) should
  # not cause a false block — normalize both sides to a hyphen before
  # comparing. Everything else about the match stays strict/case-sensitive.
  auq_norm=$(printf '%s' "$auq_payload" | sed 's/—/-/g')

  if [ -n "$subagent_type" ]; then
    printf '%s' "$auq_norm" | grep -qF "Dispatch now - $subagent_type" || return 1
  else
    printf '%s' "$auq_norm" | grep -qF "Dispatch now -" || return 1
  fi
  printf '%s' "$auq_norm" | grep -qF "Hold - let me review the brief first" || return 1
  printf '%s' "$auq_norm" | grep -qF "Wrong agent - let me pick" || return 1

  # The options were offered — now require the SELECTED answer to
  # literally match the dispatch-confirm option, not merely have been
  # offered as a choice.
  [ -n "$answer_raw" ] || return 1
  answer_text=$(printf '%s' "$answer_raw" | perl -0pe 's/.*="//s; s/"\.\s*You can now continue.*$//s')
  answer_norm=$(printf '%s' "$answer_text" | sed 's/—/-/g')

  if [ -n "$subagent_type" ]; then
    [ "$answer_norm" = "Dispatch now - $subagent_type" ]
  else
    case "$answer_norm" in
      "Dispatch now -"*) return 0 ;;
      *) return 1 ;;
    esac
  fi
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

  if dispatch_confirmation_present "$TRANSCRIPT_PATH" "$SUBAGENT_TYPE"; then
    debug_log "decision=allow tool=$TOOL_NAME subagent=$SUBAGENT_TYPE reason='dispatch confirmation present'"
    exit 0
  fi

  debug_log "decision=BLOCK tool=$TOOL_NAME subagent=$SUBAGENT_TYPE reason='missing exact dispatch confirmation'"
  if [ -n "$SUBAGENT_TYPE" ]; then
    echo "BLOCKED: Strategic Partner must confirm the exact agent before dispatch. Ask via AskUserQuestion with: [Dispatch now — $SUBAGENT_TYPE] [Hold — let me review the brief first] [Wrong agent — let me pick]." >&2
  else
    echo "BLOCKED: Strategic Partner must confirm the exact agent before dispatch. Ask via AskUserQuestion with: [Dispatch now — <subagent_type>] [Hold — let me review the brief first] [Wrong agent — let me pick]." >&2
  fi
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

  # Allowed paths (SP's own workspace)
  case "$FILE_PATH_NORM" in
    /tmp/*|/private/tmp/*)                              debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .prompts/*|.prompts|*/.prompts/*|*/.prompts)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .handoffs/*|.handoffs|*/.handoffs/*|*/.handoffs) debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .scripts/*|.scripts|*/.scripts/*|*/.scripts)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .backlog/*|.backlog|*/.backlog/*|*/.backlog)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    CLAUDE.md|*/CLAUDE.md)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    AGENTS.md|*/AGENTS.md)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    GEMINI.md|*/GEMINI.md)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    CHANGELOG.md|*/CHANGELOG.md)                      debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    README.md|*/README.md)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    SKILL.md|*/SKILL.md)                              debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .claude/*|*/.claude/*)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .gitignore|*/.gitignore)                          debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
  esac

  # Everything else is blocked
  debug_log "decision=BLOCK tool=$TOOL_NAME path=$FILE_PATH"
  echo "BLOCKED: Strategic Partner does not edit source files. Craft a prompt instead, or dispatch an agent. (Tool: $TOOL_NAME, Path: $FILE_PATH)" >&2
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

  case "$target" in
    /dev/null|/tmp|/tmp/*|/private/tmp|/private/tmp/*|\$TMPDIR|\$TMPDIR/*|\${TMPDIR}|\${TMPDIR}/*) return 0 ;;
    .prompts/*|.handoffs/*|.scripts/*|.backlog/*|.claude/*|.gitignore) return 0 ;;
    */.prompts/*|*/.handoffs/*|*/.scripts/*|*/.backlog/*|*/.claude/*|*/.gitignore) return 0 ;;
  esac

  return 1
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

  if printf '%s' "$stripped" | grep -qE '(sed[[:space:]]+-[^;&|]*i|tee[[:space:]]|perl[[:space:]]+-[^;&|]*i|git[[:space:]]+apply|git[[:space:]]+cherry-pick)'; then
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

  if printf '%s' "$raw_stripped" | grep -qE '(sed[[:space:]]+-[^;&|]*i|tee[[:space:]]|perl[[:space:]]+-[^;&|]*i|git[[:space:]]+apply|git[[:space:]]+cherry-pick)'; then
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
if echo "$TOOL_NAME" | grep -q "^mcp__plugin_serena_serena__"; then
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
        .prompts/*|.handoffs/*|.scripts/*|.backlog/*|CLAUDE.md|CHANGELOG.md|README.md|SKILL.md|.claude/*|.gitignore)
          debug_log "decision=allow tool=$TOOL_NAME path=$REL_PATH"
          exit 0
          ;;
      esac
      debug_log "decision=BLOCK tool=$TOOL_NAME path=$REL_PATH"
      echo "BLOCKED: Strategic Partner does not modify source code via Serena. Craft a prompt instead. (Tool: $TOOL_NAME, Path: $REL_PATH)" >&2
      exit 2
      ;;
  esac
fi

# All other tools — allow
debug_log "decision=allow tool=$TOOL_NAME (no guard matched)"
exit 0
