#!/usr/bin/env bash
# hooks/stop-validator.sh — Stop hook response-end validator (Layer 2).
#
# Fires when Claude is about to end its turn (Stop hook event). Validates
# three structural rules against the final assistant response:
#
#   1. AUQ-must-be-AUQ (always-on): prose sentence-final "?" must be
#      inside an AskUserQuestion tool call, not inline prose.
#   2. Tool-availability claims (always-on): text asserting tool presence/
#      absence must be backed by an actual tool call in the same turn.
#   3. Fence-write coupling (fence-conditional): any real "══ START 🟢 COPY ══"
#      fence must be preceded by a Write to .handoffs/last-prompts/[N].md
#      in the same turn.
#
# Empirically verified Stop hook stdin fields (from .handoffs/v514-spike-findings-0429.md):
#   session_id          — session identifier
#   transcript_path     — path to the JSONL conversation transcript
#   hook_event_name     — "Stop"
#   stop_hook_active    — boolean; true when already in a forced continuation
#   last_assistant_message — trailing text of the final response (fast-path)
#
# Exit codes:
#   0 — all checks pass (or graceful skip)
#   2 — violation detected; stderr message becomes Claude's continuation context
#
# NOTE: The active guard logic is inlined directly in SKILL.md frontmatter
# for distributed installs (per the PreToolUse guard precedent — see
# hooks/guard-impl.sh header and references/hooks-integration.md). This
# standalone script is kept in sync for local testing and documentation.
# Use SP_HOOK_DEBUG=1 for debug logging.

set -u

STATE_FILE=".claude/sp-state/last-prompt-writes.txt"

debug_log() {
  [ "${SP_HOOK_DEBUG:-0}" = "1" ] && printf '[%s] stop-validator: %s\n' "$(date '+%H:%M:%S')" "$*" >> /tmp/sp-stop-validator-debug.log
}

# ---------------------------------------------------------------------------
# Read stdin
# ---------------------------------------------------------------------------
INPUT=$(cat)

debug_log "stdin=$INPUT"

# ---------------------------------------------------------------------------
# Extract fields from stdin JSON.
# Use jq when available; fall back to grep+cut (bash 3.2 compatible).
# ---------------------------------------------------------------------------
if command -v jq > /dev/null 2>&1; then
  STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // "false"' 2>/dev/null)
  TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
  LAST_MSG=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null)
else
  STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | grep -o '"stop_hook_active":[^,}]*' | head -1 | cut -d: -f2 | tr -d ' "')
  TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | grep -o '"transcript_path":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -z "$TRANSCRIPT_PATH" ] && TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | grep -o '"transcript_path": "[^"]*"' | head -1 | cut -d'"' -f4)
  SESSION_ID=$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -z "$SESSION_ID" ] && SESSION_ID=$(printf '%s' "$INPUT" | grep -o '"session_id": "[^"]*"' | head -1 | cut -d'"' -f4)
  LAST_MSG=$(printf '%s' "$INPUT" | grep -o '"last_assistant_message":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -z "$LAST_MSG" ] && LAST_MSG=$(printf '%s' "$INPUT" | grep -o '"last_assistant_message": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

debug_log "stop_hook_active=$STOP_HOOK_ACTIVE transcript=$TRANSCRIPT_PATH"

# ---------------------------------------------------------------------------
# Check 1: Loop prevention
# If stop_hook_active=true, we are already in a forced continuation triggered
# by a prior exit-2. Re-validating here would create an infinite loop.
# Exit 0 immediately.
# ---------------------------------------------------------------------------
case "$STOP_HOOK_ACTIVE" in
  true|True|TRUE|1)
    debug_log "decision=skip reason=stop_hook_active"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Check 2: Graceful degradation — missing transcript
# --no-session-persistence causes the transcript file to be absent. Treat as
# no-op rather than a fatal error.
# ---------------------------------------------------------------------------
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  debug_log "decision=skip reason=transcript_missing path=$TRANSCRIPT_PATH"
  exit 0
fi

# ---------------------------------------------------------------------------
# Check 3: Fast path
# If last_assistant_message contains neither the fence character (══) nor "?",
# none of the three validators apply. Skip expensive transcript parsing.
# ---------------------------------------------------------------------------
case "$LAST_MSG" in
  *"══"*|*"?"*)
    debug_log "fast_path=skip (has fence or question mark)"
    ;;
  *)
    debug_log "decision=pass reason=fast_path_clean"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Parse the transcript tail: collect assistant blocks since the most recent
