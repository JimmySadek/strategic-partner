#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
out=$(run_gate "$FIXTURES/clean-minimal.md")
ec=$(echo "$out" | grep '^EXIT=' | sed 's/EXIT=//')
[ "$ec" = "0" ] && echo "✅ clean fixture, no exceptions → exit 0" || { echo "❌ exit $ec"; exit 1; }
