#!/bin/bash
payload=$(cat 2>/dev/null || printf '%s' '{}')

session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || printf '')
transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null || printf '')
prompt=$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || printf '')

if printf '%s' "$prompt" | perl -e 'undef $/; $_=<STDIN>; exit($_ =~ /\A\s*\/(strategic-partner|advisor|sp):(help|copy-prompt|update|serena)\s*\z/ ? 0 : 1)' 2>/dev/null; then
  exit 0
fi

# Resolve SP install dir from this script's own path (self-locating).
# Falls back to the legacy command-symlink walk only when the self-locating
# resolution returns nothing — guarantees the floor still fires on fresh
# installs (no registered command symlinks yet).
THIS_SCRIPT=$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$0" 2>/dev/null)
if [ -n "$THIS_SCRIPT" ] && [ -f "$THIS_SCRIPT" ]; then
  SP_INSTALL_DIR=$(dirname "$(dirname "$THIS_SCRIPT")")
  SP_SKILL_PATH="$SP_INSTALL_DIR/SKILL.md"
  skill_version=$(grep '^version:' "$SP_SKILL_PATH" 2>/dev/null | head -1 | awk '{print $2}')
else
  SP_SKILL_PATH=""
  skill_version=""
fi
if [ -z "$skill_version" ]; then
  SP_ANY_CMD=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | head -1)
  if [ -n "$SP_ANY_CMD" ]; then
    SP_SKILL_PATH=$(dirname "$(dirname "$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$SP_ANY_CMD" 2>/dev/null)")")/SKILL.md
    skill_version=$(grep '^version:' "$SP_SKILL_PATH" 2>/dev/null | head -1 | awk '{print $2}')
  fi
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
SP_VIOL_DIR="${HOME}/.claude/.sp-rule-violations"
if mkdir -p "$SP_VIOL_DIR" 2>/dev/null; then
  VIOLATIONS_LOG="${SP_VIOL_DIR}/${RELAY_KEY}.log"
else
  SP_VIOL_DIR=/tmp
  VIOLATIONS_LOG="/tmp/sp-rule-violations-${RELAY_KEY}.log"
fi

if [ -f "$VIOLATIONS_LOG" ]; then
  VIOL_COUNT=$(grep -c '^- ' "$VIOLATIONS_LOG" 2>/dev/null | tr -d ' \n')
  [ -z "$VIOL_COUNT" ] && VIOL_COUNT=0
  if [ "$VIOL_COUNT" -gt 0 ] 2>/dev/null; then
    VIOL_RULES=$(grep '^- ' "$VIOLATIONS_LOG" 2>/dev/null | head -3 | awk -F': ' '{print $1}' | sed 's/^- //' | paste -sd, -)
    CONSUMED="${VIOLATIONS_LOG}.consumed-$(date +%s)"
    if mv "$VIOLATIONS_LOG" "$CONSUMED" 2>/dev/null; then
      CITED="$CONSUMED"
    else
      CITED="$VIOLATIONS_LOG"
    fi
    printf 'SP-RULE-CHECK: %s violation(s) from previous turn: %s. Details: %s\n' \
      "$VIOL_COUNT" "$VIOL_RULES" "$CITED"
  fi
fi

[ "$SP_VIOL_DIR" != /tmp ] && find "$SP_VIOL_DIR" -maxdepth 1 -name '*.consumed-*' -mtime +30 -delete 2>/dev/null

[ -f "$MARKER" ] && exit 0

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

  if [ -n "$SP_SKILL_PATH" ] && [ -f "$SP_SKILL_PATH" ]; then
    SP_INSTALL_DIR=$(dirname "$SP_SKILL_PATH")
    if [ -d "$SP_INSTALL_DIR/commands" ]; then
      cmd_count=$(ls "$SP_INSTALL_DIR/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
      link_count=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | wc -l | tr -d ' ')
      if [ "$cmd_count" = "$link_count" ] && [ "${cmd_count:-0}" -gt 0 ] 2>/dev/null; then
        printf 'g1.self_repair=ok cmds=%s links=%s\n' "$cmd_count" "$link_count"
      else
        printf 'g1.self_repair=mismatch cmds=%s links=%s\n' "$cmd_count" "$link_count"
      fi
    else
      printf 'g1.self_repair=missing\n'
    fi
  else
    printf 'g1.self_repair=unknown\n'
  fi

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

  # commands_registered: yes only when source commands count equals registered
  # links count AND both non-zero. Mirrors the g1.self_repair count-comparison
  # pattern above so partial installs (some links missing or stale-from-source)
  # report no, matching the documented "fully set up" / "expected subcommand
  # symlinks" claim in CHANGELOG.md and references/floor.md.
  if [ -n "$SP_INSTALL_DIR" ] && [ -d "$SP_INSTALL_DIR/commands" ]; then
    CR_CMD_COUNT=$(ls "$SP_INSTALL_DIR/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
    CR_LINK_COUNT=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "${CR_CMD_COUNT:-0}" -gt 0 ] && [ "$CR_CMD_COUNT" = "$CR_LINK_COUNT" ]; then
      printf 'g1.commands_registered=yes\n'
    else
      printf 'g1.commands_registered=no\n'
    fi
  else
    printf 'g1.commands_registered=no\n'
  fi
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
  git_inside=""
  if [ -n "$cwd" ]; then
    git_inside=$(${TIMEOUT:+$TIMEOUT 1} git -C "$cwd" rev-parse --is-inside-work-tree 2>/dev/null)
  fi
  if [ "$git_inside" = "true" ]; then
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

