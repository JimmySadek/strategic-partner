#!/usr/bin/env bash
# hooks/lib/validators.sh — Shared validator logic for Layer 3 (release-time
# transcript lint).
#
# Source this file to get the three validator functions:
#
#   validate_auq_must_be_auq       <text_block> [has_auq_in_turn]
#   validate_tool_availability     <text_block>
#   validate_fence_write_coupling  <text_block> [tool_use_records]
#
# Each function returns:
#   0 — check passes (no violation detected)
#   1 — violation detected; violation description written to stdout
#
# "text_block" is the concatenated text content of the assistant turn
# (tool_use blocks excluded — this is purely the prose emitted by the
# assistant). Callers are responsible for assembling this from the
# transcript or last_assistant_message field.
#
# "tool_use_records" (fence-write coupling only) is a multi-line string
# carrying one record per line in "<tool_name>\t<file_path>" form,
# extracted from the same turn's tool_use entries. v5.14.0 retired the
# state-file evidence model in favour of this tool-call trace.
#
# Scope rules per synthesis Rev 3:
#   - AUQ-must-be-AUQ: ALWAYS-ON (runs regardless of fence presence)
#   - Tool-availability claims: ALWAYS-ON
#   - Fence-write coupling: FENCE-CONDITIONAL (only when fence detected)

set -u

# ---------------------------------------------------------------------------
# Helper: strip content inside markdown code blocks and blockquotes.
# Used so that fenced code examples and quoted text don't trigger validators.
# Strips lines beginning with ">", and multi-line ``` blocks.
# ---------------------------------------------------------------------------
_strip_non_prose() {
  local text="$1"
  local in_code=0
  local result=""

  while IFS= read -r line; do
    # Toggle code-block state on ``` fence lines
    case "$line" in
      '```'*) in_code=$(( 1 - in_code )); continue ;;
    esac
    # Skip lines inside code blocks
    [ "$in_code" -eq 1 ] && continue
    # Skip blockquote lines (begin with ">")
    case "$line" in
      '>'*) continue ;;
    esac
    result="${result}${line}
"
  done <<EOF
$text
EOF

  printf '%s' "$result"
}

# ---------------------------------------------------------------------------
# Check 1: AUQ-must-be-AUQ (always-on)
#
# Detects sentence-final "?" in prose that is NOT immediately followed by
# an AskUserQuestion tool-use block in the same turn.
#
# This function works on the prose-only text extracted from the turn.
# The caller strips AUQ tool_use blocks from the input before calling —
# if AUQ is present in the turn, the "?" that belongs to AUQ options is
# removed with those blocks. What remains is prose-only questions.
#
# Exempt patterns (do NOT flag):
#   - Lines ending with "?" inside code blocks or blockquotes (stripped above)
#   - Lines that are entirely a rhetorical fragment ("What does this mean?")
#     immediately followed by an answer on the next non-empty line
#   - AUQ option text already stripped by caller
#
# Returns: 0=pass, 1=violation (violation text on stdout)
# ---------------------------------------------------------------------------
validate_auq_must_be_auq() {
  local text="$1"
  local has_auq_in_turn="${2:-false}"

  # Strip non-prose content before analysing
  local prose
  prose=$(_strip_non_prose "$text")

  # Look for sentence-final "?" in prose lines
  local found_question=0
  local question_line=""

  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    # Check if line ends with "?" (allowing trailing whitespace)
    trimmed=$(printf '%s' "$line" | sed 's/[[:space:]]*$//')
    case "$trimmed" in
      *\?)
        found_question=1
        question_line="$trimmed"
        break
        ;;
    esac
  done <<EOF
