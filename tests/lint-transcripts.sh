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
#   - LEAK-TERM: SP-internal vocabulary (AUQ, bare step labels, "Mode A/B",
#     ultracode, xhigh, "floor sentinel") appearing bare in assistant chat
#     text. JSONL assistant messages only — never applied to .handoffs/*.md.
#     See check_leak_terms below for the full exemption list.
#
# ROLE / isMeta FILTER (JSONL scan path, all checks above): a JSONL entry
# only reaches these checks when its own record is type=="assistant" and
# isMeta is not true. A user-typed message or a harness-reinjected slash-
# command body is not SP's voice and must never be judged as if it were
# (tests/lint-transcripts.sh backlog: fix-transcript-lint-role-filter). The
# IDENTITY-RESET check is the one exception noted above — it still reads
# prior-turn STRUCTURE (does the record before this one carry an Agent/Task
# tool_result?) from non-assistant entries; only the content that gets
# JUDGED is role/isMeta-gated.
#
# FENCE-CONDITIONAL CHECKS (only for responses containing ══ START 🟢 COPY ══):
#   - Classify fence per Rev 3 three-step discriminator:
#       Step 1: locate command line (through optional backtick wrapper)
#       Step 2: classify by command pattern
#               /strategic-partner <handoffs-file> → handoff continuation
#               /<any-skill> or /strategic-partner (with body) → implementation prompt
#               empty / unrecognized → documentation (skip gate)
#       Step 3: apply class-specific gate
#               implementation prompt → reject an advisor alias on line 1
#                                        (/strategic-partner with no .handoffs/
#                                        path, /advisor, or /sp — a self-defeating
#                                        launcher), then verify 13-row Post-Craft
#                                        Verification table preceding AND
#                                        corresponding last-prompts write
#               handoff continuation → verify Closure evidence ledger preceding
#               documentation → skip
#   - FENCE-ENTITY: the fence BODY must not contain HTML entity escapes for
#     the angle brackets or the ampersand. A terminal renders an escape as
#     its literal text rather than the character it stands for, so the
#     on-screen prompt becomes unreadable. Applies to every fence class.
#
# RUNNER-CONDITIONAL CHECK (only for turns containing a "bash .scripts/<path>"
# runner handoff line — Script Emission Protocol parity with fence-write
# coupling):
#   - SCRIPT-WRITE: a mandated runner-handoff line (the whole line is
#     `bash .scripts/<path>` or `! bash .scripts/<path>`, not in a code
#     block / blockquote / commentary) requires a same-turn
#     Write/Edit/MultiEdit tool_use to a .scripts/ path. Fail-closed when a
#     real runner is found with no evidence (JSONL: tool-use trace; markdown
#     and no-jq: textual write-reference proxy, mirroring the fence path).
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
CEREMONY_LIB="${SCRIPT_DIR}/plugin/strategic-partner/hooks/lib/session-ceremony.sh"
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

