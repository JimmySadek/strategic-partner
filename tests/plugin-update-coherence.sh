#!/usr/bin/env bash
# Coherence harness for the plugin update command's install-state machine.
#
# WHY THIS EXISTS — read before changing it.
#
# Six consecutive cross-model review rounds found a HIGH-severity defect in
# plugin/strategic-partner/commands/update.md, and each fix produced the next
# round's finding. The last round's findings were all one shape:
#
#   - the classification table defined a state by one signal while the paragraph
#     above it rejected that signal
#   - a state was described in prose but absent from the table
#   - branches existed for two of the three states
#   - the Boundaries section listed a different set of states again
#
# Every one of those is "a state exists here and not there". The sibling suite
# could not catch any of them, because it asserts that PHRASES ARE PRESENT: it
# passed on a phrase-presence check for `claude plugin list` while the table
# three lines below still classified by marketplace registration.
#
# Presence is the wrong property. This suite checks COHERENCE instead: the
# classification table is the single source of truth for what states exist, and
# every other part of the document must agree with it. A new state cannot be
# added to the table without appearing in the branches and in Boundaries, and a
# state cannot be named anywhere without existing in the table.
#
#   It CAN prove:  the document's declared states are internally consistent —
#                  each is defined exactly once, each has a signal and a route,
#                  each has a presentation branch, each appears in Boundaries,
#                  and no state is referenced that the table does not define.
#   It CANNOT prove: that the states are the RIGHT states, that the routes are
#                  correct, or that following the document works. Round 8's
#                  blocker was a documented command that was factually wrong
#                  about the platform; no coherence check could have found it.
#                  That class needs execution, and is covered by the end-to-end
#                  marketplace install run recorded in the release notes.
#
# Read a pass as "the document does not contradict itself", never as "the
# document is correct".

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

CMD_FILE="$ROOT/plugin/strategic-partner/commands/update.md"

record_pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

if [ ! -f "$CMD_FILE" ]; then
  printf 'FAIL: missing required file: %s\n' "$CMD_FILE"
  printf '\nResult: 0 passed, 1 failed\n'
  exit 1
fi

body=$(cat "$CMD_FILE")

# --- The state table is the single source of truth -------------------------
#
# States are declared in the classification table as rows whose first cell is a
# backticked identifier. Nothing else in this file hardcodes the state names —
# that is the point. Adding a fourth state to the table automatically extends
# every assertion below to cover it.
states=$(printf '%s\n' "$body" \
  | sed -n 's/^| `\([a-z-][a-z-]*\)` *|.*|.*|$/\1/p')

state_count=$(printf '%s\n' "$states" | grep -c . || true)

if [ "${state_count:-0}" -ge 2 ]; then
  record_pass "classification table declares $state_count states: $(printf '%s' "$states" | tr '\n' ' ')"
else
  record_fail "classification table declares fewer than 2 states — the table is missing or its shape changed"
  printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
  exit 1
fi

# --- No state is declared twice --------------------------------------------
dupes=$(printf '%s\n' "$states" | sort | uniq -d)
if [ -z "$dupes" ]; then
  record_pass "no state is declared more than once"
else
  record_fail "state declared more than once: $(printf '%s' "$dupes" | tr '\n' ' ')"
fi

# --- Every declared state has a presentation branch ------------------------
#
# The remote-ahead flow must say what to do for each state. A state in the table
# with no branch is a user who reaches a dead end — round 9's finding, where
# marketplace-managed installs had no branch at all.
for st in $states; do
  if printf '%s\n' "$body" | grep -qE "^\*\*For \`$st\`"; then
    record_pass "state '$st' has a presentation branch"
  else
    record_fail "state '$st' is declared in the table but has no \`**For \`$st\`\`\` branch"
  fi
done

# --- Every declared state appears in Boundaries ----------------------------
#
# Boundaries is what a reader consults for "what will this command do". A state
# missing there is a capability claim that silently omits a case.
boundaries=$(printf '%s\n' "$body" | sed -n '/^## Boundaries/,/^## /p')
if [ -z "$boundaries" ]; then
  record_fail "no Boundaries section found — cannot check state coverage"
else
  for st in $states; do
    if printf '%s\n' "$boundaries" | grep -qF "$st"; then
      record_pass "state '$st' is covered in Boundaries"
    else
      record_fail "state '$st' is declared in the table but absent from Boundaries"
    fi
  done
fi

# --- No state is referenced that the table does not declare ----------------
#
# The reverse direction, and the one that caught the `undetermined` state: prose
# described it, the table never defined it, and no branch implemented it. Any
# backticked lowercase identifier used in a "For `x`" branch heading must exist
# in the table.
branch_states=$(printf '%s\n' "$body" \
  | sed -n 's/^\*\*For `\([a-z-][a-z-]*\)`.*/\1/p' | sort -u)
for bs in $branch_states; do
  if printf '%s\n' "$states" | grep -qx "$bs"; then
    record_pass "branch state '$bs' is declared in the table"
  else
    record_fail "branch '$bs' has no matching row in the classification table"
  fi
done

# --- The signal a state is classified by must be the one the probe collects --
#
# Round 9's blocker: the paragraph above the table said provenance must come
# from `claude plugin list`, and the table classified by whether a marketplace
# directory existed — the exact signal that paragraph rejected. Asserted as a
# contradiction check rather than a phrase check: if the document rejects
# classifying by registration, the table must not do it.
if printf '%s\n' "$body" | grep -qiE "registration is not provenance|not (a )?proof of provenance|different facts|Do not test for a registered marketplace"; then
  table_rows=$(printf '%s\n' "$body" | grep -E '^\| `[a-z-]+` *\|')
  if printf '%s\n' "$table_rows" | grep -qiE "marketplace is registered|registered marketplace"; then
    record_fail "the document rejects classifying by registration, but the table still classifies by it"
  else
    record_pass "the table does not classify by a signal the document rejects"
  fi
else
  record_pass "no registration-vs-provenance rejection to contradict"
fi

# --- A read-only command must not carry mutation-permitting boundaries ------
#
# Round 9's finding 4: the command says it changes nothing, while Boundaries
# only forbade updating "without explicit user confirmation" — which implies
# updating WITH confirmation is allowed. A conditional prohibition inside a
# read-only contract is a contradiction, not a nuance.
# Newlines are collapsed before matching: the contract sentence wraps in the
# document, and an earlier version of this check missed it for that reason and
# passed vacuously — the exact failure mode this suite exists to replace.
# Blockquote markers are stripped first: the contract sentence lives in the
# summary blockquote, so flattening alone leaves a stray '>' mid-sentence.
flat=$(printf '%s\n' "$body" | sed 's/^> *//' | tr '\n' ' ' | tr -s ' ')
if printf '%s' "$flat" | grep -qiE "changes nothing on disk|performs no (staging|refresh)"; then
  record_pass "the command states a read-only contract"
  hedged=$(printf '%s\n' "$boundaries" \
    | grep -iE "without explicit user confirmation|beyond the plugin directory itself")
  if [ -n "$hedged" ]; then
    record_fail "read-only contract contradicted by a conditional prohibition in Boundaries:
$(printf '%s' "$hedged" | sed 's/^/    /')"
  else
    record_pass "Boundaries prohibitions are unconditional, matching the read-only contract"
  fi
else
  # Not a pass. This command performs no update; if it no longer says so, either
  # the contract was dropped or a mutation path came back.
  record_fail "no read-only contract found — the command must state that it changes nothing on disk"
fi

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