# Version comparison helpers for Group 6. Strict on purpose: a version this
# cannot parse must report "unknown", never "behind" — a false "update
# available" notice is the exact bug the earlier packed-integer form produced.
#
# sp-comparator-region: begin
# Nothing between this marker and the matching end marker may turn a version
# component into a number. Two earlier forms did, and both reported "behind"
# for a local build that was ahead: first a packed integer whose multiplier
# acted as a radix, then a per-component numeric test that errored on a long
# component and let control fall through to the next component. The comparison
# below is string-only, so neither failure has anything left to stand on. The
# only numeric tests allowed here compare string LENGTHS (${#...}), never
# component values — tests/floor-version-tristate.sh asserts that mechanically.
#
# Every function below pins LC_ALL=C as its first statement, before any pattern
# match. Bash matches a digit range by collation rather than by codepoint, so
# under a locale whose digit range runs wider than ASCII a character like ٢
# satisfies [0-9], passes validation, and then reaches a byte comparison that
# cannot rank it — which reported 9.0.0 as "behind" ٢.0.0. Pinning the whole
# comparator, not only its ordering step, makes validation accept ASCII digits
# and nothing else, with no character list to maintain. The same suite asserts
# the pin mechanically.
#
# The pin is an assignment, and an assignment can be refused. A caller that
# exports LC_ALL and marks it readonly makes `local LC_ALL=C` fail; bash prints
# a diagnostic, the function carries on, and validation is back under the
# caller's locale — the hole the pin exists to close, reopened silently. So
# every pin below is guarded: a pin that cannot be applied answers "cannot
# tell" on the spot rather than proceeding unpinned.
sp_version_valid() {
  # Valid = exactly three dot-separated components, each one or more decimal
  # digits, with no leading zero unless the component is exactly "0". Pinned
  # first, because the digit range below is the gate a wide locale widens.
  # A refused pin reports invalid, which the caller turns into "unknown".
  local LC_ALL=C 2>/dev/null || return 1
  local rest comp
  case "$1" in
    *[!0-9.]*) return 1 ;;
    *.*.*.*) return 1 ;;
    *.*.*) : ;;
    *) return 1 ;;
  esac
  rest="${1#*.}"
  for comp in "${1%%.*}" "${rest%%.*}" "${rest#*.}"; do
    case "$comp" in
      '' | 0?*) return 1 ;;
    esac
  done
  return 0
}

# Compares two version components as decimal strings. Returns 0 when they are
# equal, 1 when the left is greater, 2 when the right is greater, and 3 when
# the pair cannot be compared at all. Validation upstream guarantees digits
# with no leading zero, so a longer string is always the larger number and
# equal-length strings order correctly byte by byte — no size limit applies,
# because no component is ever read as a number.
sp_component_cmp() {
  # Pinned before the first pattern match, not merely before the ordering step
  # below. The digit gate is matched by collation, so an unpinned locale lets a
  # non-ASCII digit through it and into a byte comparison that cannot rank the
  # character. Scoped with local, so the rest of the hook keeps the caller's
  # locale. A refused pin reports the pair as uncomparable.
  local LC_ALL=C 2>/dev/null || return 3
  case "$1" in '' | *[!0-9]*) return 3 ;; esac
  case "$2" in '' | *[!0-9]*) return 3 ;; esac
  if [ "$1" = "$2" ]; then
    return 0
  fi
  if [ "${#1}" -ne "${#2}" ]; then
    if [ "${#1}" -gt "${#2}" ]; then return 1; fi
    return 2
  fi
  # Equal length: byte order is numeric order for digit strings, which holds
  # whatever the ambient locale collates because of the pin at the top.
  if [[ "$1" > "$2" ]]; then return 1; fi
  return 2
}

