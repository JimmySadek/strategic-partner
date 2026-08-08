#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DOCTOR="$ROOT/.scripts/serena-doctor.sh"
REPAIR="$ROOT/.scripts/serena-repair.sh"
PASS=0
FAIL=0

pass() { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s — %s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

assert_command_contract() {
  command_file="$1"
  surface="$2"
  missing=""
  forbidden=""

  normalized=$(tr '\n' ' ' < "$command_file" | tr -s ' ')
  for required in \
    'Apply machine-wide Serena repair (Recommended)' \
    '~/.claude/settings.json' \
    '~/.claude.json' \
    'user-scope Serena MCP registration' \
    'official Serena plugin' \
    'lifecycle hooks' \
    'backup' \
    'rollback' \
    'fresh Claude session' \
    '--apply --yes' \
    '--verify'
  do
    printf '%s' "$normalized" | grep -qF -- "$required" || missing="${missing}${missing:+, }${required}"
  done

  for rejected in \
    'general-purpose' \
    'subagent_type' \
    'invoke Agent' \
    'invoke Task' \
    'Dispatch now'
  do
    grep -qF -- "$rejected" "$command_file" && forbidden="${forbidden}${forbidden:+, }${rejected}"
  done

  transaction_line=$(grep -n -- '--apply --yes && .*--verify' "$command_file" | head -1 | cut -d: -f1)

  if [ -z "$missing" ] && [ -z "$forbidden" ] && [ -n "$transaction_line" ]; then
    pass "$surface command keeps consent and execution in one shell-enforced trust boundary"
  else
    fail "$surface command contract" "missing=${missing:-none} forbidden=${forbidden:-none} transaction_line=${transaction_line:-none}"
  fi
}

assert_command_contract "$ROOT/commands/serena.md" "skill"
assert_command_contract "$ROOT/plugin/strategic-partner/commands/serena.md" "plugin"

assert_state() {
  name="$1"
  expected="$2"
  home_dir="$3"
  shift 3
  before=$(find "$home_dir" -type f -exec shasum {} \; 2>/dev/null | sort)
  output=$(HOME="$home_dir" PATH="$home_dir/bin:/usr/bin:/bin:/opt/homebrew/bin" "$@" "$DOCTOR" --format=json 2>&1)
  status=$?
  after=$(find "$home_dir" -type f -exec shasum {} \; 2>/dev/null | sort)
  actual=$(printf '%s' "$output" | sed -n 's/.*"state":"\([^"]*\)".*/\1/p')
  if [ "$status" -eq 0 ] && [ "$actual" = "$expected" ]; then
    pass "$name classifies as $expected"
  else
    fail "$name" "expected=$expected actual=${actual:-none} status=$status output=$output"
  fi
  if [ "$before" = "$after" ]; then
    pass "$name is read-only"
  else
    fail "$name read-only" "files changed during diagnosis"
  fi
}

make_home() {
  base=$(mktemp -d "${TMPDIR:-/tmp}/sp-serena-test.XXXXXX")
  mkdir -p "$base/bin" "$base/.claude"
  printf '%s\n' "$base"
}

write_stable_serena() {
  home_dir="$1"
  cat > "$home_dir/bin/serena" <<'SH'
#!/bin/sh
case "${1:-}" in
  --version) printf '%s\n' 'Serena 1.5.3' ;;
  *) exit 0 ;;
esac
SH
  cat > "$home_dir/bin/serena-hooks" <<'SH'
#!/bin/sh
exit 0
SH
  chmod +x "$home_dir/bin/serena" "$home_dir/bin/serena-hooks"
}

write_dev_serena() {
  home_dir="$1"
  cat > "$home_dir/bin/serena" <<'SH'
#!/bin/sh
printf '%s\n' 'Serena 1.5.4.dev0'
SH
  cat > "$home_dir/bin/serena-hooks" <<'SH'
#!/bin/sh
exit 0
SH
  chmod +x "$home_dir/bin/serena" "$home_dir/bin/serena-hooks"
}