# user message.
#
# The JSONL transcript has one record per line. Each record is a JSON object.
# We walk backwards from the end of the file, collecting lines until we hit
# a user-role message (which marks the start of the current turn).
#
# We extract two things:
#   TURN_TEXT — concatenated text content from assistant text blocks
#   HAS_AUQ   — whether an AskUserQuestion tool_use appears in the turn
# ---------------------------------------------------------------------------

TURN_TEXT=""
HAS_AUQ="false"

if command -v jq > /dev/null 2>&1; then
  # jq path: parse JSONL and extract current turn data
  # Walk backwards through all records, stopping at the last user message
  TURN_JSON=$(
    tac "$TRANSCRIPT_PATH" 2>/dev/null | awk '
      BEGIN { collecting=1 }
      {
        if (collecting) {
          # Stop at the first (reversed = most recent) user-role record we find
          # that is NOT a tool_result (tool_results are user-role but assistant-initiated)
          if (index($0, "\"role\":\"user\"") > 0 || index($0, "\"role\": \"user\"") > 0) {
            if (index($0, "\"type\":\"tool_result\"") == 0 && index($0, "\"type\": \"tool_result\"") == 0) {
              collecting=0
              next
            }
          }
          print
        }
      }
    '
  )

  # Newlines are preserved (no tr '\n' ' ' collapse) so the lib's
  # validate_auq_must_be_auq can scan line-by-line. Collapsing newlines made
  # the AUQ check inert for any prose question that wasn't the literal last
  # sentence of the response — see commit cc8b24e for the inlined-hook fix
  # and this matching standalone fix.
  TURN_TEXT=$(printf '%s\n' "$TURN_JSON" | jq -r 'select(.message.role=="assistant" or .role=="assistant") | (.message.content // .content // [])[] | select(.type=="text") | .text // empty' 2>/dev/null)
  HAS_AUQ_CHECK=$(printf '%s\n' "$TURN_JSON" | jq -r 'select(.message.role=="assistant" or .role=="assistant") | (.message.content // .content // [])[] | select(.type=="tool_use") | .name // empty' 2>/dev/null | grep -c "AskUserQuestion" 2>/dev/null)
  HAS_AUQ_CHECK="${HAS_AUQ_CHECK:-0}"
  [ "${HAS_AUQ_CHECK:-0}" -gt 0 ] 2>/dev/null && HAS_AUQ="true"
else
  # Fallback: grep-based extraction for systems without jq
  TURN_TEXT=$(
    tac "$TRANSCRIPT_PATH" 2>/dev/null | awk '
      BEGIN { collecting=1 }
      {
        if (collecting) {
          if (index($0, "\"role\":\"user\"") > 0 || index($0, "\"role\": \"user\"") > 0) {
            if (index($0, "\"type\":\"tool_result\"") == 0 && index($0, "\"type\": \"tool_result\"") == 0) {
              collecting=0
              next
            }
          }
          print
        }
      }
    ' | grep '"type":"text"' | grep -o '"text":"[^"]*"' | cut -d'"' -f4
  )

  AUQ_COUNT=$(
    tac "$TRANSCRIPT_PATH" 2>/dev/null | awk '
      BEGIN { collecting=1 }
      {
        if (collecting) {
          if (index($0, "\"role\":\"user\"") > 0 || index($0, "\"role\": \"user\"") > 0) {
            if (index($0, "\"type\":\"tool_result\"") == 0 && index($0, "\"type\": \"tool_result\"") == 0) {
              collecting=0
              next
            }
          }
          print
        }
      }
    ' | grep -c "AskUserQuestion" 2>/dev/null
  )
  AUQ_COUNT="${AUQ_COUNT:-0}"
  [ "${AUQ_COUNT:-0}" -gt 0 ] 2>/dev/null && HAS_AUQ="true"
fi

debug_log "turn_text_len=${#TURN_TEXT} has_auq=$HAS_AUQ"

# Use last_assistant_message as supplementary text if TURN_TEXT is sparse
# (can happen with no-jq fallback on complex JSONL)
if [ -z "$TURN_TEXT" ] && [ -n "$LAST_MSG" ]; then
  TURN_TEXT="$LAST_MSG"
fi

# ---------------------------------------------------------------------------
# Load shared validator logic
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_FILE="${SCRIPT_DIR}/lib/validators.sh"

if [ -f "$LIB_FILE" ]; then
  # shellcheck source=hooks/lib/validators.sh
  . "$LIB_FILE"
