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
#   - IDENTITY-RESET: assistant turn following an Agent/Task tool_result
#     must contain "Back in advisory mode" or "Dispatch complete. I am back
#     in strategic-partner mode" (mirrors SKILL.md Stop rule 2 as a
#     release-time backstop; only applied to JSONL transcripts where prior
#     turn structure is visible)
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
ALLOWLIST_FILE="${SCRIPT_DIR}/.lint-allowlist"

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
EXPLICIT_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE_TAG="$2"; shift 2 ;;
    --all)   CHECK_ALL=1; shift ;;
    *)       EXPLICIT_FILES+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Determine the last release tag (for filtering .handoffs/*.md by mtime)
#
# LAST_TAG_DATE: ISO 8601 string with timezone, used by `git log --since`
#                (git parses tz-aware ISO dates correctly).
# LAST_TAG_EPOCH: UTC epoch seconds, used for direct file-mtime comparison
#                 (avoids tz-parsing pitfalls in the python comparison branch).
# ---------------------------------------------------------------------------
LAST_TAG_DATE=""
LAST_TAG_EPOCH=""
if [ "$CHECK_ALL" -eq 0 ]; then
  if [ -n "$SINCE_TAG" ]; then
    LAST_TAG_DATE=$(git -C "$SCRIPT_DIR" log -1 --format='%ai' "$SINCE_TAG" 2>/dev/null)
    LAST_TAG_EPOCH=$(git -C "$SCRIPT_DIR" log -1 --format='%ct' "$SINCE_TAG" 2>/dev/null)
  else
    LAST_TAG=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null || true)
    if [ -n "$LAST_TAG" ]; then
      LAST_TAG_DATE=$(git -C "$SCRIPT_DIR" log -1 --format='%ai' "$LAST_TAG" 2>/dev/null)
      LAST_TAG_EPOCH=$(git -C "$SCRIPT_DIR" log -1 --format='%ct' "$LAST_TAG" 2>/dev/null)
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

  # ---------------------------------------------------------------------------
  # Allowlist mechanism (v5.17.0):
  # After the mtime-since-tag filter, a second pass excludes any JSONL whose
  # basename matches an entry in $ALLOWLIST_FILE (one basename per line; lines
  # starting with '#' are comments; blank lines ignored). Used sparingly to
  # exempt specific historical transcripts whose authoring drift never reached
  # published files. If the allowlist file does not exist, or contains only
  # comments/blanks, behavior is identical to pre-allowlist (no skips).
  # bash 3.2 compat: simple line-by-line grep -Fx — no associative arrays.
  # ---------------------------------------------------------------------------
  filter_allowlist() {
    if [ ! -f "$ALLOWLIST_FILE" ]; then
      cat
      return 0
    fi
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      local base
      base=$(basename "$f")
      # Skip if basename matches a non-comment, non-blank line in allowlist.
      if grep -v '^[[:space:]]*#' "$ALLOWLIST_FILE" 2>/dev/null \
           | grep -v '^[[:space:]]*$' \
           | grep -Fxq "$base"; then
        continue
      fi
      printf '%s\n' "$f"
    done
  }

  if [ "$CHECK_ALL" -eq 1 ] || [ -z "$LAST_TAG_EPOCH" ]; then
    find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null \
      | filter_allowlist
  else
    # Compare file mtime (epoch seconds) against LAST_TAG_EPOCH (epoch seconds
    # straight from `git log -1 --format=%ct`). Both are UTC epochs — no tz
    # parsing needed. Files newer than the tag are in scope.
    find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f 2>/dev/null | while read -r f; do
      if command -v python3 > /dev/null 2>&1; then
        FILE_MTIME=$(python3 -c "import os; print(int(os.path.getmtime('$f')))" 2>/dev/null || echo "0")
        [ "$FILE_MTIME" -gt "$LAST_TAG_EPOCH" ] && printf '%s\n' "$f"
      else
        # No python3: include all (conservative — may flag pre-release sessions)
        printf '%s\n' "$f"
      fi
    done | filter_allowlist
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
  #
  # has_real_fence detection: call validate_fence_write_coupling with empty
  # tool_use_records. The function returns 1 (violation) for any real fence
  # (no tool-call evidence available in markdown lint) and 0 if the fence
  # only appears in code blocks/blockquotes/commentary. We use that return
  # code as a real-fence detector. The actual coupling check for markdown
  # files runs separately below as an 80-line context window scan, which
  # is the textual proxy for tool-call trace when JSONL is unavailable.
  local has_real_fence=0
  case "$content" in
    *"══ START 🟢 COPY ══"*)
      if ! msg=$(validate_fence_write_coupling "$content" "") 2>/dev/null; then
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

  # Check 4: Voice patterns (always-on)
  # Scans for the six mechanical jargon patterns in user-facing prose.
  # Helper preserves line numbers via internal walker, so violations
  # report the actual file line.
  local voice_msg
  voice_msg=$(validate_voice_patterns "$full_text" "$file") || {
    printf '%s\n' "$voice_msg"
    violations="${violations}1"
  }

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
  local turn_tool_uses=""
  local has_auq="false"
  local turn_start_line=1
  local lineno=0
  # IDENTITY-RESET tracking: set to "true" when a user-role tool_result record
  # carries an Agent/Task tool's output. Cleared when the assistant turn that
  # follows is checked. Persists across multiple intermediate user records
  # (a dispatch may produce several tool_result lines before the assistant
  # responds).
  local prev_user_had_dispatch="false"

  if command -v jq > /dev/null 2>&1; then
    # Process with jq for reliable JSON parsing
    while IFS= read -r line; do
      lineno=$(( lineno + 1 ))
      [ -z "$line" ] && continue

      # Check for user-role non-tool-result (turn boundary)
      role=$(printf '%s' "$line" | jq -r '.message.role // .role // empty' 2>/dev/null)
      content_type=$(printf '%s' "$line" | jq -r '(.message.content // .content // [null])[0].type // empty' 2>/dev/null)

      # IDENTITY-RESET tracking: scan user-role tool_result records for an
      # Agent or Task tool name. The tool_result links back to a prior
      # tool_use by tool_use_id; we infer the original tool by name encoded
      # in the same record (Claude Code includes the original tool name in
      # the tool_result payload's tool_use_id reference, but the simplest
      # heuristic is to scan the record text for "Agent" or "Task" tool
      # names alongside the tool_result type).
      if [ "$role" = "user" ] && [ "$content_type" = "tool_result" ]; then
        # Look for Agent/Task tool name in the record (the parent tool_use
        # name surfaces in the JSONL trace within the same record's
        # surrounding context — search the full line as a substring proxy).
        if printf '%s' "$line" | grep -qE '"name"[[:space:]]*:[[:space:]]*"(Agent|Task)"'; then
          prev_user_had_dispatch="true"
        fi
      fi

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
          # IDENTITY-RESET check (only fires when prior user records carried
          # an Agent/Task tool_result)
          msg=$(validate_identity_reset "$turn_text" "$prev_user_had_dispatch") || {
            printf '%s:%s: IDENTITY-RESET: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          # Reset dispatch flag now that the assistant turn following the
          # dispatch has been checked.
          prev_user_had_dispatch="false"
          # Fence-conditional checks (Rev 3 discriminator).
          # Pass the turn's tool_use records as the coupling evidence.
          local has_real_fence_turn=0
          if ! msg=$(validate_fence_write_coupling "$turn_text" "$turn_tool_uses") 2>/dev/null; then
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
                # Coupling check via tool_use trace: scan turn_tool_uses for a
                # Write/Edit/MultiEdit to .handoffs/last-prompts/[N].md.
                local found_prompt_write=0
                if [ -n "$turn_tool_uses" ]; then
                  while IFS=$'\t' read -r tu_tool tu_path; do
                    [ -z "$tu_tool" ] && continue
                    case "$tu_tool" in
                      Write|Edit|MultiEdit) ;;
                      *) continue ;;
                    esac
                    case "$tu_path" in
                      *.handoffs/last-prompts/[0-9]*.md|*/.handoffs/last-prompts/[0-9]*.md)
                        found_prompt_write=1
                        break
                        ;;
                    esac
                  done <<EOF