write_user_server() {
  home_dir="$1"
  quiet="${2:-yes}"
  quiet_arg=''
  [ "$quiet" = yes ] && quiet_arg=', "--open-web-dashboard", "False"'
  cat > "$home_dir/.claude.json" <<EOF
{"mcpServers":{"serena":{"command":"$home_dir/bin/serena","args":["start-mcp-server","--context=claude-code","--project-from-cwd"$quiet_arg]}}}
EOF
}

write_settings() {
  home_dir="$1"
  plugin="${2:-false}"
  complete="${3:-yes}"
  if [ "$complete" = yes ]; then
    cat > "$home_dir/.claude/settings.json" <<EOF
{"enabledPlugins":{"serena@claude-plugins-official":$plugin},"permissions":{"allow":[]},"hooks":{"PreToolUse":[{"matcher":"","hooks":[{"type":"command","command":"'$home_dir/bin/serena-hooks' remind --client=claude-code"}]},{"matcher":"mcp__serena__*","hooks":[{"type":"command","command":"'$home_dir/bin/serena-hooks' auto-approve --client=claude-code"}]}],"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"'$home_dir/bin/serena-hooks' activate --client=claude-code"}]}],"SessionEnd":[{"matcher":"","hooks":[{"type":"command","command":"'$home_dir/bin/serena-hooks' cleanup --client=claude-code"}]}]}}
EOF
  else
    printf '%s\n' "{\"enabledPlugins\":{\"serena@claude-plugins-official\":$plugin},\"permissions\":{\"allow\":[]},\"hooks\":{}}" > "$home_dir/.claude/settings.json"
  fi
}

home=$(make_home)
write_settings "$home" false no
assert_state "absent" absent "$home" env

home=$(make_home)
printf '%s\n' '{malformed' > "$home/.claude/settings.json"
assert_state "malformed settings" misconfigured "$home" env

home=$(make_home)
write_settings "$home" true no
assert_state "official plugin" legacy-plugin "$home" env

home=$(make_home)
write_dev_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
assert_state "development Serena" outdated "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" true yes
assert_state "duplicate registration" duplicate "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" no
write_settings "$home" false yes
assert_state "dashboard opens" noisy-dashboard "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false no
assert_state "partial integration" partial-hooks "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
assert_state "supported setup" healthy "$home" env

home_parent=$(mktemp -d "${TMPDIR:-/tmp}/sp-serena-space.XXXXXX")
home="$home_parent/home with spaces"
mkdir -p "$home/bin" "$home/.claude"
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
assert_state "path with spaces" healthy "$home" env

home=$(make_home)
write_stable_serena "$home"
write_settings "$home" false yes
cat > "$home/bin/uvx" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$home/bin/uvx"
cat > "$home/.claude.json" <<EOF
{"mcpServers":{"serena":{"command":"$home/bin/uvx","args":["--from","git+https://github.com/oraios/serena","start-mcp-server","--context=claude-code","--project-from-cwd","--open-web-dashboard","False"]}}}
EOF
assert_state "moving Git launcher" misconfigured "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
jq --arg cwd "$ROOT" '.projects[$cwd].mcpServers.serena={"command":"serena","args":["start-mcp-server"]}' "$home/.claude.json" > "$home/.claude.json.tmp" && mv "$home/.claude.json.tmp" "$home/.claude.json"
assert_state "local scope conflict" duplicate "$home" env SP_SERENA_PROJECT_PATH="$ROOT"

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
repo_fixture=$(mktemp -d "${TMPDIR:-/tmp}/sp-serena-repo.XXXXXX")
mkdir -p "$repo_fixture/.git" "$repo_fixture/packages/app"
cat > "$repo_fixture/.mcp.json" <<EOF
{"mcpServers":{"memory-engine":{"command":"uvx","args":["--from","git+https://github.com/oraios/serena","start-mcp-server"]}}}
EOF
assert_state "repo-root alternate-name conflict from subdirectory" duplicate "$home" env SP_SERENA_PROJECT_PATH="$repo_fixture/packages/app"

home=$(make_home)
write_stable_serena "$home"
write_settings "$home" false yes
cat > "$home/.claude.json" <<EOF
{"mcpServers":{"memory-engine":{"command":"$home/bin/serena","args":["start-mcp-server","--context=claude-code","--project-from-cwd","--open-web-dashboard","False"]}}}
EOF
assert_state "alternate user server name" duplicate "$home" env

home=$(make_home)
write_stable_serena "$home"
write_user_server "$home" yes
write_settings "$home" false yes
assert_state "native Windows" unsupported-platform "$home" env SP_SERENA_PLATFORM=native-windows

write_fake_uv() {
  home_dir="$1"
  cat > "$home_dir/bin/uv" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$HOME/uv.log"
if [ "${1:-}" = tool ] && [ "${2:-}" = install ]; then
  cat > "$HOME/bin/serena" <<'EOF'
#!/bin/sh
case "${1:-}" in
  --version) printf '%s\n' 'Serena 1.5.3' ;;
  *) exit 0 ;;
esac
EOF
  cat > "$HOME/bin/serena-hooks" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$HOME/bin/serena" "$HOME/bin/serena-hooks"
elif [ "${1:-}" = tool ] && [ "${2:-}" = uninstall ]; then
  rm -f "$HOME/bin/serena" "$HOME/bin/serena-hooks"
fi
SH
  chmod +x "$home_dir/bin/uv"
}

