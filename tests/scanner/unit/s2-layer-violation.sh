#!/usr/bin/env bash
# tests/scanner/unit/s2-layer-violation.sh
# S2 — Layer violation. Positive: bloated fixture has Decisions Log
# section with date + Decision N pattern. Negative: clean-minimal.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0
out=$(scan_isolated "$FIXTURES/bloated-no-sections.md")
assert_finding_fires "$out" S2 || fail=1
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S2 || fail=1
exit $fail
