#!/usr/bin/env bash
# tests/lint-transcripts.sh — Layer 3: release-time transcript lint backstop.
#
# Scans .handoffs/*.md files and (if accessible) the Claude project JSONL
# transcripts since the last release tag, then runs structural checks per
# Rev 3 lint scope split (synthesis-voice-verification-0428.md R1.5 + R3):
#
# ALWAYS-ON CHECKS (every assistant response):
#   - AUQ-must-be-AUQ: user-directed prose questions outside AskUserQuestion
#     tool-use blocks (with rhetorical-question exemption)
#   - Tool-availability claims: first-person tool-access claims without a
#     verified tool call ("I can run X", "I have access to Y", etc.)
#
# FENCE-CONDITIONAL CHECKS (only for responses containing ══ START 🟢 COPY ══):
#   - Classify fence per Rev 3 three-step discriminator:
#       Step 1: locate command line (through optional backtick wrapper)
#       Step 2: classify by command pattern
#               /strategic-partner <handoffs-file> → handoff continuation
#               /<any-skill> or /strategic-partner (with body) → implementation prompt
#               empty / unrecognized → documentation (skip gate)
#       Step 3: apply class-specific gate
#               implementation prompt → verify 13-row Post-Craft Verification table
#                                        preceding AND corresponding last-prompts write
#               handoff continuation → verify Closure evidence ledger preceding
#               documentation → skip
#
# Exit codes:
#   0 — all checked files pass (or no files to check)
#   1 — one or more violations found; violation summary printed
#
# Output format: per-violation line:
#   <file>:<line>: <TYPE>: <description>
# for grep-ability and CI integration.
#
# Usage:
#   bash tests/lint-transcripts.sh
#   bash tests/lint-transcripts.sh --since vX.Y.Z   # override release tag
#   bash tests/lint-transcripts.sh --all             # ignore last-tag filter

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_FILE="${SCRIPT_DIR}/hooks/lib/validators.sh"

# ---------------------------------------------------------------------------
# Load shared validator logic
# ---------------------------------------------------------------------------
if [ -f "$LIB_FILE" ]; then
  # shellcheck source=hooks/lib/validators.sh
  . "$LIB_FILE"
else
  printf 'ERROR: hooks/lib/validators.sh not found at %s\n' "$LIB_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Rev 3 fence discriminator — three-step classification
#
# classify_fence_in_text <text>
#
# Extracts the ══ fence body from <text>, then applies:
#   Step 1: locate command line (through optional backtick wrapper)
#   Step 2: classify by command pattern
#   Step 3: emit class name on stdout
#
# Outputs one of:
#   implementation_prompt   — skill command found; 13-row table + write required
#   handoff_continuation    — /strategic-partner <handoffs-file> pattern
#   documentation           — empty or unrecognized command line; skip gate
#
# Returns 0 always (classification, not pass/fail).
# ---------------------------------------------------------------------------
classify_fence_in_text() {
  local text="$1"
  local fence_start="══ START 🟢 COPY ══"
  local fence_end="══ END 🛑 COPY ══"

  # Extract content between fence markers
  local in_fence=0
  local fence_body=""
  while IFS= read -r line; do
    case "$line" in
      *"$fence_start"*)
        in_fence=1
        continue
        ;;
      *"$fence_end"*)
        in_fence=0
        break
        ;;
    esac
    if [ "$in_fence" -eq 1 ]; then
      fence_body="${fence_body}${line}
"
    fi
  done <<EOF
$text
EOF

  # Step 1: locate command line through optional backtick wrapper
  local command_line=""
  local in_backtick_wrapper=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Check for backtick wrapper opener (three or more backticks)
    # Check for backtick wrapper (any line starting with three or more backticks)
    case "$line" in
      '```'*)
        if [ "$in_backtick_wrapper" -eq 0 ]; then
          in_backtick_wrapper=1
          continue
        else
          # Closing backtick — stop
          break
        fi
        ;;
    esac
    # First non-empty, non-backtick line is the command line
    command_line="$line"
    break
  done <<EOF
