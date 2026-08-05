#!/usr/bin/env bash
# tests/lint-voice.sh — Release-time voice lint for user-facing artifacts.
#
# Scans CHANGELOG.md, README.md, and commands/*.md for jargon-loaded patterns
# that violate the User-Facing Voice Rules in CLAUDE.md (line-numbered text
# scanner; see CLAUDE.md "User-Facing Voice Rules" section). Distinct from
# tests/lint-transcripts.sh: that script scans conversation transcripts for
# behavior violations; this one scans static documents for voice quality.
#
# Mechanical patterns (each is a release-blocking violation):
#   1. FUNCTION-CALL-IN-PROSE       — \w+_\w+\(\) outside code blocks
#   2. INCIDENT-ID-IN-PROSE         — INC-\d{4}-\d{2}-\d{2} outside code blocks
#   3. DIRECTION-REF                — Direction\s+\d+ outside code blocks
#   4. LAYER-REF                    — Layer\s+\d+ outside code blocks
#   5. RAW-LINE-REF                 — line\s+~?\d+ outside code blocks
#   6. DELIVERABLE-REF              — deliverable\s+\d+ (lowercase) outside code blocks
#   7. PLACEHOLDER-STRING-IN-PROSE  — [Populated at...]/[TODO]/[PENDING]/[FIXME]/[XXX] markers
#   8. CONTRADICTORY-STATUS-ROW     — ✅ rendered alongside an in-row admission
#                                     verification didn't happen (Dryness Ban
#                                     List pattern 9 in the output style)
#   9. STATUS-BRIEFING-SINGLE-SURFACE — status command tells the model to put
#                                      the full briefing only in the question
#   10. STATUS-COMMAND-DRIFT          — standalone and plugin status commands
#                                      differ beyond command namespace
#
# Heuristic patterns (warn-only, do not fail the lint):
#   INTERNAL-TERM-WITHOUT-GLOSS — first occurrence of an internal term
#     without a gloss-shaped follow-up in the same paragraph.
#   ACTOR-OWNERSHIP-AMBIGUITY — an action-ownership sentence ("who does
#     what", next steps, hand-offs) phrased with "I"/"you"/"me" instead of
#     naming the actor (SP / the user / the executor). Permissive on
#     purpose; warn-only, does not fail the lint.
#
# Every warn-only output line carries the shared marker ": WARN —". The
# warn-vs-mechanical count splits on that marker, so adding a warn-only
# pattern never inflates the release-blocking mechanical count.
#
# Skip-block markers (HTML comments) suppress scanning for an inline range:
#   <!-- voice-lint:skip-start -->
#   ...content not scanned...
#   <!-- voice-lint:skip-end -->
#
# Exit codes:
#   0 — clean (or warnings only)
#   1 — one or more mechanical violations found
#
# Output format (per-violation line, grep-friendly):
#   <file>:<line>: <TYPE>: <description>
#
# Usage:
#   bash tests/lint-voice.sh                 # scan all targets
#   bash tests/lint-voice.sh --target CHANGELOG
#   bash tests/lint-voice.sh --target README
#   bash tests/lint-voice.sh --target commands
#   bash tests/lint-voice.sh path/to/file.md # lint a specific file (used by fixtures)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_FILE="${SCRIPT_DIR}/hooks/lib/validators.sh"

# ---------------------------------------------------------------------------
# Source the shared validators library so future helpers stay in one place
# and the lint stays aligned with the release-time linter posture. The voice
# lint uses _strip_non_prose() in the heuristic check; mechanical patterns
# need exact line numbers and walk the file directly with their own toggle
# (same rule as _strip_non_prose, line numbers preserved).
# ---------------------------------------------------------------------------
if [ -f "$LIB_FILE" ]; then
  # shellcheck source=hooks/lib/validators.sh
  . "$LIB_FILE"
else
  printf 'ERROR: hooks/lib/validators.sh not found at %s\n' "$LIB_FILE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Internal terms tracked by the heuristic check. First occurrence in a file
# without a gloss-shaped follow-up in the same paragraph fires a WARN.
# Order matters only insofar as longer phrases must be checked before their
# shorter constituents; the matcher uses substring containment, not regex.
# ---------------------------------------------------------------------------
INTERNAL_TERMS=(
  "closure ledger"
  "evidence ledger"
  "typed envelope"
  "fence-write coupling"
  "pipeline stage"
  "Fast Lane"
  "Bootstrap"
  "Router"
  "Egress"
  "envelope"
  "ledger"
  "trigger"
  "hops"
)