else
  # Inline a minimal fallback for distributed installs where lib/ may not
  # be present (the full logic is inlined in SKILL.md frontmatter anyway).
  debug_log "lib/validators.sh not found — using inline fallback"

  validate_auq_must_be_auq() {
    local text="$1" has_auq="${2:-false}"
    [ "$has_auq" = "true" ] && return 0
    local prose
    prose=$(printf '%s' "$text" | grep -v '^[[:space:]]*>' | grep -v '^[[:space:]]*```')
    if printf '%s' "$prose" | grep -qE '\?[[:space:]]*$'; then
      printf 'AUQ-must-be-AUQ violation: prose question detected without AskUserQuestion tool call. Wrap questions in AskUserQuestion instead of inline prose.\n'
      return 1
    fi
    return 0
  }

  validate_tool_availability() {
    local text="$1"
    local prose
    prose=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | grep -v '^[[:space:]]*>' | grep -v '^[[:space:]]*```')
    # First-person tool-access claim patterns ONLY (matches cc8b24e tightening
    # in lib/validators.sh and SKILL.md inlined hook). Broad substring matches
    # like "is available" / "detected" were removed because they false-positive
    # on common neutral phrases ("the harness is available", "Sonnet 4.6 is
    # available", "the API is unavailable").
    # Apostrophe in "don'\''t" is escaped via close-quote / literal / reopen.
    if printf '%s' "$prose" | grep -qE '(i can run |i can call |i have access to |i cannot access |i don'\''t have access|i'\''m able to run |i am able to run )'; then
      printf 'Tool-availability-claim violation: first-person tool-access claim without a verified call. Make the actual tool call first, then describe the result.\n'
      return 1
    fi
    return 0
  }

  validate_fence_write_coupling() {
    local text="$1" state_file="${2:-.claude/sp-state/last-prompt-writes.txt}" session_id="${3:-}"
    case "$text" in *"══ START 🟢 COPY ══"*) ;; *) return 0 ;; esac
    # Check whether the fence appears outside code blocks/blockquotes (R1.1 tightened selector)
    local fence_outside=0
    local in_code=0
    while IFS= read -r line; do
      case "$line" in '```'*) in_code=$(( 1 - in_code )); continue ;; esac
      [ "$in_code" -eq 0 ] && case "$line" in '>'*) continue ;; esac
      [ "$in_code" -eq 0 ] && case "$line" in *"══ START 🟢 COPY ══"*) fence_outside=1 ;; esac
    done <<FENCEEOF2
$text
FENCEEOF2
    [ "$fence_outside" -eq 0 ] && return 0
    if [ ! -f "$state_file" ] || [ ! -s "$state_file" ]; then
      printf 'Fence-write coupling violation: fence emitted but no Write to .handoffs/last-prompts/[N].md recorded. Write the prompt file before emitting the fence.\n'
      return 1
    fi
    if [ -n "$session_id" ]; then
      grep -q "^${session_id}" "$state_file" 2>/dev/null || {
        printf 'Fence-write coupling violation: fence emitted but no matching session write to .handoffs/last-prompts/[N].md. Write the prompt file before emitting the fence.\n'
        return 1
      }
    fi
    return 0
  }
fi

# ---------------------------------------------------------------------------
# Run the three validators
# ---------------------------------------------------------------------------
VIOLATION=""

# 3a: AUQ-must-be-AUQ (always-on)
msg=$(validate_auq_must_be_auq "$TURN_TEXT" "$HAS_AUQ") || VIOLATION="$msg"

# 3b: Tool-availability claims (always-on)
if [ -z "$VIOLATION" ]; then
  msg=$(validate_tool_availability "$TURN_TEXT") || VIOLATION="$msg"
fi

# 3c: Fence-write coupling (fence-conditional)
if [ -z "$VIOLATION" ]; then
  msg=$(validate_fence_write_coupling "$TURN_TEXT" "$STATE_FILE" "$SESSION_ID") || VIOLATION="$msg"
fi

# ---------------------------------------------------------------------------
# Report result
# ---------------------------------------------------------------------------
if [ -n "$VIOLATION" ]; then
  debug_log "decision=BLOCK violation=$VIOLATION"
  printf '\n[SP Stop Validator] Response blocked — structural rule violation:\n\n%s\n\nPlease revise your response to satisfy the rule before completing your turn.\n' "$VIOLATION" >&2
  exit 2
fi

debug_log "decision=pass"
exit 0
