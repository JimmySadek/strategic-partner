#!/bin/bash
payload=$(cat 2>/dev/null || printf '%s' '{}')

session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || printf '')
transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null || printf '')
prompt=$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || printf '')
safe_session_id=$(printf '%s' "${session_id:-unknown}" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
FLOOR_READY="/tmp/sp-plugin-floor-ready-${safe_session_id}"

if printf '%s' "$prompt" | perl -e 'undef $/; $_=<STDIN>; exit($_ =~ /\A\s*\/(strategic-partner|advisor|sp):(help|copy-prompt|update|serena)\s*\z/ ? 0 : 1)' 2>/dev/null; then
  exit 0
fi

# Resolve SP install dir from this script's own path (self-locating).
# Plugin layout: this script lives at <plugin-root>/hooks/, the skill at
# <plugin-root>/skills/strategic-partner/SKILL.md. No symlink fallback —
# the plugin loader guarantees the layout.
THIS_SCRIPT=$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$0" 2>/dev/null)
if [ -n "$THIS_SCRIPT" ] && [ -f "$THIS_SCRIPT" ]; then
  SP_INSTALL_DIR=$(dirname "$(dirname "$THIS_SCRIPT")")
  SP_SKILL_PATH="$SP_INSTALL_DIR/skills/strategic-partner/SKILL.md"
  skill_version=$(grep '^version:' "$SP_SKILL_PATH" 2>/dev/null | head -1 | awk '{print $2}')
else
  SP_SKILL_PATH=""
  skill_version=""
fi
[ -z "$skill_version" ] && skill_version="unknown"
floor_schema_version="v6"
rule_schema_version="v1"

# Portable timeout (gtimeout on macOS coreutils, timeout on Linux; empty if neither)
TIMEOUT=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)

prompt_class=$(printf '%s' "$prompt" | perl -ne 'BEGIN{undef $/} m{\A\s*(/(strategic-partner|advisor|sp)(:[a-z-]+)?)} && do { print $1; last }' 2>/dev/null)
[ -z "$prompt_class" ] && prompt_class="chat"

