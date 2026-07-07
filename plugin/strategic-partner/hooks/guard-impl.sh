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
