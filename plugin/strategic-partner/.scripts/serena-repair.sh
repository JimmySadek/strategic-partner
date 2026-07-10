#!/usr/bin/env bash
set -u

# Consent-gated Serena installer and repair transaction for Strategic Partner.
# macOS bash 3.2 compatible. Use --plan before --apply.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DOCTOR="$SCRIPT_DIR/serena-doctor.sh"
SUPPORTED_VERSION="${SP_SERENA_SUPPORTED_VERSION:-1.5.3}"
STATE_DIR="${SP_SERENA_STATE_DIR:-${HOME}/.config/strategic-partner/serena}"
SETTINGS_PATH="${SP_SERENA_SETTINGS_PATH:-${HOME}/.claude/settings.json}"
CLAUDE_JSON_PATH="${SP_SERENA_CLAUDE_JSON_PATH:-${HOME}/.claude.json}"

MODE="${1:---plan}"
CONFIRMED=false
for arg in "$@"; do
  [ "$arg" = --yes ] && CONFIRMED=true
done

usage() {
  cat <<'EOF'
Usage: serena-repair.sh --plan
       serena-repair.sh --install-prerequisite --yes
       serena-repair.sh --apply --yes
       serena-repair.sh --verify
       serena-repair.sh --rollback --yes
EOF
}

require_confirmation() {
  if [ "$CONFIRMED" != true ]; then
    printf '%s\n' "No changes made. Re-run with --yes only after the user approves the displayed plan." >&2
    exit 2
  fi
}

shell_quote() {
  printf "'"
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
  printf "'"
}

state=$("$DOCTOR" --field state 2>/dev/null || printf 'unknown')

show_plan() {
  printf 'Current Serena state: %s\n\n' "$state"
  if ! command -v uv >/dev/null 2>&1 && [ "$state" != healthy ]; then
    printf '%s\n\n' "The uv package manager is required before Serena can be installed. SP will preview and ask separately before installing it."
  fi
  case "$state" in
    healthy)
      printf '%s\n' "No changes are needed. Serena is already healthy."
      ;;
    unsupported-platform)
      printf '%s\n' "Automatic repair is not supported on native Windows. Use WSL2, then run this check again."
      ;;
    duplicate)
      scope_conflict=$("$DOCTOR" --field scope_conflict 2>/dev/null || printf 'true')
      if [ "$scope_conflict" = true ]; then
        printf '%s\n' "A project or local Serena registration must be reviewed and removed separately. SP will not add another server or change that project file automatically."
      else
        cat <<EOF
SP will back up Claude's configuration, disable the legacy Serena plugin, keep one stable user-level server, normalize Serena's hooks, remove broad static Serena approvals, and verify the result. Existing .serena files and memories are preserved.
EOF
      fi
      ;;
    *)
      cat <<EOF
SP will:
  1. Back up Claude settings and MCP registration.
  2. Install or repair stable Serena ${SUPPORTED_VERSION} when needed.
  3. Configure one user-level Serena server for Claude Code and the current working directory.
  4. Add Serena's activation, reminder, cleanup, and permission-aware approval hooks; remove broad static Serena approvals.
  5. Keep the dashboard available but enforce quiet dashboard startup.
  6. Disable the legacy Serena marketplace plugin when present.
  7. Verify the resulting setup and retain a rollback receipt.

No project .serena files or memories will be moved or rewritten.
EOF
      ;;
  esac
}

install_prerequisite() {
  require_confirmation
  if command -v uv >/dev/null 2>&1; then
    printf '%s\n' "uv is already installed. No changes made."
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    brew install uv
  elif command -v python3 >/dev/null 2>&1 && python3 -m pip --version >/dev/null 2>&1; then
    python3 -m pip install --user uv
  else
    printf '%s\n' "SP could not find Homebrew or Python pip. Install uv from Astral's official instructions, then run the Serena check again." >&2
    return 2
  fi

  hash -r 2>/dev/null || true
  if command -v uv >/dev/null 2>&1; then
    printf '%s\n' "uv is installed. Re-run the Serena repair preview before continuing."
    return 0
  fi
  printf '%s\n' "uv was installed but is not visible in this shell yet. Start a fresh shell, then run the Serena check again." >&2
  return 2
}