write_fake_claude() {
  home_dir="$1"
  jq_path=$(command -v jq)
  cat > "$home_dir/bin/claude" <<SH
#!/bin/sh
printf '%s\n' "\$*" >> "\$HOME/claude.log"
JQ="$jq_path"
if [ "\${1:-}" = mcp ] && [ "\${2:-}" = remove ]; then
  [ -f "\$HOME/.claude.json" ] || exit 0
  "\$JQ" 'del(.mcpServers.serena)' "\$HOME/.claude.json" > "\$HOME/.claude.json.tmp" && mv "\$HOME/.claude.json.tmp" "\$HOME/.claude.json"
elif [ "\${1:-}" = mcp ] && [ "\${2:-}" = add ]; then
  shift 2
  [ "\${1:-}" = --scope ] && shift 2
  name="\${1:-}"; shift
  [ "\${1:-}" = -- ] && shift
  command="\${1:-}"; shift
  args_json=\$(printf '%s\n' "\$@" | "\$JQ" -R . | "\$JQ" -s .)
  [ -f "\$HOME/.claude.json" ] || printf '%s\n' '{}' > "\$HOME/.claude.json"
  "\$JQ" --arg cmd "\$command" --argjson args "\$args_json" '.mcpServers.serena={command:\$cmd,args:\$args}' "\$HOME/.claude.json" > "\$HOME/.claude.json.tmp" && mv "\$HOME/.claude.json.tmp" "\$HOME/.claude.json"
elif [ "\${1:-}" = plugin ] && [ "\${2:-}" = disable ]; then
  [ -f "\$HOME/.claude/settings.json" ] || exit 0
  "\$JQ" '.enabledPlugins["serena@claude-plugins-official"]=false' "\$HOME/.claude/settings.json" > "\$HOME/.claude/settings.json.tmp" && mv "\$HOME/.claude/settings.json.tmp" "\$HOME/.claude/settings.json"
fi
SH
  chmod +x "$home_dir/bin/claude"
}

repair_parent=$(mktemp -d "${TMPDIR:-/tmp}/sp-serena-repair-space.XXXXXX")
home="$repair_parent/home with spaces"
mkdir -p "$home/bin" "$home/.claude"
write_settings "$home" false no
write_fake_uv "$home"
write_fake_claude "$home"
jq '.permissions.allow=["mcp__serena__*"]
  | .hooks={"PreToolUse":[{"matcher":"","hooks":[{"type":"command","command":"serena-hooks remind --client=claude-code"},{"type":"command","command":"keep-me"}]}],"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"serena-hooks activate --client=claude-code"}]}],"SessionEnd":[{"matcher":"","hooks":[{"type":"command","command":"serena-hooks cleanup --client=claude-code"}]}]}' "$home/.claude/settings.json" > "$home/.claude/settings.json.tmp" && mv "$home/.claude/settings.json.tmp" "$home/.claude/settings.json"
plan_output=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --plan 2>&1)
if printf '%s' "$plan_output" | grep -q 'stable Serena 1.5.3' && printf '%s' "$plan_output" | grep -q 'quiet dashboard'; then
  pass "absent repair plan is explicit"
else
  fail "absent repair plan" "$plan_output"
fi

