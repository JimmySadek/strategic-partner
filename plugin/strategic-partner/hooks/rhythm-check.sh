#!/bin/bash
# rhythm-check.sh — Stop-event turn validators (the "rhythm enforcer").
# Extracted verbatim from production SKILL.md frontmatter (Stop hook block)
# for the plugin packaging; the only change is version resolution, which
# self-locates against the plugin layout instead of walking
# ~/.claude/commands symlinks. Existing turn rules remain log-only;
# missing startup or closure ceremonies may block Stop once.

payload=$(cat 2>/dev/null || printf '%s' '{}')
transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null || printf '')
session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || printf '')
last_assistant_message=$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null || printf '')
stop_hook_active=$(printf '%s' "$payload" | jq -r 'if .stop_hook_active == true then "true" else "false" end' 2>/dev/null || printf 'false')
safe_session_id=$(printf '%s' "${session_id:-unknown}" | tr -cd 'A-Za-z0-9._-' | cut -c1-64)
STARTUP_PENDING="/tmp/sp-plugin-startup-pending-${safe_session_id}"
FLOOR_READY="/tmp/sp-plugin-floor-ready-${safe_session_id}"

[ -z "$transcript_path" ] && exit 0
[ ! -f "$transcript_path" ] && exit 0

# Plugin layout: this script lives at <plugin-root>/hooks/, the skill at
# <plugin-root>/skills/strategic-partner/SKILL.md. Self-locate; no symlink walk.
THIS_SCRIPT=$(perl -MCwd=abs_path -e 'print abs_path(shift)' "$0" 2>/dev/null)
if [ -n "$THIS_SCRIPT" ] && [ -f "$THIS_SCRIPT" ]; then
  PLUGIN_ROOT=$(dirname "$(dirname "$THIS_SCRIPT")")
  skill_version=$(grep '^version:' "$PLUGIN_ROOT/skills/strategic-partner/SKILL.md" 2>/dev/null | head -1 | awk '{print $2}')
  CEREMONY_LIB="$PLUGIN_ROOT/hooks/lib/session-ceremony.sh"
else
  skill_version=""
fi
[ -z "$skill_version" ] && skill_version="unknown"
CEREMONY_OK=false
if [ -n "${CEREMONY_LIB:-}" ] && [ -f "$CEREMONY_LIB" ]; then
  # shellcheck source=lib/session-ceremony.sh
  # shellcheck disable=SC1091
  . "$CEREMONY_LIB"
  CEREMONY_OK=true
fi
rule_schema_version="v1"

# Portable timeout (gtimeout on macOS coreutils, timeout on Linux; empty if neither)
TIMEOUT=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)

