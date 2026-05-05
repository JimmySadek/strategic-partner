#!/usr/bin/env bash
# Shared helpers for unit tests. Sourceable.
# Each unit test scopes to one rule_id; runs scan.sh against a fixture
# and asserts the expected rule_id fires (or not).

set -u

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SCAN_SCRIPT="${PROJECT_ROOT}/.scripts/context-file-scan/scan.sh"
FIXTURES="${PROJECT_ROOT}/tests/scanner/fixtures"

# Run the scanner from a fresh tmp working dir so scanner_project_root
# isolates from SP's project source files (S3 Part B-grep cost).
scan_isolated() {
  local fixture="$1"
  local tmp
  tmp=$(mktemp -d)
  ( cd "$tmp" && bash "$SCAN_SCRIPT" --file "$fixture" 2>/dev/null )
}

# scan_in_dir DIR REL_FILE — scan REL_FILE inside DIR with DIR
# treated as the project root.
#
# Codex finding #7: the previous implementation just `cd`'d into DIR,
# but `git rev-parse --show-toplevel` resolved to the enclosing SP
# repo, so the layer probe and B2/B3/B5 cross-file rules saw SP's
# real `.claude/rules/source-editing.md` (12,785 chars) rather than
# the fixture's companion (666 chars). Fix: copy the fixture tree to
# `mktemp -d` outside the SP repo, then scan from there. The git-root
# resolution falls back to cwd → the tmp dir → no leak.
scan_in_dir() {
  local dir="$1" rel_file="$2"
  local tmp
  tmp=$(mktemp -d)
  cp -R "$dir/." "$tmp/" 2>/dev/null
  ( cd "$tmp" && bash "$SCAN_SCRIPT" --file "$rel_file" 2>/dev/null )
  local rc=$?
  \rm -rf "$tmp"
  return $rc
}

# Assert that the scan output contains a finding with the given rule_id
# (and optionally a substring in normalized_subject).
assert_finding_fires() {
  local out="$1" rule_id="$2" subject_substr="${3:-}"
  local count
  count=$(echo "$out" | jq -r --arg r "$rule_id" \
    '[.findings[] | select(.rule_id == $r)] | length')
  if [ "$count" -eq 0 ]; then
    echo "❌ $rule_id: did not fire"
    return 1
  fi
  if [ -n "$subject_substr" ]; then
    local match
    match=$(echo "$out" | jq -r --arg r "$rule_id" --arg s "$subject_substr" \
      '[.findings[] | select(.rule_id == $r and (.normalized_subject | contains($s)))] | length')
    if [ "$match" -eq 0 ]; then
      echo "❌ $rule_id: fired but no match for normalized_subject containing '$subject_substr'"
      echo "$out" | jq -c --arg r "$rule_id" '.findings[] | select(.rule_id == $r) | {normalized_subject, severity}'
      return 1
    fi
  fi
  echo "✅ $rule_id: fires ($count finding(s))"
  return 0
}

assert_finding_silent() {
  local out="$1" rule_id="$2"
  if [ -z "$out" ]; then
    echo "❌ $rule_id: scan produced no output (scanner failure)"
    return 1
  fi
  local count
  count=$(echo "$out" | jq -r --arg r "$rule_id" \
    '[.findings[] | select(.rule_id == $r)] | length' 2>/dev/null)
  count=${count:-0}
  if [ "$count" -eq 0 ]; then
    echo "✅ $rule_id: silent (as expected)"
    return 0
  fi
  echo "❌ $rule_id: should be silent, fired $count time(s)"
  echo "$out" | jq -c --arg r "$rule_id" '.findings[] | select(.rule_id == $r) | {normalized_subject, severity}'
  return 1
}
