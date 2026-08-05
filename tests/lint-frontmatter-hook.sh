#!/usr/bin/env bash
# tests/lint-frontmatter-hook.sh — Release-time fail-closed lint:
# no literal triple-dash inside the SKILL.md YAML frontmatter.
#
# Why this exists
# ---------------
# SKILL.md carries an inline UserPromptSubmit hook command inside its YAML
# frontmatter block. The harness's frontmatter parser treats ANY line that
# contains three-or-more consecutive ASCII hyphens (`---`) as a YAML document
# separator — even inside an awk regex, a quoted string, or a `#` comment.
# When that happens mid-frontmatter, the inline hook command is truncated at
# that point; the shell then receives an unterminated quote and BLOCKS EVERY
# NEW SESSION with a raw-hook dump.
#
# This bit production via commit c53d530 (literal `/^---$/` in an awk pattern)
# and survived the first surgical fix fd6dff7 (the fix's own warning comment
# re-introduced a literal `---`). Scoped human review kept inspecting *the
# change* and missing *the invariant*. This lint checks the invariant
# mechanically, every release, immune to where anyone thinks the problem is.
#
# The invariant (exact)
# ---------------------
# SKILL.md opens with a YAML frontmatter block: line 1 is exactly `---`, and
# the block ends at the next standalone `---` line. Between those two
# delimiter lines (exclusive), there must be NO line containing three-or-more
# consecutive hyphens. The two delimiter lines themselves are allowed (they
# ARE the delimiters); anything else with `---` is a FAIL.
#
# Fail-closed posture
# -------------------
# Any of these conditions exits non-zero (release-blocking):
#   - a triple-dash on a non-delimiter line inside the frontmatter
#   - line 1 is not exactly `---` (no valid frontmatter to verify)
#   - no closing `---` delimiter found (unterminated frontmatter — the exact
#     symptom of the bug this lint guards against)
#
# Self-safety
# -----------
# This script's OWN source legitimately contains the pattern it greps for
# (see this header). It scans ONLY the target SKILL.md — never itself, never
# any other file. The target is resolved relative to the script (repo root)
# or taken from an explicit path argument; no hardcoded absolute paths.
#
# bash 3.2 compatible (macOS): no associative arrays, no mapfile, no nameref.
#
# Exit codes:
#   0 — clean (no triple-dash in the frontmatter hook region)
#   1 — one or more violations, or malformed/unterminated frontmatter
#
# Output format (per-violation line, grep-friendly):
#   <line-number>: <line-content>
#
# Usage:
#   bash tests/lint-frontmatter-hook.sh                 # lint repo SKILL.md
#   bash tests/lint-frontmatter-hook.sh path/to/file    # lint a specific file
#   git show <rev>:SKILL.md | bash tests/lint-frontmatter-hook.sh -   # stdin

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Resolve the target file.
#   (no arg)  -> repo-root SKILL.md (resolved relative to this script)
#   <path>    -> that file
#   -         -> read stdin into a temp file (for `git show <rev>:SKILL.md |`)
# A stdin temp file is cleaned up on exit via trap.
# ---------------------------------------------------------------------------
STDIN_TMP=""
cleanup() {
  [ -n "$STDIN_TMP" ] && [ -f "$STDIN_TMP" ] && rm -f "$STDIN_TMP"
}
trap cleanup EXIT

if [ "$#" -eq 0 ]; then
  TARGET="${SCRIPT_DIR}/SKILL.md"
elif [ "$1" = "-" ]; then
  STDIN_TMP="$(mktemp "${TMPDIR:-/tmp}/lint-frontmatter-hook.XXXXXX")" || {
    printf 'Frontmatter-hook lint: could not create temp file for stdin. Aborting (fail-closed).\n' >&2
    exit 1
  }
  cat > "$STDIN_TMP"
  TARGET="$STDIN_TMP"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  sed -n '2,70p' "$0" | sed 's/^# \?//'
  exit 0
else
  TARGET="$1"
fi

if [ ! -f "$TARGET" ]; then
  printf 'Frontmatter-hook lint: target not found: %s. Aborting (fail-closed).\n' "$TARGET" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Validate the opening delimiter: line 1 must be exactly `---`.
# A file that does not open with a frontmatter block has no hook to verify;
# treat it as malformed and fail closed.
# ---------------------------------------------------------------------------
FIRST_LINE=$(sed -n '1p' "$TARGET")
if [ "$FIRST_LINE" != "---" ]; then
  printf 'Frontmatter-hook lint: %s line 1 is not exactly "---" (got: %s). No valid YAML frontmatter to verify. Aborting (fail-closed).\n' \
    "$TARGET" "$FIRST_LINE" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate the closing delimiter: the first standalone `^---[[:space:]]*$`
# line at or after line 2. awk reports its line number; empty = none found.
# ---------------------------------------------------------------------------
CLOSE_LINE=$(awk 'NR>1 && /^---[[:space:]]*$/ { print NR; exit }' "$TARGET")
if [ -z "$CLOSE_LINE" ]; then
  printf 'Frontmatter-hook lint: %s has no closing "---" delimiter after line 1. Frontmatter is unterminated — this is the exact failure mode the lint guards. Aborting (fail-closed).\n' \
    "$TARGET" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Scan every line STRICTLY BETWEEN the opener (line 1) and the closing
# delimiter (CLOSE_LINE), exclusive of both, for three-or-more consecutive
# hyphens. awk emits "<lineno>\t<content>"; grep -E -- '-{3,}' flags the
# pattern. The leading `--` keeps grep from parsing the pattern as a flag.
# ---------------------------------------------------------------------------
# NOTE: `close` is a reserved built-in function name in awk — using it as a
# variable bails out BWK awk (macOS) with a syntax error, which would make
# this gate fail OPEN. The bound variable is named `endln` for that reason.
VIOLATIONS=$(awk -v endln="$CLOSE_LINE" \
  'NR>1 && NR<endln { print NR "\t" $0 }' "$TARGET" \
  | grep -E -- '-{3,}' || true)

if [ -n "$VIOLATIONS" ]; then
  printf 'Frontmatter-hook lint: FAIL — literal triple-dash found inside the SKILL.md frontmatter hook region (lines 2-%d):\n\n' \
    "$((CLOSE_LINE - 1))" >&2
  # Reformat "<lineno><TAB><content>" -> "<lineno>: <content>"
  printf '%s\n' "$VIOLATIONS" | while IFS="$(printf '\t')" read -r lnum lcontent; do
    printf '  %s: %s\n' "$lnum" "$lcontent" >&2
  done
  printf '\nA literal triple-dash inside the frontmatter inline hook is read by the YAML\n' >&2
  printf 'parser as a document separator — it truncates the hook and blocks every new\n' >&2
  printf 'session. In awk patterns use the brace form (e.g. /^-{3}$/), and never type a\n' >&2
  printf 'literal triple-dash in comments or strings inside the frontmatter.\n' >&2
  exit 1
fi

printf 'Frontmatter-hook lint: OK — %s frontmatter (lines 2-%d) has no literal triple-dash.\n' \
  "$TARGET" "$((CLOSE_LINE - 1))"
exit 0
