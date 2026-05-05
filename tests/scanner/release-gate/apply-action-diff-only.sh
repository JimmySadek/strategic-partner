#!/usr/bin/env bash
# Verify the scanner does NOT mutate files (apply action is diff-only
# in v1 per locked mini-decision 13). Check file mtime unchanged after
# scan.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
cp "$FIXTURES/bloated-no-sections.md" "$TMP/CLAUDE.md"
mtime_before=$(stat -f %m "$TMP/CLAUDE.md" 2>/dev/null || stat -c %Y "$TMP/CLAUDE.md")
cd "$TMP"
bash "$SCAN_SCRIPT" --release-gate >/dev/null 2>&1
mtime_after=$(stat -f %m "$TMP/CLAUDE.md" 2>/dev/null || stat -c %Y "$TMP/CLAUDE.md")
[ "$mtime_before" = "$mtime_after" ] && echo "✅ scan did not mutate the target file" || { echo "❌ mtime changed ($mtime_before → $mtime_after)"; exit 1; }
