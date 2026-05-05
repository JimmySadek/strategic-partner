#!/usr/bin/env bash
# Bloated fixture has S2 warn findings; no exception file → exit 4
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"
out=$(run_gate "$FIXTURES/bloated-no-sections.md")
ec=$(echo "$out" | grep '^EXIT=' | sed 's/EXIT=//')
[ "$ec" = "4" ] && echo "✅ uncovered warn → exit 4" || { echo "❌ exit $ec"; exit 1; }
