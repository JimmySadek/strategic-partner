#!/usr/bin/env bash
# tests/lint-transcripts.sh — Layer 3: release-time transcript lint backstop.
#
# Scans .handoffs/*.md files and (if accessible) the Claude project JSONL
# transcripts since the last release tag, then runs the same three structural
# checks as Layer 2 (stop-validator.sh):
#
#   - AUQ-must-be-AUQ (always-on)
#   - Tool-availability claims (always-on)
#   - Fence-write coupling (fence-conditional)
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
  cwd_encoded=$(printf '%s' "$SCRIPT_DIR" | tr '/' '-')
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

  # Check 3: Fence-write coupling (fence-conditional)
  # For markdown files, we can't check the state file because these are
  # historical records. Instead, we check whether the file contains a
  # fence marker AND a reference to a .handoffs/last-prompts/ write within
  # the same session block (heuristic: within 50 lines of each other).
  case "$content" in
    *"══ START 🟢 COPY ══"*)
      # Verify a last-prompts path reference appears near the fence
      local fence_line
      fence_line=$(grep -n "══ START 🟢 COPY ══" "$file" 2>/dev/null | head -1 | cut -d: -f1)
      if [ -n "$fence_line" ]; then
        # Look for a .handoffs/last-prompts/ reference within 80 lines before the fence
        local start_line=$(( fence_line - 80 ))
        [ "$start_line" -lt 1 ] && start_line=1
        local context_block
        context_block=$(sed -n "${start_line},${fence_line}p" "$file" 2>/dev/null)
        case "$context_block" in
          *"last-prompts/"*)
            : # write reference found — pass
            ;;
          *)
            # Check if this fence is in a code block (R1.1 tightened selector)
            msg=$(validate_fence_write_coupling "$content" "/nonexistent-no-state-file" "") || {
              printf '%s:%s: FENCE-WRITE: fence emitted near line %s without visible .handoffs/last-prompts/ write reference in preceding context. Verify write preceded fence emission.\n' "$file" "$fence_line" "$fence_line"
              violations="${violations}1"
            }
            ;;
        esac
      fi
      ;;
  esac

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
          msg=$(validate_auq_must_be_auq "$turn_text" "$has_auq") || {
            printf '%s:%s: AUQ: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          msg=$(validate_tool_availability "$turn_text") || {
            printf '%s:%s: TOOL-CLAIM: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          msg=$(validate_fence_write_coupling "$turn_text" "/nonexistent" "") || {
            printf '%s:%s: FENCE-WRITE: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
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
      msg=$(validate_auq_must_be_auq "$turn_text" "$has_auq") || {
        printf '%s:%s: AUQ: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      msg=$(validate_tool_availability "$turn_text") || {
        printf '%s:%s: TOOL-CLAIM: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      msg=$(validate_fence_write_coupling "$turn_text" "/nonexistent" "") || {
        printf '%s:%s: FENCE-WRITE: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
    fi
  else
    # No jq: grep-based heuristic (less precise but avoids hard dependency)
    local full_text
    full_text=$(grep '"type":"text"' "$file" 2>/dev/null | grep -o '"text":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
    local has_auq_count
    has_auq_count=$(grep -c "AskUserQuestion" "$file" 2>/dev/null || echo "0")
    [ "$has_auq_count" -gt 0 ] && has_auq="true"

    local msg
    msg=$(validate_auq_must_be_auq "$full_text" "$has_auq") || {
      printf '%s:?: AUQ: %s\n' "$file" "$msg"
      violations="${violations}1"
    }
    msg=$(validate_tool_availability "$full_text") || {
      printf '%s:?: TOOL-CLAIM: %s\n' "$file" "$msg"
      violations="${violations}1"
    }
    msg=$(validate_fence_write_coupling "$full_text" "/nonexistent" "") || {
      printf '%s:?: FENCE-WRITE: %s\n' "$file" "$msg"
      violations="${violations}1"
    }
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