# Prints one of: current | ahead | behind | unknown. Walks major, then minor,
# then patch, stopping at the first pair that is not equal. Every failure —
# a version that will not parse, or a pair that cannot be compared — prints
# unknown and returns on the spot. Continuing past a failed comparison is what
# produced the wrong answer before, not the failure itself, so no branch here
# falls through to a later component.
sp_version_diff() {
  # Pinned here too, so the region holds the property uniformly rather than
  # depending on which function a future caller happens to enter through.
  # This is the entry point callers use, so a refused pin prints the answer.
  local LC_ALL=C 2>/dev/null || { printf 'unknown'; return 0; }
  local lv="$1" rv="$2" lrest rrest pair
  if ! sp_version_valid "$lv" || ! sp_version_valid "$rv"; then
    printf 'unknown'
    return 0
  fi
  lrest="${lv#*.}"
  rrest="${rv#*.}"
  for pair in "${lv%%.*}:${rv%%.*}" "${lrest%%.*}:${rrest%%.*}" "${lrest#*.}:${rrest#*.}"; do
    sp_component_cmp "${pair%%:*}" "${pair##*:}"
    case "$?" in
      0) : ;;
      1) printf 'ahead'; return 0 ;;
      2) printf 'behind'; return 0 ;;
      *) printf 'unknown'; return 0 ;;
    esac
  done
  printf 'current'
  return 0
}
# sp-comparator-region: end

