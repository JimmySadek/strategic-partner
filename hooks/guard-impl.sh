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

# Extract tool name from stdin JSON (Claude Code passes tool_name in the JSON payload)
TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$TOOL_NAME" ]; then
  TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

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

# --- Guard 1: Block Edit/Write/MultiEdit on disallowed paths ---
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path": "[^"]*"' | head -1 | cut -d'"' -f4)
  fi
  # No file_path in payload — fail open to avoid breaking the session
  if [ -z "$FILE_PATH" ]; then
    debug_log "decision=allow reason='no file_path parsed'"
    exit 0
  fi
  case "$FILE_PATH" in
    [A-Za-z]:\\*|\\\\*)  FILE_PATH_NORM=$(echo "$FILE_PATH" | tr '\\' '/') ;;
    *)                   FILE_PATH_NORM="$FILE_PATH" ;;
  esac

  # Allowed paths (SP's own workspace)
  case "$FILE_PATH_NORM" in
    .prompts/*|.prompts|*/.prompts/*|*/.prompts)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .handoffs/*|.handoffs|*/.handoffs/*|*/.handoffs) debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .scripts/*|.scripts|*/.scripts/*|*/.scripts)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    .backlog/*|.backlog|*/.backlog/*|*/.backlog)     debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
    CLAUDE.md|*/CLAUDE.md)                            debug_log "decision=allow path=$FILE_PATH"; exit 0 ;;
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

# --- Guard 2: Block Bash commands with obvious file-mutation patterns ---
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$COMMAND" ]; then
    COMMAND=$(echo "$INPUT" | grep -o '"command": "[^"]*"' | head -1 | cut -d'"' -f4)
  fi

  if echo "$COMMAND" | grep -qE '(sed\s+-i|>\s|>>|tee\s|perl\s+-i|git\s+apply|git\s+cherry-pick)'; then
    ALLOWED=false
    for pattern in ".prompts" ".handoffs" ".scripts" ".backlog" "CLAUDE.md" "CHANGELOG.md" "README.md" "SKILL.md" ".claude/" ".gitignore"; do
      if echo "$COMMAND" | grep -q "$pattern"; then
        ALLOWED=true
        break
      fi
    done
    if [ "$ALLOWED" = false ]; then
      debug_log "decision=BLOCK tool=Bash command=$COMMAND"
      echo "BLOCKED: Strategic Partner does not mutate source files via shell. Craft a prompt instead. (Command pattern detected)" >&2
      exit 2
    else
      debug_log "decision=allow tool=Bash (allowed path in command)"
    fi
  fi
fi

# --- Guard 3: Block Serena write tools on source files ---
if echo "$TOOL_NAME" | grep -q "^mcp__plugin_serena_serena__"; then
  case "$TOOL_NAME" in
    *replace_content|*replace_symbol_body|*insert_after_symbol|*insert_before_symbol|*create_text_file|*rename_symbol|*execute_shell_command)
      REL_PATH=$(echo "$INPUT" | grep -o '"relative_path":"[^"]*"' | head -1 | cut -d'"' -f4)
      if [ -z "$REL_PATH" ]; then
        REL_PATH=$(echo "$INPUT" | grep -o '"relative_path": "[^"]*"' | head -1 | cut -d'"' -f4)
      fi
      case "$REL_PATH" in
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
