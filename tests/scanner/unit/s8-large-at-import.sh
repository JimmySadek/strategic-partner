#!/usr/bin/env bash
# tests/scanner/unit/s8-large-at-import.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
# Positive: 3K imported file, @ in primary
yes c | head -c 3000 > "$TMP/big.md"
cat > "$TMP/CLAUDE.md" <<MD
# Project
@./big.md
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" S8 || fail=1

# Negative: small import → no S8
yes c | head -c 100 > "$TMP/small.md"
cat > "$TMP/CLAUDE.md" <<MD
# Project
@./small.md
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_silent "$out" S8 || fail=1

exit $fail
