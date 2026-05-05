#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"
fail=0
result=$(scan_isolated "$FIXTURES/clean-minimal.md")
ec=$?
[ "$ec" = "0" ] && echo "✅ clean-baseline exit 0" || fail=1
total=$(echo "$result" | jq '.findings | length')
[ "$total" = "0" ] && echo "✅ 0 findings on clean-minimal" || { echo "❌ expected 0, got $total"; fail=1; }
exit $fail
