#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
companions=$(echo "$out" | jq '.scan_metadata.companion_files | length')
[ "$companions" = "1" ] && echo "✅ companion file discovered" || { echo "❌ companions=$companions"; fail=1; }
b2=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B2")] | length')
b3=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B3")] | length')
b5=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B5")] | length')
b7=$(echo "$out" | jq '[.findings[] | select(.rule_id == "B7")] | length')
[ "$b2" = "0" ] && [ "$b3" = "0" ] && [ "$b5" = "0" ] && [ "$b7" = "0" ] && \
  echo "✅ B2/B3/B5/B7 all silent on hybrid-clean" || { echo "❌ B2=$b2 B3=$b3 B5=$b5 B7=$b7"; fail=1; }
exit $fail
