#!/usr/bin/env bash
# Run scanner with PATH that contains everything EXCEPT jq.
# Approach: prepend a shadow dir that masks jq via a non-executable stub.
# scan.sh's `command -v jq` check tests for an executable jq and exits 3
# when it's absent. The shadow stub blocks PATH lookup without breaking
# `dirname`, `sed`, `awk`, etc., which the rest of the scanner needs.
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/_helpers.sh"

TMP=$(mktemp -d); trap '\rm -rf "$TMP"' EXIT
SHADOW="$TMP/shadow"
mkdir -p "$SHADOW"
# Create a jq-named entry that is NOT executable. command -v skips
# non-executable entries, but the directory still appears first on PATH.
# However, on macOS PATH search finds the next jq in PATH if the first
# match is non-executable. To force command -v to report jq as missing,
# we have to rewrite PATH so no executable jq is reachable.
# Simplest portable trick: build a PATH containing only the directories
# that hold the essential tools (dirname, awk, sed, grep, find, file,
# stat, mktemp, ls, sort, head, tail, cat, tr, wc, basename, mkdir,
# chmod, env, sha256sum/shasum) but NOT the directory containing jq.

# Discover required-tool dirs.
declare -a tools=(dirname awk sed grep find file stat mktemp ls sort head tail cat tr wc basename mkdir chmod env shasum date git)
ALLOWED_PATH=""
for t in "${tools[@]}"; do
  d=$(dirname "$(command -v "$t" 2>/dev/null || true)")
  [ -z "$d" ] && continue
  case ":$ALLOWED_PATH:" in *":$d:"*) ;; *) ALLOWED_PATH="${ALLOWED_PATH:+${ALLOWED_PATH}:}$d" ;; esac
done

# Verify jq is reachable in the allowed PATH (we'll need to remove its
# directory only).
JQ_BIN=$(command -v jq)
JQ_DIR=$(dirname "$JQ_BIN")

# If jq lives in a dir that also has many other essential tools, the test
# can't isolate jq removal. Skip in that case (typical macOS — jq is in
# /usr/bin alongside ~everything).
shared_tools=0
for t in "${tools[@]}"; do
  this_dir=$(dirname "$(command -v "$t" 2>/dev/null || true)")
  [ "$this_dir" = "$JQ_DIR" ] && shared_tools=$((shared_tools + 1))
done
if [ "$shared_tools" -gt 5 ]; then
  echo "⚠️  jq lives in $JQ_DIR alongside many essential tools — skipping isolated-removal test"
  echo "✅ skip (cannot isolate jq on this platform)"
  exit 0
fi

# Otherwise, remove the jq dir from ALLOWED_PATH and run the scanner.
NEW_PATH=$(echo "$ALLOWED_PATH" | tr ':' '\n' | grep -v "^${JQ_DIR}$" | tr '\n' ':')
cp "$FIXTURES/clean-minimal.md" "$TMP/CLAUDE.md"
cd "$TMP"
PATH="$NEW_PATH" bash "$SCAN_SCRIPT" >/dev/null 2>&1
ec=$?
[ "$ec" = "3" ] && echo "✅ jq missing → exit 3" || { echo "❌ exit $ec (jq dir was $JQ_DIR)"; exit 1; }