manifest_value() {
  key="$1"
  file="$2"
  sed -n "s/^${key}=//p" "$file" | head -1
}

restore_backup() {
  backup_dir="$1"
  manifest="$backup_dir/manifest"
  [ -r "$manifest" ] || { printf 'Rollback manifest is missing: %s\n' "$manifest" >&2; return 1; }

  restore_ok=true
  if [ -f "$backup_dir/settings.missing" ]; then
    rm -f "$SETTINGS_PATH" || restore_ok=false
  else
    mkdir -p "$(dirname "$SETTINGS_PATH")" || restore_ok=false
    cp "$backup_dir/settings.json" "$SETTINGS_PATH" || restore_ok=false
  fi

  if [ -f "$backup_dir/claude-json.missing" ]; then
    rm -f "$CLAUDE_JSON_PATH" || restore_ok=false
  else
    cp "$backup_dir/claude.json" "$CLAUDE_JSON_PATH" || restore_ok=false
  fi

  runtime_present=$(manifest_value runtime_present "$manifest")
  old_version=$(manifest_value runtime_version "$manifest")
  runtime_uv_managed=$(manifest_value runtime_uv_managed "$manifest")
  if [ "$runtime_present" = false ]; then
    if command -v uv >/dev/null 2>&1; then
      uv tool uninstall serena-agent >/dev/null 2>&1 || true
      remaining_serena=$(command -v serena 2>/dev/null || printf '')
      [ -z "$remaining_serena" ] || restore_ok=false
    else
      restore_ok=false
    fi
  elif [ "$runtime_uv_managed" = true ] && [ -n "$old_version" ] && [ "$old_version" != "$SUPPORTED_VERSION" ]; then
    if command -v uv >/dev/null 2>&1 \
      && uv tool install --force --python 3.11 "serena-agent==${old_version}" >/dev/null 2>&1; then
      restored_serena=$(command -v serena 2>/dev/null || printf '')
      restored_version=""
      [ -z "$restored_serena" ] || restored_version=$("$restored_serena" --version 2>/dev/null | sed -n 's/^Serena[[:space:]]*//p' | head -1)
      [ "$restored_version" = "$old_version" ] || restore_ok=false
    else
      restore_ok=false
    fi
  fi
  if [ "$restore_ok" != true ]; then
    printf '%s\n' "Rollback was incomplete. The backup is preserved at $backup_dir; inspect it before starting Claude again." >&2
    return 1
  fi
  printf '%s\n' "Serena setup restored from $backup_dir"
}

