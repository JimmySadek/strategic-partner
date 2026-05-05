#!/usr/bin/env bash
# tests/scanner/infra/os-matrix.sh
# Smoke-runs the scanner on the host OS. Acts as the OS matrix gate when
# CI runs this test on multiple platforms (macOS + Linux). Locally, just
# confirms the host invocation works.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

uname_s=$(uname -s)
echo "Host OS: $uname_s"

case "$uname_s" in
  Darwin|Linux) ;;
  *) echo "⚠️  Unsupported OS: $uname_s — scanner requires macOS or Linux"; exit 1 ;;
esac

# Run scanner against the clean-minimal fixture; any non-zero exit is a
# host-OS compat failure.
out=$(bash "$SCAN_SCRIPT" --file "$FIXTURES/clean-minimal.md" 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "❌ scanner failed on $uname_s (exit $ec)"
  echo "$out" | tail -20
  exit 1
fi
echo "✅ scanner succeeded on $uname_s"

# Validate JSON shape on this OS
echo "$out" | jq -e '.findings | type == "array"' >/dev/null
echo "✅ JSON conformant on $uname_s"

echo ""
echo "── os-matrix: $uname_s baseline pass ──"
exit 0
