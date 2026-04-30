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
    # Strip inline quoted spans before matching to suppress false positives from
    # meta-discussion quoting the validator's own pattern set. Three forms are
    # handled, in order (italic-quoted MUST precede plain-quoted so the inner
    # quotes are consumed before the surrounding asterisks become residue):
    #   1. Backtick-wrapped:   `...`         e.g. `"i have access to"`
    #   2. Italic-quoted:      *"..."*        e.g. *"I can run the bash command"*
    #   3. Plain double-quoted: "..."         e.g. "I have access to the database"
    # _strip_non_prose already removed multi-line ``` blocks; these patterns
    # handle the remaining false-positive surface within prose lines.
    line=$(printf '%s' "$line" | sed 's/`[^`]*`//g; s/\*"[^"]*"\*//g; s/"[^"]*"//g')
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

# ---------------------------------------------------------------------------
# Check 5: Identity-reset announcement (always-on when prev user had dispatch)
#
# Mirrors SKILL.md Stop rule 2 (`identity-reset-announcement`). When the
# previous user-side record contained a tool_result for an Agent or Task
# tool_use (i.e., a background dispatch returned), the assistant's next
# turn MUST contain one of two reset phrases:
#
#   "Back in advisory mode"
#   "Dispatch complete. I am back in strategic-partner mode."
#
# The Stop rule catches this in real time per turn. This validator is the
# release-time backstop — it catches the same pattern in the transcript
# lint, redundant detection mirroring how AUQ-must-be-AUQ is enforced both
# at runtime (Stop rule 1) and at release time (validate_auq_must_be_auq).
#
# Arguments:
#   text                       — assistant turn text (prose)
#   prev_user_had_dispatch     — "true" if the prior user record contained
#                                a tool_result for an Agent/Task tool_use
#
# Returns: 0=pass (or check inapplicable — no prior dispatch), 1=violation
# ---------------------------------------------------------------------------
validate_identity_reset() {
  local text="$1"
  local prev_user_had_dispatch="${2:-false}"

  # Check inapplicable when the previous user record did not contain a
  # tool_result for an Agent/Task tool_use.
  [ "$prev_user_had_dispatch" != "true" ] && return 0

  # Look for either reset phrase. The Stop rule's regex:
  #   'Back in advisory mode|Dispatch complete\. I am back in strategic-partner mode'
  # We match the same patterns here as plain substrings to avoid regex-engine
  # quirks across bash versions.
  case "$text" in
    *"Back in advisory mode"*|*"Dispatch complete. I am back in strategic-partner mode"*)
      return 0
      ;;
  esac

  printf 'Identity-reset announcement violation: previous user record contained an Agent/Task tool_result, but assistant turn does not include "Back in advisory mode" or "Dispatch complete. I am back in strategic-partner mode." phrase. Add the reset phrase at the start of the turn so the user knows the SP has resumed advisory mode.\n'
  return 1
}