# Gloss-shaped indicators looked for within the same paragraph as the term.
# Permissive on purpose — heuristic is warn-only. False positives are cheaper
# than false negatives here.
GLOSS_INDICATORS=(
  "("       # parenthetical gloss
  "—"      # em-dash phrase
  " -- "    # double-dash phrase
  "what we call"
  "called"
  "meaning"
  "which is"
  "i.e."
  "e.g."
  "is the"
  "is a"
  "are the"
  "are a"
)

# ---------------------------------------------------------------------------
# Scan a single file for mechanical patterns.
#
# Thin wrapper over validate_voice_patterns in hooks/lib/validators.sh so
# the regex set lives in exactly one place. The helper preserves line
# numbers, tracks code-block / skip-block state, and emits violation lines
# in the same format used by the transcript lint.
#
# Emits violation lines on stdout. Returns 0 always (caller counts violations).
# ---------------------------------------------------------------------------
scan_mechanical() {
  local file="$1"
  local content
  content=$(cat "$file")
  validate_voice_patterns "$content" "$file"
  return 0
}

# ---------------------------------------------------------------------------
# Status command contract scan. This protects the regression where the recenter
# was instructed to live only inside AskUserQuestion, leaving no useful visible
# brief before the question widget.
# ---------------------------------------------------------------------------
scan_status_command_contract() {
  local file="$1"
  case "$file" in
    */commands/status.md) ;;
    *) return 0 ;;
  esac

  if grep -qF 'Show the full briefing in the question description.' "$file"; then
    printf '%s:%d: STATUS-BRIEFING-SINGLE-SURFACE: Status must show a visible briefing before AskUserQuestion; do not put the full briefing only in the question description.\n' \
      "$file" "$(grep -nF 'Show the full briefing in the question description.' "$file" | head -1 | cut -d: -f1)"
  fi

  if ! grep -qF 'visible briefing in normal chat' "$file"; then
    printf '%s:1: STATUS-BRIEFING-SINGLE-SURFACE: Status command must require a visible briefing in normal chat before AskUserQuestion.\n' "$file"
  fi

  if ! grep -qF 'compact context echo' "$file"; then
    printf '%s:1: STATUS-BRIEFING-SINGLE-SURFACE: Status command must require a compact context echo inside the question/options.\n' "$file"
  fi
}

# ---------------------------------------------------------------------------
# Heuristic scan: first-occurrence-without-gloss for each internal term.
# Walks the file in paragraph blocks (consecutive non-empty lines outside
# code/skip blocks). For each paragraph, checks if any tracked term appears.
# If the term hasn't been seen before in this file, AND the paragraph
# contains no gloss indicator after the term, emit a WARN.
#
# Returns 0 always (warnings only, never fail the lint).
# ---------------------------------------------------------------------------
scan_heuristic() {
  local file="$1"
  local in_code=0
  local in_skip=0
  local lineno=0
  local para_start=0
  local para_text=""
  # Track which terms have been seen (first occurrence is the only one warned).
  local seen_terms=""

  process_paragraph() {
    [ -z "$para_text" ] && return 0
    local term
    for term in "${INTERNAL_TERMS[@]}"; do
      # Skip if already seen
      case "$seen_terms" in
        *"<${term}>"*) continue ;;
      esac
      # Look for term in the paragraph (case-sensitive — internal terms are
      # capitalised meaningfully, e.g. Bootstrap, Fast Lane).
      case "$para_text" in
        *"$term"*) ;;
        *) continue ;;
      esac
      # Mark seen
      seen_terms="${seen_terms}<${term}>"
      # Look for any gloss indicator in the paragraph
      local has_gloss=0
      local indicator
      for indicator in "${GLOSS_INDICATORS[@]}"; do
        case "$para_text" in
          *"$indicator"*) has_gloss=1; break ;;
        esac
      done
      if [ "$has_gloss" -eq 0 ]; then
        printf '%s:%d: INTERNAL-TERM-WITHOUT-GLOSS: WARN — first mention of "%s" appears without a gloss in the same paragraph. Add a parenthetical or em-dash gloss the first time the term appears so a non-developer can follow.\n' \
          "$file" "$para_start" "$term"
      fi
    done
  }

  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$(( lineno + 1 ))

    # Skip-block toggle
    case "$line" in
      *"voice-lint:skip-start"*) in_skip=1; process_paragraph; para_text=""; para_start=0; continue ;;
      *"voice-lint:skip-end"*)   in_skip=0; continue ;;
    esac
    [ "$in_skip" -eq 1 ] && continue

    # Code-block toggle
    case "$line" in
      '```'*)
        in_code=$(( 1 - in_code ))
        process_paragraph
        para_text=""; para_start=0
        continue
        ;;
    esac
    [ "$in_code" -eq 1 ] && continue

    # Blockquote — treat as paragraph break
    case "$line" in
      '>'*)
        process_paragraph
        para_text=""; para_start=0
        continue
        ;;
    esac

    # Empty line = paragraph boundary
    if [ -z "$line" ]; then
      process_paragraph
      para_text=""; para_start=0
      continue
    fi

    # Accumulate paragraph
    if [ "$para_start" -eq 0 ]; then
      para_start="$lineno"
      para_text="$line"
    else
      para_text="${para_text} ${line}"
    fi
  done < "$file"

  # Final paragraph
  process_paragraph
}

