#!/usr/bin/env bash
set -u

# Read-only Serena integration health check for Strategic Partner.
# macOS bash 3.2 compatible. No files, settings, or registrations are changed.

FORMAT=human
FIELD=""
case "${1:-}" in
  --format=json) FORMAT=json ;;
  --field) FIELD="${2:-}" ;;
  --help|-h)
    printf '%s\n' "Usage: serena-doctor.sh [--format=json | --field state]"
    exit 0
    ;;
esac

SETTINGS_PATH="${SP_SERENA_SETTINGS_PATH:-${HOME}/.claude/settings.json}"
CLAUDE_JSON_PATH="${SP_SERENA_CLAUDE_JSON_PATH:-${HOME}/.claude.json}"
PROJECT_PATH="${SP_SERENA_PROJECT_PATH:-$(pwd -P)}"
SUPPORTED_VERSION="${SP_SERENA_SUPPORTED_VERSION:-1.5.3}"

PROJECT_ROOT="$PROJECT_PATH"
probe="$PROJECT_PATH"
while [ -n "$probe" ]; do
  if [ -e "$probe/.git" ] || [ -f "$probe/.serena/project.yml" ]; then
    PROJECT_ROOT="$probe"
    break
  fi
  parent=$(dirname "$probe")
  [ "$parent" = "$probe" ] && break
  probe="$parent"
done
PROJECT_MCP_PATH="${SP_SERENA_PROJECT_MCP_PATH:-${PROJECT_ROOT}/.mcp.json}"

has_jq=false
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
  has_jq=true
fi

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

plugin_enabled=false
user_server=false
local_server=false
project_server=false
user_server_count=0
local_server_count=0
project_server_count=0
settings_valid=true
claude_json_valid=true
project_mcp_valid=true
server_text=""
server_command=""

if [ -r "$SETTINGS_PATH" ]; then
  if [ "$has_jq" = false ]; then
    settings_valid=false
  elif ! jq -e type "$SETTINGS_PATH" >/dev/null 2>&1; then
    settings_valid=false
  elif jq -e '.enabledPlugins["serena@claude-plugins-official"] == true' "$SETTINGS_PATH" >/dev/null 2>&1; then
    plugin_enabled=true
  fi
fi

