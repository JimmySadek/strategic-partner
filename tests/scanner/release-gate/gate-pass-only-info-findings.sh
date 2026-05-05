#!/usr/bin/env bash
# Provisional Guards fixture produces only info findings → exit 0
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
out=$(run_gate "$FIXTURES/provisional-guards-expired.md")
ec=$(echo "$out" | grep '^EXIT=' | sed 's/EXIT=//')
[ "$ec" = "0" ] && echo "✅ info-only findings → exit 0" || { echo "❌ exit $ec"; exit 1; }
