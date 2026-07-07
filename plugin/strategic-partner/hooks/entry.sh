#!/bin/bash
# entry.sh — plugin hook entry point that scopes session-global plugin hooks
# to sessions where Strategic Partner (SP) is actually active.
#
# Why this exists: hooks/hooks.json hooks fire in EVERY session while the
# plugin is enabled. Production SP's hooks were skill-frontmatter-scoped
# (active only once the skill loaded into a session). This gate reproduces
# that scoping so unrelated executor sessions are never blocked by the
# advisory guard (plugin-migration audit, condition C2).
#
# Arming signals — deterministic and structural, never content-sniffing
# (a transcript grep for "strategic-partner" would false-positive in
# executor sessions that merely mention SP, e.g. sessions editing SP source):
#
#   1. UserPromptSubmit whose prompt is an SP invocation:
#      /strategic-partner[...], /sp, /advisor, or a namespaced plugin form
#      like /sp-plugin-trial:strategic-partner — EXCEPT the three utility
#      subcommands (:help :copy-prompt :update), matching the exemption
#      already inside floor-check.sh.
#   2. PreToolUse on the Skill tool whose skill input is
#      "strategic-partner" or "<namespace>:strategic-partner"
#      (the natural-language activation path).
#   3. SessionStart in a project whose .claude settings opt into the
#      resident advisor (an "agent" value containing "sp-advisor").
#
# Armed state is a per-session marker file in /tmp keyed by session_id.
# Disarms naturally: /clear starts a new session_id; compaction keeps it.
#
# macOS bash 3.2 compatible. Tool name comes from stdin JSON, never
# ${CLAUDE_*} env vars (see claudedocs/provisional-guards.md).
# Set SP_PLUGIN_TRACE=1 to append one line per event to /tmp/sp-plugin-trace.log.

EVENT="$1"
PAYLOAD=$(cat 2>/dev/null || printf '%s' '{}')
HOOKS_DIR=$(cd "$(dirname "$0")" && pwd)

JQ_OK=false
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
  JQ_OK=true
fi

# Top-level string field from the payload (jq when available, grep fallback).
json_field() {
  if [ "$JQ_OK" = true ]; then
    printf '%s' "$PAYLOAD" | jq -r --arg k "$1" '.[$k] // ""' 2>/dev/null
  else
    printf '%s' "$PAYLOAD" | grep -Eo "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | cut -d'"' -f4
  fi
}

SESSION_ID=$(json_field session_id)
[ -z "$SESSION_ID" ] && SESSION_ID=unknown
SAFE_SID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
MARKER="/tmp/sp-plugin-active-${SAFE_SID}"

trace() {
  [ "${SP_PLUGIN_TRACE:-0}" = "1" ] || return 0
  printf '%s event=%s sid=%s %s\n' "$(date -u +%FT%TZ 2>/dev/null)" "$EVENT" "$SAFE_SID" "$*" >> /tmp/sp-plugin-trace.log
}

flush_probe() {
  [ "${SP_PLUGIN_TRACE:-0}" = "1" ] || return 0
  probe_tool="$1"
  probe_transcript=$(json_field transcript_path)
  [ -n "$probe_transcript" ] && [ -r "$probe_transcript" ] || return 0

  probe_has_text=no
  probe_has_tool=no
  if [ "$JQ_OK" = true ]; then
    probe_last_asst=$(tail -200 "$probe_transcript" 2>/dev/null | jq -s 'map(select(type == "object" and ((.message.role // .role // "") == "assistant"))) | last // empty' 2>/dev/null)
    if [ -n "$probe_last_asst" ]; then
      probe_has_text=$(printf '%s' "$probe_last_asst" | jq -r 'def content: (.message.content // .content // []); if (((content | type) == "array") and any(content[]?; .type == "text" and ((.text // "") | length > 0))) or (((content | type) == "string") and ((content // "") | length > 0)) then "yes" else "no" end' 2>/dev/null)
      probe_has_tool=$(printf '%s' "$probe_last_asst" | jq -r --arg tool "$probe_tool" 'if ([ .. | objects | select(.type? == "tool_use" and .name? == $tool) ] | length) > 0 then "yes" else "no" end' 2>/dev/null)
    fi
  else
    probe_last_asst=$(tail -200 "$probe_transcript" 2>/dev/null | grep '"role"[[:space:]]*:[[:space:]]*"assistant"' | tail -1)
    if [ -n "$probe_last_asst" ]; then
      printf '%s' "$probe_last_asst" | grep -qE '"type"[[:space:]]*:[[:space:]]*"text"[^}]*"text"[[:space:]]*:[[:space:]]*"[^"]+' && probe_has_text=yes
      printf '%s' "$probe_last_asst" | perl -e 'my $tool = quotemeta shift; undef $/; my $s = <STDIN>; exit($s =~ /"name"\s*:\s*"$tool"/ ? 0 : 1);' "$probe_tool" 2>/dev/null && probe_has_tool=yes
    fi
  fi
  [ "$probe_has_text" = "yes" ] || probe_has_text=no
  [ "$probe_has_tool" = "yes" ] || probe_has_tool=no
  printf '%s probe=flush tool=%s last_asst_has_text=%s last_asst_has_this_tool=%s\n' "$(date -u +%FT%TZ 2>/dev/null)" "$probe_tool" "$probe_has_text" "$probe_has_tool" >> /tmp/sp-plugin-trace.log
  return 0
}

