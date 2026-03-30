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

# Read the tool input JSON from stdin
INPUT=$(cat)

# Extract tool name from the hook environment variable
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

# --- Guard 1: Block Edit/Write/MultiEdit on disallowed paths ---
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "MultiEdit" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
  FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path": "[^"]*"' | head -1 | cut -d'"' -f4)
  fi

  # Allowed paths (SP's own workspace)
  case "$FILE_PATH" in
    */.prompts/*|*/.prompts)     exit 0 ;;
    */.handoffs/*|*/.handoffs)   exit 0 ;;
    */.scripts/*|*/.scripts)     exit 0 ;;
    */CLAUDE.md)                 exit 0 ;;
    */CHANGELOG.md)              exit 0 ;;
    */README.md)                 exit 0 ;;
    */SKILL.md)                  exit 0 ;;
    */.claude/*)                 exit 0 ;;
    */.gitignore)                exit 0 ;;
  esac

  # Everything else is blocked
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
    for pattern in ".prompts" ".handoffs" ".scripts" "CLAUDE.md" "CHANGELOG.md" "README.md" "SKILL.md" ".claude/" ".gitignore"; do
      if echo "$COMMAND" | grep -q "$pattern"; then
        ALLOWED=true
        break
      fi
    done
    if [ "$ALLOWED" = false ]; then
      echo "BLOCKED: Strategic Partner does not mutate source files via shell. Craft a prompt instead. (Command pattern detected)" >&2
      exit 2
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
        .prompts/*|.handoffs/*|.scripts/*|CLAUDE.md|CHANGELOG.md|README.md|SKILL.md|.claude/*|.gitignore) exit 0 ;;
      esac
      echo "BLOCKED: Strategic Partner does not modify source code via Serena. Craft a prompt instead. (Tool: $TOOL_NAME, Path: $REL_PATH)" >&2
      exit 2
      ;;
  esac
fi

# All other tools — allow
exit 0