$turn_tool_uses
EOF
                fi
                if [ "$found_prompt_write" -eq 0 ]; then
                  printf '%s:%s: FENCE-WRITE: implementation-prompt fence without a Write/Edit/MultiEdit tool_use to .handoffs/last-prompts/[N].md in same turn.\n' "$file" "$turn_start_line"
                  violations="${violations}1"
                fi
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
          # Check 4: Voice patterns (always-on).
          # display_line=turn_start_line — within-turn line offsets don't
          # map back to JSONL lines (turn_text is concatenated from many
          # JSON records), so all violations are pinned to the turn boundary.
          local voice_msg_turn
          voice_msg_turn=$(validate_voice_patterns "$turn_text" "$file" "$turn_start_line") || {
            printf '%s\n' "$voice_msg_turn"
            violations="${violations}1"
          }
        fi
        # Reset for next turn
        turn_text=""
        turn_tool_uses=""
        has_auq="false"
        turn_start_line=$lineno
        continue
      fi

      # Accumulate assistant text blocks and tool_use records
      if [ "$role" = "assistant" ]; then
        block_text=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="text") | .text // empty' 2>/dev/null)
        if [ -n "$block_text" ]; then
          turn_text="${turn_text} ${block_text}"
        fi
        # Extract tool_use records for fence-write coupling evidence.
        # Format: "<tool_name>\t<file_path>" per line. Empty file_path is fine
        # (validate_fence_write_coupling filters non-matching paths).
        local block_tool_uses
        block_tool_uses=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="tool_use") | "\(.name // "")\t\(.input.file_path // "")"' 2>/dev/null)
        if [ -n "$block_tool_uses" ]; then
          turn_tool_uses="${turn_tool_uses}${block_tool_uses}