cwd_hash=$(printf '%s' "$cwd" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
tp_hash=$(printf '%s' "$transcript_path" | shasum -a 256 2>/dev/null | cut -d' ' -f1)
RELAY_KEY=$(printf '%s|%s|%s|%s|%s' \
      "$session_id" "$cwd_hash" "$tp_hash" \
      "$skill_version" "$rule_schema_version" \
    | shasum -a 256 2>/dev/null | cut -d' ' -f1 | head -c 16)

VIOLATIONS_LOG="/tmp/sp-rule-violations-${RELAY_KEY}.log"

last_turn=$(${TIMEOUT:+$TIMEOUT 1} tail -200 "$transcript_path" 2>/dev/null | jq -s 'map(select((.message.role // .role) == "assistant")) | last' 2>/dev/null)
[ -z "$last_turn" ] && exit 0
[ "$last_turn" = "null" ] && exit 0

turn_text=$(printf '%s' "$last_turn" | jq -r 'if .message.content then (if (.message.content | type) == "array" then (.message.content | map(select(.type == "text") | .text) | join("\n")) else .message.content end) elif .content then (if (.content | type) == "array" then (.content | map(select(.type == "text") | .text) | join("\n")) else .content end) else "" end' 2>/dev/null)
# AUQ presence, the AUQ payload text, and the violation logger are
# computed BEFORE the empty-turn_text early exit so the
# render-before-ask rule (which NEEDS the empty-text swallow case,
# claude-code#66112) can evaluate. Every other validator stays
# gated behind the early exit below and sees the same inputs.
has_auq=$(printf '%s' "$last_turn" | jq -r 'tostring | if test("\"name\"\\s*:\\s*\"AskUserQuestion\""; "i") then "true" else "false" end' 2>/dev/null)
auq_payload_text=$(printf '%s' "$last_turn" | jq -r '[ .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | if length == 0 then "" else ((.[0].input.questions // []) | map((.question // "") + " " + (.header // "") + " " + (((.options // []) | map((.label // "") + " " + (.description // "")) | join(" ")))) | join(" ")) end' 2>/dev/null)

violation_count=0
log_violation() {
  if [ "$violation_count" = 0 ]; then
    printf '=== Turn check %s RELAY_KEY=%s ===\n' "$(date -u +%FT%TZ)" "$RELAY_KEY" >> "$VIOLATIONS_LOG"
  fi
  printf -- '- %s\n' "$1" >> "$VIOLATIONS_LOG"
  violation_count=$((violation_count + 1))
}

block_stop() {
  block_reason="$1"
  jq -cn --arg reason "$block_reason" '{decision:"block",reason:$reason}'
  exit 0
}

# Lifecycle absence checks are the only blocking rules in this hook. A first
# miss gets one corrective turn. If Claude is already in that corrective turn,
# log the remaining gap and allow Stop so the hook cannot loop indefinitely.
if [ "$CEREMONY_OK" = true ] && [ -f "$STARTUP_PENDING" ]; then
  continuation_path=$(head -1 "$STARTUP_PENDING" 2>/dev/null)
  floor_ready=no
  if [ -s "$FLOOR_READY" ]; then
    floor_results=$(head -1 "$FLOOR_READY" 2>/dev/null)
    [ -n "$floor_results" ] && [ -f "$floor_results" ] && floor_ready=yes
  fi
  startup_missing=$(sp_startup_missing_evidence "$transcript_path" "$last_assistant_message" "$continuation_path" "$floor_ready")
  if [ -n "$startup_missing" ]; then
    if [ "$stop_hook_active" = "true" ]; then
      log_violation "startup-ceremony-incomplete after corrective turn: missing ${startup_missing}"
      rm -f "$STARTUP_PENDING"
    else
      block_stop "Strategic Partner startup ceremony is incomplete: missing ${startup_missing}. Continue by rendering a concise project-first recenter and end that orientation with AskUserQuestion. If a handoff path was supplied, read it or surface an honest load-failure choice before stopping."
    fi
  else
    rm -f "$STARTUP_PENDING"
  fi
fi

if [ "$CEREMONY_OK" = true ] && sp_transcript_has_session_end_intent "$transcript_path"; then
  closure_missing=$(sp_closure_missing_evidence "$transcript_path")
  if [ -n "$closure_missing" ]; then
    if [ "$stop_hook_active" = "true" ]; then
      log_violation "closure-ceremony-incomplete after corrective turn: missing ${closure_missing}"
    else
      block_stop "Strategic Partner closure ceremony is incomplete: missing ${closure_missing}. Continue through the existing handoff workflow: render the full Closure Walk Status, capture /insights or an explicit fallback, write the continuation handoff, and show the plugin continuation fence before stopping."
    fi
  fi
fi

# Rule 11: question-visible-lead. For the turn span after the last
# genuine user text prompt, an AskUserQuestion must not be the first
# assistant surface. Tool-result carrier entries do not start a new span.
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e type >/dev/null 2>&1; then
  auq_surface_result=$(${TIMEOUT:+$TIMEOUT 1} tail -400 "$transcript_path" 2>/dev/null | jq -sr '
    def role: (.message.role // .role // "");
    def content: (.message.content // .content // []);
    def nonempty_text:
      if (content | type) == "array" then any(content[]?; .type == "text" and ((.text // "") | length > 0))
      elif (content | type) == "string" then ((content // "") | length > 0)
      else false end;
    def genuine_user_text: role == "user" and nonempty_text;
    def has_auq: ([ .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | length) > 0;
    (map(select(type == "object"))) as $rows
    | ([$rows | to_entries[] | select(.value | genuine_user_text) | .key] | last // -1) as $last_prompt
    | ([$rows | to_entries[] | select(.key >= $last_prompt and ((.value | role) == "user")) | .key] | last // $last_prompt) as $last_user
    | ([$rows | to_entries[] | select(.key > $last_user and ((.value | role) == "assistant") and (.value | has_auq)) | .key] | first // -1) as $first_auq
    | if $first_auq == -1 then "ok"
      elif ([$rows | to_entries[] | select(.key > $last_user and .key <= $first_auq and ((.value | role) == "assistant") and (.value | nonempty_text))] | length) > 0 then "ok"
      else "violation" end
  ' 2>/dev/null)
else
  auq_surface_result=$(${TIMEOUT:+$TIMEOUT 1} tail -400 "$transcript_path" 2>/dev/null | perl -ne '
    my $role = /"role"\s*:\s*"(user|assistant)"/ ? $1 : "";
    my $has_text = /"type"\s*:\s*"text"/ && /"text"\s*:\s*"[^"]+/;
    my $has_auq = /"type"\s*:\s*"tool_use"/ && /"name"\s*:\s*"AskUserQuestion"/;
    push @rows, { role => $role, has_text => $has_text, genuine => ($role eq "user" && $has_text), has_auq => $has_auq };
    END {
      my $last_prompt = -1;
      for (my $i = 0; $i <= $#rows; $i++) {
        $last_prompt = $i if $rows[$i]->{genuine};
      }
      my $last_user = $last_prompt;
      for (my $i = 0; $i <= $#rows; $i++) {
        $last_user = $i if $i >= $last_prompt && $rows[$i]->{role} eq "user";
      }
      my $first_auq = -1;
      for (my $i = $last_user + 1; $i <= $#rows; $i++) {
        if ($rows[$i]->{role} eq "assistant" && $rows[$i]->{has_auq}) { $first_auq = $i; last; }
      }
      if ($first_auq == -1) { print "ok"; exit; }
      for (my $i = $last_user + 1; $i <= $first_auq; $i++) {
        if ($rows[$i]->{role} eq "assistant" && $rows[$i]->{has_text}) { print "ok"; exit; }
      }
      print "violation";
    }
  ' 2>/dev/null)
fi
if [ "$auq_surface_result" = "violation" ]; then
  auq_surface_message="question-visible-lead: AskUserQuestion appeared before visible assistant text in this turn — render the recommendation or status as visible chat text first, then re-ask the question next turn"
  log_violation "$auq_surface_message"
fi

# Rule 7: render-before-ask (anti-swallow). A turn closing in
# AskUserQuestion whose question text references rendered content
# ("here's", "above", "the table", ...) while the turn carries no
# visible text block of 300+ chars is the claude-code#66112 swallow
# shape: the deliverable went into hidden thinking and never reached
# chat. Evaluated before the early exit because the swallow case has
# zero visible text by definition.
if [ "$has_auq" = "true" ] && [ -n "$auq_payload_text" ]; then
  auq_lower=$(printf '%s' "$auq_payload_text" | tr '[:upper:]' '[:lower:]')
  referential=no
  case "$auq_lower" in
    *"here's"*|*"here is"*|*above*|*"as shown"*|*"that's the full"*|*"where things stand"*|*"the table"*|*"the queue"*|*"the breakdown"*|*"the summary"*|*rendered*)
      referential=yes
      ;;
  esac
  if [ "$referential" = "yes" ]; then
    prose_len=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/^>.*$//mg; $t =~ s/^\s+//; $t =~ s/\s+$//; print length($t);' 2>/dev/null)
    [ -z "$prose_len" ] && prose_len=0
    if [ "$prose_len" -lt 300 ] 2>/dev/null; then
      log_violation "render-before-ask: AUQ references rendered content but the turn carries no visible text block of 300+ chars — re-render the deliverable as a visible chat block at the top of the next response, then continue"
    fi
  fi
fi

[ -z "$turn_text" ] && exit 0

has_tool_use=$(printf '%s' "$last_turn" | jq -r 'tostring | if test("\"type\"\\s*:\\s*\"tool_use\"") then "true" else "false" end' 2>/dev/null)
has_lastprompts_write=$(printf '%s' "$last_turn" | jq -r 'tostring | if test("\\.handoffs/last-prompts/[0-9]+\\.md") then "true" else "false" end' 2>/dev/null)
has_scripts_write=$(printf '%s' "$last_turn" | jq -r 'tostring | if test("\"file_path\"\\s*:\\s*\"[^\"]*\\.scripts/") then "true" else "false" end' 2>/dev/null)
has_context_preflight=$(printf '%s' "$last_turn" | jq -r 'tostring | if test("proposal-preflight|context-file preflight|preflight receipt|\"receipt\"\\s*:"; "i") then "true" else "false" end' 2>/dev/null)

had_dispatch=$(${TIMEOUT:+$TIMEOUT 1} tail -400 "$transcript_path" 2>/dev/null | jq -s '[.[] | select((.message.role // .role) == "user")] | last | if . == null then "false" elif (tostring | test("\"name\"\\s*:\\s*\"(Agent|Task)\""; "i")) then "true" else "false" end' 2>/dev/null)

# Rule 1: AUQ-must-be-AUQ — prose question without AskUserQuestion in same turn
auq_violation=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/^>.*$//mg; if ($t =~ /^([^\n]{15,}\?)\s*$/m) { print $1; }' 2>/dev/null | head -c 80)
if [ -n "$auq_violation" ] && [ "$has_auq" != "true" ]; then
  log_violation "AUQ-must-be-AUQ: prose question detected: ${auq_violation}"
fi

# Rule 2: Identity-reset announcement — required after Agent dispatch return
if [ "$had_dispatch" = "true" ]; then
  if ! printf '%s' "$turn_text" | grep -qE 'Back in advisory mode|Dispatch complete\. I am back in strategic-partner mode'; then
    log_violation "identity-reset-announcement: missing reset phrase after dispatch return"
  fi
fi

# Rule 3: Tool-availability claims — first-person tool-access claim without tool_use
tool_claim=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/`[^`]*`//g; $t =~ s/\*"[^"]*"\*//g; $t =~ s/"[^"]*"//g; $t =~ s/^>.*$//mg; if ($t =~ /\b(I can run |I can call |I have access to |I cannot access |I don.t have access|I.m able to run |I am able to run )/i) { print $1; }' 2>/dev/null | head -c 60)
if [ -n "$tool_claim" ] && [ "$has_tool_use" != "true" ]; then
  log_violation "tool-availability-claim: first-person claim without tool_use: ${tool_claim}"
fi

# Rule 10: context-file proposal preflight. If SP proposes exact
# text for an always-loaded context file, the same turn must show a
# proposal-preflight verdict or receipt. Actual writes are blocked
# separately by hooks/context-file-guard.sh; this catches proposal
# text before a write tool is used.
context_proposal=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```/ CODEFENCE /g; if ($t =~ /\b(CLAUDE\.md|AGENTS\.md|GEMINI\.md|\.claude\/rules\/[^\s`]+\.md)\b/i && $t =~ /\b(proposed text|add this|add the following|append|write this|update .*context|context-file text)\b/i) { print "yes"; }' 2>/dev/null)
if [ "$context_proposal" = "yes" ] && [ "$has_context_preflight" != "true" ]; then
  log_violation "context-file-preflight: proposed exact context-file text without a proposal-preflight verdict/receipt"
fi

# Rule 4: Fence-write coupling — fence emitted without same-turn last-prompts write
if printf '%s' "$turn_text" | grep -qF '══ START 🟢 COPY ══'; then
  real_fence=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/`[^`]*`//g; $t =~ s/^>.*$//mg; if ($t =~ /══ START 🟢 COPY ══/) { print "yes"; }' 2>/dev/null)
  if [ "$real_fence" = "yes" ] && [ "$has_lastprompts_write" != "true" ]; then
    log_violation "fence-write-coupling: fence emitted without preceding last-prompts write"
  fi
fi

# Rule 5: Floor-signal acknowledgment — non-clean actionable signal in last user
# prompt requires either dispatch (Agent/Task tool_use) or explicit text mention
last_user_text=$(${TIMEOUT:+$TIMEOUT 1} tail -400 "$transcript_path" 2>/dev/null | jq -s '[.[] | select((.message.role // .role) == "user")] | last | tostring' 2>/dev/null)
floor_line=$(printf '%s' "$last_user_text" | grep -oE 'SP-FLOOR-COMPLETE [^.]+' | head -1)
if [ -n "$floor_line" ]; then
  non_clean=""
  echo "$floor_line" | grep -q 'conventions=missing'      && non_clean="$non_clean conventions"
  echo "$floor_line" | grep -q 'memory=missing'           && non_clean="$non_clean memory"
  echo "$floor_line" | grep -q 'git=dirty'                && non_clean="$non_clean git"
  echo "$floor_line" | grep -q 'version=behind'           && non_clean="$non_clean version"
  echo "$floor_line" | grep -qE 'routing=(missing|stale)' && non_clean="$non_clean routing"
  if [ -n "$non_clean" ]; then
    acknowledged=false
    if [ "$has_tool_use" = "true" ]; then
      printf '%s' "$last_turn" | jq -r 'tostring' 2>/dev/null \
        | grep -qE '"name"[[:space:]]*:[[:space:]]*"(Agent|Task)"' && acknowledged=true
    fi
    if [ "$acknowledged" = false ]; then
      ack_pattern='matrix|routing|memory|onboard|serena|claude\.md|conventions|uncommitted|behind|update.*available|defer'
      printf '%s' "$turn_text" | grep -qiE "$ack_pattern" && acknowledged=true
    fi
    if [ "$acknowledged" = false ]; then
      log_violation "floor-signal-acknowledgment: non-clean signals (${non_clean# }) not addressed"
    fi
  fi
fi

# Rule 6: script-write coupling — a "bash .scripts/<path>" runner
# handoff emitted without a same-turn Write/Edit/MultiEdit to a
# .scripts/ path (Script Emission Protocol parity with Rule 4).
if printf '%s' "$turn_text" | grep -qF '.scripts/'; then
  real_runner=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/`([^`]*)`/$1/g; $t =~ s/^>.*$//mg; for my $ln (split /\n/, $t) { $ln =~ s/^\s+//; $ln =~ s/\s+$//; next unless $ln =~ /^(?:! )?bash \.scripts\//; next if $ln =~ /[;|&]/; print "yes"; last; }' 2>/dev/null)
  if [ "$real_runner" = "yes" ] && [ "$has_scripts_write" != "true" ]; then
    log_violation "script-write-coupling: runner handoff emitted without preceding .scripts/ write"
  fi
fi

# Rule 8: advisor-launcher — a real COPY fence whose first line is an
# advisor alias (/strategic-partner with no .handoffs/ path, /advisor,
# /sp) launches an advisor the guard bars from implementing, so the
# deliverables never get built (Fence discriminator parity with Rule 4).
if printf '%s' "$turn_text" | grep -qF '══ START 🟢 COPY ══'; then
  real_fence8=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/`[^`]*`//g; $t =~ s/^>.*$//mg; if ($t =~ /══ START 🟢 COPY ══/) { print "yes"; }' 2>/dev/null)
  if [ "$real_fence8" = "yes" ]; then
    launcher_line=$(printf '%s' "$turn_text" | perl -e 'undef $/; my $t=<STDIN>; $t =~ s/```[\s\S]*?```//g; $t =~ s/`[^`]*`//g; $t =~ s/^>.*$//mg; my $in=0; for my $ln (split /\n/, $t) { if ($ln =~ /══ END 🛑 COPY ══/) { last; } if ($in) { my $s=$ln; $s =~ s/^\s+//; $s =~ s/\s+$//; next if $s eq ""; print $s; last; } if ($ln =~ /══ START 🟢 COPY ══/) { $in=1; } }' 2>/dev/null)
    case "$launcher_line" in
      /strategic-partner[[:space:]]*.handoffs/*) : ;;   # exempt — handoff continuation
      /strategic-partner|/strategic-partner[[:space:]]*)
        log_violation "advisor-launcher: COPY fence first line is /strategic-partner with no .handoffs/ path for an implementation prompt — pasting it launches an advisor the guard bars from implementing, so nothing gets built; emit a real implementation skill on line 1, or omit the command line for a bare prompt (the advisor command is valid only as a /strategic-partner <.handoffs path> handoff continuation)" ;;
      /advisor|/advisor[[:space:]]*)
        log_violation "advisor-launcher: COPY fence first line is /advisor for an implementation prompt — pasting it launches an advisor the guard bars from implementing, so nothing gets built; emit a real implementation skill on line 1, or omit the command line for a bare prompt (the advisor command is valid only as a /strategic-partner <.handoffs path> handoff continuation)" ;;
      /sp|/sp[[:space:]]*)
        log_violation "advisor-launcher: COPY fence first line is /sp for an implementation prompt — pasting it launches an advisor the guard bars from implementing, so nothing gets built; emit a real implementation skill on line 1, or omit the command line for a bare prompt (the advisor command is valid only as a /strategic-partner <.handoffs path> handoff continuation)" ;;
    esac
  fi
fi

# Rule 9: delivery-choice-missing (LOG-ONLY) — a real implementation
# COPY fence emitted without recording a delivery choice (no
# **Simplicity:** marker in turn_text, and no "Dispatch now" in
# auq_payload_text) means the Delivery Choice Checkpoint was skipped.
# Reuses Rule 8's real_fence8 discriminator and launcher_line. LOG-ONLY:
# never returns or exits nonzero; the final exit 0 below is unchanged.
# Known limitation (accepted, LOG-ONLY): detection is single-turn, so a
# fence emitted in a follow-up turn after the checkpoint already ran one
# turn earlier (user picked "Give me the prompt") can log a benign false
# positive. By design per the brief — no cross-turn lookback.
if [ "${real_fence8:-}" = "yes" ]; then
  dc_skip=no
  case "$launcher_line" in
    /strategic-partner[[:space:]]*.handoffs/*) dc_skip=yes ;;   # exempt — handoff continuation
  esac
  printf '%s' "$turn_text" | grep -qF '**Simplicity:**' && dc_skip=yes
  printf '%s' "$auq_payload_text" | grep -qF 'Dispatch now' && dc_skip=yes
  if [ "$dc_skip" = no ]; then
    log_violation "delivery-choice-missing: implementation prompt emitted without a Simplicity marker or a dispatch offer — the Delivery Choice Checkpoint was skipped"
  fi
fi

exit 0