$fence_body
EOF

  # Step 2: classify by command pattern
  # Trim leading/trailing whitespace from command_line
  command_line=$(printf '%s' "$command_line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

  if [ -z "$command_line" ]; then
    # Empty command line = documentation example
    printf 'documentation'
    return 0
  fi

  # Handoff continuation: /strategic-partner followed by a .handoffs/ path
  case "$command_line" in
    /strategic-partner\ .handoffs/*|/strategic-partner\ "'.handoffs/"*)
      printf 'handoff_continuation'
      return 0
      ;;
  esac

  # Implementation prompt: any skill command line starting with /
  case "$command_line" in
    /*)
      printf 'implementation_prompt'
      return 0
      ;;
  esac

  # Unrecognized — treat as documentation (skip gate)
  printf 'documentation'
  return 0
}

# ---------------------------------------------------------------------------
# Verify Post-Craft Verification table precedes the fence in <text>
#
# check_postcraft_table_preceding <text> <fence_line_number>
#
# Looks for a markdown table with a "Verification" or "Post-Craft" header
# (case-insensitive) in the content before the fence. Uses a heuristic:
# a table row containing "Pass" or "Fail" appearing before the fence.
#
# Returns: 0=found (pass), 1=not found (violation)
# ---------------------------------------------------------------------------
check_postcraft_table_preceding() {
  local text="$1"
  local fence_marker="══ START 🟢 COPY ══"

  # Extract text before the fence
  local before_fence=""
  while IFS= read -r line; do
    case "$line" in
      *"$fence_marker"*) break ;;
    esac
    before_fence="${before_fence}${line}
"
  done <<EOF
$text
EOF

  # Look for Post-Craft Verification section header (H2 or H3) or a
  # table row with Pass/Fail columns — indicating the 13-row table.
  case "$before_fence" in
    *"Post-Craft Verification"*|*"post-craft verification"*)
      return 0
      ;;
  esac

  # Fallback: look for a markdown table with Pass/Fail entries in ≥5 rows
  # (a 13-row table will certainly have more than 5 pipe-delimited rows).
  local table_rows=0
  while IFS= read -r line; do
    case "$line" in
      *'|'*Pass*'|'*|*'|'*Fail*'|'*|*'|'*pass*'|'*|*'|'*fail*'|'*)
        table_rows=$(( table_rows + 1 ))
        ;;
    esac
  done <<EOF
$before_fence
EOF

  [ "$table_rows" -ge 5 ] && return 0

  return 1
}

# ---------------------------------------------------------------------------
# Verify Closure evidence ledger precedes the fence in <text>
#
# check_closure_ledger_preceding <text>
#
# Looks for a closure ledger indicator before the fence. The ledger has
# rows with state labels (RESOLVED, DECISION, SKIPPED, RESOLVED-AUTO, etc.)
# and a verification command per row — a structural pattern specific to
# closure handoff continuations.
#
# Returns: 0=found (pass), 1=not found (violation)
# ---------------------------------------------------------------------------
check_closure_ledger_preceding() {
  local text="$1"
  local fence_marker="══ START 🟢 COPY ══"

  # Extract text before the fence
  local before_fence=""
  while IFS= read -r line; do
    case "$line" in
      *"$fence_marker"*) break ;;
    esac
    before_fence="${before_fence}${line}
"
  done <<EOF
$text
EOF

  # Look for closure ledger indicators — state labels combined with a ledger
  # layer label to avoid false positives from generic "RESOLVED" usage.
  # Check each state label individually (avoids SC2221/SC2222 pattern override).
  local has_state_label=0
  case "$before_fence" in
    *"RESOLVED"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"DECISION"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"SKIPPED"*) has_state_label=1 ;;
  esac

  if [ "$has_state_label" -eq 1 ]; then
    # Require at least one ledger-layer-specific label to confirm it's a closure ledger
    case "$before_fence" in
      *"Serena"*|*"CLAUDE.md"*|*"findings"*|*"backlog"*|*"\.handoffs"*|*"Git"*)
        return 0
        ;;
    esac
  fi

  # Also accept explicit "Closure evidence ledger" or "Closure Checklist"
  case "$before_fence" in
    *"Closure evidence ledger"*|*"closure evidence ledger"*|*"Closure Checklist"*|*"closure checklist"*)
      return 0
      ;;
  esac

  return 1
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
SINCE_TAG=""
CHECK_ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE_TAG="$2"; shift 2 ;;
    --all)   CHECK_ALL=1; shift ;;
    *)       shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Determine the last release tag (for filtering .handoffs/*.md by mtime)
# ---------------------------------------------------------------------------
LAST_TAG_DATE=""
if [ "$CHECK_ALL" -eq 0 ]; then
  if [ -n "$SINCE_TAG" ]; then
    LAST_TAG_DATE=$(git -C "$SCRIPT_DIR" log -1 --format='%ai' "$SINCE_TAG" 2>/dev/null)
  else
    LAST_TAG=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$LAST_TAG" ]; then
      LAST_TAG_DATE=$(git -C "$SCRIPT_DIR" log -1 --format='%ai' "$LAST_TAG" 2>/dev/null)
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Helper: collect .handoffs/*.md files (modified since last tag if filtering)
# ---------------------------------------------------------------------------
collect_handoff_files() {
  local handoffs_dir="${SCRIPT_DIR}/.handoffs"
  [ -d "$handoffs_dir" ] || return 0

  if [ "$CHECK_ALL" -eq 1 ] || [ -z "$LAST_TAG_DATE" ]; then
    find "$handoffs_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null
  else
    # Find files newer than the last release tag
    find "$handoffs_dir" -maxdepth 1 -name "*.md" -type f -newer /dev/null 2>/dev/null | while read -r f; do
      # Compare mtime against tag date using ls and sort (bash 3.2 compatible)
      # Use git log --since for files tracked in git
      if git -C "$SCRIPT_DIR" log --since="$LAST_TAG_DATE" --name-only --pretty="" -- "$f" 2>/dev/null | grep -q .; then
        printf '%s\n' "$f"
      elif [ ! -f "$f" ]; then
        : # skip
      else
        # For untracked files, use find's own -newer against a reference file
        # created at tag date — not available, so include all untracked .md
        printf '%s\n' "$f"
      fi
    done
  fi
}

# ---------------------------------------------------------------------------
# Helper: collect JSONL transcript files since last tag
# ---------------------------------------------------------------------------
collect_jsonl_files() {
  # Project JSONL transcripts live at:
  #   ~/.claude/projects/<encoded-cwd>/*.jsonl
  local cwd_encoded
  cwd_encoded=$(printf '%s' "$SCRIPT_DIR" | tr '/' '-' | tr '.' '-')
  local transcript_dir="${HOME}/.claude/projects/${cwd_encoded}"

  [ -d "$transcript_dir" ] || return 0

  if [ "$CHECK_ALL" -eq 1 ] || [ -z "$LAST_TAG_DATE" ]; then
    find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null
  else
    find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | while read -r f; do
      # JSONL files have session timestamps in their records; use file mtime
      # as a proxy (close enough for release-time gating).
      # Use find -newer with a temp reference file at the tag date.
      # Simpler: use stat + date comparison via python if available.
      if command -v python3 > /dev/null 2>&1; then
        FILE_MTIME=$(python3 -c "import os; print(int(os.path.getmtime('$f')))" 2>/dev/null || echo "0")
        TAG_EPOCH=$(python3 -c "import datetime, calendar; t=datetime.datetime.fromisoformat('${LAST_TAG_DATE}'); print(int(calendar.timegm(t.timetuple())))" 2>/dev/null || echo "0")
        [ "$FILE_MTIME" -gt "$TAG_EPOCH" ] && printf '%s\n' "$f"
      else
        # No python3: include all (conservative — may flag pre-release sessions)
        printf '%s\n' "$f"
      fi
    done
  fi
}

# ---------------------------------------------------------------------------
# Lint a single .handoffs/*.md file
#
# These are markdown files containing session notes, handoff prompts, and
# SP-to-Claude communication. They may contain fence emissions, questions,
# and tool-availability claims that need to be checked.
#
# Returns violations on stdout in the format: <file>:<line>: <TYPE>: <desc>
# ---------------------------------------------------------------------------
lint_markdown_file() {
  local file="$1"
  local violations=""
  local lineno=0

  # Skip files over 100KB — these are typically Codex output files or
  # reference documents, not SP-emitted session transcripts. Shell string
  # processing of multi-hundred-KB files is prohibitively slow and these
  # files are not SP output to be validated.
  local file_size
  file_size=$(wc -c < "$file" 2>/dev/null || echo "0")
  if [ "$file_size" -gt 102400 ]; then
    return 0
  fi

  # Read the file content
  local content
  content=$(cat "$file" 2>/dev/null) || return 0

  # Accumulate full text for validator calls
  local full_text="$content"

  # Check 1: AUQ-must-be-AUQ (always-on)
  # For markdown files, we approximate "AUQ present in turn" by checking
  # whether the file contains an AskUserQuestion reference.
  local has_auq="false"
  case "$content" in *"AskUserQuestion"*) has_auq="true" ;; esac

  local msg
  msg=$(validate_auq_must_be_auq "$full_text" "$has_auq") || {
    # Find the line number of the violating "?"
    lineno=$(grep -n '\?[[:space:]]*$' "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$lineno" ] && lineno="?"
    printf '%s:%s: AUQ: %s\n' "$file" "$lineno" "$msg"
    violations="${violations}1"
  }

  # Check 2: Tool-availability claims (always-on)
  msg=$(validate_tool_availability "$full_text") || {
    lineno=$(grep -in 'i can run \|i can call \|i have access to \|is available\|is not available\|is unavailable\|not detected\|i cannot access ' "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$lineno" ] && lineno="?"
    printf '%s:%s: TOOL-CLAIM: %s\n' "$file" "$lineno" "$msg"
    violations="${violations}1"
  }

  # Check 3: Fence-conditional checks (Rev 3 lint scope split)
  # Apply only when file contains a real ══ fence marker (not in code blocks).
  # Use Rev 3 three-step discriminator to classify the fence, then apply
  # class-specific gate.
  local has_real_fence=0
  case "$content" in
    *"══ START 🟢 COPY ══"*)
      # Check via existing lib helper whether this is a real fence (not in code block)
      msg=$(validate_fence_write_coupling "$content" "/nonexistent-no-state-file" "")
      # If validate_fence_write_coupling passes (returns 0), it means either:
      #   a) no real fence detected (false — we know content has the marker)
      #   b) fence in code block (R1.1 tightened selector skipped it)
      # We need to know if it's a real fence. Use the return code differently:
      # validate_fence_write_coupling returns 1 (violation) if real fence + no state file.
      # So if it returns 0 here, fence is inside code block / blockquote.
      if ! msg=$(validate_fence_write_coupling "$content" "/nonexistent-no-state-file" "") 2>/dev/null; then
        has_real_fence=1
      fi
      ;;
  esac

  if [ "$has_real_fence" -eq 1 ]; then
    local fence_class
    fence_class=$(classify_fence_in_text "$content")
    local fence_line
    fence_line=$(grep -n "══ START 🟢 COPY ══" "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$fence_line" ] && fence_line="?"

    case "$fence_class" in
      implementation_prompt)
        # Gate: 13-row Post-Craft Verification table must precede fence
        if ! check_postcraft_table_preceding "$content"; then
          printf '%s:%s: FENCE-IMPL: implementation-prompt fence emitted without a preceding Post-Craft Verification table (13-row pass/fail table required before ══ fence per SKILL.md protocol).\n' "$file" "$fence_line"
          violations="${violations}1"
        fi
        # Gate: .handoffs/last-prompts/ write must be referenced in preceding context
        local start_lnum=$(( fence_line - 80 ))
        [ "$start_lnum" -lt 1 ] && start_lnum=1
        local context_block
        context_block=$(sed -n "${start_lnum},${fence_line}p" "$file" 2>/dev/null)
        case "$context_block" in
          *"last-prompts/"*)
            : # write reference found — pass
            ;;
          *)
            printf '%s:%s: FENCE-WRITE: implementation-prompt fence emitted without visible .handoffs/last-prompts/ write reference in preceding %d lines. A Write to .handoffs/last-prompts/[N].md must precede fence emission per SKILL.md Layer 1 protocol.\n' "$file" "$fence_line" "80"
            violations="${violations}1"
            ;;
        esac
        ;;
      handoff_continuation)
        # Gate: Closure evidence ledger must precede the fence
        if ! check_closure_ledger_preceding "$content"; then
          printf '%s:%s: FENCE-HANDOFF: handoff-continuation fence emitted without a preceding Closure evidence ledger. Each closure ledger row must be walked (verification commands run) before the continuation fence per SKILL.md protocol.\n' "$file" "$fence_line"
          violations="${violations}1"
        fi
        ;;
      documentation)
        : # Documentation / example fences — no gate applied
        ;;
    esac
  fi

  [ -n "$violations" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# Lint a single JSONL transcript file
#
# Each JSONL record is one assistant/user block. We walk through the file,
# collect each assistant turn, and apply the validators.
# ---------------------------------------------------------------------------
lint_jsonl_file() {
  local file="$1"
  local violations=""

  # Collect and check each assistant turn
  # JSONL line-by-line: group records by turn boundary (user-role non-tool-result)
  local turn_text=""
  local has_auq="false"
  local turn_start_line=1
  local lineno=0

  if command -v jq > /dev/null 2>&1; then
    # Process with jq for reliable JSON parsing
    while IFS= read -r line; do
      lineno=$(( lineno + 1 ))
      [ -z "$line" ] && continue

      # Check for user-role non-tool-result (turn boundary)
      role=$(printf '%s' "$line" | jq -r '.message.role // .role // empty' 2>/dev/null)
      content_type=$(printf '%s' "$line" | jq -r '(.message.content // .content // [null])[0].type // empty' 2>/dev/null)

      if [ "$role" = "user" ] && [ "$content_type" != "tool_result" ]; then
        # Process accumulated turn
        if [ -n "$turn_text" ]; then
          local msg
          # Always-on checks
          msg=$(validate_auq_must_be_auq "$turn_text" "$has_auq") || {
            printf '%s:%s: AUQ: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          msg=$(validate_tool_availability "$turn_text") || {
            printf '%s:%s: TOOL-CLAIM: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          # Fence-conditional checks (Rev 3 discriminator)
          local has_real_fence_turn=0
          if ! msg=$(validate_fence_write_coupling "$turn_text" "/nonexistent" "") 2>/dev/null; then
            has_real_fence_turn=1
          fi
          if [ "$has_real_fence_turn" -eq 1 ]; then
            local fence_class_turn
            fence_class_turn=$(classify_fence_in_text "$turn_text")
            case "$fence_class_turn" in
              implementation_prompt)
                if ! check_postcraft_table_preceding "$turn_text"; then
                  printf '%s:%s: FENCE-IMPL: implementation-prompt fence without preceding Post-Craft Verification table.\n' "$file" "$turn_start_line"
                  violations="${violations}1"
                fi
                case "$turn_text" in
                  *"last-prompts/"*) : ;;
                  *)
                    printf '%s:%s: FENCE-WRITE: implementation-prompt fence without .handoffs/last-prompts/ write reference in same turn.\n' "$file" "$turn_start_line"
                    violations="${violations}1"
                    ;;
                esac
                ;;
              handoff_continuation)
                if ! check_closure_ledger_preceding "$turn_text"; then
                  printf '%s:%s: FENCE-HANDOFF: handoff-continuation fence without preceding Closure evidence ledger.\n' "$file" "$turn_start_line"
                  violations="${violations}1"
                fi
                ;;
              documentation)
                : # skip
                ;;
            esac
          fi
        fi
        # Reset for next turn
        turn_text=""
        has_auq="false"
        turn_start_line=$lineno
        continue
      fi

      # Accumulate assistant text blocks
      if [ "$role" = "assistant" ]; then
        block_text=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="text") | .text // empty' 2>/dev/null)
        if [ -n "$block_text" ]; then
          turn_text="${turn_text} ${block_text}"
        fi
        # Check for AUQ tool use
        auq_check=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="tool_use") | .name // empty' 2>/dev/null | grep -c "AskUserQuestion" 2>/dev/null || echo "0")
        [ "$auq_check" -gt 0 ] && has_auq="true"
      fi
    done < "$file"

    # Process the final turn
    if [ -n "$turn_text" ]; then
      local msg
      # Always-on checks
      msg=$(validate_auq_must_be_auq "$turn_text" "$has_auq") || {
        printf '%s:%s: AUQ: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      msg=$(validate_tool_availability "$turn_text") || {
        printf '%s:%s: TOOL-CLAIM: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      # Fence-conditional checks (Rev 3 discriminator)
      local has_real_fence_final=0
      if ! msg=$(validate_fence_write_coupling "$turn_text" "/nonexistent" "") 2>/dev/null; then
        has_real_fence_final=1
      fi
      if [ "$has_real_fence_final" -eq 1 ]; then
        local fence_class_final
        fence_class_final=$(classify_fence_in_text "$turn_text")
        case "$fence_class_final" in
          implementation_prompt)
            if ! check_postcraft_table_preceding "$turn_text"; then
              printf '%s:%s: FENCE-IMPL: implementation-prompt fence without preceding Post-Craft Verification table.\n' "$file" "$turn_start_line"
              violations="${violations}1"
            fi
            case "$turn_text" in
              *"last-prompts/"*) : ;;
              *)
                printf '%s:%s: FENCE-WRITE: implementation-prompt fence without .handoffs/last-prompts/ write reference in same turn.\n' "$file" "$turn_start_line"
                violations="${violations}1"
                ;;
            esac
            ;;
          handoff_continuation)
            if ! check_closure_ledger_preceding "$turn_text"; then
              printf '%s:%s: FENCE-HANDOFF: handoff-continuation fence without preceding Closure evidence ledger.\n' "$file" "$turn_start_line"
              violations="${violations}1"
            fi
            ;;
          documentation)
            : # skip
            ;;
        esac
      fi
    fi
  else
    # No jq: grep-based heuristic (less precise but avoids hard dependency)
    local full_text
    full_text=$(grep '"type":"text"' "$file" 2>/dev/null | grep -o '"text":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
    local has_auq_count
    has_auq_count=$(grep -c "AskUserQuestion" "$file" 2>/dev/null || echo "0")
    [ "$has_auq_count" -gt 0 ] && has_auq="true"

    local msg
    # Always-on checks
    msg=$(validate_auq_must_be_auq "$full_text" "$has_auq") || {
      printf '%s:?: AUQ: %s\n' "$file" "$msg"
      violations="${violations}1"
    }
    msg=$(validate_tool_availability "$full_text") || {
      printf '%s:?: TOOL-CLAIM: %s\n' "$file" "$msg"
      violations="${violations}1"
    }
    # Fence-conditional checks (Rev 3 discriminator, no-jq fallback)
    local has_real_fence_nojq=0
    if ! msg=$(validate_fence_write_coupling "$full_text" "/nonexistent" "") 2>/dev/null; then
      has_real_fence_nojq=1
    fi
    if [ "$has_real_fence_nojq" -eq 1 ]; then
      local fence_class_nojq
      fence_class_nojq=$(classify_fence_in_text "$full_text")
      case "$fence_class_nojq" in
        implementation_prompt)
          if ! check_postcraft_table_preceding "$full_text"; then
            printf '%s:?: FENCE-IMPL: implementation-prompt fence without preceding Post-Craft Verification table.\n' "$file"
            violations="${violations}1"
          fi
          case "$full_text" in
            *"last-prompts/"*) : ;;
            *)
              printf '%s:?: FENCE-WRITE: implementation-prompt fence without .handoffs/last-prompts/ write reference.\n' "$file"
              violations="${violations}1"
              ;;
          esac
          ;;
        handoff_continuation)
          if ! check_closure_ledger_preceding "$full_text"; then
            printf '%s:?: FENCE-HANDOFF: handoff-continuation fence without preceding Closure evidence ledger.\n' "$file"
            violations="${violations}1"
          fi
          ;;
        documentation)
          : # skip
          ;;
      esac
    fi
  fi

  [ -n "$violations" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# Main: collect and lint all applicable files
# ---------------------------------------------------------------------------
total_files=0
total_violations=0
all_violation_lines=""

# Lint .handoffs/*.md files
while IFS= read -r f; do
  [ -z "$f" ] && continue
  total_files=$(( total_files + 1 ))
  output=$(lint_markdown_file "$f")
  if [ -n "$output" ]; then
    total_violations=$(( total_violations + 1 ))
    all_violation_lines="${all_violation_lines}${output}
"
  fi
done <<EOF
$(collect_handoff_files)
EOF

# Lint JSONL transcript files
while IFS= read -r f; do
  [ -z "$f" ] && continue
  total_files=$(( total_files + 1 ))
  output=$(lint_jsonl_file "$f")
  if [ -n "$output" ]; then
    total_violations=$(( total_violations + 1 ))
    all_violation_lines="${all_violation_lines}${output}
"
  fi
done <<EOF
$(collect_jsonl_files)
EOF

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ "$total_violations" -gt 0 ]; then
  printf 'Transcript lint: %d violation(s) found across %d file(s)\n\n' "$total_violations" "$total_files"
  printf '%s\n' "$all_violation_lines"
  exit 1
fi

printf 'Transcript lint: %d file(s) checked, all clean.\n' "$total_files"
exit 0
