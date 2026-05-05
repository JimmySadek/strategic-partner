#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/hybrid-broken-stub-only.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
b2=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B2")] | length')
[ "$b2" -ge 1 ] && echo "✅ B2 fires on hybrid-broken-stub-only" || { echo "❌ B2 silent"; fail=1; }
exit $fail
