#!/usr/bin/env bash
# tests/scanner/unit/b5-rule-without-example.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: karpathy-aligned has rules but no examples → expect B5
out=$(scan_isolated "$FIXTURES/karpathy-aligned.md")
assert_finding_fires "$out" B5 || fail=1

# Negative: hybrid-clean-pair — rule names match across files, examples
# in companion → B5 silent (canonical hybrid)
out=$(scan_in_dir "$FIXTURES/hybrid-clean-pair" CLAUDE.md)
assert_finding_silent "$out" B5 || fail=1

exit $fail
