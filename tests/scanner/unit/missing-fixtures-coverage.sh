#!/usr/bin/env bash
# tests/scanner/unit/missing-fixtures-coverage.sh
# Codex finding #10: spec § 8.6 listed 19 fixtures total; the v1 build
# was missing 6. The other five came in alongside their feature
# (latin-1 / utf-16 with #2, agentsmd-with-stub-pointer/ with #5,
# huge-single-line.md with #9). This test exercises the three
# remaining fixtures: bloated-with-sections.md, mixed-violations.md,
# and binary.md.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# bloated-with-sections.md: S1 must fire (size > soft band) + at least
# one B-class finding because the fixture has rules in its BG section.
out=$(scan_isolated "$FIXTURES/bloated-with-sections.md")
s1_count=$(echo "$out" | jq -r '[.findings[] | select(.rule_id=="S1")] | length')
b_class_count=$(echo "$out" | jq -r '[.findings[] | select(.rule_class=="behavioral")] | length')
if [ "$s1_count" -ge 1 ] && [ "$b_class_count" -ge 1 ]; then
  echo "✅ bloated-with-sections.md: S1 + B-class fires (s1=$s1_count, b=$b_class_count)"
else
  echo "❌ bloated-with-sections.md: expected S1 + B-class, got s1=$s1_count b=$b_class_count"
  fail=1
fi

# mixed-violations.md: cross-class triggers — at least 4 of S1/S2/S3
# + B5/B6/B7 should fire.
out=$(scan_isolated "$FIXTURES/mixed-violations.md")
declare_seen() {
  local rid="$1"
  local n
  n=$(echo "$out" | jq -r --arg r "$rid" '[.findings[] | select(.rule_id == $r)] | length')
  [ "$n" -ge 1 ] && echo 1 || echo 0
}
s1_seen=$(declare_seen S1)
s2_seen=$(declare_seen S2)
s3_seen=$(declare_seen S3)
b5_seen=$(declare_seen B5)
b6_seen=$(declare_seen B6)
b7_seen=$(declare_seen B7)
total_classes=$((s1_seen + s2_seen + s3_seen + b5_seen + b6_seen + b7_seen))
if [ "$total_classes" -ge 4 ]; then
  echo "✅ mixed-violations.md: $total_classes / 6 expected classes fired (S1=$s1_seen S2=$s2_seen S3=$s3_seen B5=$b5_seen B6=$b6_seen B7=$b7_seen)"
else
  echo "❌ mixed-violations.md: only $total_classes / 6 classes fired"
  fail=1
fi

# binary.md: scanner must exit 3 with binary message.
out=$(bash "$SCAN_SCRIPT" --file "$FIXTURES/binary.md" 2>&1 >/dev/null)
ec=$?
if [ "$ec" = "3" ] && echo "$out" | grep -qiF "binary"; then
  echo "✅ binary.md: exit 3 with binary message"
else
  echo "❌ binary.md: exit=$ec stderr='$out'"
  fail=1
fi

exit $fail
