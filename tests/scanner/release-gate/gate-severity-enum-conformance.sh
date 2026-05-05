#!/usr/bin/env bash
# Verify all emitted findings use the canonical severity enum
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
cd "$TMP"
out=$(bash "$SCAN_SCRIPT" --release-gate 2>/dev/null)
invalid=$(echo "$out" | jq -r '[.findings[] | select(.severity != "info" and .severity != "warn" and .severity != "surface-loudly")] | length')
[ "$invalid" = "0" ] && echo "✅ all severity values in {info, warn, surface-loudly}" || { echo "❌ $invalid invalid severities"; exit 1; }
