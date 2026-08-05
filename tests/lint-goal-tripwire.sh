#!/usr/bin/env bash
# tests/lint-goal-tripwire.sh — Release-time fail-closed lint:
# no EXECUTABLE /goal line in any copyable or runnable artifact.
#
# Why this exists
# ---------------
# Claude Code's `/goal <finish-line>` puts a session into autonomous mode. SP may
# RECOMMEND it (a chat-only "goal-mode option" — see SKILL.md § Goal-Mode Option),
# but SP must NEVER write an executable `/goal` line into anything that can be
# pasted or fired on resume. An executable line in such an artifact could launch
# autonomous mode unexpectedly. This lint enforces that invariant mechanically,
# every release, so the safety property does not rest on author discipline alone.
#
# The invariant (exact)
# ---------------------
# An EXECUTABLE `/goal` line is one that begins (after optional leading spaces/tabs)
# with `/goal` followed by a word boundary — i.e. it matches:
#     ^[ \t]*/goal([^A-Za-z0-9_]|$)
# A mid-line or backtick-wrapped mention ("the `/goal` line", "explains /goal usage")
# does NOT match the line-start anchor and is exempt — prose may discuss `/goal`
# freely. Only a bare, runnable, line-start `/goal` is a violation.
#
# Four covered locations (a violation in ANY fails the release):
#   1. ══ COPY fences anywhere in source: SKILL.md, plus ANY file (not just .md)
#      under references/, commands/, assets/ — flagged only INSIDE a
#      `START 🟢 COPY` / `END 🛑 COPY` fence. Binary files (e.g. images) are
#      skipped: they carry no readable fence and are not pasteable artifacts.
#   2. .handoffs/last-prompts/**  — whole-file (these files ARE prompt content).
#   3. .prompts/**                — whole-file (saved briefs are runnable artifacts).
#   4. .handoffs prompt artifacts:
#        a. ══ COPY fences inside .handoffs/**/*.md (recursive — subfolders too;
#           last-prompts/ is excluded here, it is whole-file scanned by location 2).
#        b. top-level .handoffs/*.txt and *.log — whole-file (a saved prompt dump,
#           e.g. a Codex brief, is runnable in full, not only inside a fence).
# Intentionally OUT of scope: root-level author-curated release docs (CHANGELOG.md,
# README.md, ARCHITECTURE.md). They may carry COPY fences but are not artifacts a user
# pastes or resumes, and spec §7 enumerates exactly the four locations above.
#
# Fail-closed posture
# -------------------
# Any of these conditions exits non-zero (release-blocking):
#   - an executable line-start `/goal` in any covered location
#   - the default repo root has no SKILL.md (nothing valid to verify)
#   - a covered file exists but cannot be read/scanned (skipping it would let an
#     unscanned artifact pass the gate — so an unscannable file fails closed)
# Missing optional directories (e.g. a fixture root with no .prompts/) are skipped
# silently — absence of a location is not a failure.
#
# Self-safety
# -----------
# This script's OWN source legitimately contains the pattern it greps for (see this
# header and the awk programs below). It NEVER scans tests/ on default repo runs —
# the default scan covers SKILL.md, references/, commands/, assets/, .prompts/, and
# .handoffs/, so the lint and its fixtures (under tests/) are never self-scanned.
# Use --root to point the lint at a fixture tree for self-testing; fixture roots may
# use SKILL.fixture.md to avoid Claude Code treating test data as a real skill.
#
# bash 3.2 compatible (macOS): no associative arrays, no mapfile, no nameref.
#
# Exit codes:
#   0 — clean (no executable /goal line in any covered location)
#   1 — one or more violations, or a malformed default root
#
# Output format (per-violation line, grep-friendly):
#   <file>:<line-number>: <line-content>
#
# Usage:
#   bash tests/lint-goal-tripwire.sh                 # lint the repo
#   bash tests/lint-goal-tripwire.sh --root <dir>    # lint a fixture tree (self-test)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_IS_DEFAULT=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; ROOT_IS_DEFAULT=0; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; ROOT_IS_DEFAULT=0; shift ;;
    -h|--help) sed -n '2,68p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) printf 'Goal-tripwire lint: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  printf 'Goal-tripwire lint: root not found: %s. Aborting (fail-closed).\n' "$ROOT" >&2
  exit 1
fi

# The default repo root must contain SKILL.md; a fixture root need not.
if [ "$ROOT_IS_DEFAULT" -eq 1 ] && [ ! -f "$ROOT/SKILL.md" ]; then
  printf 'Goal-tripwire lint: %s has no SKILL.md. No valid source to verify. Aborting (fail-closed).\n' \
    "$ROOT" >&2
  exit 1
fi

SOURCE_SKILL="$ROOT/SKILL.md"
if [ "$ROOT_IS_DEFAULT" -eq 0 ] && [ ! -e "$SOURCE_SKILL" ] && [ -e "$ROOT/SKILL.fixture.md" ]; then
  SOURCE_SKILL="$ROOT/SKILL.fixture.md"
fi