arm() { : > "$MARKER"; trace "armed reason=$1"; }
armed() { [ -f "$MARKER" ]; }

# Re-pipe the payload into a sibling script and adopt its exit code.
delegate() {
  trace "delegate target=$1"
  target="$1"
  shift
  printf '%s' "$PAYLOAD" | bash "$HOOKS_DIR/$target" "$@"
  exit $?
}

# Does this prompt invoke SP? (Exempts :help :copy-prompt :update.)
prompt_is_sp_invocation() {
  printf '%s' "$1" | perl -e '
    undef $/; my $p = <STDIN>;
    exit 1 unless $p =~ m{\A\s*/(?:[A-Za-z0-9-]+:)?(?:strategic-partner|sp|advisor)(?::([a-z-]+))?(?:\s|\z)};
    my $sub = defined $1 ? $1 : "";
    exit 1 if $sub =~ /^(?:help|copy-prompt|update)$/;
    exit 0;
  ' 2>/dev/null
}

case "$EVENT" in

  SessionStart)
    CWD=$(json_field cwd)
    if [ -n "$CWD" ]; then
      for SETTINGS in "$CWD/.claude/settings.local.json" "$CWD/.claude/settings.json"; do
        [ -f "$SETTINGS" ] || continue
        if [ "$JQ_OK" = true ]; then
          AGENT_VAL=$(jq -r '.agent // empty' "$SETTINGS" 2>/dev/null)
        else
          AGENT_VAL=$(grep -Eo '"agent"[[:space:]]*:[[:space:]]*"[^"]*"' "$SETTINGS" 2>/dev/null | head -1 | cut -d'"' -f4)
        fi
        case "$AGENT_VAL" in
          *sp-advisor*)
            arm "resident-advisor settings=$SETTINGS"
            delegate floor-check.sh
            ;;
        esac
      done
    fi
    trace "pass-through"
    exit 0
    ;;

  UserPromptSubmit)
    PROMPT=$(json_field prompt)
    if [ -n "$PROMPT" ] && prompt_is_sp_invocation "$PROMPT"; then
      arm "prompt-invocation"
    fi
    if armed; then
      delegate floor-check.sh
    fi
    trace "pass-through"
    exit 0
    ;;

  PreToolUse)
    TOOL_NAME=$(json_field tool_name)
    flush_probe "$TOOL_NAME"
    if [ "$TOOL_NAME" = "Skill" ]; then
      if [ "$JQ_OK" = true ]; then
        SKILL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.skill // ""' 2>/dev/null)
      else
        SKILL_NAME=$(printf '%s' "$PAYLOAD" | grep -Eo '"skill"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f4)
      fi
      case "$SKILL_NAME" in
        strategic-partner|*:strategic-partner) arm "skill-tool name=$SKILL_NAME" ;;
      esac
      exit 0
    fi
    if armed; then
      delegate guard-impl.sh
    fi
    trace "pass-through tool=$TOOL_NAME"
    exit 0
    ;;

  Stop)
    if armed; then
      delegate rhythm-check.sh
    fi
    trace "pass-through"
    exit 0
    ;;

  *)
    trace "unknown-event"
    exit 0
    ;;
esac
