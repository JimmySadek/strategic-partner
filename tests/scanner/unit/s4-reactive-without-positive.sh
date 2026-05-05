#!/usr/bin/env bash
# tests/scanner/unit/s4-reactive-without-positive.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: bullet item with prohibition language and no positive direction
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/CLAUDE.md" <<MD
# Project

## Rules

- Never use mutable global state in production handlers; refactor away from it before merging.
- Don't roll your own crypto without team review and an external audit.
- Avoid blocking the event loop; if a long task is necessary, find another path.
MD
out=$(scan_isolated "$TMP/CLAUDE.md")
assert_finding_fires "$out" S4 || fail=1

# Negative: prohibition WITH positive direction
TMP2=$(mktemp -d); trap 'rm -rf "$TMP" "$TMP2"' EXIT
cat > "$TMP2/CLAUDE.md" <<MD
# Project

## Rules

- Never use mutable global state in production handlers — instead use the request-scoped context object.
MD
out=$(scan_isolated "$TMP2/CLAUDE.md")
assert_finding_silent "$out" S4 || fail=1

exit $fail
