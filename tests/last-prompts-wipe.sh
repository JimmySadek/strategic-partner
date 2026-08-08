#!/usr/bin/env bash
# last-prompts-wipe.sh — regression test for the portable last-prompts wipe
# (SKILL.md § Fenced Prompt Emission Protocol, step 1 — v6.13.0 deliverable 2).
#
# The prescribed command must:
#   (i)   not abort on a MISSING directory,
#   (ii)  not abort on an EMPTY directory,
#   (iii) not depend on `rm` (the user's `rm` is aliased to refuse-and-warn),
#   exiting 0 with no error on stderr in every case.
#
# Usage:  bash tests/last-prompts-wipe.sh
# Exit 0 = all scenarios passed. Exit 1 = at least one scenario failed.

FAIL=0
WORK=$(mktemp -d)
DIR="$WORK/.handoffs/last-prompts"

# The exact command prescribed in SKILL.md, run relative to a scratch cwd.
wipe() {
  ( cd "$WORK" && mkdir -p .handoffs/last-prompts && find .handoffs/last-prompts -maxdepth 1 -name '*.md' -delete )
}

check() {
  label=$1
  stderr=$(wipe 2>&1 1>/dev/null)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL  $label — exit $rc (expected 0)"
    FAIL=1
  elif [ -n "$stderr" ]; then
    echo "FAIL  $label — unexpected stderr: $stderr"
    FAIL=1
  else
    echo "PASS  $label (exit 0, clean stderr)"
  fi
}

# Scenario 1: MISSING directory (nothing created yet)
rm() { echo "rm is aliased — refusing" >&2; return 1; }  # simulate the user's rm alias
check "missing directory"

# Scenario 2: EMPTY directory (created, no .md files)
check "empty directory"

# Scenario 3: directory with files, under the rm alias (must use find, not rm)
touch "$DIR/1.md" "$DIR/2.md" "$DIR/notes.txt"
check "populated directory under rm-alias"
# The .md files must be gone; the non-.md file must survive (maxdepth/name scope).
if [ -e "$DIR/1.md" ] || [ -e "$DIR/2.md" ]; then
  echo "FAIL  .md files were not deleted"
  FAIL=1
elif [ ! -e "$DIR/notes.txt" ]; then
  echo "FAIL  non-.md file was wrongly deleted"
  FAIL=1
else
  echo "PASS  scope correct (.md deleted, notes.txt kept)"
fi

unset -f rm
\rm -rf "$WORK" 2>/dev/null

if [ "$FAIL" -eq 0 ]; then
  echo "All last-prompts wipe scenarios passed."
  exit 0
fi
echo "last-prompts wipe scenarios FAILED."
exit 1
