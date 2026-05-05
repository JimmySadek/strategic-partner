#!/usr/bin/env bash
# tests/scanner/unit/b8-karpathy-drift.sh
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0

# Positive: karpathy-drift has Surgical Changes + "improve adjacent code"
# in NORMATIVE prose (no ❌ wrapper)
out=$(scan_isolated "$FIXTURES/karpathy-drift.md")
assert_finding_fires "$out" B8 || fail=1

# Negative: karpathy-aligned — same names, no contradiction signals
out=$(scan_isolated "$FIXTURES/karpathy-aligned.md")
assert_finding_silent "$out" B8 || fail=1

exit $fail
