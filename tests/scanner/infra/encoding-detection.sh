#!/usr/bin/env bash
# tests/scanner/infra/encoding-detection.sh
# Asserts: binary inputs produce exit 3.
# (UTF-16 / Latin-1 detection per spec § 7.1 is a v6.1+ enhancement;
# v1's `file -b --mime-encoding` check catches binary; non-UTF-8 text
# files often pass the binary check in macOS's `file` and are scanned
# as-is. This test verifies the binary-detection path.)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Build a binary fixture (random bytes)
dd if=/dev/urandom of="$TMP/binary.md" bs=1024 count=1 2>/dev/null

# Run scanner — expect exit 3
bash "$SCAN_SCRIPT" --file "$TMP/binary.md" >/dev/null 2>&1
ec=$?

if [ "$ec" -eq 3 ]; then
  echo "✅ binary file → exit 3"
else
  echo "❌ binary file: expected exit 3, got $ec"
  exit 1
fi

echo ""
echo "── encoding-detection: binary path correct ──"
exit 0
