#!/usr/bin/env bash
# lint-context-path-heuristic.sh — truth-table check for the context-file
# path-shape heuristic in proposal-preflight.sh (root + plugin copies).
#
# The branch that routes a CLAUDE.md snippet to .claude/rules/ as
# "path-scoped or file-specific" must fire on snippets that name a real
# repo-relative path, and must not fire on ordinary prose that merely
# contains a slash (and/or, input/output, read/write) or a bare file
# extension (README.md, Node.js) with no directory attached. GitHub issue #1
# measured the old regex blocking eight plain-English sentences on that
# basis. Drives the real proposal-preflight.sh scripts against a scratch
# target in a temp directory; no writes anywhere in the project tree.

HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$HERE/.." && pwd)

FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# MUST NOW BE ALLOWED — no usable path in these sentences.
ALLOW_CASES=(
  "Record the author and/or the reviewer for each change."
  "Describe the input/output of every helper."
  "Keep client/server responsibilities separate."
  "Note whether a helper is read/write or read-only."
  "This project targets Node.js version 20."
  "Update the README.md whenever behaviour changes."
  "The freeze begins on 2026/09/01 for all teams."
  "Always run the tests before you commit."
  # Date exemption survives, narrowed: all-numeric chains WITHOUT a trailing
  # slash are dates however many segments they carry.
  "Use the build stamp 2026/09/01/02 for the rollout."
)

# MUST STILL BE BLOCKED — genuinely path-scoped.
BLOCK_CASES=(
  "In src/components/Button.tsx prefer named exports."
  "Detailed rules live in .claude/rules/testing.md."
  "The hook at hooks/guard-impl.sh must stay fail-closed."
  "See references/prompt-crafting-guide.md before crafting."
  "Run tests/guard-regression.sh after touching the guard."
  "Config for this lives at ./config/app.json."
  # Unambiguous path shapes the prose fix (63cf05a) let through — the
  # cross-model review's five escapes: dot-prefixed first segment, ./ and
  # ../ prefixes, multi-segment non-numeric chain, backslash separators.
  "Everything under .claude/rules is path-scoped."
  "Rules for ./src/utils apply to every helper there."
  "The code in ../packages/core needs review."
  "Keep helpers in packages/core/utils small."
  "In src\components\Button.tsx prefer named exports."
  # Correction-round shapes: absolute paths, home-prefixed paths (both
  # blocked on main), and all-numeric chains ENDING in a slash — the
  # trailing separator disqualifies the date reading.
  "Never read /etc/passwd during tests."
  "Keep scratch clones under ~/src/utils for now."
  "Rotate builds through 123/456/ before archiving."
)

run_case() {
  label="$1"; preflight="$2"; snippet="$3"; expect_verdict="$4"
  out=$(printf '%s\n' "$snippet" | bash "$preflight" --target "$TMP/CLAUDE.md" --snippet - 2>&1)
  verdict=$(printf '%s' "$out" | jq -r '.verdict // "PARSE-ERROR"' 2>/dev/null)
  if [ "$verdict" = "$expect_verdict" ]; then
    echo "PASS  [$label] $expect_verdict: $snippet"
  else
    echo "FAIL  [$label] expected $expect_verdict, got '$verdict': $snippet"
    echo "        raw output: $out"
    FAIL=1
  fi
}

for entry in \
  "root:$PROJECT_ROOT/.scripts/context-file-scan/proposal-preflight.sh" \
  "plugin:$PROJECT_ROOT/plugin/strategic-partner/.scripts/context-file-scan/proposal-preflight.sh"
do
  label="${entry%%:*}"
  preflight="${entry#*:}"
  if [ ! -r "$preflight" ]; then
    echo "FAIL  $preflight is missing or unreadable (run from the repo root)"
    FAIL=1
    continue
  fi
  for snippet in "${ALLOW_CASES[@]}"; do
    run_case "$label" "$preflight" "$snippet" "allow"
  done
  for snippet in "${BLOCK_CASES[@]}"; do
    run_case "$label" "$preflight" "$snippet" "needs-extraction"
  done
done

if [ "$FAIL" -eq 0 ]; then
  echo "Context-file path-heuristic lint passed."
  exit 0
fi

echo "Context-file path-heuristic lint FAILED."
exit 1