unconfirmed=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --apply 2>&1)
unconfirmed_status=$?
if [ "$unconfirmed_status" -eq 2 ] && [ ! -e "$home/.claude.json" ]; then
  pass "apply requires explicit confirmation"
else
  fail "apply confirmation" "status=$unconfirmed_status output=$unconfirmed"
fi

prereq_home=$(make_home)
write_settings "$prereq_home" false no
prereq_unconfirmed=$(HOME="$prereq_home" PATH="$prereq_home/bin:/usr/bin:/bin" "$REPAIR" --install-prerequisite 2>&1)
prereq_status=$?
if [ "$prereq_status" -eq 2 ] && printf '%s' "$prereq_unconfirmed" | grep -q 'user approves'; then
  pass "prerequisite install requires separate confirmation"
else
  fail "prerequisite confirmation" "status=$prereq_status output=$prereq_unconfirmed"
fi

conflict_home=$(make_home)
write_stable_serena "$conflict_home"
write_user_server "$conflict_home" yes
write_settings "$conflict_home" false yes
write_fake_uv "$conflict_home"
write_fake_claude "$conflict_home"
jq --arg cwd "$ROOT" '.projects[$cwd].mcpServers.serena={"command":"serena","args":["start-mcp-server"]}' "$conflict_home/.claude.json" > "$conflict_home/.claude.json.tmp" && mv "$conflict_home/.claude.json.tmp" "$conflict_home/.claude.json"
conflict_before=$(find "$conflict_home" -type f -exec shasum {} \; | sort)
conflict_output=$(HOME="$conflict_home" PATH="$conflict_home/bin:/usr/bin:/bin:/opt/homebrew/bin" SP_SERENA_PROJECT_PATH="$ROOT" "$REPAIR" --apply --yes 2>&1)
conflict_status=$?
conflict_after=$(find "$conflict_home" -type f -exec shasum {} \; | sort)
if [ "$conflict_status" -eq 2 ] && [ "$conflict_before" = "$conflict_after" ] && printf '%s' "$conflict_output" | grep -q 'will not add a user server'; then
  pass "scope conflict fails closed before mutation"
else
  fail "scope conflict safety" "status=$conflict_status output=$conflict_output"
fi

dev_home=$(make_home)
mkdir -p "$dev_home/.local/share/uv/tools/serena-agent/bin"
cat > "$dev_home/.local/share/uv/tools/serena-agent/bin/serena" <<'SH'
#!/bin/sh
printf '%s\n' 'Serena 1.5.4.dev0'
SH
cat > "$dev_home/.local/share/uv/tools/serena-agent/bin/serena-hooks" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$dev_home/.local/share/uv/tools/serena-agent/bin/serena" "$dev_home/.local/share/uv/tools/serena-agent/bin/serena-hooks"
ln -s "$dev_home/.local/share/uv/tools/serena-agent/bin/serena" "$dev_home/bin/serena"
ln -s "$dev_home/.local/share/uv/tools/serena-agent/bin/serena-hooks" "$dev_home/bin/serena-hooks"
write_user_server "$dev_home" yes
write_settings "$dev_home" false yes
write_fake_uv "$dev_home"
write_fake_claude "$dev_home"
dev_before=$(find "$dev_home" -type f -exec shasum {} \; | sort)
dev_output=$(HOME="$dev_home" PATH="$dev_home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --apply --yes 2>&1)
dev_status=$?
dev_after=$(find "$dev_home" -type f -exec shasum {} \; | sort)
if [ "$dev_status" -eq 2 ] && [ "$dev_before" = "$dev_after" ] && printf '%s' "$dev_output" | grep -q 'development installation'; then
  pass "development runtime is not replaced without restorable provenance"
else
  fail "development runtime safety" "status=$dev_status output=$dev_output"
fi

apply_output=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --apply --yes 2>&1)
apply_status=$?
state=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$DOCTOR" --field state)
if [ "$apply_status" -eq 0 ] && [ "$state" = healthy ]; then
  pass "absent setup converges to healthy"
else
  fail "absent setup" "status=$apply_status state=$state output=$apply_output"
fi
if grep -q -- '--open-web-dashboard False' "$home/claude.log" && grep -q -- '--context=claude-code --project-from-cwd' "$home/claude.log"; then
  pass "repair registers quiet Claude launcher"
