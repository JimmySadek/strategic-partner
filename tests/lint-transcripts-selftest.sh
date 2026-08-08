#!/usr/bin/env bash
# tests/lint-transcripts-selftest.sh — fixture-based self-test for four
# tests/lint-transcripts.sh changes:
#
#   1. The assistant-role/isMeta filter (.backlog/fix-transcript-lint-role-
#      filter.md) — a JSONL entry only reaches a check when its own record
#      is type=="assistant" and isMeta is not true.
#   2. The LEAK-TERM rule — SP-internal vocabulary (AUQ, bare step labels,
#      "Mode A/B", ultracode, xhigh, "floor sentinel") flagged when it
#      appears bare in assistant chat text, JSONL only. LEAK-TERM findings
#      are warn-only: they carry the shared ": WARN —" marker and report
#      without failing the lint. This self-test checks both that detection
#      still fires AND that the lint still exits 0, so a regression that
#      re-promoted the warning to a blocker would be caught.
#   3. The AUQ presence flag in the no-jq fallback — the flag that records
#      whether a turn contained an AskUserQuestion tool call must be derived
#      from the same assistant-only filtered set as the message text. Text
#      the user typed can never authorize an assistant prose question.
#   4. RAW-LINE-REF demotion on .jsonl transcripts only (backlog:
#      scope-raw-line-ref-to-shipped-artifacts) — a raw line reference in
#      assistant chat text is reported with the shared ": WARN —" marker
#      instead of blocking, because a session transcript is an immutable
#      record. The same rule keeps blocking on .handoffs/*.md, which is
#      editable, so this self-test checks both sides of that split.
#
# Each fixture is a short JSONL file under tests/fixtures/lint-transcripts/.
# This script runs the lint directly against each one (bypassing
# --since/--all auto-discovery, using the explicit-file argument path
# lint-transcripts.sh already supports) and checks the output and exit status.
#
# Usage: bash tests/lint-transcripts-selftest.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="${SCRIPT_DIR}/lint-transcripts.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/lint-transcripts"

FAIL=0

# ---------------------------------------------------------------------------
# No-jq PATH stub. Case 6 exercises lint-transcripts.sh's grep-based fallback,
# which the lint selects with `command -v jq`. The only way to make that
# selection go the other way is to hand the lint a PATH on which jq does not
# exist. NOJQ_BIN is a directory of symlinks to everything in /bin and
# /usr/bin except jq, so the fallback runs with every other tool it needs.
# ---------------------------------------------------------------------------
NOJQ_BIN=$(mktemp -d)

cleanup_nojq_bin() {
  [ -n "$NOJQ_BIN" ] && [ -d "$NOJQ_BIN" ] || return 0
  find "$NOJQ_BIN" -mindepth 1 -maxdepth 1 -delete 2>/dev/null
  rmdir "$NOJQ_BIN" 2>/dev/null
}
trap cleanup_nojq_bin EXIT

