#!/usr/bin/env bash
# tests/scanner/unit/b1-missing-baseline.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: code-producing project (has src/) but no BG section in primary
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/src"
cat > "$TMP/CLAUDE.md" <<MD
# Project
## Project Facts
- nothing
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" B1 || fail=1

# Negative: doc-only project (no src/, no package.json) → silent
TMP2=$(mktemp -d); trap 'rm -rf "$TMP" "$TMP2"' EXIT
cat > "$TMP2/CLAUDE.md" <<MD
# Doc Project
- doc only
MD
out=$(cd "$TMP2" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_silent "$out" B1 || fail=1

exit $fail
