#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
out=$(run_gate "$FIXTURES/clean-minimal.md")
ec=$(echo "$out" | grep '^EXIT=' | sed 's/EXIT=//')
[ "$ec" = "0" ] && echo "✅ missing exception file → exit 0 on clean fixture" || { echo "❌ exit $ec"; exit 1; }