"
        fi
        # Check for AUQ tool use
        auq_check=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="tool_use") | .name // empty' 2>/dev/null | grep -c "AskUserQuestion" 2>/dev/null || echo "0")
        [ "$(printf '%s' "$auq_check" | head -n1)" -gt 0 ] && has_auq="true"
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
      # IDENTITY-RESET check (final turn)
      msg=$(validate_identity_reset "$turn_text" "$prev_user_had_dispatch") || {
        printf '%s:%s: IDENTITY-RESET: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      # Fence-conditional checks (Rev 3 discriminator)
      local has_real_fence_final=0
      if ! msg=$(validate_fence_write_coupling "$turn_text" "$turn_tool_uses") 2>/dev/null; then
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
            # Coupling check via tool_use trace
            local found_prompt_write_final=0
            if [ -n "$turn_tool_uses" ]; then
              while IFS=$'\t' read -r tu_tool tu_path; do
                [ -z "$tu_tool" ] && continue
                case "$tu_tool" in
                  Write|Edit|MultiEdit) ;;
                  *) continue ;;
                esac
                case "$tu_path" in
                  *.handoffs/last-prompts/[0-9]*.md|*/.handoffs/last-prompts/[0-9]*.md)
                    found_prompt_write_final=1
                    break
                    ;;
                esac
              done <<EOF