# ---------------------------------------------------------------------------
# Check 4: Voice patterns (release-time, mechanical)
#
# Scans prose content for jargon-loaded patterns that violate the User-Facing
# Voice Rules in CLAUDE.md. Single source of truth for the regex set —
# tests/lint-voice.sh (static-file scanner) and tests/lint-transcripts.sh
# (transcript scanner) both call this helper instead of inlining the patterns.
#
# Six mechanical patterns, each emitting a per-violation line on stdout:
#
#   1. FUNCTION-CALL-IN-PROSE    — \w+_\w+\(\) function-call notation
#   2. INCIDENT-ID-IN-PROSE      — INC-YYYY-MM-DD incident IDs
#   3. DIRECTION-REF             — Direction N internal references
#   4. LAYER-REF                 — Layer N internal references
#   5. RAW-LINE-REF              — line N raw line references
#   6. DELIVERABLE-REF           — deliverable N internal references
#
# The DELIVERABLE-REF pattern is case-sensitive on the lowercase form only.
# A capitalised "Deliverable 1" in a section header is legitimate ceremony,
# whereas the lowercase "deliverable 5" in prose is internal jargon.
#
# Code-block awareness: lines inside ``` fences and lines starting with ">"
# are skipped (matches _strip_non_prose semantics, but with line numbers
# preserved so the violation reports the original line).
#
# Skip-block awareness: <!-- voice-lint:skip-start --> ... skip-end markers
# suppress scanning for an inline range. Useful for sections that legitimately
# use internal vocabulary (file trees, architecture details).
#
# Each violation is emitted on stdout in the format:
#   <file_path>:<line>: <TYPE>: <description>
#
# Args:
#   text          — content to scan (multi-line string)
#   file_path     — file identifier used in the violation prefix
#   display_line  — optional: override every reported line number with this
#                   single value (used by transcript callers where within-text
#                   line numbers don't map back to the source file). When
#                   omitted, violations report the actual within-text line.
#
# Returns: 0=clean, 1=one or more violations found
# ---------------------------------------------------------------------------
validate_voice_patterns() {
  local text="$1"
  local file_path="${2:-?}"
  local display_line="${3:-}"
  local in_code=0
  local in_skip=0
  local lineno=0
  local found_violation=0
  local report_line
  local match

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$(( lineno + 1 ))

    # Skip-block toggle (HTML comment markers)
    case "$line" in
      *"voice-lint:skip-start"*) in_skip=1; continue ;;
      *"voice-lint:skip-end"*)   in_skip=0; continue ;;
    esac
    [ "$in_skip" -eq 1 ] && continue

    # Code-block toggle
    case "$line" in
      '```'*) in_code=$(( 1 - in_code )); continue ;;
    esac
    [ "$in_code" -eq 1 ] && continue

    # Blockquote skip
    case "$line" in
      '>'*) continue ;;
    esac

    if [ -n "$display_line" ]; then
      report_line="$display_line"
    else
      report_line="$lineno"
    fi

    # ---- Pattern 1: FUNCTION-CALL-IN-PROSE — word_with_underscore() ----
    if [[ "$line" =~ ([a-zA-Z][a-zA-Z0-9_]*_[a-zA-Z0-9_]+\(\)) ]]; then
      match="${BASH_REMATCH[1]}"
      printf '%s:%s: FUNCTION-CALL-IN-PROSE: function-call notation "%s" appears in user-facing prose. Describe what it does in plain English instead.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Pattern 2: INCIDENT-ID-IN-PROSE — INC-YYYY-MM-DD ----
    if [[ "$line" =~ (INC-[0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
      match="${BASH_REMATCH[1]}"
      printf '%s:%s: INCIDENT-ID-IN-PROSE: incident ID "%s" appears without explanation. Reference incidents by what happened, not by ID — the ID belongs in claudedocs/INCIDENTS.md only.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Pattern 3: DIRECTION-REF — Direction N ----
    if [[ "$line" =~ (Direction[[:space:]]+[0-9]+) ]]; then
      match="${BASH_REMATCH[1]}"
      printf '%s:%s: DIRECTION-REF: internal direction reference "%s" appears in user-facing prose. Replace with a plain-English description of the direction.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Pattern 4: LAYER-REF — Layer N ----
    if [[ "$line" =~ (Layer[[:space:]]+[0-9]+) ]]; then
      match="${BASH_REMATCH[1]}"
      printf '%s:%s: LAYER-REF: internal layer reference "%s" appears in user-facing prose without a gloss. Describe what the layer does ("the release-time check that..."), not its number.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Pattern 5: RAW-LINE-REF — line N (or line ~N) ----
    if [[ "$line" =~ (^|[^a-zA-Z])(line[[:space:]]+~?[0-9]+) ]]; then
      match="${BASH_REMATCH[2]}"
      printf '%s:%s: RAW-LINE-REF: raw line reference "%s" appears in user-facing prose. Line numbers belong in commit messages and PR descriptions, not in CHANGELOG/README/commands.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Pattern 6: DELIVERABLE-REF — deliverable N (lowercase only) ----
    # Case-sensitive: "Deliverable 1" in a section header is legitimate
    # ceremony; "deliverable 5" in prose is internal jargon. Bash regex is
    # case-sensitive by default, so the lowercase pattern only matches the
    # jargon form.
    if [[ "$line" =~ (deliverable[[:space:]]+[0-9]+) ]]; then
      match="${BASH_REMATCH[1]}"
      printf '%s:%s: DELIVERABLE-REF: internal deliverable reference "%s" appears in user-facing prose. Describe what the work item is in plain English instead of citing it by number.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi
  done <<EOF
$text
EOF

  [ "$found_violation" -eq 1 ] && return 1
  return 0
}
