#!/usr/bin/env bash
# tests/scanner/infra/encoding-detection.sh
# Codex finding #2 (BLOCKER): the scanner must reject any text encoding
# other than UTF-8 / US-ASCII per spec § 7.1. The previous implementation
# checked only for "binary" in `file -b --mime-encoding`, so Latin-1 /
# UTF-16 text passed through and produced awk multibyte conversion
# warnings.
#
# This test asserts exit 3 with a detected-encoding message for:
#   - Latin-1 (iso-8859-1) input
#   - UTF-16 LE BOM-prefixed input
#   - Binary input (random bytes)
# and asserts UTF-8 / US-ASCII input still scans normally.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

PROJECT_ROOT="$(cd "$HERE/../../.." && pwd)"
FIXTURES="$PROJECT_ROOT/tests/scanner/fixtures"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail=0

assert_exit3_with_msg() {
  local label="$1" file="$2" needle="$3"
  local out
  out=$(bash "$SCAN_SCRIPT" --file "$file" 2>&1 >/dev/null)
  local ec=$?
  if [ "$ec" -ne 3 ]; then
    echo "❌ ${label}: expected exit 3, got $ec"
    fail=1
    return
  fi
  if ! echo "$out" | grep -qiF "$needle"; then
    echo "❌ ${label}: exit 3 ok but stderr missing '$needle'"
    echo "    stderr: $out"
    fail=1
    return
  fi
  echo "✅ ${label}: exit 3 with '$needle' message"
}

assert_exit0() {
  local label="$1" file="$2"
  bash "$SCAN_SCRIPT" --file "$file" >/dev/null 2>&1
  local ec=$?
  if [ "$ec" -ne 0 ]; then
    echo "❌ ${label}: expected exit 0, got $ec"
    fail=1
    return
  fi
  echo "✅ ${label}: scans normally (exit 0)"
}

# Latin-1 fixture (real on-disk file, iso-8859-1 encoded)
if [ ! -f "$FIXTURES/latin-1.md" ]; then
  echo "❌ fixture missing: $FIXTURES/latin-1.md"
  exit 1
fi
assert_exit3_with_msg 'Latin-1 fixture' "$FIXTURES/latin-1.md" 'iso-8859-1'

# UTF-16 fixture
if [ ! -f "$FIXTURES/utf-16.md" ]; then
  echo "❌ fixture missing: $FIXTURES/utf-16.md"
  exit 1
fi
assert_exit3_with_msg 'UTF-16 fixture' "$FIXTURES/utf-16.md" 'utf-16'

# Binary input (random bytes)
dd if=/dev/urandom of="$TMP/binary.md" bs=1024 count=1 2>/dev/null
assert_exit3_with_msg 'binary input' "$TMP/binary.md" 'binary'

# UTF-8 fixture (clean-minimal exists)
assert_exit0 'UTF-8 fixture (clean-minimal)' "$FIXTURES/clean-minimal.md"

# US-ASCII fixture (small all-ASCII file)
printf '# Project\n\n## Project Facts\n\n- A fact.\n' > "$TMP/ascii.md"
assert_exit0 'US-ASCII fixture' "$TMP/ascii.md"

if [ "$fail" -eq 0 ]; then
  echo ""
  echo "── encoding-detection: spec § 7.1 contract verified ──"
fi
exit "$fail"
