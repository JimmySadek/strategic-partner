#!/usr/bin/env bash
# tests/scanner/infra/bash-version.sh
# Sanity-check: scripts run under bash 3.2 (macOS default). Catches
# 4.x-only syntax (associative arrays, ${var,,}, namerefs).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/_test_helper.sh"

# Ensure /bin/bash exists (bash 3.2 on macOS) and run the scanner under it.
if [ ! -x /bin/bash ]; then
  echo "skip: /bin/bash not found"
  exit 0
fi

bash_version=$(/bin/bash --version | head -1)
echo "Running scanner under: $bash_version"

# Run the scan via /bin/bash explicitly
out=$(/bin/bash "$SCAN_SCRIPT" --file "$FIXTURES/clean-minimal.md" 2>&1)
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "❌ scanner failed under bash 3.2 (exit $ec)"
  echo "$out" | tail -20
  exit 1
fi
echo "✅ scanner runs under bash 3.2"

# Spot-check: search for forbidden bash 4+ syntax in scanner sources.
# Strip comments before matching so the rule's documentation can mention
# the forbidden syntax (e.g., "no ${var,,}") without false-positives.
forbidden_patterns=(
  'declare[[:space:]]+-A'
  'declare[[:space:]]+-n'
  'local[[:space:]]+-n'
  '\$\{[^}]+,,\}'
  '\$\{[^}]+\^\^\}'
)
for pattern in "${forbidden_patterns[@]}"; do
  hits=$(find "$PROJECT_ROOT/.scripts/context-file-scan" -name '*.sh' \
         -exec sed -E 's/[[:space:]]*#.*$//' {} + 2>/dev/null \
         | grep -E "$pattern" || true)
  if [ -n "$hits" ]; then
    echo "❌ forbidden bash 4+ syntax matching '$pattern' found in non-comment code:"
    echo "$hits"
    exit 1
  fi
done
echo "✅ no forbidden bash 4+ syntax in scanner sources"

echo ""
echo "── bash-version: scanner is bash 3.2 compatible ──"
exit 0
