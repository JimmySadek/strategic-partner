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

# Codex finding #11: glob-style env-var families like `${CLAUDE_*}`
# must NOT produce S3 candidates. The strict regex `^[A-Z][A-Z0-9_]+$`
# rejects asterisks, question marks, and character classes. Concrete
# env-var names (`${CLAUDE_PROJECT_DIR}`) still produce candidates.
TMP2=$(mktemp -d); trap 'rm -rf "$TMP" "$TMP2"' EXIT
cp "$FIXTURES/s3-glob-envvar-rejection.md" "$TMP2/CLAUDE.md"
out=$(cd "$TMP2" && bash "$SCAN_SCRIPT" --file CLAUDE.md 2>/dev/null)
glob_findings=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S3") | select(.normalized_subject | test("\\*|\\?|\\[|\\]"))] | length')
if [ "$glob_findings" = "0" ]; then
  echo "✅ S3: globs rejected (no asterisk/question/bracket subjects)"
else
  echo "❌ S3: $glob_findings glob candidates leaked through"
  echo "$out" | jq -r '.findings[] | select(.rule_id == "S3") | select(.normalized_subject | test("\\*|\\?|\\[|\\]"))'
  fail=1
fi
# The 'claude' subject is the historical glob-normalized fingerprint —
# must NOT appear because the glob is rejected upstream.
claude_subject=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S3" and .normalized_subject == "claude")] | length')
if [ "$claude_subject" = "0" ]; then
  echo "✅ S3: 'claude' broad subject (glob normalization) absent"
else
  echo "❌ S3: 'claude' broad subject still produced — glob accepted"
  fail=1
fi
# Concrete env-var name still works
assert_finding_fires "$out" S3 claude-project-dir || fail=1

exit $fail
