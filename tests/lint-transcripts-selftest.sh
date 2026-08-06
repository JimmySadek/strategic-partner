#!/usr/bin/env bash
# tests/lint-transcripts-selftest.sh — fixture-based self-test for two
# tests/lint-transcripts.sh changes:
#
#   1. The assistant-role/isMeta filter (.backlog/fix-transcript-lint-role-
#      filter.md) — a JSONL entry only reaches a check when its own record
#      is type=="assistant" and isMeta is not true.
#   2. The LEAK-TERM rule — SP-internal vocabulary (AUQ, bare step labels,
#      "Mode A/B", ultracode, xhigh, "floor sentinel") flagged when it
#      appears bare in assistant chat text, JSONL only.
#
# Each fixture is a single-record JSONL file under tests/fixtures/
# lint-transcripts/. This script runs the lint directly against each one
# (bypassing --since/--all auto-discovery, using the explicit-file argument
# path lint-transcripts.sh already supports) and checks the output.
#
# Usage: bash tests/lint-transcripts-selftest.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="${SCRIPT_DIR}/lint-transcripts.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/lint-transcripts"

FAIL=0

# expect_violation <fixture> <substring> — the lint output must contain the
# given substring (a positive LEAK-TERM case).
expect_violation() {
  local fixture="$1"
  local expect_substr="$2"
  local output
  output=$(bash "$LINT" "${FIXTURE_DIR}/${fixture}" 2>&1)
  if printf '%s' "$output" | grep -qF "$expect_substr"; then
    echo "PASS  ${fixture} flags: ${expect_substr}"
  else
    echo "FAIL  ${fixture} did not flag: ${expect_substr}"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  fi
}

# expect_clean <fixture> — the lint output must contain no LEAK-TERM finding
# (a negative case: exempted context, or a non-assistant/isMeta entry).
expect_clean() {
  local fixture="$1"
  local output
  output=$(bash "$LINT" "${FIXTURE_DIR}/${fixture}" 2>&1)
  if printf '%s' "$output" | grep -q 'LEAK-TERM'; then
    echo "FAIL  ${fixture} unexpectedly flagged LEAK-TERM"
    echo "  --- lint output ---"
    printf '%s\n' "$output" | sed 's/^/  /'
    FAIL=1
  else
    echo "PASS  ${fixture} stays clean of LEAK-TERM"
  fi
}

# ---- Case 1: positive — bare terms in assistant chat text must flag. ----
expect_violation "leak-term-positive-auq.jsonl"       'LEAK-TERM: internal term "AUQ"'
expect_violation "leak-term-positive-step.jsonl"      'LEAK-TERM: internal step label "Step 2b"'
expect_violation "leak-term-positive-ultracode.jsonl" 'LEAK-TERM: internal term "ultracode"'

# ---- Case 2: negative — same terms inside backticks. ----
expect_clean "leak-term-negative-backtick.jsonl"

# ---- Case 3: negative — term inside a ``` code block and inside a ══ COPY
#      fence (both exemptions exercised in one fixture). ----
expect_clean "leak-term-negative-fenced-copy.jsonl"

# ---- Case 4: negative — term in a type:"user" message. ----
expect_clean "leak-term-negative-user-role.jsonl"

# ---- Case 5: negative — term in an isMeta:true entry. ----
expect_clean "leak-term-negative-ismeta.jsonl"

if [ "$FAIL" -eq 0 ]; then
  echo "LEAK-TERM / role-filter self-test passed."
  exit 0
fi

echo "LEAK-TERM / role-filter self-test FAILED."
exit 1