else
  fail "quiet Claude launcher" "$(cat "$home/claude.log" 2>/dev/null)"
fi
managed_hook_count=$(jq '[.hooks[][]?.hooks[]?.command | select(test("serena-hooks"))] | length' "$home/.claude/settings.json")
broad_allow_count=$(jq '[.permissions.allow[]? | select(. == "mcp__serena__*" or . == "mcp__plugin_serena_serena__*")] | length' "$home/.claude/settings.json")
unrelated_hook_count=$(jq '[.hooks.PreToolUse[]?.hooks[]?.command | select(. == "keep-me")] | length' "$home/.claude/settings.json")
if [ "$managed_hook_count" -eq 4 ] && [ "$broad_allow_count" -eq 0 ] && [ "$unrelated_hook_count" -eq 1 ]; then
  pass "repair normalizes Serena hooks and preserves stricter permissions"
else
  fail "hook and permission normalization" "managed=$managed_hook_count broad=$broad_allow_count unrelated=$unrelated_hook_count"
fi

migration_home=$(make_home)
write_stable_serena "$migration_home"
write_settings "$migration_home" true no
write_fake_uv "$migration_home"
write_fake_claude "$migration_home"
cat > "$migration_home/.claude.json" <<EOF
{"mcpServers":{"serena":{"command":"$migration_home/bin/uvx","args":["--from","git+https://github.com/oraios/serena","start-mcp-server","--context=claude-code","--project-from-cwd","--open-web-dashboard","False"]}}}
EOF
cat > "$migration_home/bin/uvx" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$migration_home/bin/uvx"
migration_output=$(HOME="$migration_home" PATH="$migration_home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --apply --yes 2>&1)
migration_status=$?
migration_state=$(HOME="$migration_home" PATH="$migration_home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$DOCTOR" --field state)
if [ "$migration_status" -eq 0 ] && [ "$migration_state" = healthy ] && [ ! -e "$migration_home/uv.log" ]; then
  pass "moving Git launcher migrates to the existing stable runtime"
else
  fail "moving Git migration" "status=$migration_status state=$migration_state output=$migration_output"
fi

before_second=$(shasum "$home/.claude/settings.json" "$home/.claude.json")
second_output=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --apply --yes 2>&1)
second_status=$?
after_second=$(shasum "$home/.claude/settings.json" "$home/.claude.json")
if [ "$second_status" -eq 0 ] && [ "$before_second" = "$after_second" ]; then
  pass "repair is idempotent when healthy"
else
  fail "repair idempotency" "status=$second_status output=$second_output"
fi

bad_home=$(make_home)
bad_state="$bad_home/state"
mkdir -p "$bad_state/backups/broken"
printf '%s\n' 'runtime_present=true' 'runtime_version=1.5.3' 'runtime_uv_managed=false' > "$bad_state/backups/broken/manifest"
printf '%s\n' "$bad_state/backups/broken" > "$bad_state/latest-backup"
printf '%s\n' 'expected_state=healthy' > "$bad_state/restart-verification"
bad_rollback_output=$(HOME="$bad_home" PATH="$bad_home/bin:/usr/bin:/bin:/opt/homebrew/bin" SP_SERENA_STATE_DIR="$bad_state" "$REPAIR" --rollback --yes 2>&1)
bad_rollback_status=$?
if [ "$bad_rollback_status" -ne 0 ] && [ -f "$bad_state/restart-verification" ] && printf '%s' "$bad_rollback_output" | grep -q 'incomplete'; then
  pass "incomplete rollback fails and preserves verification receipt"
else
  fail "rollback failure safety" "status=$bad_rollback_status output=$bad_rollback_output"
fi

rollback_output=$(HOME="$home" PATH="$home/bin:/usr/bin:/bin:/opt/homebrew/bin" "$REPAIR" --rollback --yes 2>&1)
rollback_status=$?
if [ "$rollback_status" -eq 0 ] && [ ! -e "$home/.claude.json" ] && [ ! -e "$home/bin/serena" ]; then
  pass "rollback restores absent state"
else
  fail "repair rollback" "status=$rollback_status output=$rollback_output"
fi

printf '\nSerena stewardship doctor: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