create_backup() {
  mkdir -p "$STATE_DIR/backups" || return 1
  chmod 700 "$STATE_DIR" "$STATE_DIR/backups" 2>/dev/null || true
  timestamp=$(date -u +%Y%m%dT%H%M%SZ)
  backup_dir="$STATE_DIR/backups/$timestamp-$$"
  mkdir -p "$backup_dir" || return 1
  chmod 700 "$backup_dir" 2>/dev/null || true

  if [ -f "$SETTINGS_PATH" ]; then
    cp "$SETTINGS_PATH" "$backup_dir/settings.json" || return 1
  else
    : > "$backup_dir/settings.missing" || return 1
  fi
  if [ -f "$CLAUDE_JSON_PATH" ]; then
    cp "$CLAUDE_JSON_PATH" "$backup_dir/claude.json" || return 1
  else
    : > "$backup_dir/claude-json.missing" || return 1
  fi

  old_serena=$(command -v serena 2>/dev/null || printf '')
  old_version=""
  runtime_present=false
  runtime_uv_managed=false
  if [ -n "$old_serena" ]; then
    runtime_present=true
    old_version=$("$old_serena" --version 2>/dev/null | sed -n 's/^Serena[[:space:]]*//p' | head -1)
    old_target=$(readlink "$old_serena" 2>/dev/null || printf '%s' "$old_serena")
    case "$old_target" in
      */uv/tools/serena-agent/*) runtime_uv_managed=true ;;
    esac
  fi
  {
    printf 'runtime_present=%s\n' "$runtime_present"
    printf 'runtime_version=%s\n' "$old_version"
    printf 'runtime_uv_managed=%s\n' "$runtime_uv_managed"
  } > "$backup_dir/manifest" || return 1
  [ -s "$backup_dir/manifest" ] || return 1
  printf '%s\n' "$backup_dir" > "$STATE_DIR/latest-backup" || return 1
  printf '%s\n' "$backup_dir"
}

merge_settings() {
  hooks_path="$1"
  command -v jq >/dev/null 2>&1 || {
    printf '%s\n' "jq is required for merge-safe Claude hook configuration. Install jq, then retry." >&2
    return 1
  }
  mkdir -p "$(dirname "$SETTINGS_PATH")"
  [ -f "$SETTINGS_PATH" ] || printf '%s\n' '{}' > "$SETTINGS_PATH"
  jq -e type "$SETTINGS_PATH" >/dev/null 2>&1 || {
    printf '%s\n' "Claude settings JSON is malformed. No repair was applied." >&2
    return 1
  }
  tmp=$(mktemp "${TMPDIR:-/tmp}/sp-serena-settings.XXXXXX")
  quoted_hooks=$(shell_quote "$hooks_path")
  jq --arg hooks "$quoted_hooks" '
    def add_unique($item): if index($item) then . else . + [$item] end;
    .permissions = (.permissions // {}) |
    .permissions.allow = ((.permissions.allow // [])
      | map(select(. != "mcp__serena__*" and . != "mcp__plugin_serena_serena__*"))) |
    .hooks = (.hooks // {}) |
    .hooks.PreToolUse = ((.hooks.PreToolUse // [])
      | map(.hooks = ((.hooks // []) | map(select(((.command // "") | test("serena-hooks.? (remind|auto-approve)")) | not))))
      | map(select((.hooks | length) > 0))
      | add_unique({"matcher":"","hooks":[{"type":"command","command":($hooks + " remind --client=claude-code")}]})
      | add_unique({"matcher":"mcp__serena__*","hooks":[{"type":"command","command":($hooks + " auto-approve --client=claude-code")}]})) |
    .hooks.SessionStart = ((.hooks.SessionStart // [])
      | map(.hooks = ((.hooks // []) | map(select(((.command // "") | test("serena-hooks.? activate")) | not))))
      | map(select((.hooks | length) > 0))
      | add_unique({"matcher":"","hooks":[{"type":"command","command":($hooks + " activate --client=claude-code")}]})) |
    .hooks.SessionEnd = ((.hooks.SessionEnd // [])
      | map(.hooks = ((.hooks // []) | map(select(((.command // "") | test("serena-hooks.? cleanup")) | not))))
      | map(select((.hooks | length) > 0))
      | add_unique({"matcher":"","hooks":[{"type":"command","command":($hooks + " cleanup --client=claude-code")}]}))
  ' "$SETTINGS_PATH" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$SETTINGS_PATH"
}

apply_repair() {
  require_confirmation
  if [ "$state" = healthy ]; then
    printf '%s\n' "Serena is already healthy. No changes made."
    return 0
  fi
  if [ "$state" = unsupported-platform ]; then
    printf '%s\n' "Automatic Serena repair is unsupported on this platform. Use WSL2." >&2
    return 2
  fi
  command -v claude >/dev/null 2>&1 || { printf '%s\n' "Claude Code is required for Serena registration." >&2; return 1; }
  command -v jq >/dev/null 2>&1 || { printf '%s\n' "jq is required for safe settings merge." >&2; return 1; }

  if [ -f "$SETTINGS_PATH" ] && ! jq -e type "$SETTINGS_PATH" >/dev/null 2>&1; then
    printf '%s\n' "Claude settings are malformed. SP will not mutate them; fix the JSON and rerun the preview." >&2
    return 2
  fi
  if [ -f "$CLAUDE_JSON_PATH" ] && ! jq -e type "$CLAUDE_JSON_PATH" >/dev/null 2>&1; then
    printf '%s\n' "Claude's MCP configuration is malformed. SP will not mutate it; fix the JSON and rerun the preview." >&2
    return 2
  fi
  scope_conflict=$("$DOCTOR" --field scope_conflict 2>/dev/null || printf 'true')
  if [ "$scope_conflict" = true ]; then
    printf '%s\n' "A local or project Serena server is already configured. SP will not add a user server until that scope is removed through a separately approved cleanup." >&2
    return 2
  fi

  existing_serena=$(command -v serena 2>/dev/null || printf '')
  current_version=""
  [ -z "$existing_serena" ] || current_version=$("$existing_serena" --version 2>/dev/null | sed -n 's/^Serena[[:space:]]*//p' | head -1)
  hooks_path=$(command -v serena-hooks 2>/dev/null || printf '')
  runtime_change_needed=false
  if [ "$current_version" != "$SUPPORTED_VERSION" ] || [ -z "$hooks_path" ]; then
    runtime_change_needed=true
  fi
  if [ "$runtime_change_needed" = true ] && [ -n "$existing_serena" ]; then
    existing_target=$(readlink "$existing_serena" 2>/dev/null || printf '%s' "$existing_serena")
    stable_version=false
    printf '%s' "$current_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' && stable_version=true
    case "$existing_target" in
      */uv/tools/serena-agent/*) : ;;
      *) stable_version=false ;;
    esac
    if [ "$stable_version" != true ]; then
      printf '%s\n' "The existing Serena runtime was not installed as a stable uv tool. SP will not replace an unknown or development installation automatically." >&2
      return 2
    fi
  fi
  if [ "$runtime_change_needed" = true ] && ! command -v uv >/dev/null 2>&1; then
    printf '%s\n' "uv is required to install the supported Serena runtime. Approve the separate prerequisite step, then rerun this repair." >&2
    return 2
  fi

  backup_dir=$(create_backup) || {
    printf '%s\n' "SP could not create and verify the Serena rollback backup. No changes were made." >&2
    return 1
  }
  failed=false

  if [ "$runtime_change_needed" = true ]; then
    if ! command -v uv >/dev/null 2>&1; then
      printf '%s\n' "uv is required to install the supported Serena runtime. Install uv after reviewing its official installer, then retry." >&2
      failed=true
    elif ! uv tool install --force --python 3.11 "serena-agent==${SUPPORTED_VERSION}"; then
      failed=true
    fi
  fi

  serena_path=$(command -v serena 2>/dev/null || printf '')
  hooks_path=$(command -v serena-hooks 2>/dev/null || printf '')
  [ -n "$serena_path" ] && [ -n "$hooks_path" ] || failed=true

  if [ "$failed" = false ]; then
    claude mcp remove --scope user serena >/dev/null 2>&1 || true
    claude mcp add --scope user serena -- "$serena_path" start-mcp-server --context=claude-code --project-from-cwd --open-web-dashboard False || failed=true
  fi
  if [ "$failed" = false ]; then
    claude plugin disable serena@claude-plugins-official >/dev/null 2>&1 || true
    merge_settings "$hooks_path" || failed=true
  fi

  if [ "$failed" = true ]; then
    printf '%s\n' "Serena repair failed. Restoring the previous configuration." >&2
    restore_backup "$backup_dir" || return 1
    return 1
  fi

  new_state=$("$DOCTOR" --field state 2>/dev/null || printf 'unknown')
  if [ "$new_state" != healthy ]; then
    printf 'Serena verification returned %s. Restoring the previous configuration.\n' "$new_state" >&2
    "$DOCTOR" --format=json >&2 || true
    restore_backup "$backup_dir" || return 1
    return 1
  fi

  if ! {
    printf 'expected_state=healthy\n'
    printf 'backup=%s\n' "$backup_dir"
    printf 'created=%s\n' "$(date -u +%FT%TZ)"
  } > "$STATE_DIR/restart-verification"; then
    printf '%s\n' "Serena was configured but SP could not write its verification receipt. Restoring the previous setup." >&2
    restore_backup "$backup_dir" || return 1
    return 1
  fi
  printf '%s\n' "Serena is configured and locally verified. Start a fresh Claude session to confirm exact-project activation."
}

case "$MODE" in
  --plan) show_plan ;;
  --install-prerequisite) install_prerequisite ;;
  --apply) apply_repair ;;
  --verify)
    "$DOCTOR"
    [ "$state" = healthy ]
    ;;
  --rollback)
    require_confirmation
    pointer="$STATE_DIR/latest-backup"
    [ -r "$pointer" ] || { printf '%s\n' "No Serena repair backup is available." >&2; exit 1; }
    backup_dir=$(sed -n '1p' "$pointer")
    restore_backup "$backup_dir" || exit 1
    rm -f "$STATE_DIR/restart-verification" || exit 1
    ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