# ---------------------------------------------------------------------------
# Heuristic scan: actor-ownership ambiguity. Thin wrapper around the shared
# validate_actor_ownership in hooks/lib/validators.sh — see that function
# for the regex and rationale. Warn-only: return value is ignored by callers.
# ---------------------------------------------------------------------------
scan_actor_ownership() {
  local file="$1"
  local content
  content=$(cat "$file")
  validate_actor_ownership "$content" "$file"
  return 0
}

# ---------------------------------------------------------------------------
# Lint a single file. Runs both scans, accumulates output, returns exit code.
#   0 = clean (or warnings only)
#   1 = mechanical violations found
# ---------------------------------------------------------------------------
lint_file() {
  local file="$1"
  [ -f "$file" ] || return 0

  local mech_output
  mech_output=$(scan_mechanical "$file")
  local status_contract_output
  status_contract_output=$(scan_status_command_contract "$file")
  local heur_output
  heur_output=$(scan_heuristic "$file")
  local actor_output
  actor_output=$(scan_actor_ownership "$file")

  if [ -n "$mech_output" ]; then
    printf '%s\n' "$mech_output"
  fi
  if [ -n "$status_contract_output" ]; then
    printf '%s\n' "$status_contract_output"
  fi
  if [ -n "$heur_output" ]; then
    printf '%s\n' "$heur_output"
  fi
  if [ -n "$actor_output" ]; then
    printf '%s\n' "$actor_output"
  fi

  if [ -n "$mech_output" ] || [ -n "$status_contract_output" ]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Root/plugin status command drift scan. The command content is supposed to
# stay identical after normalizing the command namespace, so the plugin cannot
# quietly lose the restored briefing shape again.
# ---------------------------------------------------------------------------
check_status_command_parity() {
  local root_status="${SCRIPT_DIR}/commands/status.md"
  local plugin_status="${SCRIPT_DIR}/plugin/strategic-partner/commands/status.md"
  [ -f "$root_status" ] || return 0
  [ -f "$plugin_status" ] || return 0

  local root_tmp plugin_tmp diff_tmp
  root_tmp=$(mktemp "/tmp/sp-status-root.XXXXXX") || return 0
  plugin_tmp=$(mktemp "/tmp/sp-status-plugin.XXXXXX") || return 0
  diff_tmp=$(mktemp "/tmp/sp-status-diff.XXXXXX") || return 0

  sed 's#/strategic-partner-plugin:#/strategic-partner:#g' "$root_status" > "$root_tmp"
  sed 's#/strategic-partner-plugin:#/strategic-partner:#g' "$plugin_status" > "$plugin_tmp"

  if ! diff -u "$root_tmp" "$plugin_tmp" > "$diff_tmp"; then
    printf '%s:1: STATUS-COMMAND-DRIFT: standalone and plugin status commands differ after command namespace normalization.\n' "$plugin_status"
    sed -n '1,40p' "$diff_tmp" | sed "s#^#${plugin_status}:1: STATUS-COMMAND-DRIFT: #"
  fi

  rm -f "$root_tmp" "$plugin_tmp" "$diff_tmp"
}

# ---------------------------------------------------------------------------
# Collect target files based on --target flag (or default = all targets).
# ---------------------------------------------------------------------------
collect_targets() {
  local target="$1"
  case "$target" in
    CHANGELOG)
      [ -f "${SCRIPT_DIR}/CHANGELOG.md" ] && printf '%s\n' "${SCRIPT_DIR}/CHANGELOG.md"
      ;;
    README)
      [ -f "${SCRIPT_DIR}/README.md" ] && printf '%s\n' "${SCRIPT_DIR}/README.md"
      ;;
    commands)
      if [ -d "${SCRIPT_DIR}/commands" ]; then
        find "${SCRIPT_DIR}/commands" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort
      fi
      ;;
    output-styles)
      if [ -d "${SCRIPT_DIR}/output-styles" ]; then
        find "${SCRIPT_DIR}/output-styles" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort
      fi
      ;;
    all)
      collect_targets CHANGELOG
      collect_targets README
      collect_targets commands
      collect_targets output-styles
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Argument parsing.
#   --target {CHANGELOG|README|commands|output-styles}   restrict scope
#   <path>                                  lint a specific file
#   (no args)                               scan all targets
# ---------------------------------------------------------------------------
TARGET="all"
EXPLICIT_FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --help|-h)
      sed -n '2,40p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      EXPLICIT_FILES+=("$1")
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Main: collect files, lint each, aggregate.
# ---------------------------------------------------------------------------
total_files=0
total_mech_violations=0
total_warnings=0
all_output=""

