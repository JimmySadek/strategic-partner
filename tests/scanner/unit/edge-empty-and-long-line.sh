#!/usr/bin/env bash
# tests/scanner/unit/edge-empty-and-long-line.sh
# Codex finding #9 + spec § 7.1 file-level edge cases:
#   - Empty file (0 bytes): exit 0 with a single info finding
#     "File exists but is empty. Add at least the project name and one
#     rule, or remove the file."
#   - Single line >100K chars: exit 0 with the existing S1 (size band)
#     finding PLUS a warn-severity "Extremely long single line"
#     finding.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Empty file → exit 0 with single info finding
out=$(scan_isolated "$FIXTURES/empty.md")
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "❌ empty.md: expected exit 0, got $ec"
  fail=1
fi
total=$(echo "$out" | jq -r '.findings | length')
if [ "$total" != "1" ]; then
  echo "❌ empty.md: expected 1 finding, got $total"
  fail=1
else
  sev=$(echo "$out" | jq -r '.findings[0].severity')
  title=$(echo "$out" | jq -r '.findings[0].title')
  if [ "$sev" = "info" ] && echo "$title" | grep -qiE 'empty'; then
    echo "✅ empty.md: 1 info finding with empty-file title"
  else
    echo "❌ empty.md finding shape: severity=$sev title=$title"
    fail=1
  fi
fi

# Huge single-line → exit 0 with S1 + warn long-line finding
out=$(scan_isolated "$FIXTURES/huge-single-line.md")
ec=$?
if [ "$ec" -ne 0 ]; then
  echo "❌ huge-single-line.md: expected exit 0, got $ec"
  fail=1
fi
s1_count=$(echo "$out" | jq -r '[.findings[] | select(.rule_id == "S1" and .severity != "info")] | length')
long_line_count=$(echo "$out" | jq -r '[.findings[] | select(.title | test("[Ll]ong"))] | length')
if [ "$s1_count" -lt 1 ]; then
  echo "❌ huge-single-line.md: expected S1 finding with size severity, got $s1_count"
  fail=1
else
  echo "✅ huge-single-line.md: S1 size finding fires"
fi
if [ "$long_line_count" -lt 1 ]; then
  echo "❌ huge-single-line.md: expected long-line warn finding, got $long_line_count"
  fail=1
else
  warn_sev=$(echo "$out" | jq -r '[.findings[] | select(.title | test("[Ll]ong"))][0].severity')
  if [ "$warn_sev" = "warn" ]; then
    echo "✅ huge-single-line.md: long-line warn finding fires"
  else
    echo "❌ huge-single-line.md: long-line severity=$warn_sev (expected warn)"
    fail=1
  fi
fi

exit $fail
