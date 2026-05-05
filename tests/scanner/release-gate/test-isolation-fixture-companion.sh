#!/usr/bin/env bash
# tests/scanner/release-gate/test-isolation-fixture-companion.sh
# Codex finding #7: multi-file fixture tests claimed the fixture
# directory was the project root, but git rev-parse resolved to the
# enclosing SP repo. The hybrid-clean-pair test was reading the real
# 12,785-char SP rules file instead of the 666-char fixture companion
# — passing for the wrong reason.
#
# This test asserts the scanner reads the FIXTURE's companion file
# (size 666) when scanning hybrid-clean-pair, by checking the JSON
# output's companion_files[].size_chars value.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../unit/_helpers.sh"

EXPECTED_FIXTURE_SIZE=666
FIXTURE_DIR="$FIXTURES/hybrid-clean-pair"

out=$(scan_in_dir "$FIXTURE_DIR" CLAUDE.md)
if [ -z "$out" ]; then
  echo "❌ scan_in_dir produced no output"
  exit 1
fi

companion_size=$(echo "$out" | jq -r '.scan_metadata.companion_files[0].size_chars // 0')
companion_path=$(echo "$out" | jq -r '.scan_metadata.companion_files[0].path // ""')

if [ "$companion_size" != "$EXPECTED_FIXTURE_SIZE" ]; then
  echo "❌ companion size mismatch: got $companion_size, expected $EXPECTED_FIXTURE_SIZE"
  echo "   companion_path=$companion_path"
  echo "   This means the scanner read SP's real .claude/rules/ instead of the fixture's."
  exit 1
fi

# Sanity: companion path must NOT include 'strategic-partner' (the SP repo dir name).
case "$companion_path" in
  *strategic-partner*)
    echo "❌ companion path contains 'strategic-partner' — leaked SP repo: $companion_path"
    exit 1 ;;
esac

echo "✅ fixture companion isolated: size=$companion_size path=$companion_path"
exit 0