# ---------------------------------------------------------------------------
# scan_fence <file>  — emit "<file>:<lineno>: <content>" for an executable
# line-start /goal that sits INSIDE a ══ COPY fence (locations 1 and 4).
# Fence boundaries are detected by substring, matching SKILL.md's own hook.
# ---------------------------------------------------------------------------
scan_fence() {
  awk '
    index($0, "START 🟢 COPY") > 0 { infence=1; next }
    index($0, "END 🛑 COPY")   > 0 { infence=0; next }
    infence==1 && $0 ~ /^[ \t]*\/goal([^A-Za-z0-9_]|$)/ { print FILENAME ":" FNR ": " $0 }
  ' "$1"
}

# ---------------------------------------------------------------------------
# scan_whole <file>  — emit "<file>:<lineno>: <content>" for an executable
# line-start /goal anywhere in the file (locations 2 and 3: the whole file is
# itself a copyable/runnable prompt artifact).
# ---------------------------------------------------------------------------
scan_whole() {
  awk '
    $0 ~ /^[ \t]*\/goal([^A-Za-z0-9_]|$)/ { print FILENAME ":" FNR ": " $0 }
  ' "$1"
}

VIOLATIONS=""

add_violations() {
  # $1 = newline-delimited output from a scan_* call (may be empty)
  [ -n "$1" ] || return 0
  if [ -n "$VIOLATIONS" ]; then
    VIOLATIONS="$VIOLATIONS
$1"
  else
    VIOLATIONS="$1"
  fi
}

scan_and_collect() {
  # $1 = mode (fence|whole), $2 = file. Fail CLOSED if a covered file exists but
  # cannot be scanned — a silent skip would let an unscanned artifact pass the gate.
  if [ ! -r "$2" ]; then
    add_violations "$2:0: [UNSCANNABLE — file exists but is not readable; failing closed]"
    return
  fi
  _sac_out=$("scan_$1" "$2"); _sac_rc=$?
  if [ "$_sac_rc" -ne 0 ]; then
    add_violations "$2:0: [UNSCANNABLE — scan exited $_sac_rc; failing closed]"
    return
  fi
  add_violations "$_sac_out"
}

# --- Location 1: source ══ COPY fences (SKILL.md, references/, commands/, assets/)
[ -f "$SOURCE_SKILL" ] && scan_and_collect fence "$SOURCE_SKILL"
for d in references commands assets; do
  [ -d "$ROOT/$d" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # Skip binary files (e.g. images under assets/): they carry no readable COPY
    # fence and are not pasteable artifacts. Unreadable files are NOT skipped here —
    # scan_and_collect fails them closed below.
    if [ -r "$f" ] && ! grep -Iq . "$f" 2>/dev/null; then
      continue
    fi
    scan_and_collect fence "$f"
  done <<EOF
$(find "$ROOT/$d" -type f)
EOF
done

# --- Location 2: .handoffs/last-prompts/** (whole-file)
if [ -d "$ROOT/.handoffs/last-prompts" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scan_and_collect whole "$f"
  done <<EOF
$(find "$ROOT/.handoffs/last-prompts" -type f)
EOF
fi

# --- Location 3: .prompts/** (whole-file)
if [ -d "$ROOT/.prompts" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scan_and_collect whole "$f"
  done <<EOF
$(find "$ROOT/.prompts" -type f)
EOF
fi

# --- Location 4: .handoffs prompt artifacts
if [ -d "$ROOT/.handoffs" ]; then
  # 4a: continuation fences in .md files (recursive — subfolders included).
  #     last-prompts/ is excluded: location 2 already scans it whole-file.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scan_and_collect fence "$f"
  done <<EOF
$(find "$ROOT/.handoffs" -type f -name '*.md' -not -path '*/last-prompts/*')
EOF
  # 4b: top-level pasteable prompt dumps (.txt/.log) — whole-file. A saved Codex
  #     brief or prompt dump is runnable in full, not only inside a fence.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    scan_and_collect whole "$f"
  done <<EOF
$(find "$ROOT/.handoffs" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.log' \))
EOF
fi

if [ -n "$VIOLATIONS" ]; then
  printf 'Goal-tripwire lint: FAIL — executable /goal line(s) found in a copyable/runnable artifact:\n\n' >&2
  printf '%s\n' "$VIOLATIONS" | while IFS= read -r line; do
    [ -n "$line" ] && printf '  %s\n' "$line" >&2
  done
  printf '\nAn executable /goal line (^[ \\t]*/goal ...) in a COPY fence, a saved prompt\n' >&2
  printf '(.prompts/ or .handoffs/last-prompts/), or a handoff continuation fence can fire\n' >&2
  printf 'autonomous mode when pasted or resumed. The /goal line lives ONLY in chat (see\n' >&2
  printf 'SKILL.md § Goal-Mode Option). Move it out of the artifact, or — if it is a prose\n' >&2
  printf 'mention — backtick it or place it mid-line so it is not a bare line-start command.\n' >&2
  exit 1
fi

printf 'Goal-tripwire lint: OK — %s has no executable /goal line in any covered artifact.\n' "$ROOT"
exit 0
