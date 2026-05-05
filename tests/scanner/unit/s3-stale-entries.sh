#!/usr/bin/env bash
# tests/scanner/unit/s3-stale-entries.sh
# S3 — Stale entries. Part A: broken paths (stale-entries-paths.md).
# Part B: removed features (stale-entries-features.md).
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Part A
out=$(scan_isolated "$FIXTURES/stale-entries-paths.md")
assert_finding_fires "$out" S3 legacy || fail=1

# Negative: clean-minimal has no S3
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S3 || fail=1

# Part B: removed-feature detection — set up an isolated tmp project
# without the candidate identifiers anywhere
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp "$FIXTURES/stale-entries-features.md" "$TMP/CLAUDE.md"
out=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
assert_finding_fires "$out" S3 legacy-mode || fail=1

exit $fail
