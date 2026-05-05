#!/usr/bin/env bash
# tests/scanner/unit/s1-injection-safety.sh
# Codex finding #1 (BLOCKER, security): probe S1 with hostile filenames
# that contain shell metacharacters. The original implementation built
# an awk-internal shell command via string-concatenation of the filename,
# letting `;touch PWN;` execute during section-size calculation. The fix
# replaces shell-out-per-section with a single awk pass that computes
# section sizes internally, so filenames are never interpreted by a shell.
#
# Assertions per hostile filename:
#   1. Scan exits 0 (no crash).
#   2. NO artifact file is created during the scan (PWN, test, etc.).
#   3. JSON output is valid and contains a primary_file.size_chars value
#      that matches the actual byte count of the fixture content (so we
#      verify both safety AND correctness — a filename with spaces must
#      still produce the right char_count, not 0 like the original bug).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
SCAN_SCRIPT="${PROJECT_ROOT}/.scripts/context-file-scan/scan.sh"

# Body large enough (>16KB) to push S1 past the soft band so the
# section-size calculation runs (that's where the original vulnerability
# lived). Multiple H2/H3 sections so the per-section enumeration loops.
BODY=$'# Project\n\n## Project Facts\n\n- A fact.\n\n'
BODY+="$(printf 'Filler line %d for section A. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n' {1..120})"
BODY+=$'\n\n## Where to Look\n\n'
BODY+="$(printf 'Pointer line %d. Lorem ipsum dolor sit amet, consectetur adipiscing elit.\n' {1..40})"
BODY+=$'\n\n### Sub-section\n\n'
BODY+="$(printf 'Sub line %d. Lorem ipsum dolor sit amet.\n' {1..30})"

probe() {
  local hostile_name="$1"
  local probe_label="$2"
  local tmp
  tmp=$(mktemp -d)

  # Write fixture under the hostile filename.
  local target="${tmp}/${hostile_name}"
  printf '%s' "$BODY" > "$target"

  # Capture pre-scan inventory (artifacts that already exist in tmp).
  local pre_inventory
  pre_inventory=$(cd "$tmp" && find . -maxdepth 2 -type f 2>/dev/null | sort)

  # Run the scan from inside the tmp dir so any artifact a shell would
  # create lands here, where we can detect it.
  local out
  out=$( cd "$tmp" && bash "$SCAN_SCRIPT" --file "$hostile_name" 2>&1 )
  local rc=$?

  # Check 1: exit 0
  if [ "$rc" -ne 0 ]; then
    echo "❌ ${probe_label}: scan exit $rc (expected 0)"
    echo "    output: ${out}"
    rm -rf "$tmp"
    return 1
  fi

  # Check 2: no artifact files created
  local post_inventory
  post_inventory=$(cd "$tmp" && find . -maxdepth 2 -type f 2>/dev/null | sort)
  if [ "$pre_inventory" != "$post_inventory" ]; then
    echo "❌ ${probe_label}: SCAN CREATED ARTIFACT(S) — INJECTION SUCCESSFUL"
    echo "    pre:  ${pre_inventory}"
    echo "    post: ${post_inventory}"
    rm -rf "$tmp"
    return 1
  fi

  # Check 3: char_count correct (matches actual byte count of fixture)
  local expected_chars
  expected_chars=$(wc -c <"$target" | tr -d ' \t\n')
  local actual_chars
  actual_chars=$(echo "$out" | jq -r '.scan_metadata.primary_file.size_chars' 2>/dev/null)
  if [ "$actual_chars" != "$expected_chars" ]; then
    echo "❌ ${probe_label}: char_count mismatch (got $actual_chars, expected $expected_chars)"
    rm -rf "$tmp"
    return 1
  fi

  echo "✅ ${probe_label}: safe (no artifact, exit 0, char_count=${actual_chars})"
  rm -rf "$tmp"
  return 0
}

fail=0
probe ';touch PWN;.md'        'semicolon-touch-injection'  || fail=1
probe '$(touch PWN).md'       'dollar-paren-injection'     || fail=1
probe '`touch PWN`.md'        'backtick-injection'         || fail=1
probe 'CLAUDE with space.md'  'filename-with-spaces'       || fail=1
probe "'CLAUDE'.md"           'filename-with-quotes'       || fail=1

# Final guard: the test itself must NOT have left a PWN file in PWD.
if [ -e "${PROJECT_ROOT}/PWN" ] || [ -e "$(pwd)/PWN" ]; then
  echo "❌ leaked: a PWN artifact exists somewhere"
  ls -la "${PROJECT_ROOT}/PWN" "$(pwd)/PWN" 2>/dev/null || true
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "─── S1 injection safety: all probes safe ───"
fi
exit "$fail"