if [ "${#EXPLICIT_FILES[@]}" -gt 0 ]; then
  # Explicit file mode: verify each file exists. Fail-closed if any path is
  # bogus — the caller asked for a specific file by name and silently skipping
  # it would mask configuration errors.
  for explicit_f in "${EXPLICIT_FILES[@]}"; do
    if [ ! -f "$explicit_f" ]; then
      printf 'Voice lint: file not found: %s\n' "$explicit_f" >&2
      exit 1
    fi
  done
  files_to_lint=$(printf '%s\n' "${EXPLICIT_FILES[@]}")
else
  files_to_lint=$(collect_targets "$TARGET")
fi

while IFS= read -r f; do
  [ -z "$f" ] && continue
  total_files=$(( total_files + 1 ))
  output=$(lint_file "$f")
  rc=$?
  if [ -n "$output" ]; then
    # Count violations (mechanical) vs warnings (heuristic) in this file.
    # Every warn-only output line carries the shared marker ": WARN —"; any
    # line without it is a mechanical (release-blocking) violation. Splitting
    # on the shared marker keeps the count correct as new warn-only patterns
    # are added — no per-type string hardcoded here.
    mech_count=$(printf '%s\n' "$output" | grep -cv ': WARN —' || true)
    warn_count=$(printf '%s\n' "$output" | grep -c ': WARN —' || true)
    # grep -c may return non-zero on no match; default to 0
    [ -z "$mech_count" ] && mech_count=0
    [ -z "$warn_count" ] && warn_count=0
    total_mech_violations=$(( total_mech_violations + mech_count ))
    total_warnings=$(( total_warnings + warn_count ))
    all_output="${all_output}${output}
"
  fi
  # rc reserved for future use (per-file exit codes)
  : "$rc"
done <<EOF
$files_to_lint
EOF

if [ "${#EXPLICIT_FILES[@]}" -eq 0 ] \
   && { [ "$TARGET" = "all" ] || [ "$TARGET" = "commands" ]; }; then
  parity_output=$(check_status_command_parity)
  if [ -n "$parity_output" ]; then
    parity_count=$(printf '%s\n' "$parity_output" | grep -cv ': WARN —' || true)
    [ -z "$parity_count" ] && parity_count=0
    total_mech_violations=$(( total_mech_violations + parity_count ))
    all_output="${all_output}${parity_output}
"
  fi
fi

# ---------------------------------------------------------------------------
# Fail-closed sentinel: if we asked the lint to scan everything by default
# (no --target flag, no explicit files) and the loop above produced zero
# iterations, but the project's expected user-facing files are present on
# disk, abort with exit 1. A release-time gate that silently reports "all
# clean" when it never actually scanned anything is the most dangerous
# failure mode (e.g., broken find, hostile environment, missing TMPDIR).
# ---------------------------------------------------------------------------
if [ "$total_files" -eq 0 ] \
   && [ "$TARGET" = "all" ] \
   && [ "${#EXPLICIT_FILES[@]}" -eq 0 ]; then
  if [ -f "${SCRIPT_DIR}/CHANGELOG.md" ] \
     || [ -f "${SCRIPT_DIR}/README.md" ] \
     || [ -d "${SCRIPT_DIR}/commands" ]; then
    printf 'Voice lint: scan failed — zero files collected, but expected files exist in %s. Aborting (fail-closed).\n' \
      "$SCRIPT_DIR" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if [ "$total_mech_violations" -gt 0 ]; then
  printf 'Voice lint: %d mechanical violation(s) and %d warning(s) found across %d file(s)\n\n' \
    "$total_mech_violations" "$total_warnings" "$total_files"
  printf '%s\n' "$all_output"
  exit 1
fi

if [ "$total_warnings" -gt 0 ]; then
  printf 'Voice lint: %d file(s) checked, 0 mechanical violations, %d warning(s):\n\n' \
    "$total_files" "$total_warnings"
  printf '%s\n' "$all_output"
  exit 0
fi

printf 'Voice lint: %d file(s) checked, all clean.\n' "$total_files"
exit 0