$turn_tool_uses
EOF
            fi
            if [ "$found_prompt_write_final" -eq 0 ]; then
              printf '%s:%s: FENCE-WRITE: implementation-prompt fence without a Write/Edit/MultiEdit tool_use to .handoffs/last-prompts/[N].md in same turn.\n' "$file" "$turn_start_line"
              violations="${violations}1"
            fi
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
      # Check 4: Voice patterns (always-on, final turn).
      local voice_msg_final
      voice_msg_final=$(validate_voice_patterns "$turn_text" "$file" "$turn_start_line") || {
        printf '%s\n' "$voice_msg_final"
        violations="${violations}1"
      }
    fi
  else
    # No jq: grep-based heuristic (less precise but avoids hard dependency).
    # Without jq we cannot extract structured tool_use records, so the coupling
    # check falls back to a textual proxy — looking for `last-prompts/` substring
    # anywhere in the assembled assistant text. This is conservative (may miss
    # violations where the substring appears for unrelated reasons) but matches
    # the pre-v5.14.0 fallback behaviour.
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
    # Fence-conditional checks (Rev 3 discriminator, no-jq fallback).
    # Use empty tool_use_records → real-fence detection only; coupling is
    # checked by the substring proxy below.
    local has_real_fence_nojq=0
    if ! msg=$(validate_fence_write_coupling "$full_text" "") 2>/dev/null; then
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
              printf '%s:?: FENCE-WRITE: implementation-prompt fence without .handoffs/last-prompts/ write reference (no-jq fallback proxy).\n' "$file"
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
    # Check 4: Voice patterns (always-on, no-jq fallback).
    # full_text here has newlines collapsed to spaces, so within-text line
    # numbers are meaningless — display_line="?" matches the existing
    # no-jq fallback convention used by the AUQ and tool-availability checks.
    local voice_msg_nojq
    voice_msg_nojq=$(validate_voice_patterns "$full_text" "$file" "?") || {
      printf '%s\n' "$voice_msg_nojq"
      violations="${violations}1"
    }
  fi

  [ -n "$violations" ] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# Main: collect and lint all applicable files.
# When explicit file paths are passed on the command line, lint those
# directly (dispatching to the markdown or JSONL handler based on extension).
# Otherwise, auto-discover handoff and transcript files since the last tag.
# ---------------------------------------------------------------------------
total_files=0
total_violations=0
files_with_violations=0
all_violation_lines=""

lint_one_file() {
  local file="$1"
  local output
  case "$file" in
    *.jsonl) output=$(lint_jsonl_file "$file") ;;
    *)       output=$(lint_markdown_file "$file") ;;
  esac
  total_files=$(( total_files + 1 ))
  if [ -n "$output" ]; then
    files_with_violations=$(( files_with_violations + 1 ))
    # Count individual violation lines (each violation is one line in output).
    local n
    n=$(printf '%s\n' "$output" | grep -c ':' || true)
    [ -z "$n" ] && n=0
    total_violations=$(( total_violations + n ))
    all_violation_lines="${all_violation_lines}${output}
"
  fi
}

if [ "${#EXPLICIT_FILES[@]}" -gt 0 ]; then
  for f in "${EXPLICIT_FILES[@]}"; do
    [ -z "$f" ] && continue
    lint_one_file "$f"
  done
else
  # Lint .handoffs/*.md files
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    lint_one_file "$f"
  done <<EOF
$(collect_handoff_files)
EOF

  # Lint JSONL transcript files
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    lint_one_file "$f"
  done <<EOF
$(collect_jsonl_files)
EOF
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ "$total_violations" -gt 0 ]; then
  # Output shape note (v5.15.0):
  # The format "across %d of %d file(s)" is an intentional evolution from the
  # v5.14.0 baseline of "across %d file(s)". The new format reports BOTH
  # files-with-findings AND total-files-scanned (strictly more information),
  # whereas the prior format only surfaced one number. This is a deliberate
  # backward-incompatible change documented in CHANGELOG.md v5.15.0 § Changed.
  # Downstream parsers expecting the older single-number format must update.
  printf 'Transcript lint: %d violation(s) found across %d of %d file(s)\n\n' \
    "$total_violations" "$files_with_violations" "$total_files"
  printf '%s\n' "$all_violation_lines"
  exit 1
fi

printf 'Transcript lint: %d file(s) checked, all clean.\n' "$total_files"
exit 0
