#!/usr/bin/env bash
# Shared test helper for tests/scanner/. Sourceable.
# Provides:
#   - PROJECT_ROOT, SCAN_SCRIPT
#   - assert_eq / assert_neq / assert_contains / assert_not_contains
#   - test_pass / test_fail / test_run

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCAN_SCRIPT="${PROJECT_ROOT}/.scripts/context-file-scan/scan.sh"
SCANNER_LIB="${PROJECT_ROOT}/.scripts/context-file-scan/lib"
SCANNER_RULES="${PROJECT_ROOT}/.scripts/context-file-scan/rules"
FIXTURES="${PROJECT_ROOT}/tests/scanner/fixtures"

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" = "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "✅ ${msg:-assert_eq} ($actual)"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ ${msg:-assert_eq}: expected '$expected', got '$actual'"
  fi
}

assert_neq() {
  local unexpected="$1" actual="$2" msg="${3:-}"
  if [ "$unexpected" != "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "✅ ${msg:-assert_neq}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ ${msg:-assert_neq}: should not equal '$unexpected'"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "✅ ${msg:-assert_contains}"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ ${msg:-assert_contains}: '$needle' not in haystack"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if echo "$haystack" | grep -qF "$needle"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "❌ ${msg:-assert_not_contains}: '$needle' is in haystack"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "✅ ${msg:-assert_not_contains}"
  fi
}

test_summary() {
  local total=$((PASS_COUNT + FAIL_COUNT))
  echo ""
  echo "── Summary: ${PASS_COUNT}/${total} passed ──"
  [ "$FAIL_COUNT" -eq 0 ] && return 0 || return 1
}

# Run scan.sh in a subshell capturing exit code + stdout
run_scan() {
  "$SCAN_SCRIPT" "$@" 2>/dev/null
}
