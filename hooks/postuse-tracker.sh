#!/usr/bin/env bash
# hooks/postuse-tracker.sh — PostToolUse hook script for the strategic-partner skill.
#
# Tracks Write/Edit/MultiEdit tool calls that write to
# .handoffs/last-prompts/[N].md so the Stop hook (Layer 2) and
# the release-time transcript lint (Layer 3) can validate fence + write
# coupling without inspecting the full transcript.
#
# Exit 0 always (tracking only — this hook never blocks).
#
# State file: .claude/sp-state/last-prompt-writes.txt
# Format: <session_id>\t<timestamp>\t<file_path>
#
# Session cleanup: if the first entry in the state file belongs to a
# different session_id, the file is truncated before the new entry is
# appended. This prevents stale cross-session state from leaking into a
# fresh session's fence-write coupling checks.

set -u

STATE_FILE=".claude/sp-state/last-prompt-writes.txt"

# --- Parse stdin JSON ---
INPUT=$(cat)

# Extract tool_name — try compact form, then spaced form
TOOL_NAME=""
TOOL_NAME=$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$TOOL_NAME" ]; then
  TOOL_NAME=$(printf '%s' "$INPUT" | grep -o '"tool_name": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

# No tool_name → fail open (don't block anything)
[ -z "$TOOL_NAME" ] && exit 0

# Only process Write / Edit / MultiEdit
case "$TOOL_NAME" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

# Extract file_path — handle compact and spaced forms
FILE_PATH=""
FILE_PATH=$(printf '%s' "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$FILE_PATH" ]; then
  FILE_PATH=$(printf '%s' "$INPUT" | grep -o '"file_path": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

# No file_path → fail open
[ -z "$FILE_PATH" ] && exit 0

# Normalise Windows paths (defensive; SP runs on macOS/Linux).
# The tr argument uses a doubled backslash to match a single literal backslash.
case "$FILE_PATH" in
  [A-Za-z]:\\*|\\\\*) FILE_PATH=$(printf '%s' "$FILE_PATH" | sed 's|\\|/|g') ;;
esac

# Filter: only track writes to .handoffs/last-prompts/[0-9]+.md
# Match both relative (.handoffs/…) and absolute (…/.handoffs/…) paths.
case "$FILE_PATH" in
  .handoffs/last-prompts/[0-9]*.md|*/.handoffs/last-prompts/[0-9]*.md) ;;
  *) exit 0 ;;
esac

# Extract session_id — try compact form first
SESSION_ID=""
if command -v jq > /dev/null 2>&1; then
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
else
  SESSION_ID=$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ -z "$SESSION_ID" ]; then
    SESSION_ID=$(printf '%s' "$INPUT" | grep -o '"session_id": "[^"]*"' | head -1 | cut -d'"' -f4)
  fi
fi
# Fall back to "unknown" rather than recording an empty session_id
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Session-scoped state cleanup ---
# If the state file exists and its first entry belongs to a different
# session, truncate it so stale data doesn't bleed into the new session.
if [ -f "$STATE_FILE" ]; then
  FIRST_LINE=$(head -1 "$STATE_FILE" 2>/dev/null)
  if [ -n "$FIRST_LINE" ]; then
    STORED_SESSION=$(printf '%s' "$FIRST_LINE" | cut -f1)
    if [ "$STORED_SESSION" != "$SESSION_ID" ]; then
      : > "$STATE_FILE"
    fi
  fi
fi

# Ensure directory exists (in case .claude/sp-state was not pre-created)
mkdir -p "$(dirname "$STATE_FILE")"

# Append the tracking entry
printf '%s\t%s\t%s\n' "$SESSION_ID" "$TIMESTAMP" "$FILE_PATH" >> "$STATE_FILE"

exit 0