$prose
EOF

  if [ "$found_question" -eq 1 ] && [ "$has_auq_in_turn" != "true" ]; then
    printf 'AUQ-must-be-AUQ violation: prose question detected without AskUserQuestion tool call in same turn. Question: "%s" — Refactor: wrap the question in an AskUserQuestion tool call instead of inline prose.\n' "$question_line"
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Check 2: Tool-availability claims (always-on)
#
# Detects text patterns asserting tool presence/absence without a
# corresponding actual tool call. Examples:
#   "I can run X" / "I can call Y" / "I have access to Z"
#   "X is available" / "X is not available" / "X is unavailable"
#   "X detected" / "X not detected"
#
# The has_tool_calls argument is a space-separated list of tool names
# that were ACTUALLY called in the current turn (provided by the caller
# from transcript analysis). If the text claims a tool is available/
# unavailable but no call for it was made, flag it.
#
# Returns: 0=pass, 1=violation (violation text on stdout)
# ---------------------------------------------------------------------------
validate_tool_availability() {
  local text="$1"

  local prose
  prose=$(_strip_non_prose "$text")

  # Patterns to detect unverified tool-availability claims
  local violation_found=0
  local violation_line=""

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Strip inline backtick-quoted spans (e.g. `"i have access to "`) before
    # matching. _strip_non_prose already removed multi-line ``` blocks; this
    # handles the remaining false-positive surface: backtick-quoted code
    # references inside prose lines that happen to contain one of the
    # first-person patterns (e.g. meta-discussion of the validator's own
    # pattern set).
    line=$(printf '%s' "$line" | sed 's/`[^`]*`//g')
    # Match first-person tool-access claim patterns ONLY (case-insensitive via tr).
    # Broad substring matches like "is available" / "detected" were removed
    # because they false-positive on common neutral phrases ("the harness is
    # available", "the API is unavailable", "Sonnet 4.6 is available", etc.).
    # The intent of this check is to catch the model claiming "I have access
    # to X" without a verifying tool call.
    lower=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
      *"i can run "* | *"i can call "* | *"i have access to "* | \
      *"i cannot access "* | *"i don't have access"* | \
      *"i'm able to run "* | *"i am able to run "*)
        violation_found=1
        violation_line="$line"
        break
        ;;
    esac
  done <<EOF
$prose
EOF

  if [ "$violation_found" -eq 1 ]; then
    printf 'Tool-availability-claim violation: first-person tool-access claim without a verified call. Line: "%s" — Fix: make the actual tool call first, then describe the result. Never infer availability from indirect signals.\n' "$violation_line"
    return 1
  fi

  return 0
}

# ---------------------------------------------------------------------------
# Helper: detect whether a line is a fence marker inside a markdown code block
# (i.e., the fence characters appear inside a ``` block, meaning they are
# being shown as an example rather than emitted as actual fences).
# Used by validate_fence_write_coupling for Rev 3 R1.1 tightened selector.
# ---------------------------------------------------------------------------
_is_fence_in_code_block() {
  local text="$1"
  local target_fence="══ START 🟢 COPY ══"
  local in_code=0
  local found_in_code=0

  while IFS= read -r line; do
    case "$line" in
      '```'*)
        in_code=$(( 1 - in_code ))
        continue
        ;;
    esac
    if [ "$in_code" -eq 1 ]; then
      case "$line" in
        *"$target_fence"*)
          found_in_code=1
          break
          ;;
      esac
    fi
  done <<EOF
$text
EOF

  return $(( 1 - found_in_code ))  # 0 = found in code block; 1 = not found in code block
}

