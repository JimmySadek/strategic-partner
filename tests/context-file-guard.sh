#!/usr/bin/env bash
HERE=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$HERE/.." && pwd)
GUARD="$PROJECT_ROOT/hooks/context-file-guard.sh"
fail=0

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

run_guard() {
  printf '%s' "$1" | bash "$GUARD" >/tmp/context-file-guard-test.out 2>&1
}

safe_content='- Run `pnpm test` before committing frontend changes.'
safe_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg content "$safe_content" \
  '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
if run_guard "$safe_payload"; then
  echo "✅ guard allows concise CLAUDE.md write"
else
  echo "❌ guard blocked concise write"; cat /tmp/context-file-guard-test.out; fail=1
fi

journey='## #5177 Data Upload page — locked 2026-06-19
✅ **SHIPPED (local, unpushed)** — 5 commits, browser-verified both tenants.
Commit `5f953ca`. Files: `DataUpload.tsx`, `UploadModal.tsx`, `UploadChoiceModal.tsx`, `ManualEntryModal.tsx`.'
journey_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg content "$journey" \
  '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
if run_guard "$journey_payload"; then
  echo "❌ guard allowed journey dump"; fail=1
else
  echo "✅ guard blocks journey dump"
fi

yes "- Existing line." | head -210 > "$TMP/CLAUDE.md"
short='# Project Rules

- Run `pnpm test` before committing frontend changes.'
edit_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg old "$(cat "$TMP/CLAUDE.md")" --arg new "$short" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed destructive tiny replacement"; fail=1
else
  echo "✅ guard blocks destructive tiny replacement"
fi

stub='# Project Rules

See [context-file stewardship](references/context-file-stewardship.md) for extracted context rules.'
edit_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg old "$(cat "$TMP/CLAUDE.md")" --arg new "$stub" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "✅ guard allows extraction-shaped shrink replacement"
else
  echo "❌ guard blocked extraction-shaped shrink replacement"; cat /tmp/context-file-guard-test.out; fail=1
fi

shrink_old='# Project

- See src/api/foo.ts for API patterns.
- Delete this line.
'
shrink_new='# Project