CEREMONY_OK=false
if [ -f "$CEREMONY_LIB" ]; then
  # shellcheck source=/dev/null
  . "$CEREMONY_LIB"
  CEREMONY_OK=true
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

  # Handoff continuation: standalone or plugin SP followed by a .handoffs/ path
  case "$command_line" in
    /strategic-partner\ .handoffs/*|/strategic-partner\ "'.handoffs/"*|/strategic-partner-plugin:strategic-partner\ .handoffs/*|/strategic-partner-plugin:strategic-partner\ "'.handoffs/"*)
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
# rows with state labels and a verification command per row — a structural
# pattern specific to closure handoff continuations.
#
# State labels come in two flavors and either is accepted:
#   - Internal names (pre-v6.3.3 rendering): RESOLVED, DECISION, SKIPPED, etc.
#   - Plain-English phrases (v6.3.3+ rendering): "Checked, all clean",
#     "Already handled", "Needs your input", "Skipped (you declined)",
#     "Doesn't apply this session", "Uncommitted source changes".
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
  # Both internal-name and plain-English-rendering variants are accepted so
  # this lint passes against transcripts from before AND after v6.3.3.
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
  # v6.3.3+ plain-English rendering variants
  case "$before_fence" in
    *"Checked, all clean"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"Already handled"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"Needs your input"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"Skipped (you declined)"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"Doesn't apply this session"*) has_state_label=1 ;;
  esac
  case "$before_fence" in
    *"Uncommitted source changes"*) has_state_label=1 ;;
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
# Verify the FULL Closure Walk Status table precedes the fence in CHAT TEXT
#
# check_closure_table_in_chat <text>
#
# Tighter sibling of check_closure_ledger_preceding, modeled on
# check_postcraft_table_preceding. Where the looser check passes on a single
# state-label + single layer-label substring (which a collapsed one-line chat
# summary can satisfy via casual prose like "findings are current; tree clean"),
# this check requires evidence that the full 8-group table was actually
# rendered: the "Closure Walk Status" header, OR both the first and last
# row anchors ("Staleness" AND "Working tree"), OR an explicit ledger string.
# Stable plain-English anchors are matched rather than the row-anchor emojis,
# which are brittle to render-format drift.
#
# SCOPE — chat text only. This is called ONLY from the JSONL call sites, where
# the text it receives is the assistant turn's VISIBLE TEXT (built from
# `select(.type=="text").text` blocks; tool_use / file-write bodies never enter
# turn_text). The markdown .handoffs/*.md path keeps the looser
# check_closure_ledger_preceding: handoff FILES legitimately persist the full
# table in their body, and many pre-v5.15.0 files logged a valid ledger in
# state-label+layer prose without the "Closure Walk Status" header — tightening
# the FILE scan would false-positive on those legitimate files. The chat-text
# scope is what lets this fail the chat-collapse case without touching the FILE
# scan (the trap the render-fix brief flags).
#
# Returns: 0=found (pass), 1=not found (violation)
# ---------------------------------------------------------------------------
check_closure_table_in_chat() {
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

  # Explicit table header — the canonical render.
  case "$before_fence" in
    *"Closure Walk Status"*) return 0 ;;
  esac

  # Plain-English row anchors: first row (Staleness) AND last row (Working tree)
  # both present indicates the full table was rendered, not a one-line summary.
  case "$before_fence" in
    *"Staleness"*)
      case "$before_fence" in
        *"Working tree"*) return 0 ;;
      esac
      ;;
  esac

  # Explicit ledger strings (kept from the looser check — these are
  # unambiguous closure-walk markers).
  case "$before_fence" in
    *"Closure evidence ledger"*|*"closure evidence ledger"*|*"Closure Checklist"*|*"closure checklist"*)
      return 0
      ;;
  esac

  return 1
}

# ---------------------------------------------------------------------------
# Verify the fence BODY carries no HTML entity escapes
#
# check_entity_escapes_in_fence <text>
#
# A copyable prompt whose body is built from XML-style tags has to be wrapped
# in a backtick code fence, otherwise the markdown renderer strips the bare
# tags as HTML and the structure is lost (references/prompt-crafting-guide.md
# line 191, repeated in SKILL.md). Substituting HTML entity escapes for the
# angle brackets is the anti-pattern this catches: a terminal does not decode
# entities, so the reader sees the escape text where the character belongs and
# the on-screen prompt is unreadable for review. The saved prompt file is
# unaffected, which is why no other check notices.
#
# SCOPE — only the text BETWEEN the fence markers is inspected. Escapes in the
# surrounding prose are legitimate (documentation quoting them, commentary
# about this very rule) and must not fire. Every fence in the text is walked,
# not just the first: one turn may emit more than one.
#
# Returns: 0=clean (pass), 1=escapes found (violation) — same polarity as the
# check_*_preceding siblings above.
# ---------------------------------------------------------------------------
check_entity_escapes_in_fence() {
  local text="$1"
  local fence_start="══ START 🟢 COPY ══"
  local fence_end="══ END 🛑 COPY ══"

  # The escape spellings are assembled from $amp instead of being written out,
  # so this file never contains the literal patterns it searches for. That is
  # load-bearing, not decorative: several fence-start literals in this source
  # have no matching fence-end literal after them, so a body walk over the
  # lint's own source treats long stretches of it as fence body. A literal
  # spelling written in any of those stretches makes the file flag its own
  # documentation. Assembling the patterns keeps that impossible wherever a
  # maintainer later puts them.
  local amp='&'

  local in_fence=0
  while IFS= read -r line; do
    case "$line" in
      *"$fence_start"*) in_fence=1; continue ;;
      *"$fence_end"*)   in_fence=0; continue ;;
    esac
    [ "$in_fence" -eq 1 ] || continue
    case "$line" in
      *"${amp}lt;"*|*"${amp}gt;"*|*"${amp}amp;"*) return 1 ;;
    esac
  done <<EOF
$text
EOF

  return 0
}

# ---------------------------------------------------------------------------
# Check: LEAK-TERM — SP-internal vocabulary leaking into assistant chat text
#
# check_leak_terms <text> <file_path> <display_line>
#
# Always-on check, scoped to JSONL assistant-message text only (never called
# from lint_markdown_file — .handoffs/*.md files legitimately author this
# vocabulary as source material, so the exemption is "don't call this
# function there" rather than a content-shape carve-out). Flags six pieces of
# SP-internal shorthand appearing bare in live assistant prose, word-boundary
# matched, case-sensitive except where noted:
#   1. AUQ
#   2. bare step labels — "Step" + digit + lowercase letter (Step 1a, Step 2b)
#   3. "Mode A" / "Mode B"
#   4. ultracode (case-insensitive)
#   5. xhigh (case-insensitive)
#   6. "floor sentinel" (case-insensitive)
#
# Exemptions (does NOT flag):
#   - backtick-wrapped inline code on the same line (stripped before matching)
#   - fenced ``` code blocks
#   - ══ START 🟢 COPY ══ / ══ END 🛑 COPY ══ fence bodies — prompt text
#     handed to an executor, not chat prose read by the user
#   - allowlisted files (handled upstream by collect_jsonl_files's
#     filter_allowlist — this function never sees an allowlisted file)
#
# Args mirror validate_voice_patterns: text, file_path, display_line (JSONL
# callers pass turn_start_line — within-turn line offsets don't map back to
# JSONL file lines, same limitation the voice-pattern check documents).
#
# Returns: 0=clean, 1=one or more violations found (violations on stdout)
# ---------------------------------------------------------------------------
check_leak_terms() {
  local text="$1"
  local file_path="${2:-?}"
  local display_line="${3:-}"
  local in_code=0
  local in_copy_fence=0
  local lineno=0
  local found_violation=0
  local report_line
  local stripped lower match

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$(( lineno + 1 ))

    case "$line" in
      *"══ START 🟢 COPY ══"*) in_copy_fence=1; continue ;;
      *"══ END 🛑 COPY ══"*)   in_copy_fence=0; continue ;;
    esac
    [ "$in_copy_fence" -eq 1 ] && continue

    case "$line" in
      '```'*) in_code=$(( 1 - in_code )); continue ;;
    esac
    [ "$in_code" -eq 1 ] && continue

    if [ -n "$display_line" ]; then
      report_line="$display_line"
    else
      report_line="$lineno"
    fi

    # Strip inline backtick spans before matching — a code-quoted mention of
    # one of these terms is documentation, not a leak.
    stripped=$(printf '%s' "$line" | sed 's/`[^`]*`//g')

    # ---- Term 1: AUQ ----
    if [[ "$stripped" =~ (^|[^A-Za-z])(AUQ)($|[^A-Za-z]) ]]; then
      printf '%s:%s: LEAK-TERM: internal term "AUQ" appears bare in assistant chat text. Say what the question is for, or describe the tool call in plain English, instead of the internal shorthand.\n' \
        "$file_path" "$report_line"
      found_violation=1
    fi

    # ---- Term 2: bare step labels — Step<digit><lowercase letter> ----
    if [[ "$stripped" =~ (^|[^A-Za-z])(Step[[:space:]]+[0-9][a-z])([^A-Za-z]|$) ]]; then
      match="${BASH_REMATCH[2]}"
      printf '%s:%s: LEAK-TERM: internal step label "%s" appears bare in assistant chat text. Describe the step in plain English instead of citing its internal label.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Term 3: "Mode A" / "Mode B" ----
    if [[ "$stripped" =~ (^|[^A-Za-z])(Mode[[:space:]]+[AB])($|[^A-Za-z]) ]]; then
      match="${BASH_REMATCH[2]}"
      printf '%s:%s: LEAK-TERM: internal mode label "%s" appears bare in assistant chat text. Describe what the mode does instead of citing its internal letter.\n' \
        "$file_path" "$report_line" "$match"
      found_violation=1
    fi

    # ---- Terms 4-6: case-insensitive ----
    lower=$(printf '%s' "$stripped" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower" =~ (^|[^a-z])(ultracode)($|[^a-z]) ]]; then
      printf '%s:%s: LEAK-TERM: internal term "ultracode" appears bare in assistant chat text. Describe the behavior in plain English instead of the internal name.\n' \
        "$file_path" "$report_line"
      found_violation=1
    fi

    if [[ "$lower" =~ (^|[^a-z])(xhigh)($|[^a-z]) ]]; then
      printf '%s:%s: LEAK-TERM: internal term "xhigh" appears bare in assistant chat text. Name the setting in plain English instead of the internal shorthand.\n' \
        "$file_path" "$report_line"
      found_violation=1
    fi

    if [[ "$lower" =~ (^|[^a-z])(floor[[:space:]]+sentinel)($|[^a-z]) ]]; then
      printf '%s:%s: LEAK-TERM: internal term "floor sentinel" appears bare in assistant chat text. Describe what it does in plain English instead of the internal name.\n' \
        "$file_path" "$report_line"
      found_violation=1
    fi
  done <<EOF
$text
EOF

  [ "$found_violation" -eq 1 ] && return 1
  return 0
}

# ---------------------------------------------------------------------------
# Helper: filter a JSONL file down to assistant, non-isMeta lines (no-jq
# fallback role/isMeta filter — see the call site in lint_jsonl_file for the
# rationale). A named function, not an inline `while ... case ... esac ...
# done` inside `$(...)` — bash 3.2 fails to parse `case` as the first
# statement of a while loop that is the direct body of a command
# substitution (reproduced independently of this file's content), so the
# loop is wrapped in a function and the function itself is what gets called
# inside `$(...)`, matching every other line-filtering helper in this file.
# ---------------------------------------------------------------------------
_filter_assistant_lines() {
  local src_file="$1"
  local jline
  while IFS= read -r jline; do
    case "$jline" in
      *'"isMeta":true'*) continue ;;
    esac
    case "$jline" in
      *'"type":"assistant"'*) printf '%s\n' "$jline" ;;
    esac
  done < "$src_file"
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
        # Gate: an advisor alias (/strategic-partner with no .handoffs/ path,
        # /advisor, or /sp) as the fence's first line is a self-defeating
        # launcher — fail-closed. The handoff_continuation path is untouched.
        local advisor_msg
        if ! advisor_msg=$(validate_advisor_launcher "$content"); then
          printf '%s:%s: FENCE-ADVISOR: %s\n' "$file" "$fence_line" "$advisor_msg"
          violations="${violations}1"
        fi
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

  # Check 3a: HTML entity escapes in a fence body (fence-conditional).
  #
  # Deliberately NOT placed behind has_real_fence. That flag is set from
  # validate_fence_write_coupling's FAILURE return, so it only opens for a
  # fence whose prompt-file write is missing. A correctly-coupled emission —
  # precisely the shape this display bug ships in — would never reach the
  # check. check_entity_escapes_in_fence is self-gating instead: no fence
  # markers means no body, which means no finding.
  if ! check_entity_escapes_in_fence "$content"; then
    local entity_line
    entity_line=$(grep -n "══ START 🟢 COPY ══" "$file" 2>/dev/null | head -1 | cut -d: -f1)
    [ -z "$entity_line" ] && entity_line="?"
    printf '%s:%s: FENCE-ENTITY: copyable prompt fence contains HTML entity escapes in its body. A terminal renders an escape as its literal text instead of the character it stands for, so the reader sees the escape where the angle bracket or ampersand belongs. Wrap the prompt body in a backtick code fence and write the characters directly.\n' "$file" "$entity_line"
    violations="${violations}1"
  fi

  # Check 3b: Script-write coupling (runner-conditional) — parity with the
  # fence-write coupling check above, for the Script Emission Protocol.
  # Markdown path has no tool-call trace, so pass empty records as a
  # real-runner detector (the validator returns 1 for a real runner handoff
  # with no evidence), then apply a textual proxy: a .scripts/ write
  # reference in the surrounding context clears it (mirrors the
  # last-prompts/ context scan the fence path uses for markdown files).
  case "$content" in
    *".scripts/"*)
      if ! msg=$(validate_script_write_coupling "$content" "") 2>/dev/null; then
        local runner_line
        runner_line=$(grep -nE '^[[:space:]]*`?(! )?bash \.scripts/' "$file" 2>/dev/null | head -1 | cut -d: -f1)
        [ -z "$runner_line" ] && runner_line="?"
        case "$content" in
          *"Write"*".scripts/"*|*"Edit"*".scripts/"*|*"MultiEdit"*".scripts/"*|*"written to "*".scripts/"*|*"wrote "*".scripts/"*)
            : # write reference present in doc context — pass
            ;;
          *)
            printf '%s:%s: SCRIPT-WRITE: %s\n' "$file" "$runner_line" "$msg"
            violations="${violations}1"
            ;;
        esac
      fi
      ;;
  esac

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
  local turn_auq_payload=""
  local has_auq="false"
  local turn_start_line=1
  # turn_line_anchored: "false" until the current turn segment's first
  # assistant/non-meta record has set turn_start_line (see the accumulation
  # gate below). Reported violations must anchor to a real assistant, non-meta
  # JSONL line — not to the user/isMeta boundary line that started the
  # segment (tests/lint-transcripts.sh backlog: fix-transcript-lint-role-filter).
  local turn_line_anchored="false"
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

      # One jq read per record yields the four fields the walk needs: the
      # record's own type, its role, whether the harness injected it (isMeta),
      # and the type of its first content block. entry_type and is_meta are what
      # keep non-assistant and re-injected records out of the evaluated text
      # further down; role and content_type still drive turn segmentation.
      entry_fields=$(printf '%s' "$line" | jq -r '[
        (.type // ""),
        (.message.role // .role // ""),
        ((.isMeta // false) | tostring),
        ((.message.content // .content // []) | if type == "array" then (.[0].type // "") else "" end)
      ] | @tsv' 2>/dev/null)
      IFS=$'\t' read -r entry_type role is_meta content_type <<EOF
$entry_fields
EOF

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
                local advisor_msg_turn
                if ! advisor_msg_turn=$(validate_advisor_launcher "$turn_text"); then
                  printf '%s:%s: FENCE-ADVISOR: %s\n' "$file" "$turn_start_line" "$advisor_msg_turn"
                  violations="${violations}1"
                fi
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
                # JSONL → turn_text is assistant chat text only; require the
                # full Closure Walk Status table rendered in chat (not a
                # collapsed one-liner). See check_closure_table_in_chat header.
                if ! check_closure_table_in_chat "$turn_text"; then
                  printf '%s:%s: FENCE-HANDOFF: handoff-continuation fence without the full Closure Walk Status table rendered in chat text (collapsed closure — the 8-group table must appear inline before the continuation fence per SKILL.md Auto-dispatch step 2).\n' "$file" "$turn_start_line"
                  violations="${violations}1"
                fi
                ;;
              documentation)
                : # skip
                ;;
            esac
          fi
          # Check 3a: HTML entity escapes in a fence body (fence-conditional,
          # self-gating — see the markdown call site for why this sits outside
          # the has_real_fence block).
          if ! check_entity_escapes_in_fence "$turn_text"; then
            printf '%s:%s: FENCE-ENTITY: copyable prompt fence contains HTML entity escapes in its body. A terminal renders an escape as its literal text instead of the character it stands for, so the reader sees the escape where the angle bracket or ampersand belongs. Wrap the prompt body in a backtick code fence and write the characters directly.\n' "$file" "$turn_start_line"
            violations="${violations}1"
          fi
          # Check 3b: Script-write coupling (runner-conditional). JSONL has the
          # real tool_use trace, so pass turn_tool_uses for the full coupling
          # check — same evidence shape as the fence-write coupling call above.
          msg=$(validate_script_write_coupling "$turn_text" "$turn_tool_uses") || {
            printf '%s:%s: SCRIPT-WRITE: %s\n' "$file" "$turn_start_line" "$msg"
            violations="${violations}1"
          }
          # Check 4: Voice patterns (always-on).
          # display_line=turn_start_line — within-turn line offsets don't
          # map back to JSONL lines (turn_text is concatenated from many
          # JSON records), so all violations are pinned to the turn boundary.
          local voice_msg_turn
          voice_msg_turn=$(validate_voice_patterns "$turn_text" "$file" "$turn_start_line") || {
            printf '%s\n' "$voice_msg_turn"
            violations="${violations}1"
          }
          # Check: LEAK-TERM (always-on, JSONL assistant messages only — see
          # check_leak_terms header; never called from lint_markdown_file).
          local leak_msg_turn
          leak_msg_turn=$(check_leak_terms "$turn_text" "$file" "$turn_start_line") || {
            printf '%s\n' "$leak_msg_turn"
            violations="${violations}1"
          }
          # Check: Actor-ownership ambiguity (warn-only — see hooks/lib/
          # validators.sh). Covers both assistant prose and AskUserQuestion
          # option labels/descriptions, since the failure shape ("I'll clean
          # it up" as an option label) has appeared in tool-call text, not
          # just prose.
          local actor_msg_turn
          actor_msg_turn=$(validate_actor_ownership "${turn_text} ${turn_auq_payload}" "$file" "$turn_start_line") || {
            printf '%s\n' "$actor_msg_turn"
          }
        fi
        # Reset for next turn
        turn_text=""
        turn_tool_uses=""
        turn_auq_payload=""
        has_auq="false"
        turn_line_anchored="false"
        continue
      fi

      # Accumulate assistant text blocks and tool_use records.
      # Only records the assistant actually authored are evaluated. A record of
      # type "user" carries text the person typed or a command body the harness
      # re-injected, and any record flagged isMeta is harness-generated — neither
      # is SP voice, so neither may reach the validators. Turn segmentation above
      # still uses those records; this gate governs what gets judged.
      #
      # Line attribution: turn_start_line is anchored HERE, to this turn's
      # first assistant/non-meta record, instead of to the preceding
      # user-turn-boundary line. A reported violation's file:line must itself
      # be an assistant, non-meta entry — not the isMeta/user line that
      # happened to start the segment.
      if [ "$entry_type" = "assistant" ] && [ "$is_meta" != "true" ]; then
        if [ "$turn_line_anchored" = "false" ]; then
          turn_start_line=$lineno
          turn_line_anchored="true"
        fi
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
        # Extract AUQ option/question text (actor-ownership check needs the
        # option labels/descriptions, not just presence — see Check: Actor-
        # ownership ambiguity in hooks/lib/validators.sh).
        local block_auq_payload
        block_auq_payload=$(printf '%s' "$line" | jq -r '(.message.content // .content // [])[] | select(.type=="tool_use" and .name=="AskUserQuestion") | (.input.questions // []) | map((.question // "") + " " + (.header // "") + " " + ((.options // []) | map((.label // "") + " " + (.description // "")) | join(" "))) | join(" ")' 2>/dev/null)
        if [ -n "$block_auq_payload" ]; then
          turn_auq_payload="${turn_auq_payload} ${block_auq_payload}"
        fi
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
            local advisor_msg_final
            if ! advisor_msg_final=$(validate_advisor_launcher "$turn_text"); then
              printf '%s:%s: FENCE-ADVISOR: %s\n' "$file" "$turn_start_line" "$advisor_msg_final"
              violations="${violations}1"
            fi
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
            # JSONL final turn → chat text only; require the full table in chat.
            if ! check_closure_table_in_chat "$turn_text"; then
              printf '%s:%s: FENCE-HANDOFF: handoff-continuation fence without the full Closure Walk Status table rendered in chat text (collapsed closure — the 8-group table must appear inline before the continuation fence per SKILL.md Auto-dispatch step 2).\n' "$file" "$turn_start_line"
              violations="${violations}1"
            fi
            ;;
          documentation)
            : # skip
            ;;
        esac
      fi
      # Check 3a: HTML entity escapes in a fence body (final turn,
      # self-gating — see the markdown call site).
      if ! check_entity_escapes_in_fence "$turn_text"; then
        printf '%s:%s: FENCE-ENTITY: copyable prompt fence contains HTML entity escapes in its body. A terminal renders an escape as its literal text instead of the character it stands for, so the reader sees the escape where the angle bracket or ampersand belongs. Wrap the prompt body in a backtick code fence and write the characters directly.\n' "$file" "$turn_start_line"
        violations="${violations}1"
      fi
      # Check 3b: Script-write coupling (runner-conditional, final turn).
      # Same tool_use-trace evidence shape as the fence-write coupling call.
      msg=$(validate_script_write_coupling "$turn_text" "$turn_tool_uses") || {
        printf '%s:%s: SCRIPT-WRITE: %s\n' "$file" "$turn_start_line" "$msg"
        violations="${violations}1"
      }
      # Check 4: Voice patterns (always-on, final turn).
      local voice_msg_final
      voice_msg_final=$(validate_voice_patterns "$turn_text" "$file" "$turn_start_line") || {
        printf '%s\n' "$voice_msg_final"
        violations="${violations}1"
      }
      # Check: LEAK-TERM (always-on, JSONL assistant messages only, final turn).
      local leak_msg_final
      leak_msg_final=$(check_leak_terms "$turn_text" "$file" "$turn_start_line") || {
        printf '%s\n' "$leak_msg_final"
        violations="${violations}1"
      }
      # Check: Actor-ownership ambiguity (warn-only, final turn).
      local actor_msg_final
      actor_msg_final=$(validate_actor_ownership "${turn_text} ${turn_auq_payload}" "$file" "$turn_start_line") || {
        printf '%s\n' "$actor_msg_final"
      }
    fi

    # Lifecycle absence checks share the runtime detector. Unlike the Stop
    # hook, lint has no per-session floor marker, so startup lint verifies the
    # visible recenter and AUQ while treating floor execution as externally
    # established by the activation hook.
    if [ "$CEREMONY_OK" = true ] && sp_transcript_has_current_startup_activation "$file"; then
      local ceremony_last_text
      local startup_missing
      ceremony_last_text=$(jq -sr '
        [ .[] | select((.message.role // .role // "") == "assistant") ]
        | last
        | (.message.content // .content // [])
        | if type == "array" then map(select(.type == "text") | .text) | join("\n") else . end
      ' "$file" 2>/dev/null)
      startup_missing=$(sp_startup_missing_evidence "$file" "$ceremony_last_text" "" "yes")
      if [ -n "$startup_missing" ]; then
        printf '%s:1: STARTUP-CEREMONY: direct SP startup is missing %s.\n' "$file" "$startup_missing"
        violations="${violations}1"
      fi
    fi

    if [ "$CEREMONY_OK" = true ] && sp_transcript_has_session_end_intent "$file"; then
      local closure_missing
      closure_missing=$(sp_closure_missing_evidence "$file")
      if [ -n "$closure_missing" ]; then
        printf '%s:1: CLOSURE-CEREMONY: explicit session end is missing %s.\n' "$file" "$closure_missing"
        violations="${violations}1"
      fi
    fi
  else
    # No jq: grep-based heuristic (less precise but avoids hard dependency).
    # Without jq we cannot extract structured tool_use records, so the coupling
    # check falls back to a textual proxy — looking for `last-prompts/` substring
    # anywhere in the assembled assistant text. This is conservative (may miss
    # violations where the substring appears for unrelated reasons) but matches
    # the pre-v5.14.0 fallback behaviour.
    # Role/isMeta filter (no-jq fallback) — mirrors the jq path's assistant-
    # only, isMeta-excluded gate. Each JSONL line is one complete JSON
    # record, so a per-line substring test on the record's own compact
    # "type":"..." / "isMeta":... fields is reliable for records Claude Code
    # writes itself (verified compact, no inner whitespace, against the
    # actual transcript format). It is NOT full JSON parsing, so it is
    # deliberately default-exclude: a line is kept ONLY when it positively
    # matches "type":"assistant" AND does not contain "isMeta":true. Without
    # jq there is no way to tell whether a stray "type":"assistant" substring
    # sits in the record's own top-level field or inside a user's quoted
    # prose — default-exclude means that ambiguity resolves toward dropping
    # the line, not toward flagging user-authored text.
    local assistant_lines
    assistant_lines=$(_filter_assistant_lines "$file")
    local full_text
    full_text=$(printf '%s\n' "$assistant_lines" | grep '"type":"text"' 2>/dev/null | grep -o '"text":"[^"]*"' | cut -d'"' -f4 | tr '\n' ' ')
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
          local advisor_msg_nojq
          if ! advisor_msg_nojq=$(validate_advisor_launcher "$full_text"); then
            printf '%s:?: FENCE-ADVISOR: %s\n' "$file" "$advisor_msg_nojq"
            violations="${violations}1"
          fi
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
          # No-jq fallback: full_text is grep-extracted assistant text only
          # (from "type":"text" blocks), so it is chat-text-scoped too —
          # require the full table in chat, same as the jq path.
          if ! check_closure_table_in_chat "$full_text"; then
            printf '%s:?: FENCE-HANDOFF: handoff-continuation fence without the full Closure Walk Status table rendered in chat text (collapsed closure — the 8-group table must appear inline before the continuation fence per SKILL.md Auto-dispatch step 2).\n' "$file"
            violations="${violations}1"
          fi
          ;;
        documentation)
          : # skip
          ;;
      esac
      # No FENCE-ENTITY gate on this path. full_text has its newlines collapsed
      # to spaces, so the fence-body walk (which needs the START and END markers
      # on separate lines) can never isolate a body here — the call would be
      # dead code. Same documented conservatism as the coupling proxies below.
    fi
    # Check 3b: Script-write coupling (runner-conditional, no-jq fallback).
    # No structured tool_use trace and newlines are collapsed to spaces, so
    # this is conservative (the validator's line-shape detection rarely fires
    # on space-joined text) — mirrors the documented conservatism of the
    # fence-write coupling no-jq proxy. Empty records = real-runner detector;
    # a .scripts/ write-reference substring clears it.
    case "$full_text" in
      *".scripts/"*)
        if ! msg=$(validate_script_write_coupling "$full_text" "") 2>/dev/null; then
          case "$full_text" in
            *"Write"*".scripts/"*|*"Edit"*".scripts/"*|*"MultiEdit"*".scripts/"*)
              : # write reference present — pass (no-jq proxy)
              ;;
            *)
              printf '%s:?: SCRIPT-WRITE: %s (no-jq fallback proxy).\n' "$file" "$msg"
              violations="${violations}1"
              ;;
          esac
        fi
        ;;
    esac
    # Check 4: Voice patterns (always-on, no-jq fallback).
    # full_text here has newlines collapsed to spaces, so within-text line
    # numbers are meaningless — display_line="?" matches the existing
    # no-jq fallback convention used by the AUQ and tool-availability checks.
    local voice_msg_nojq
    voice_msg_nojq=$(validate_voice_patterns "$full_text" "$file" "?") || {
      printf '%s\n' "$voice_msg_nojq"
      violations="${violations}1"
    }
    # Check: LEAK-TERM (always-on, JSONL assistant messages only, no-jq
    # fallback). full_text above is already role/isMeta-filtered.
    local leak_msg_nojq
    leak_msg_nojq=$(check_leak_terms "$full_text" "$file" "?") || {
      printf '%s\n' "$leak_msg_nojq"
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
total_warnings=0
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
    # Warn-vs-mechanical split (matches tests/lint-voice.sh): every warn-only
    # output line carries the shared ": WARN —" marker. Warnings display but
    # never fail the lint or count toward files_with_violations.
    local n warn_n mech_n
    n=$(printf '%s\n' "$output" | grep -c ':' || true)
    warn_n=$(printf '%s\n' "$output" | grep -c ': WARN —' || true)
    [ -z "$n" ] && n=0
    [ -z "$warn_n" ] && warn_n=0
    mech_n=$(( n - warn_n ))
    if [ "$mech_n" -gt 0 ]; then
      files_with_violations=$(( files_with_violations + 1 ))
      total_violations=$(( total_violations + mech_n ))
    fi
    total_warnings=$(( total_warnings + warn_n ))
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
  printf 'Transcript lint: %d violation(s) found across %d of %d file(s) (%d warning(s))\n\n' \
    "$total_violations" "$files_with_violations" "$total_files" "$total_warnings"
  printf '%s\n' "$all_violation_lines"
  exit 1
fi

if [ "$total_warnings" -gt 0 ]; then
  printf 'Transcript lint: %d file(s) checked, 0 mechanical violations, %d warning(s):\n\n' \
    "$total_files" "$total_warnings"
  printf '%s\n' "$all_violation_lines"
  exit 0
fi

printf 'Transcript lint: %d file(s) checked, all clean.\n' "$total_files"
exit 0
