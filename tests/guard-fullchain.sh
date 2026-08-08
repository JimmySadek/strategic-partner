#!/usr/bin/env bash
# guard-fullchain.sh — whole-chain regression fixtures for the context-file
# stewardship feature, exercised through the FULL PreToolUse source-edit guard
# (hooks/guard-impl.sh), NOT context-file-guard.sh in isolation.
#
# Why the full chain: hooks/context-file-guard.sh (the content guard) already
# treats CLAUDE.md / AGENTS.md / GEMINI.md identically. The bug these fixtures
# guard against lived ONE layer up — guard-impl.sh's own path allow-list
# (Guard 1, Guard 2) allow-listed only CLAUDE.md, so a clean, preflight-approved
# edit of AGENTS.md / GEMINI.md was still blocked by the broad source-edit guard.
# Testing the content guard alone (tests/context-file-guard.sh) could never have
# caught that — these fixtures pipe through guard-impl.sh so the whole chain is
# proven for ALL THREE context files.
#
# Each context file gets:
#   - a clean, concise project-wide-instruction Write/Edit → expect exit 0 (allowed)
#   - a bloat/junk edit (session-journal dump / path-scoped rule) → expect exit 2 (blocked)
#
# jq is required by the content guard; this test assumes jq is present.
#
# Usage:  bash tests/guard-fullchain.sh
# Exit 0 = all fixtures passed. Exit 1 = at least one fixture failed.

HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$HERE/.." && pwd)
GUARD="$PROJECT_ROOT/hooks/guard-impl.sh"
FAIL=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# run_case "label" expected_exit json_input
run_case() {
  label=$1
  expected=$2
  payload=$3
  printf '%s' "$payload" | bash "$GUARD" >/dev/null 2>&1
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS  $label (exit $actual)"
  else
    echo "FAIL  $label — expected $expected, got $actual"
    FAIL=1
  fi
}

safe_content='- Run `pnpm test` before committing frontend changes.'

journey='## #5177 Data Upload page - locked 2026-06-19
SHIPPED (local, unpushed) - 5 commits, browser-verified both tenants.
Commit `5f953ca`. Files: `DataUpload.tsx`, `UploadModal.tsx`, `UploadChoiceModal.tsx`, `ManualEntryModal.tsx`.'

for name in CLAUDE AGENTS GEMINI; do
  target="$TMP/$name.md"

  # 1. Clean, concise project-wide-instruction Write → allowed.
  clean_payload=$(jq -n --arg path "$target" --arg content "$safe_content" \
    '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
  run_case "$name: clean concise Write allows" 0 "$clean_payload"

  # 2. Bloat/junk Write (session-journal dump) → blocked by content guard,
  #    proving the clean case above reached the verdict (not a path bypass).
  junk_payload=$(jq -n --arg path "$target" --arg content "$journey" \
    '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
  run_case "$name: journey-dump Write blocks" 2 "$junk_payload"

  # 3. Path-scoped-rule Edit append → blocked. Seed a small concise file, then
  #    propose appending a path-scoped rule (belongs in .claude/rules, not the
  #    always-loaded root context file).
  printf '# Project\n\n' > "$target"
  path_rule_payload=$(jq -n --arg path "$target" --arg old "$(cat "$target")" --arg new '# Project

- All files under `src/api/` must use the shared request validator.
' '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
  run_case "$name: path-scoped Edit append blocks" 2 "$path_rule_payload"

  # 4. Clean shrink Edit (drop a stale line, retain a durable pointer) → allowed.
  shrink_old='# Project

- See src/api/foo.ts for API patterns.
- Delete this line.
'
  shrink_new='# Project

- See src/api/foo.ts for API patterns.
'
  printf '%s' "$shrink_old" > "$target"
  shrink_payload=$(jq -n --arg path "$target" --arg old "$shrink_old" --arg new "$shrink_new" \
    '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
  run_case "$name: clean shrink Edit allows" 0 "$shrink_payload"
done

if [ "$FAIL" -eq 0 ]; then
  echo "All full-chain context-file fixtures passed."
  exit 0
fi
echo "Full-chain context-file fixtures FAILED."
exit 1
