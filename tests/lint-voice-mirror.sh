#!/usr/bin/env bash
# tests/lint-voice-mirror.sh — Release-time fail-closed lint:
# SKILL.md and output-styles/strategic-partner-voice.md must AGREE on the voice rules.
#
# Why this exists
# ---------------
# SKILL.md is the canonical home of SP's voice rules; the installable output style
# (output-styles/strategic-partner-voice.md) is a DERIVED MIRROR of it (see SKILL.md
# § Plain-English Default). If the two drift apart, a user who installs the output
# style and a session that reads only SKILL.md would get different voice rules. This
# lint enforces agreement mechanically, every release, so the property does not rest
# on author discipline alone.
#
# [⚠️ RISK] anchor agreement is a drift tripwire, not proof of full equivalence.
# It checks that a curated set of distinctive rule phrases appears in BOTH files; it
# does NOT prove the two files state every rule identically. A wording change to a
# rule that is not one of the anchors will not be caught. Treat a clean run as "no
# tracked rule went missing from one side," not "the two files are equivalent."
#
# Checks (in order; any failure exits 1):
#   a. The style file contains the literal DERIVED MIRROR header.
#   b. SKILL.md contains the literal canonical-source declaration.
#   c. Anchor agreement: each anchor below must appear in BOTH files. An anchor
#      missing from either file fails, naming the anchor and the file. Either file
#      missing or unreadable fails closed.
#
# WHY THIS FILE IS FORCE-TRACKED DESPITE `tests/` BEING IGNORED.
# `.gitignore` excludes `tests/`, so an untracked copy of this lint is absent from
# a fresh clone or CI checkout and cannot gate a release run there — a v8
# cross-model review caught exactly this: the file existed and passed locally
# while `git ls-files --error-unmatch` proved it invisible to anyone else. It is
# force-added (`git add -f`), matching the settled practice for the other
# contract suites in this directory: lint-dispatch-labels.sh,
# codex-dispatch-contract.sh, floor-startup-contract.sh,
# floor-version-tristate.sh, plugin-update-contract.sh,
# startup-reference-contract.sh, validation-launcher-contract.sh.
#
# Self-safety
# -----------
# This script's OWN source legitimately contains the strings it greps for (the two
# declarations and the anchor list below). Default repo runs NEVER scan tests/ — they
# scan only SKILL.md and output-styles/strategic-partner-voice.md under ROOT, so the
# lint is never self-scanned. Use --root to point the lint at a fixture tree for
# self-testing; fixture roots may use SKILL.fixture.md to avoid Claude Code treating
# test data as a real skill.
#
# bash 3.2 compatible (macOS): no associative arrays, no mapfile, no nameref.
# Depends only on grep (stock macOS).
#
# Exit codes:
#   0 — clean (both declarations present; every anchor in both files)
#   1 — a missing declaration/header, a one-file-only anchor, or a missing/unreadable file
#
# Usage:
#   bash tests/lint-voice-mirror.sh                 # lint the repo
#   bash tests/lint-voice-mirror.sh --root <dir>    # lint a fixture tree (self-test)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --root=*) ROOT="${1#--root=}"; shift ;;
    -h|--help) sed -n '2,46p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) printf 'Voice-mirror lint: unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

SKILL="$ROOT/SKILL.md"
if [ ! -e "$SKILL" ] && [ -e "$ROOT/SKILL.fixture.md" ]; then
  SKILL="$ROOT/SKILL.fixture.md"
fi
STYLE="$ROOT/output-styles/strategic-partner-voice.md"

# Literal declarations checked one-file-only (NOT anchors — each lives in exactly one
# file by design, so they are never added to the anchor list below).
MIRROR_HEADER="DERIVED MIRROR: canonical voice rules live in SKILL.md"
CANONICAL_DECL="SKILL.md is the canonical source of SP's voice rules."

FAIL=0
fail() { printf 'Voice-mirror lint: FAIL — %s\n' "$1" >&2; FAIL=1; }

# Both files must exist and be readable — a missing canonical file is not "clean".
for f in "$SKILL" "$STYLE"; do
  if [ ! -r "$f" ]; then
    fail "required file missing or unreadable: $f"
  fi
done
[ "$FAIL" -ne 0 ] && exit 1

# Check a: style file carries the DERIVED MIRROR header.
grep -qF "$MIRROR_HEADER" "$STYLE" \
  || fail "style file is missing the DERIVED MIRROR header: $STYLE"

# Check b: SKILL.md carries the canonical-source declaration.
grep -qF "$CANONICAL_DECL" "$SKILL" \
  || fail "SKILL.md is missing the canonical-source declaration: $SKILL"

# Check c: anchor agreement. Each anchor is a distinctive literal phrase — one per
# major voice rule — copied BYTE-IDENTICAL from the post-fold files. Do not paraphrase:
# a paraphrased anchor never matches and becomes a permanent false-fail. The list is
# fed via a quoted here-doc (no expansion) into a while loop in the CURRENT shell (not
# a pipe), so fail() updates persist. Keep 12-18 entries.
while IFS= read -r anchor; do
  [ -n "$anchor" ] || continue
  grep -qF "$anchor" "$SKILL" \
    || fail "anchor missing from SKILL.md: [$anchor]"
  grep -qF "$anchor" "$STYLE" \
    || fail "anchor missing from style file: [$anchor]"
done <<'ANCHORS_EOF'
That assumption doesn't hold because [specific reason].
Take a position on every question.
Smaller / Recommended / Bigger
Codify with target+pending note (Recommended)
auth.js:45 → 🛡️ sec risk in user val()
Tackle the small bookkeeping file first, then the timer fix, and stretch into the card layout if there's time.
While B-039 step 2 runs, B-040 is the natural next implementation candidate.
SP writes the brief, the user runs the tests, and SP hands it to the specialist once the user confirms.
Walk through it together first
contrarian theater
adding agents or depth makes that worse, not better
Hedging is not diplomacy
before compliment, never after
Rating the user's own artifact
Contradictory status rows
Greek option labels
STOP markers
or earlier dispatch skips this confirmation.
ANCHORS_EOF

if [ "$FAIL" -ne 0 ]; then
  printf '\nSKILL.md and the output-style mirror disagree. Edit SKILL.md first (canonical),\n' >&2
  printf 'then mirror the change into output-styles/strategic-partner-voice.md, so both files\n' >&2
  printf 'state the rule. See SKILL.md § Plain-English Default and CLAUDE.md § 2e.\n' >&2
  exit 1
fi

printf 'Voice-mirror lint: OK — SKILL.md and the output-style mirror agree on all tracked rules (%s).\n' "$ROOT"
exit 0
