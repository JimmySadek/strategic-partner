#!/usr/bin/env bash
# tests/scanner/infra/shellcheck.sh
# Asserts every .sh in .scripts/context-file-scan/ passes shellcheck at
# warning level or above.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "skip: shellcheck not in PATH"
  exit 0
fi

FAILED=0
while IFS= read -r f; do
  if shellcheck -S warning -x "$f" >/dev/null 2>&1; then
    echo "✅ $f"
  else
    echo "❌ $f"
    shellcheck -S warning -x "$f" 2>&1 | head -20
    FAILED=$((FAILED + 1))
  fi
done < <(find "$PROJECT_ROOT/.scripts/context-file-scan" -name '*.sh')

if [ "$FAILED" -eq 0 ]; then
  echo ""
  echo "── shellcheck: all clean at warning level ──"
  exit 0
fi
echo ""
echo "── shellcheck: $FAILED file(s) failed ──"
exit 1