# ---------------------------------------------------------------------------
# Check 3: Fence-write coupling (fence-conditional)
#
# If a real "══ START 🟢 COPY ══" fence is present in the text (i.e., NOT
# inside a markdown code block, NOT inside a blockquote, NOT commentary
# about a prior fence emission), verify that the same turn contains a
# Write/Edit/MultiEdit tool_use record targeting .handoffs/last-prompts/[N].md.
#
# Rev 3 R1.1 tightened fence selector — skip fences that are:
#   1. Inside markdown code blocks (shown as examples, not real fences)
#   2. Inside blockquotes ("> ══ START…" — commentary about fences)
#   3. In text that is explicitly describing a prior fence emission
#      (heuristic: line contains "emitted" or "above" within 2 lines of fence)
#
# v5.14.0 evidence model — tool-call trace.
#   The earlier evidence model (PostToolUse-tracked state file at
#   .claude/sp-state/last-prompt-writes.txt) was retired with Layer 2.
#   The replacement: callers pass the tool_use records from the same turn
#   as a multi-line string. The function scans those records for at least
#   one matching the prompt-file pattern.
#
# Arguments:
#   text              — assistant turn text (prose with fence markers)
#   tool_use_records  — multi-line string; one record per line in the form
#                       "<tool_name>\t<file_path>". Empty string is treated
#                       as no evidence (fail-closed when a real fence is found).
#                       Callers pass the empty string when they have no JSONL
#                       transcript context (e.g., markdown-file lint), in which
#                       case they apply their own textual proxy check separately.
#
# Returns: 0=pass, 1=violation (violation text on stdout)
# ---------------------------------------------------------------------------
validate_fence_write_coupling() {
  local text="$1"
  local tool_use_records="${2:-}"

  local fence_marker="══ START 🟢 COPY ══"

  # Fast path: no fence marker in text at all
  case "$text" in
    *"$fence_marker"*) ;;
    *) return 0 ;;
  esac

  # Apply R1.1 tightened selector: skip if fence only appears in code blocks
  # or blockquotes.
  local real_fence_found=0
  local in_code=0
  local prev_line=""
  local prev2_line=""

  while IFS= read -r line; do
    case "$line" in
      '```'*)
        in_code=$(( 1 - in_code ))
        prev2_line="$prev_line"
        prev_line="$line"
        continue
        ;;
    esac

    # Skip lines in code blocks (shown as examples)
    if [ "$in_code" -eq 1 ]; then
      prev2_line="$prev_line"
      prev_line="$line"
      continue
    fi

    # Skip blockquote lines
    case "$line" in
      '>'*)
        prev2_line="$prev_line"
        prev_line="$line"
        continue
        ;;
    esac

    # Check for fence marker
    case "$line" in
      *"$fence_marker"*)
        # R1.1 condition 3: commentary about a prior fence emission.
        # Heuristic: if the surrounding 2 lines contain "emitted", "above",
        # "previous", "prior", "example" — treat as commentary, not real fence.
        local context="${prev2_line}${prev_line}${line}"
        case "$context" in
          *emitted*|*" above"*|*previous*|*prior*|*example*|*"the fence"*)
            # Skip — this is commentary about a fence, not an actual fence emission
            ;;
          *)
            real_fence_found=1
            break
            ;;
        esac
        ;;
    esac

    prev2_line="$prev_line"
    prev_line="$line"
  done <<EOF
$text
EOF

  # No real fence found after applying the tightened selector
  [ "$real_fence_found" -eq 0 ] && return 0

  # Real fence found — scan tool_use records for a matching Write/Edit/MultiEdit
  # to .handoffs/last-prompts/[N].md.
  local found_write=0
  if [ -n "$tool_use_records" ]; then
    while IFS=$'\t' read -r record_tool record_path; do
      [ -z "$record_tool" ] && continue
      case "$record_tool" in
        Write|Edit|MultiEdit) ;;
        *) continue ;;
      esac
      case "$record_path" in
        *.handoffs/last-prompts/[0-9]*.md|*/.handoffs/last-prompts/[0-9]*.md)
          found_write=1
          break
          ;;
      esac
    done <<EOF
$tool_use_records
EOF
  fi

  if [ "$found_write" -eq 0 ]; then
    printf 'Fence-write coupling violation: "══ START 🟢 COPY ══" fence emitted but no matching Write/Edit/MultiEdit to .handoffs/last-prompts/[N].md was recorded in the same turn. Write the prompt file first, then emit the fence.\n'
    return 1
  fi

  return 0
}