ln -s /bin/*     "$NOJQ_BIN/" 2>/dev/null
ln -s /usr/bin/* "$NOJQ_BIN/" 2>/dev/null
unlink "${NOJQ_BIN}/jq" 2>/dev/null

# expect_exit <fixture> <expected_status> <actual_status> <output> — shared
# exit-status assertion. A LEAK-TERM fixture reports its finding as a warning
# and must still exit 0; a fixture carrying a real mechanical violation must
# exit 1. Checking output text alone would pass either way, which is how a
# warning silently re-promoted to a blocker would go unnoticed.
expect_exit() {
  local fixture="$1"
  local want="$2"
  local got="$3"
  local output="$4"
  if [ "$got" -eq "$want" ]; then
    echo "PASS  ${fixture} exits ${want}"
  else
    echo "FAIL  ${fixture} exited ${got}, expected ${want}"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  fi
}

# expect_finding <fixture> <substring> — the lint output must contain the
# given substring (a positive LEAK-TERM case). LEAK-TERM reports as a
# warning, so this asserts the finding is emitted AND that the lint still
# exits 0.
expect_finding() {
  local fixture="$1"
  local expect_substr="$2"
  local output
  local status
  output=$(bash "$LINT" "${FIXTURE_DIR}/${fixture}" 2>&1)
  status=$?
  if printf '%s' "$output" | grep -qF "$expect_substr"; then
    echo "PASS  ${fixture} flags: ${expect_substr}"
  else
    echo "FAIL  ${fixture} did not flag: ${expect_substr}"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  fi
  expect_exit "$fixture" 0 "$status" "$output"
}

# expect_clean <fixture> — the lint output must contain no LEAK-TERM finding
# (a negative case: exempted context, or a non-assistant/isMeta entry), and
# the lint must exit 0.
expect_clean() {
  local fixture="$1"
  local output
  local status
  output=$(bash "$LINT" "${FIXTURE_DIR}/${fixture}" 2>&1)
  status=$?
  if printf '%s' "$output" | grep -q 'LEAK-TERM'; then
    echo "FAIL  ${fixture} unexpectedly flagged LEAK-TERM"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  else
    echo "PASS  ${fixture} stays clean of LEAK-TERM"
  fi
  expect_exit "$fixture" 0 "$status" "$output"
}

# expect_violation_nojq <fixture> <substring> — run the lint against the
# fixture with jq hidden, forcing the grep-based fallback. The output must
# contain the given substring and the lint must exit 1 (a real mechanical
# violation, not a warning).
expect_violation_nojq() {
  local fixture="$1"
  local expect_substr="$2"
  local output
  local status
  output=$(PATH="$NOJQ_BIN" bash "$LINT" "${FIXTURE_DIR}/${fixture}" 2>&1)
  status=$?
  if printf '%s' "$output" | grep -qF "$expect_substr"; then
    echo "PASS  ${fixture} (no-jq) flags: ${expect_substr}"
  else
    echo "FAIL  ${fixture} (no-jq) did not flag: ${expect_substr}"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  fi
  expect_exit "${fixture} (no-jq)" 1 "$status" "$output"
}

# ---- Case 1: positive — bare terms in assistant chat text must flag. ----
expect_finding "leak-term-positive-auq.jsonl"       'LEAK-TERM: WARN — internal term "AUQ"'
expect_finding "leak-term-positive-step.jsonl"      'LEAK-TERM: WARN — internal step label "Step 2b"'
expect_finding "leak-term-positive-ultracode.jsonl" 'LEAK-TERM: WARN — internal term "ultracode"'

# ---- Case 2: negative — same terms inside backticks. ----
expect_clean "leak-term-negative-backtick.jsonl"

# ---- Case 3: negative — term inside a ``` code block and inside a ══ COPY
#      fence (both exemptions exercised in one fixture). ----
expect_clean "leak-term-negative-fenced-copy.jsonl"

# ---- Case 4: negative — term in a type:"user" message. ----
expect_clean "leak-term-negative-user-role.jsonl"

# ---- Case 5: negative — term in an isMeta:true entry. ----
expect_clean "leak-term-negative-ismeta.jsonl"

# ---- Case 6: the AUQ presence flag must ignore user-authored text. ----
#      The fixture pairs a user message that merely mentions AskUserQuestion
#      with an assistant prose question and no AskUserQuestion tool call.
#      Reading the flag from the raw file lets the user's mention suppress
#      the assistant's violation; reading it from the assistant-only filtered
#      set reports the violation. This defect lives in the no-jq fallback, so
#      the case only means anything when the fallback is what runs — verify
#      the stub PATH really hides jq before trusting the result.
if PATH="$NOJQ_BIN" command -v jq > /dev/null 2>&1; then
  echo "FAIL  no-jq stub PATH still resolves jq — Case 6 cannot exercise the fallback"
  FAIL=1
elif ! PATH="$NOJQ_BIN" command -v grep > /dev/null 2>&1; then
  echo "FAIL  no-jq stub PATH is missing grep — Case 6 cannot run the fallback"
  FAIL=1
else
  expect_violation_nojq "auq-user-mention-not-authorization.jsonl" \
    'AUQ-must-be-AUQ violation: prose question detected without AskUserQuestion tool call'
fi

# ---- Case 7: RAW-LINE-REF is demoted to a warning on .jsonl transcripts —
#      a raw line reference in assistant chat text must still be flagged for
#      visibility, but must not fail the lint (the file is an immutable
#      record). ----
expect_finding "raw-line-ref-positive.jsonl" \
  'RAW-LINE-REF: WARN — raw line reference "line 42"'

# ---- Case 8: RAW-LINE-REF keeps blocking on .handoffs/*.md — only the
#      .jsonl path is demoted; the same rule on an editable working file
#      still fails the lint with no ": WARN —" marker. ----
raw_line_ref_md_output=$(bash "$LINT" "${FIXTURE_DIR}/raw-line-ref-handoffs-blocks.md" 2>&1)
raw_line_ref_md_status=$?
if printf '%s' "$raw_line_ref_md_output" | grep -qF 'RAW-LINE-REF: raw line reference "line 42"' \
   && ! printf '%s' "$raw_line_ref_md_output" | grep -q 'RAW-LINE-REF:.*WARN'; then
  echo "PASS  raw-line-ref-handoffs-blocks.md flags RAW-LINE-REF as a mechanical violation"
else
  echo "FAIL  raw-line-ref-handoffs-blocks.md did not flag RAW-LINE-REF as a mechanical violation"
  echo "  --- lint output ---"
  printf '%s\n' "$raw_line_ref_md_output" | sed 's/^/  /'
  FAIL=1
fi
expect_exit "raw-line-ref-handoffs-blocks.md" 1 "$raw_line_ref_md_status" "$raw_line_ref_md_output"

if [ "$FAIL" -eq 0 ]; then
  echo "LEAK-TERM / role-filter self-test passed."
  exit 0
fi

echo "LEAK-TERM / role-filter self-test FAILED."
exit 1