# Group 6 — Version (local SKILL.md grep + remote GitHub release lookup, bounded curl)
{
  if [ -n "$SP_SKILL_PATH" ] && [ -f "$SP_SKILL_PATH" ]; then
    local_version=$(grep '^version:' "$SP_SKILL_PATH" 2>/dev/null | head -1 | awk '{print $2}')
    printf 'g6.local=%s\n' "${local_version:-unknown}"
    # Keep the raw response so a failed lookup stays distinguishable from a
    # response whose tag could not be parsed: no response is unreachable,
    # an unparseable tag is unknown.
    remote_raw=$(curl --max-time 8 -sf "https://api.github.com/repos/JimmySadek/strategic-partner/releases/latest" 2>/dev/null)
    remote_version=$(printf '%s' "$remote_raw" | grep -oE '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
    if [ -z "$remote_raw" ]; then
      printf 'g6.remote=unreachable\n'
      printf 'g6.diff=unreachable\n'
    else
      printf 'g6.remote=%s\n' "${remote_version:-unknown}"
      printf 'g6.diff=%s\n' "$(sp_version_diff "$local_version" "$remote_version")"
    fi
  else
    printf 'g6.local=unknown\n'
    printf 'g6.remote=unreachable\n'
    printf 'g6.diff=unknown\n'
  fi

  # Plugin discovery — one-time notice, never re-shown once dismissed by
  # installing or by the marker below. Silent if this install predates
  # the plugin packaging (no plugin/strategic-partner in the repo).
  PLUGIN_NOTICE_MARKER="${HOME}/.claude/.sp-plugin-notice-shown"
  SP_DIR_FOR_PLUGIN_CHECK=$([ -n "$SP_SKILL_PATH" ] && dirname "$SP_SKILL_PATH" 2>/dev/null)
  if [ -n "$SP_DIR_FOR_PLUGIN_CHECK" ] && [ -f "${SP_DIR_FOR_PLUGIN_CHECK}/plugin/strategic-partner/.claude-plugin/plugin.json" ]; then
    if [ -e "${HOME}/.claude/skills/strategic-partner-plugin" ]; then
      printf 'g6.plugin=installed\n'
    elif [ -f "$PLUGIN_NOTICE_MARKER" ]; then
      printf 'g6.plugin=shown\n'
    else
      printf 'g6.plugin=available\n'
      touch "$PLUGIN_NOTICE_MARKER" 2>/dev/null
    fi
  fi
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

# Group 8 — Output Style. An isolated launcher may provide the same transient
# value it passes through `--settings`, because Claude records the runtime
# attachment only after this hook returns. Then prefer an existing runtime
# attachment before falling back to settings-file precedence.
{
  os_value="${SP_SESSION_OUTPUT_STYLE:-}"
  if [ -z "$os_value" ] && [ -n "$transcript_path" ] && [ -f "$transcript_path" ] && command -v jq >/dev/null 2>&1; then
    os_value=$(${TIMEOUT:+$TIMEOUT 1} tail -200 "$transcript_path" 2>/dev/null \
      | jq -rs '[.[] | select(.attachment.type? == "output_style") | .attachment.style] | last // ""' 2>/dev/null)
  fi
  # Fallback precedence: project-local override → project → user.
  for os_file in \
    "${cwd:+$cwd/.claude/settings.local.json}" \
    "${cwd:+$cwd/.claude/settings.json}" \
    "${HOME}/.claude/settings.json"
  do
    [ -n "$os_value" ] && break
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

  # Output-style freshness: compare the style-version stamp in the repo
  # source file against the stamp in the installed ~/.claude copy.
  # Path resolution is deterministic via SP_SKILL_PATH (the proven
  # ~/.claude/commands symlink → readlink → dirname cascade resolved
  # above) — NO ${CLAUDE_*} env vars (they are not real Claude Code
  # variables; see CHANGELOG v5.4.0→v5.4.1 and v6.x hook-path entries).
  if [ -n "$SP_SKILL_PATH" ] && [ -f "$SP_SKILL_PATH" ]; then
    SP_STYLE_SRC_FILE="$(dirname "$SP_SKILL_PATH")/output-styles/strategic-partner-voice.md"
  else
    SP_STYLE_SRC_FILE=""
  fi
  SP_STYLE_INSTALLED_FILE="${HOME}/.claude/output-styles/strategic-partner-voice.md"

  os_src=""
  if [ -n "$SP_STYLE_SRC_FILE" ] && [ -f "$SP_STYLE_SRC_FILE" ]; then
    os_src=$(grep '^style-version:' "$SP_STYLE_SRC_FILE" 2>/dev/null | head -1 | awk '{print $2}')
  fi
  [ -z "$os_src" ] && os_src="none"

  if [ -f "$SP_STYLE_INSTALLED_FILE" ]; then
    os_installed=$(grep '^style-version:' "$SP_STYLE_INSTALLED_FILE" 2>/dev/null | head -1 | awk '{print $2}')
    # Installed copy exists but carries no stamp (predates the
    # style-version field) → treat as stale, never missing. missing is
    # reserved for "no installed copy at all".
    [ -z "$os_installed" ] && os_installed="unstamped"
  else
    os_installed="none"
  fi

  if [ "$os_installed" = "none" ]; then
    os_state="missing"
  elif [ "$os_src" = "none" ]; then
    # No source stamp to compare against — cannot prove staleness.
    os_state="fresh"
  elif [ "$os_installed" = "$os_src" ]; then
    os_state="fresh"
  else
    os_state="stale"
  fi

  printf 'g8.output_style_src=%s\n' "$os_src"
  printf 'g8.output_style_installed=%s\n' "$os_installed"
  printf 'g8.output_style_state=%s\n' "$os_state"
} >> "${RESULTS}.tmp" 2>/dev/null

# Atomic finalize + summary stdout (Claude sees stdout in context)
mv "${RESULTS}.tmp" "$RESULTS" 2>/dev/null

conventions=$(grep -q '^g2.claude_md=present' "$RESULTS" 2>/dev/null && printf 'present' || printf 'missing')
memory_count=$(grep '^g3.serena_memories=present count=' "$RESULTS" 2>/dev/null | head -1 | sed 's/.*count=//')
if [ "${memory_count:-0}" -gt 0 ] 2>/dev/null \
  && grep -q '^g3.project_overview=present' "$RESULTS" 2>/dev/null \
  && grep -q '^g3.decision_log=present' "$RESULTS" 2>/dev/null; then
  memory=ok
else
  memory=missing
fi
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
[ -z "$plugin" ] && plugin=unknown

touch "$MARKER"

printf 'SP-FLOOR-COMPLETE key=%s session=%s model=%s conventions=%s memory=%s findings=%s backlog=%s oldschema=%s git=%s version=%s claudemd_band=%s routing=%s output_style=%s output_style_state=%s commands_registered=%s review_policy=%s plugin=%s. Full results: %s\n' \
  "$KEY" "$session_id" "$model_id" "$conventions" "$memory" "$findings" "$backlog" "$oldschema" "$git_summary" "$version_summary" "$claudemd_band" "$routing" "$output_style" "$output_style_state" "$commands_registered" "$review_policy" "$plugin" "$RESULTS"

exit 0
