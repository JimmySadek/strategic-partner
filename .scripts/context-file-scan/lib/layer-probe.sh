#!/usr/bin/env bash
# .scripts/context-file-scan/lib/layer-probe.sh
# Adjacent-layer detection for context-file stewardship scans. Sourceable.
#
# Detects which storage layers (Serena memory, .claude/rules/, claudedocs/,
# hooks, etc.) are available in the project, returning a JSON object that
# downstream rules consult for routing per the C5 fallback matrix.
#
# MCP tool availability (Serena, Context7) is NOT shell-probable — those
# tools live in the agent's runtime, not in $PATH. The agent passes their
# state via --serena-available true|false and --context7-available
# true|false. Filesystem fallback heuristics handle absence of the flag
# where one is defined.
#
# Requires: jq, plus lib/utils.sh + lib/root.sh sourced.

# scanner_probe_layers PROJECT_ROOT [SERENA_FLAG] [CONTEXT7_FLAG]
#   SERENA_FLAG and CONTEXT7_FLAG are "true" / "false" / "" (empty when
#   the agent didn't pass a flag — filesystem fallback used). Echoes a
#   single-line JSON object on stdout, conformant to spec § 5.1.
scanner_probe_layers() {
  local root="$1"
  local serena_flag="${2:-}"
  local context7_flag="${3:-}"

  # ── Serena ─────────────────────────────────────────────────────────
  local serena
  case "$serena_flag" in
    true|false) serena="$serena_flag" ;;
    *)
      # Fallback heuristic: per-project Serena memory dir.
      if [ -d "$root/.serena/memories" ]; then
        serena=true
      else
        serena=false
      fi
      ;;
  esac

  # ── Context7 ───────────────────────────────────────────────────────
  local context7
  case "$context7_flag" in
    true|false) context7="$context7_flag" ;;
    *) context7=false ;;  # No filesystem fallback per spec § 5.1
  esac

  # ── Filesystem layers ──────────────────────────────────────────────
  local claude_rules=false
  [ -d "$root/.claude/rules" ] && claude_rules=true

  local claude_hooks=false
  if grep -q '^hooks:' "$root/SKILL.md" 2>/dev/null; then
    claude_hooks=true
  elif [ -f "$root/.claude/settings.json" ] \
       && jq -e '.hooks' "$root/.claude/settings.json" >/dev/null 2>&1; then
    claude_hooks=true
  fi

  local claudedocs=false
  [ -d "$root/claudedocs" ] && claudedocs=true

  local progress=false
  if [ -d "$root/progress" ] || [ -d "$root/workspace" ]; then
    progress=true
  fi

  local conventional_state=false
  if [ -d "$root/decisions" ] || [ -d "$root/docs" ]; then
    conventional_state=true
  fi

  local git_repo
  git_repo=$(scanner_is_git_repo "$root")

  # ── Build the JSON ─────────────────────────────────────────────────
  # primary_destinations_available follows the C5 fallback matrix.
  # Each content type → the highest-tier available layer name, or null.

  local pd_decision_log="null"
  local pd_architecture_facts="null"
  local pd_code_conventions="null"
  local pd_known_gotchas="null"
  local pd_path_scoped_rules="null"
  local pd_reference_material="null"
  local pd_operational_state="null"
  local pd_enforceable_rules="null"

  if [ "$serena" = "true" ]; then
    pd_decision_log='"serena"'
    pd_architecture_facts='"serena"'
    pd_code_conventions='"serena"'
    pd_known_gotchas='"serena"'
  elif [ "$claudedocs" = "true" ]; then
    pd_decision_log='"claudedocs"'
    pd_architecture_facts='"claudedocs"'
    pd_code_conventions='"claudedocs"'
    pd_known_gotchas='"claudedocs"'
  elif [ "$conventional_state" = "true" ]; then
    pd_decision_log='"conventional-state"'
  fi

  if [ "$claude_rules" = "true" ]; then
    pd_path_scoped_rules='"claude-rules"'
  fi

  if [ "$claudedocs" = "true" ]; then
    pd_reference_material='"claudedocs"'
  elif [ "$conventional_state" = "true" ]; then
    pd_reference_material='"conventional-state"'
  fi

  if [ "$progress" = "true" ]; then
    pd_operational_state='"progress"'
  elif [ "$claudedocs" = "true" ]; then
    pd_operational_state='"claudedocs"'
  fi

  if [ "$claude_hooks" = "true" ]; then
    pd_enforceable_rules='"claude-hooks"'
  elif [ "$claude_rules" = "true" ]; then
    pd_enforceable_rules='"claude-rules"'
  fi

  # Layers present / absent — for situational awareness and tool-suggest.
  local present_arr="[]"
  local absent_arr="[]"
  local layer
  for layer in "serena:$serena" "context7:$context7" "claude-rules:$claude_rules" \
               "claude-hooks:$claude_hooks" "claudedocs:$claudedocs" \
               "progress:$progress" "conventional-state:$conventional_state"; do
    local name="${layer%%:*}"
    local val="${layer#*:}"
    if [ "$val" = "true" ]; then
      present_arr=$(echo "$present_arr" | jq --arg n "$name" '. + [$n]')
    else
      absent_arr=$(echo "$absent_arr" | jq --arg n "$name" '. + [$n]')
    fi
  done

  jq -n \
    --argjson layers_present "$present_arr" \
    --argjson layers_absent "$absent_arr" \
    --argjson git_repo "$git_repo" \
    --argjson pd_decision_log "$pd_decision_log" \
    --argjson pd_architecture_facts "$pd_architecture_facts" \
    --argjson pd_code_conventions "$pd_code_conventions" \
    --argjson pd_known_gotchas "$pd_known_gotchas" \
    --argjson pd_path_scoped_rules "$pd_path_scoped_rules" \
    --argjson pd_reference_material "$pd_reference_material" \
    --argjson pd_operational_state "$pd_operational_state" \
    --argjson pd_enforceable_rules "$pd_enforceable_rules" \
    '{
      layers_present: $layers_present,
      layers_absent: $layers_absent,
      git_repo: $git_repo,
      primary_destinations_available: {
        decision_log: $pd_decision_log,
        architecture_facts: $pd_architecture_facts,
        code_conventions: $pd_code_conventions,
        known_gotchas: $pd_known_gotchas,
        path_scoped_rules: $pd_path_scoped_rules,
        reference_material: $pd_reference_material,
        operational_state: $pd_operational_state,
        enforceable_rules: $pd_enforceable_rules
      }
    }'
}

# scanner_layer_present LAYER_PROBE_JSON LAYER_NAME
#   Echoes "true" / "false" given the JSON output from scanner_probe_layers
#   and a layer name (e.g., "serena", "claudedocs").
scanner_layer_present() {
  local probe_json="$1"
  local layer="$2"
  echo "$probe_json" | jq -r --arg l "$layer" '
    if (.layers_present | index($l)) != null then "true" else "false" end
  '
}

# scanner_destination_for LAYER_PROBE_JSON CONTENT_TYPE
#   Echoes the layer name for a content type (e.g., "decision_log",
#   "path_scoped_rules") or empty string if no destination available.
scanner_destination_for() {
  local probe_json="$1"
  local content_type="$2"
  echo "$probe_json" | jq -r --arg t "$content_type" '
    .primary_destinations_available[$t] // ""
  '
}