cwd_hash=$(printf '%s' "$cwd" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
tp_hash=$(printf '%s' "$transcript_path" | shasum -a 256 2>/dev/null | cut -d' ' -f1)

KEY=$(printf '%s|%s|%s|%s|%s|%s' \
      "$session_id" "$cwd_hash" "$tp_hash" \
      "$skill_version" "$floor_schema_version" "$prompt_class" \
    | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c 16)
RELAY_KEY=$(printf '%s|%s|%s|%s|%s' \
      "$session_id" "$cwd_hash" "$tp_hash" \
      "$skill_version" "$rule_schema_version" \
    | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c 16)

MARKER="/tmp/sp-floor-${KEY}.flag"
RESULTS="/tmp/sp-floor-${KEY}.txt"
LOCK="/tmp/sp-floor-${KEY}.lock"
VIOLATIONS_LOG="/tmp/sp-rule-violations-${RELAY_KEY}.log"

expose_floor_ready() {
  [ -s "$RESULTS" ] || return 1
  printf '%s\n' "$RESULTS" > "$FLOOR_READY"
}

if [ -f "$VIOLATIONS_LOG" ]; then
  VIOL_COUNT=$(grep -c '^- ' "$VIOLATIONS_LOG" 2>/dev/null | tr -d ' \n')
  [ -z "$VIOL_COUNT" ] && VIOL_COUNT=0
  if [ "$VIOL_COUNT" -gt 0 ] 2>/dev/null; then
    VIOL_RULES=$(grep '^- ' "$VIOLATIONS_LOG" 2>/dev/null | head -3 | awk -F': ' '{print $1}' | sed 's/^- //' | paste -sd, -)
    printf 'SP-RULE-CHECK: %s violation(s) from previous turn: %s. Details: %s\n' \
      "$VIOL_COUNT" "$VIOL_RULES" "$VIOLATIONS_LOG"
    mv "$VIOLATIONS_LOG" "${VIOLATIONS_LOG}.consumed-$(date +%s)" 2>/dev/null
  fi
fi

if [ -f "$MARKER" ] && expose_floor_ready; then
  exit 0
elif [ -f "$MARKER" ]; then
  rm -f "$MARKER"
fi

if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap "rmdir '$LOCK' 2>/dev/null" EXIT

: > "${RESULTS}.tmp"

# Group 1 — Environment
{
  # Model detection fallback chain (read-only): payload .model when real,
  # else the most recent assistant event's model from the transcript (the
  # payload .model arrives empty in practice — live sessions reported
  # model=unknown while running Fable 5), else "unknown". Same bounded-tail
  # pattern the Stop block uses for last_turn.
  model=$(printf '%s' "$payload" | jq -r '.model // ""' 2>/dev/null || printf '')
  if [ -z "$model" ] || [ "$model" = "unknown" ] || [ "$model" = "null" ]; then
    if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
      model=$(${TIMEOUT:+$TIMEOUT 1} tail -200 "$transcript_path" 2>/dev/null \
        | jq -rs 'map(select((.message.role // .role) == "assistant")) | last | (.message.model // .model // "")' 2>/dev/null)
    fi
  fi
  if [ -z "$model" ] || [ "$model" = "null" ]; then
    model=unknown
  fi
  printf 'g1.model=%s\n' "$model"

  # Plugin packaging: commands load natively from the plugin's commands/
  # directory — there are no ~/.claude/commands symlinks to repair.
  printf 'g1.self_repair=plugin-native\n'

  if command -v codex >/dev/null 2>&1; then
    printf 'g1.codex=available\n'
  else
    printf 'g1.codex=missing\n'
  fi

  if printf '%s' "$model" | grep -qi '1m' || [ "${SP_CONTEXT_WINDOW:-}" = "1M" ]; then
    printf 'g1.context_window=1m\n'
  else
    printf 'g1.context_window=default\n'
  fi

  if [ -d "${HOME}/.claude/projects" ]; then
    printf 'g1.auto_memory=available\n'
  else
    printf 'g1.auto_memory=unknown\n'
  fi

  # Plugin packaging: command registration is the plugin loader's job, not
  # a setup script's. Report plugin-native so orientation never nags about
  # symlink setup that no longer exists.
  printf 'g1.commands_registered=plugin-native\n'
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 2 — Project conventions
{
  if [ -n "$cwd" ] && [ -f "$cwd/CLAUDE.md" ]; then
    line_count=$(wc -l < "$cwd/CLAUDE.md" 2>/dev/null | tr -d ' ')
    char_count=$(wc -c < "$cwd/CLAUDE.md" 2>/dev/null | tr -d ' ')
    char_count=${char_count:-0}
    line_count=${line_count:-0}
    # Mirror .scripts/context-file-scan/lib/output.sh scanner_file_size_band:
    # Claude Code recommends targeting under 200 lines; the older char
    # thresholds still apply for dense files.
    if [ "$char_count" -ge 36864 ] || [ "$line_count" -gt 350 ]; then
      band=surface-loudly
    elif [ "$char_count" -ge 24576 ] || [ "$line_count" -gt 200 ]; then
      band=warn
    elif [ "$char_count" -ge 16384 ] || [ "$line_count" -ge 150 ]; then
      band=soft-warn
    else
      band=under-soft
    fi
    printf 'g2.claude_md=present lines=%s chars=%s band=%s\n' "$line_count" "${char_count}" "${band}"
  else
    printf 'g2.claude_md=missing\n'
  fi
  if [ -n "$cwd" ] && [ -d "$cwd/.claude/rules" ]; then
    rule_count=$(find "$cwd/.claude/rules" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    printf 'g2.rules_dir=present count=%s\n' "${rule_count:-0}"
  else
    printf 'g2.rules_dir=missing\n'
  fi
  review_policy=unset
  for policy_file in "$cwd/CLAUDE.md" "$cwd/AGENTS.md" "$cwd/GEMINI.md"; do
    [ -f "$policy_file" ] || continue
    if grep -qE '^review-policy:[[:space:]]*cross-model-go-no-go[[:space:]]*$' "$policy_file" 2>/dev/null; then
      review_policy=cross-model-go-no-go
      break
    fi
  done
  printf 'g2.review_policy=%s\n' "$review_policy"
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 3 — Persistent memory (read files; hooks can't call Serena MCP)
{
  if [ -n "$cwd" ] && [ -d "$cwd/.serena/memories" ]; then
    mem_count=$(ls "$cwd/.serena/memories/"*.md 2>/dev/null | wc -l | tr -d ' ')
    printf 'g3.serena_memories=present count=%s\n' "${mem_count:-0}"
  else
    printf 'g3.serena_memories=missing\n'
  fi
  if [ -n "$cwd" ] && [ -f "$cwd/.serena/memories/project_overview.md" ]; then
    printf 'g3.project_overview=present\n'
  else
    printf 'g3.project_overview=missing\n'
  fi
  if [ -n "$cwd" ] && [ -f "$cwd/.serena/memories/decision_log.md" ]; then
    dl_lines=$(wc -l < "$cwd/.serena/memories/decision_log.md" 2>/dev/null | tr -d ' ')
    printf 'g3.decision_log=present lines=%s\n' "${dl_lines:-0}"
  else
    printf 'g3.decision_log=missing\n'
  fi
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 4 — Working memory (.handoffs/findings, .backlog/ frontmatter)
{
  if [ -n "$cwd" ] && [ -d "$cwd/.handoffs" ]; then
    findings_count=$(ls "$cwd/.handoffs/findings-"*.md 2>/dev/null | wc -l | tr -d ' ')
  else
    findings_count=0
  fi
  printf 'g4.findings=%s\n' "${findings_count:-0}"

  if [ -n "$cwd" ] && [ -d "$cwd/.backlog" ]; then
    backlog_count=$(ls "$cwd/.backlog/"*.md 2>/dev/null | wc -l | tr -d ' ')
    printf 'g4.backlog_count=%s\n' "${backlog_count:-0}"
    oldschema_count=0
    for f in "$cwd/.backlog/"*.md; do
      [ -f "$f" ] || continue
      bn=$(basename "$f" .md)
      title=$(awk '/^-{3}$/{c++; next} c==1 && /^title:/{sub(/^title:[[:space:]]*/,""); print; exit}' "$f" 2>/dev/null | head -c 80)
      status_field=$(awk '/^-{3}$/{c++; next} c==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}' "$f" 2>/dev/null | head -c 30)
      trigger=$(awk '/^-{3}$/{c++; next} c==1 && /^trigger:/{sub(/^trigger:[[:space:]]*/,""); print; exit}' "$f" 2>/dev/null | head -c 100)
      printf 'g4.backlog_item name=%s status=%s title=%s\n' "$bn" "${status_field:-unknown}" "${title:-unknown}"
      # Old-schema detection: same field set and logic as
      # .scripts/migrate-backlog.sh. The frontmatter delimiter is
      # matched as /^-{3}$/ (brace-count form). It MUST NOT be
      # written as a literal triple-dash token: a literal
      # triple-dash anywhere in this inline hook (even inside a
      # comment) is read as a YAML document separator and
      # truncates the hook, blocking every new session (incident
      # c53d530, fix fd6dff7). Do not "restore byte-identical".
      if awk 'BEGIN{infm=0} /^-{3}$/{infm=!infm; next} infm && /^(status|trigger|type|priority|severity|added): /{print "MATCH"; exit}' "$f" 2>/dev/null | grep -q MATCH; then
        # Exclude old-schema closed-state markers — migrate-backlog.sh
        # treats status: completed|stale|superseded as closed and
        # refuses to migrate them, so they must not be nagged.
        if ! awk 'BEGIN{infm=0} /^-{3}$/{infm=!infm; next} infm && /^status:[[:space:]]+(completed|stale|superseded)[[:space:]]*$/{print "C"; exit}' "$f" 2>/dev/null | grep -q C; then
          oldschema_count=$((oldschema_count + 1))
        fi
      fi
    done
    printf 'g4.oldschema=%s\n' "${oldschema_count:-0}"
  else
    printf 'g4.backlog_count=0\n'
    printf 'g4.oldschema=0\n'
  fi
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 5 — Git state (timeout-bounded git ops)
{
  if [ -n "$cwd" ] && [ -d "$cwd/.git" ]; then
    branch=$(cd "$cwd" 2>/dev/null && ${TIMEOUT:+$TIMEOUT 1} git branch --show-current 2>/dev/null)
    printf 'g5.branch=%s\n' "${branch:-unknown}"
    porcelain_count=$(cd "$cwd" 2>/dev/null && ${TIMEOUT:+$TIMEOUT 1} git status --porcelain 2>/dev/null | head -10 | wc -l | tr -d ' ')
    if [ "${porcelain_count:-0}" = "0" ]; then
      printf 'g5.status=clean\n'
    else
      printf 'g5.status=dirty changed=%s\n' "$porcelain_count"
    fi
    last_commit=$(cd "$cwd" 2>/dev/null && ${TIMEOUT:+$TIMEOUT 1} git log --oneline -1 2>/dev/null | head -c 80)
    printf 'g5.last_commit=%s\n' "${last_commit:-none}"
  else
    printf 'g5.git=missing\n'
  fi
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 6 — Version (local SKILL.md grep + remote GitHub release lookup, bounded curl)
{
  if [ -n "$SP_SKILL_PATH" ] && [ -f "$SP_SKILL_PATH" ]; then
    local_version=$(grep '^version:' "$SP_SKILL_PATH" 2>/dev/null | head -1 | awk '{print $2}')
    printf 'g6.local=%s\n' "${local_version:-unknown}"
    remote_version=$(curl --max-time 8 -sf "https://api.github.com/repos/JimmySadek/strategic-partner/releases/latest" 2>/dev/null | grep -oE '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
    if [ -z "$remote_version" ]; then
      printf 'g6.remote=unreachable\n'
      printf 'g6.diff=unreachable\n'
    elif [ "$remote_version" = "$local_version" ]; then
      printf 'g6.remote=%s\n' "$remote_version"
      printf 'g6.diff=current\n'
    else
      printf 'g6.remote=%s\n' "$remote_version"
      printf 'g6.diff=behind\n'
    fi
  else
    printf 'g6.local=unknown\n'
    printf 'g6.remote=unreachable\n'
    printf 'g6.diff=unknown\n'
  fi

  # Plugin packaging: a plugin install already IS the plugin — no discovery needed to detect whether a plugin exists.
  printf 'g6.plugin=plugin-native\n'
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 7 — Routing matrix freshness (agent-inventory hash)
{
  ROUTING_FILE_SERENA="$cwd/.serena/memories/skill_routing_matrix.md"
  ROUTING_FILE_FALLBACK="$cwd/.claude/skill-routing-matrix.md"
  if [ -n "$cwd" ] && [ -f "$ROUTING_FILE_SERENA" ]; then
    ROUTING_FILE="$ROUTING_FILE_SERENA"
  elif [ -n "$cwd" ] && [ -f "$ROUTING_FILE_FALLBACK" ]; then
    ROUTING_FILE="$ROUTING_FILE_FALLBACK"
  else
    ROUTING_FILE=""
  fi
  if [ -z "$ROUTING_FILE" ]; then
    printf 'g7.routing=missing\n'
  else
    if command -v sha256sum >/dev/null 2>&1; then
      SHA_CMD="sha256sum"
    elif command -v shasum >/dev/null 2>&1; then
      SHA_CMD="shasum -a 256"
    else
      SHA_CMD=""
    fi
    if [ -z "$SHA_CMD" ]; then
      printf 'g7.routing=stale hash_compute_failed\n'
    else
      # Inventory source: agent filenames in ~/.claude/agents/ only.
      # This is the one inventory both the floor and Agent D can read
      # from the same filesystem location → identical hash inputs →
      # identical hashes when nothing changed. Skills and MCP servers
      # are NOT in the hash because the UserPromptSubmit payload does
      # not reliably expose them at hook time, and skill/MCP install
      # paths vary across harnesses. Trade-off: pure skill or MCP
      # installs without an accompanying agent change are not
      # auto-detected by the floor; explicit refresh
      # (/strategic-partner:update or any future explicit-refresh
      # path) handles those cases.
      AGENT_DIR="${HOME}/.claude/agents"
      if [ -d "$AGENT_DIR" ]; then
        agents_list=$(ls "$AGENT_DIR"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sort)
        agent_count=$(printf '%s' "$agents_list" | grep -c . 2>/dev/null | tr -d ' \n')
      else
        agents_list=""
        agent_count=0
      fi
      [ -z "$agent_count" ] && agent_count=0
      if [ -z "$agents_list" ] || [ "$agent_count" = "0" ]; then
        printf 'g7.routing=stale hash_compute_failed inventory_unavailable\n'
      else
        current_hash=$(printf 'agents:\n%s\ncount:%s\n' \
                       "$agents_list" "$agent_count" \
                       | $SHA_CMD 2>/dev/null | awk '{print $1}' | cut -c1-16)
        if [ -z "$current_hash" ] || [ ${#current_hash} -ne 16 ]; then
          printf 'g7.routing=stale hash_compute_failed\n'
        else
          stored_hash=$(grep '^inventory_hash:' "$ROUTING_FILE" 2>/dev/null | head -1 | awk -F'"' '{print $2}' | sed 's/^sha256://')
          if [ -n "$stored_hash" ] && [ "$current_hash" = "$stored_hash" ]; then
            printf 'g7.routing=fresh hash=%s\n' "$current_hash"
          elif [ -n "$stored_hash" ]; then
            printf 'g7.routing=stale hash_diff=%s:%s\n' "$current_hash" "$stored_hash"
          else
            printf 'g7.routing=stale hash_diff=%s:none\n' "$current_hash"
          fi
        fi
      fi
    fi
  fi
} >> "${RESULTS}.tmp" 2>/dev/null

# Group 8 — Output Style (settings-file resolved; runtime header
# disagreement detection lives on the model side, since the hook
# cannot read the system prompt's `# Output Style:` header).
{
  os_value=""
  # Precedence: project-local override → project → user.
  for os_file in \
    "${cwd:+$cwd/.claude/settings.local.json}" \
    "${cwd:+$cwd/.claude/settings.json}" \
    "${HOME}/.claude/settings.json"
  do
    [ -z "$os_file" ] && continue
    [ -f "$os_file" ] || continue
    if command -v jq >/dev/null 2>&1; then
      v=$(jq -r '.outputStyle // empty' "$os_file" 2>/dev/null)
    else
      # grep/sed fallback: extract first "outputStyle":"..." value.
      v=$(grep -oE '"outputStyle"[[:space:]]*:[[:space:]]*"[^"]*"' "$os_file" 2>/dev/null \
          | head -1 | sed -E 's/.*"outputStyle"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
    fi
    if [ -n "$v" ]; then
      os_value="$v"
      break
    fi
  done
  [ -z "$os_value" ] && os_value="none"
  printf 'g8.output_style=%s\n' "$os_value"

  # Plugin packaging: the voice style ships as a native plugin component and
  # loads directly from the plugin directory — there is no copied
  # ~/.claude/output-styles file to go stale. Report the shipped stamp for
  # observability and plugin-native for the state.
  os_src=""
  if [ -n "$SP_INSTALL_DIR" ] && [ -f "$SP_INSTALL_DIR/output-styles/strategic-partner-voice.md" ]; then
    os_src=$(grep '^style-version:' "$SP_INSTALL_DIR/output-styles/strategic-partner-voice.md" 2>/dev/null | head -1 | awk '{print $2}')
  fi
  [ -z "$os_src" ] && os_src="none"

  printf 'g8.output_style_src=%s\n' "$os_src"
  printf 'g8.output_style_installed=plugin-native\n'
  printf 'g8.output_style_state=plugin-native\n'
} >> "${RESULTS}.tmp" 2>/dev/null

# Atomic finalize + summary stdout (Claude sees stdout in context)
mv "${RESULTS}.tmp" "$RESULTS" 2>/dev/null

conventions=$(grep -q '^g2.claude_md=present' "$RESULTS" 2>/dev/null && printf 'present' || printf 'missing')
memory=$(grep -q '^g3.serena_memories=present' "$RESULTS" 2>/dev/null && printf 'ok' || printf 'missing')
findings=$(grep '^g4.findings=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$findings" ] && findings=0
backlog=$(grep '^g4.backlog_count=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$backlog" ] && backlog=0
oldschema=$(grep '^g4.oldschema=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$oldschema" ] && oldschema=0
git_summary=$(grep '^g5.status=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}' | awk '{print $1}')
[ -z "$git_summary" ] && git_summary=missing
version_summary=$(grep '^g6.diff=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$version_summary" ] && version_summary=unknown
routing=$(grep '^g7.routing=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}' | awk '{print $1}')
[ -z "$routing" ] && routing=missing
claudemd_band=$(grep '^g2.claude_md=present' "$RESULTS" 2>/dev/null | head -1 | grep -oE 'band=[^ ]*' | cut -d= -f2)
[ -z "$claudemd_band" ] && claudemd_band=none
model_id=$(grep '^g1.model=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$model_id" ] && model_id=unknown
output_style=$(grep '^g8.output_style=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$output_style" ] && output_style=unknown
output_style_state=$(grep '^g8.output_style_state=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$output_style_state" ] && output_style_state=unknown
commands_registered=$(grep '^g1.commands_registered=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$commands_registered" ] && commands_registered=unknown
review_policy=$(grep '^g2.review_policy=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')
[ -z "$review_policy" ] && review_policy=unset
plugin=$(grep '^g6.plugin=' "$RESULTS" 2>/dev/null | head -1 | awk -F= '{print $2}')

touch "$MARKER"
expose_floor_ready

printf 'SP-FLOOR-COMPLETE key=%s session=%s model=%s conventions=%s memory=%s findings=%s backlog=%s oldschema=%s git=%s version=%s claudemd_band=%s routing=%s output_style=%s output_style_state=%s commands_registered=%s review_policy=%s plugin=%s. Full results: %s\n' \
  "$KEY" "$session_id" "$model_id" "$conventions" "$memory" "$findings" "$backlog" "$oldschema" "$git_summary" "$version_summary" "$claudemd_band" "$routing" "$output_style" "$output_style_state" "$commands_registered" "$review_policy" "$plugin" "$RESULTS"

exit 0
