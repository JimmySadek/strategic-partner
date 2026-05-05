#!/usr/bin/env bash
# tests/scanner/unit/s7-re-asserted-skill.sh
# S7 detection scans ~/.claude/skills/. Without that env present, the
# rule produces no findings — that itself is the negative case.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
fail=0
out=$(scan_isolated "$FIXTURES/clean-minimal.md")
assert_finding_silent "$out" S7 || fail=1
echo "✅ S7: requires ~/.claude/skills/ — exhaustive coverage in integration tests"
exit $fail