if [ -r "$CLAUDE_JSON_PATH" ]; then
  if [ "$has_jq" = false ]; then
    claude_json_valid=false
  elif ! jq -e type "$CLAUDE_JSON_PATH" >/dev/null 2>&1; then
    claude_json_valid=false
  else
    user_server_count=$(jq '[.mcpServers // {} | to_entries[] | select(
      .key == "serena"
      or ((.value.command // "") | test("(^|/)serena$"))
      or (((.value.command // "") | test("(^|/)uvx$")) and (((.value.args // []) | join(" ")) | test("serena"; "i")))
      or ((((.value.args // []) | join(" ")) | test("serena"; "i")) and (((.value.args // []) | join(" ")) | test("start-mcp-server")))
    )] | length' "$CLAUDE_JSON_PATH" 2>/dev/null || printf '0')
    if jq -e '.mcpServers.serena | type == "object"' "$CLAUDE_JSON_PATH" >/dev/null 2>&1; then
      user_server=true
      server_text=$(jq -c '.mcpServers.serena' "$CLAUDE_JSON_PATH" 2>/dev/null)
      server_command=$(jq -r '.mcpServers.serena.command // ""' "$CLAUDE_JSON_PATH" 2>/dev/null)
    fi
    local_server_count=$(jq --arg root "$PROJECT_ROOT" '[.projects[$root].mcpServers // {} | to_entries[] | select(
      .key == "serena"
      or ((.value.command // "") | test("(^|/)serena$"))
      or (((.value.command // "") | test("(^|/)uvx$")) and (((.value.args // []) | join(" ")) | test("serena"; "i")))
      or ((((.value.args // []) | join(" ")) | test("serena"; "i")) and (((.value.args // []) | join(" ")) | test("start-mcp-server")))
    )] | length' "$CLAUDE_JSON_PATH" 2>/dev/null || printf '0')
    if [ "$local_server_count" -gt 0 ]; then
      local_server=true
    fi
  fi
fi

if [ -r "$PROJECT_MCP_PATH" ]; then
  if [ "$has_jq" = false ]; then
    project_mcp_valid=false
  elif ! jq -e type "$PROJECT_MCP_PATH" >/dev/null 2>&1; then
    project_mcp_valid=false
  else
    project_server_count=$(jq '[.mcpServers // {} | to_entries[] | select(
      .key == "serena"
      or ((.value.command // "") | test("(^|/)serena$"))
      or (((.value.command // "") | test("(^|/)uvx$")) and (((.value.args // []) | join(" ")) | test("serena"; "i")))
      or ((((.value.args // []) | join(" ")) | test("serena"; "i")) and (((.value.args // []) | join(" ")) | test("start-mcp-server")))
    )] | length' "$PROJECT_MCP_PATH" 2>/dev/null || printf '0')
    [ "$project_server_count" -eq 0 ] || project_server=true
  fi
fi

registration_count=0
[ "$plugin_enabled" = true ] && registration_count=$((registration_count + 1))
registration_count=$((registration_count + user_server_count + local_server_count + project_server_count))
scope_conflict=false
if [ "$local_server" = true ] || [ "$project_server" = true ] \
  || { [ "$user_server_count" -gt 0 ] && [ "$user_server" = false ]; } \
  || [ "$user_server_count" -gt 1 ]; then
  scope_conflict=true
fi

path_serena=$(command -v serena 2>/dev/null || printf '')
serena_path="$path_serena"
configured_binary_ok=false
if [ "$user_server" = true ]; then
  case "$server_command" in
    /*)
      if [ -x "$server_command" ] && ! printf '%s' "$server_text" | grep -Eq 'uvx|git\+'; then
        serena_path="$server_command"
        configured_binary_ok=true
      fi
      ;;
  esac
fi

hooks_path=$(command -v serena-hooks 2>/dev/null || printf '')
runtime_pair_ok=false
if [ -n "$serena_path" ] && [ -n "$hooks_path" ] \
  && [ "$(dirname "$serena_path")" = "$(dirname "$hooks_path")" ]; then
  runtime_pair_ok=true
fi

serena_version=""
if [ -n "$serena_path" ] && [ -x "$serena_path" ]; then
  serena_version=$("$serena_path" --version 2>/dev/null | sed -n 's/^Serena[[:space:]]*//p' | head -1)
fi
version_is_outdated=false
if [ -n "$serena_version" ]; then
  case "$serena_version" in
    *dev*|*dirty*|*-*) version_is_outdated=true ;;
    *) [ "$serena_version" = "$SUPPORTED_VERSION" ] || version_is_outdated=true ;;
  esac
fi

context_ok=false
project_ok=false
quiet_dashboard=false
if [ "$user_server" = true ]; then
  printf '%s' "$server_text" | grep -Eq -- '--context=claude-code|"--context"[[:space:]]*,[[:space:]]*"claude-code"' && context_ok=true
  printf '%s' "$server_text" | grep -q -- '--project-from-cwd' && project_ok=true
  printf '%s' "$server_text" | grep -Eq -- '--open-web-dashboard(=|"[[:space:]]*,[[:space:]]*")([Ff]alse|false)' && quiet_dashboard=true
fi

hooks_complete=false
remind_hook=false
activate_hook=false
cleanup_hook=false
approve_hook=false
if [ "$has_jq" = true ] && [ "$settings_valid" = true ] && [ -n "$hooks_path" ]; then
  quoted_hooks=$(shell_quote "$hooks_path")
  remind_command="${quoted_hooks} remind --client=claude-code"
  activate_command="${quoted_hooks} activate --client=claude-code"
  cleanup_command="${quoted_hooks} cleanup --client=claude-code"
  approve_command="${quoted_hooks} auto-approve --client=claude-code"
  jq -e --arg cmd "$remind_command" '[.hooks.PreToolUse[]?.hooks[]?.command] | any(. == $cmd)' "$SETTINGS_PATH" >/dev/null 2>&1 && remind_hook=true
  jq -e --arg cmd "$activate_command" '[.hooks.SessionStart[]?.hooks[]?.command] | any(. == $cmd)' "$SETTINGS_PATH" >/dev/null 2>&1 && activate_hook=true
  jq -e --arg cmd "$cleanup_command" '[.hooks.SessionEnd[]?.hooks[]?.command] | any(. == $cmd)' "$SETTINGS_PATH" >/dev/null 2>&1 && cleanup_hook=true
  jq -e --arg cmd "$approve_command" '[.hooks.PreToolUse[]? | select(.matcher == "mcp__serena__*") | .hooks[]?.command] | any(. == $cmd)' "$SETTINGS_PATH" >/dev/null 2>&1 && approve_hook=true
fi
if [ "$remind_hook" = true ] && [ "$activate_hook" = true ] \
  && [ "$cleanup_hook" = true ] && [ "$approve_hook" = true ]; then
  hooks_complete=true
fi

permission_safe=true
if [ "$has_jq" = false ] && [ -r "$SETTINGS_PATH" ]; then
  permission_safe=false
elif [ "$settings_valid" = true ] && [ -r "$SETTINGS_PATH" ]; then
  if jq -e '(.permissions.allow // []) | any(. == "mcp__serena__*" or . == "mcp__plugin_serena_serena__*")' "$SETTINGS_PATH" >/dev/null 2>&1; then
    permission_safe=false
  fi
fi

platform="${SP_SERENA_PLATFORM:-}"
if [ -z "$platform" ]; then
  case "${OSTYPE:-}" in
    msys*|cygwin*|MINGW*) platform=native-windows ;;
    darwin*) platform=macos ;;
    linux*) platform=linux ;;
    *) platform=unknown ;;
  esac
fi

state=healthy
action=none
if [ "$platform" = native-windows ] || [ "$platform" = unknown ]; then
  state=unsupported-platform
  action=use-wsl
elif [ "$settings_valid" = false ] || [ "$claude_json_valid" = false ] || [ "$project_mcp_valid" = false ]; then
  state=misconfigured
  action=repair
elif [ "$registration_count" -gt 1 ] || [ "$scope_conflict" = true ]; then
  state=duplicate
  action=resolve-scope-conflict
elif [ "$plugin_enabled" = true ]; then
  state=legacy-plugin
  action=migrate
elif [ "$user_server" = false ] && [ -z "$path_serena" ]; then
  state=absent
  action=install
elif [ "$user_server" = false ] || [ "$configured_binary_ok" = false ]; then
  state=misconfigured
  action=repair
elif [ "$version_is_outdated" = true ] || [ "$runtime_pair_ok" = false ]; then
  state=outdated
  action=upgrade
elif [ "$context_ok" = false ] || [ "$project_ok" = false ]; then
  state=misconfigured
  action=repair
elif [ "$quiet_dashboard" = false ]; then
  state=noisy-dashboard
  action=repair
elif [ "$hooks_complete" = false ]; then
  state=partial-hooks
  action=repair
elif [ "$permission_safe" = false ]; then
  state=stale-permissions
  action=repair
fi

if [ -n "$FIELD" ]; then
  case "$FIELD" in
    state) printf '%s\n' "$state" ;;
    action) printf '%s\n' "$action" ;;
    version) printf '%s\n' "$serena_version" ;;
    scope_conflict) printf '%s\n' "$scope_conflict" ;;
    *) printf 'Unknown field: %s\n' "$FIELD" >&2; exit 2 ;;
  esac
  exit 0
fi

if [ "$FORMAT" = json ]; then
  uv_available=false
  command -v uv >/dev/null 2>&1 && uv_available=true
  printf '{"state":"%s","recommended_action":"%s","serena_version":"%s","supported_version":"%s","plugin_enabled":%s,"user_server":%s,"user_server_count":%s,"local_server":%s,"project_server":%s,"scope_conflict":%s,"configured_binary_ok":%s,"quiet_dashboard":%s,"hooks_complete":%s,"runtime_pair_ok":%s,"permission_safe":%s,"settings_valid":%s,"uv_available":%s,"platform":"%s"}\n' \
    "$state" "$action" "$serena_version" "$SUPPORTED_VERSION" "$plugin_enabled" "$user_server" "$user_server_count" "$local_server" "$project_server" "$scope_conflict" "$configured_binary_ok" "$quiet_dashboard" "$hooks_complete" "$runtime_pair_ok" "$permission_safe" "$settings_valid" "$uv_available" "$platform"
  exit 0
fi

case "$state" in
  healthy) printf '%s\n' "Serena is healthy. One stable server is configured with quiet startup and lifecycle hooks." ;;
  absent) printf '%s\n' "Serena is not installed. Strategic Partner still works, but project memory and code navigation are limited." ;;
  legacy-plugin) printf '%s\n' "Serena is connected through the legacy marketplace launcher. SP can migrate it to the stable supported setup." ;;
  duplicate)
    if [ "$scope_conflict" = true ]; then
      printf '%s\n' "A project or local Serena registration conflicts with SP's managed user setup. SP will not add another server until that scope is resolved."
    else
      printf '%s\n' "Two Serena registrations are configured. SP can migrate them to one managed server."
    fi
    ;;
  noisy-dashboard) printf '%s\n' "Serena is connected, but its dashboard may open during startup. SP can make startup quiet without disabling the dashboard." ;;
  unsupported-platform) printf '%s\n' "This platform is not supported for automatic Serena repair. Use WSL2 for the supported Windows path." ;;
  *) printf 'Serena needs attention (%s). SP can preview and repair the supported setup.\n' "$state" ;;
esac