- See src/api/foo.ts for API patterns.
'
printf '%s' "$shrink_old" > "$TMP/CLAUDE.md"
edit_payload=$(jq -n --arg path "$TMP/CLAUDE.md" --arg old "$shrink_old" --arg new "$shrink_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "✅ guard allows pure shrink with retained path"
else
  echo "❌ guard blocked pure shrink with retained path"; cat /tmp/context-file-guard-test.out; fail=1
fi

mkdir -p "$TMP/sibling-match"
sibling_good='- See .claude/rules/x.md for source-editing rules.'
sibling_bad='- See .Codex/rules/x.md for source-editing rules.'
printf '%s\n' "$sibling_good" > "$TMP/sibling-match/CLAUDE.md"
printf '%s\n' "$sibling_bad" > "$TMP/sibling-match/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/sibling-match/AGENTS.md" --arg old "$sibling_bad" --arg new "$sibling_good" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "✅ guard allows same-content sibling-matched path fix"
else
  echo "❌ guard blocked same-content sibling-matched path fix"; cat /tmp/context-file-guard-test.out; fail=1
fi

mkdir -p "$TMP/large-sibling-duplicate"
large_duplicate_block=$(
  i=1
  while [ "$i" -le 205 ]; do
    printf -- '- Shared context policy %03d applies to root files.\n' "$i"
    i=$((i + 1))
  done
)
large_duplicate_old='# Project Rules'
large_duplicate_new="# Project Rules

$large_duplicate_block"
printf '# Shared Rules\n\n%s\n' "$large_duplicate_block" > "$TMP/large-sibling-duplicate/CLAUDE.md"
printf '%s\n' "$large_duplicate_old" > "$TMP/large-sibling-duplicate/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/large-sibling-duplicate/AGENTS.md" --arg old "$large_duplicate_old" --arg new "$large_duplicate_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed large sibling-duplicate context growth"; fail=1
else
  echo "✅ guard blocks large sibling-duplicate context growth"
fi

mkdir -p "$TMP/substring-sibling-match"
substring_old='# Project Rules
'
substring_new='# Project Rules

.md'
printf '%s\n' '- See CHANGELOG.md' > "$TMP/substring-sibling-match/CLAUDE.md"
printf '%s\n' "$substring_old" > "$TMP/substring-sibling-match/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/substring-sibling-match/AGENTS.md" --arg old "$substring_old" --arg new "$substring_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed substring-only sibling match"; fail=1
else
  echo "✅ guard blocks substring-only sibling match"
fi

mkdir -p "$TMP/no-sibling-match"
printf '%s\n' '- Keep root instructions concise.' > "$TMP/no-sibling-match/CLAUDE.md"
printf '%s\n' "$sibling_bad" > "$TMP/no-sibling-match/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/no-sibling-match/AGENTS.md" --arg old "$sibling_bad" --arg new "$sibling_good" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed sibling-missing path fix through append preflight"; fail=1
else
  echo "✅ guard still blocks path fix without sibling match"
fi

mkdir -p "$TMP/partial-sibling-match"
partial_old='# Project Rules

- Keep root instructions concise.'
partial_new='# Project Rules

- Keep root instructions concise.
- See .claude/rules/x.md for source-editing rules.
- See .claude/rules/y.md for hook rules.'
printf '%s\n' "$sibling_good" > "$TMP/partial-sibling-match/CLAUDE.md"
printf '%s\n' "$partial_old" > "$TMP/partial-sibling-match/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/partial-sibling-match/AGENTS.md" --arg old "$partial_old" --arg new "$partial_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed partial sibling match through append preflight"; fail=1
else
  echo "✅ guard still blocks partial sibling match"
fi

mkdir -p "$TMP/genuine-growth"
growth_old='# Project Rules'
growth_new='# Project Rules

- See .claude/rules/new.md for backend rules.'
printf '%s\n' "$growth_old" > "$TMP/genuine-growth/CLAUDE.md"
printf '%s\n' '- Keep root instructions concise.' > "$TMP/genuine-growth/AGENTS.md"
edit_payload=$(jq -n --arg path "$TMP/genuine-growth/CLAUDE.md" --arg old "$growth_old" --arg new "$growth_new" \
  '{tool_name:"Edit", tool_input:{file_path:$path, old_string:$old, new_string:$new}}')
if run_guard "$edit_payload"; then
  echo "❌ guard allowed genuine root context growth"; fail=1
else
  echo "✅ guard still blocks genuine root context growth"
fi

mkdir -p "$TMP/.claude/rules"
rule_payload=$(jq -n --arg path "$TMP/.claude/rules/api.md" --arg content "- All files under \`src/api/\` must use the shared request validator." \
  '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
if run_guard "$rule_payload"; then
  echo "✅ guard allows path-scoped rule file"
else
  echo "❌ guard blocked path-scoped rule"; cat /tmp/context-file-guard-test.out; fail=1
fi

rule_journey_payload=$(jq -n --arg path "$TMP/.claude/rules/api.md" --arg content "$journey" \
  '{tool_name:"Write", tool_input:{file_path:$path, content:$content}}')
if run_guard "$rule_journey_payload"; then
  echo "❌ guard allowed journey dump in rules file"; fail=1
else
  echo "✅ guard blocks journey dump in rules file"
fi

shadow="$TMP/shadow-jq"
mkdir -p "$shadow"
printf '#!/bin/sh\nexit 127\n' > "$shadow/jq"
chmod +x "$shadow/jq"
if printf '%s' "$journey_payload" | PATH="$shadow:/usr/bin:/bin" bash "$GUARD" >/tmp/context-file-guard-test.out 2>&1; then
  echo "❌ guard allowed context-file write when jq was unavailable"; fail=1
else
  code=$?
  if [ "$code" = "2" ]; then
    echo "✅ guard fails closed when jq is unavailable"
  else
    echo "❌ expected jq-unavailable block exit 2, got $code"; cat /tmp/context-file-guard-test.out; fail=1
  fi
fi

bash_payload=$(jq -n --arg cmd "printf '%s\n' bad >> $TMP/CLAUDE.md" \
  '{tool_name:"Bash", tool_input:{command:$cmd}}')
if run_guard "$bash_payload"; then
  echo "❌ guard allowed direct shell mutation"; fail=1
else
  echo "✅ guard blocks direct shell mutation"
fi

readonly_payload=$(jq -n --arg cmd "grep -n Project $TMP/CLAUDE.md >/dev/null" \
  '{tool_name:"Bash", tool_input:{command:$cmd}}')
if run_guard "$readonly_payload"; then
  echo "✅ guard allows read-only shell redirect"
else
  echo "❌ guard blocked read-only shell redirect"; cat /tmp/context-file-guard-test.out; fail=1
fi

for cmd in \
  "cp /tmp/x $TMP/CLAUDE.md" \
  "mv /tmp/x '$TMP/CLAUDE.md'" \
  "install /tmp/x $TMP/CLAUDE.md" \
  "dd if=/tmp/x of=$TMP/CLAUDE.md" \
  "sed -i 's/x/y/' $TMP/CLAUDE.md" \
  "perl -pi -e 's/x/y/' $TMP/CLAUDE.md" \
  "f=$TMP/CLAUDE.md; echo junk > \"\$f\"" \
  "cp /tmp/x $TMP/claude.md"
do
  bash_payload=$(jq -n --arg cmd "$cmd" '{tool_name:"Bash", tool_input:{command:$cmd}}')
  if run_guard "$bash_payload"; then
    echo "❌ guard allowed shell mutation: $cmd"; fail=1
  else
    echo "✅ guard blocks shell mutation: $cmd"
  fi
done

exit $fail
