#!/usr/bin/env bash
# tests/scanner/unit/b3-rules-without-stub.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: rules file exists; primary has no reference to it
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.claude/rules"
echo "rules content" > "$TMP/.claude/rules/source-editing.md"
cat > "$TMP/CLAUDE.md" <<MD
# Project
## Project Facts
- no reference to the rules file at all
MD
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" B3 || fail=1

# Negative: hybrid-clean-pair → primary references the rules file
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
assert_finding_silent "$out" B3 || fail=1

exit $fail
