#!/bin/bash
# startup-latency-probe.sh — measure what a user waits through at SP session start.
#
# Reads Claude Code session transcripts (JSONL, one file per session) and, for
# every Strategic Partner *opening* — an invocation of the main SP command or of
# the `:status` recenter briefing — measures the span between the user pressing
# Enter and the opening actually arriving:
#
#   * how many tool calls run silently inside that span   (headline metric)
#   * wall-clock seconds to first assistant output of any kind, to first
#     visible text, and to the opening itself
#   * the size of the opening message
#   * whether a short "signal line" preceded the silent run
#
# TWO endpoints are measured per opening, because they answer different
# questions and a menu satisfies only one of them:
#
#   time_to_first_actionable_control — when the user could act again. Ends at
#     the first structured briefing OR at an AskUserQuestion / ExitPlanMode
#     menu, whichever comes first. SP's opening menu is an AskUserQuestion and
#     it hands control back just as a briefing does.
#
#   time_to_briefing — when the user was actually told anything. Ends ONLY at a
#     substantive text block. A menu does not end it. An opening that hands the
#     user a menu with no briefing in front of it records briefing = ABSENT,
#     not a number. That absence is the render-before-ask defect, and it is
#     invisible if the two endpoints are collapsed into one.
#
# One-line progress narration ("Starting the session by loading...") ends
# neither; it is recorded separately as a signal line.
#
# Openings are deduplicated by the USER-EVENT UUID of the command turn. Forked
# transcripts replay the same opening event into more than one file; counting
# those as separate waits inflates n and distorts the tail. When one UUID
# appears in several transcripts, the copy whose transcript continues furthest
# past the opening is kept — the fork that stops right after the opening is a
# truncated replay, not a user who never answered.
#
# Every opening is classified (floor green / non-clean, fresh / continuation,
# plugin / standalone skill, SP's own repo vs other projects, empty folder,
# session-start vs mid-session) and the distribution (n / min / median / p90 /
# max) is printed per category, followed by one machine-comparable summary line
# so an after-measurement can be diffed against this run.
#
# A floor classification carries forward within a transcript: the floor hook
# stays silent when it has already run for the scope, so a second opening in
# the same session inherits the most recent SP-FLOOR-COMPLETE line rather than
# falling into the unclassified bucket.
#
# Sub-agent dispatch calls (the tool is named "Agent" in this corpus, "Task" in
# other Claude Code versions — both are recognised, by exact name) are counted
# separately from the tool total. One such call can hide arbitrary work, so a
# tool-count target that cannot see sub-agent usage can be met by moving work
# into sub-agents rather than removing it.
#
# The corpus is READ-ONLY. This script never writes inside it.
#
# Usage:
#   tests/startup-latency-probe.sh [--corpus DIR] [--records FILE] [--manifest FILE]
#                                  [--since ISO-DATE] [--exclude-manifest FILE]
#
# --since and --exclude-manifest define the AFTER cohort. The corpus grows, so
# an after-run over the whole of it would blend post-change openings with the
# baseline ones and dilute the result. Either flag works alone or together:
#
#   --since 2026-08-04            keep only openings on or after that date
#   --exclude-manifest base.tsv   drop every opening listed in that manifest
#
# A manifest is `slug <tab> session <tab> date <tab> opening-uuid`. Exclusion
# matches on the UUID when the manifest carries one, and on slug/session/date
# otherwise, so manifests written before the UUID column existed still work.
# An empty cohort is reported as an empty cohort and exits 0; only a corpus
# that yields no openings at all is treated as a broken run (exit 4).
#
# Environment overrides: SUBSTANTIVE_MIN_LINES, SUBSTANTIVE_MIN_CHARS,
#                        SP_DEV_SLUG, SP_HARNESS_RE, CORPUS_ROOT
#
# Constraints honoured: macOS bash 3.2 (no associative arrays, no namerefs),
# BSD awk (no mktime/strftime), BSD grep (bounded repetition capped at 255 —
# hence jq, not grep, for extraction). Requires jq.

set -u

# ---------------------------------------------------------------------------
# Tunables (documented in BASELINE-REPORT.md § Methodology)
# ---------------------------------------------------------------------------

# A text block is the opening (rather than progress narration) when it has at
# least SUBSTANTIVE_MIN_LINES non-blank lines, OR at least 2 non-blank lines and
# at least SUBSTANTIVE_MIN_CHARS characters. Empirically every progress line in
# this corpus is exactly one line; every real briefing is multi-line.
SUBSTANTIVE_MIN_LINES=${SUBSTANTIVE_MIN_LINES:-4}
SUBSTANTIVE_MIN_CHARS=${SUBSTANTIVE_MIN_CHARS:-240}

# Project slug of SP's own development repo. Openings there are reported
# separately and never blended into the headline.
SP_DEV_SLUG=${SP_DEV_SLUG:-'-Users-OldJimmy--config-skillshare-skills-strategic-partner'}

# Project slugs that are SP's own test / smoke harnesses rather than real user
# projects. Extended regex matched against the project slug.
SP_HARNESS_RE=${SP_HARNESS_RE:-'(SP-Serena-Validation|sp-ceremony-smoke)'}

CORPUS_ROOT=${CORPUS_ROOT:-"$HOME/.claude/projects"}
RECORDS_OUT=""
MANIFEST_OUT=""
SINCE=""
EXCLUDE_MANIFEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus)   CORPUS_ROOT=$2; shift 2 ;;
    --records)  RECORDS_OUT=$2; shift 2 ;;
    --manifest) MANIFEST_OUT=$2; shift 2 ;;
    --since)    SINCE=$2; shift 2 ;;
    --exclude-manifest) EXCLUDE_MANIFEST=$2; shift 2 ;;
    -h|--help)  sed -n '2,81p' "$0"; exit 0 ;;
    *) printf 'startup-latency-probe: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

SINCE_BAD=0
case "$SINCE" in
  '') ;;
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
    # Shape alone would accept 2026-13-99, which silently empties the cohort.
    # Strip the leading zero before comparing: bash reads 08 as bad octal.
    since_m=${SINCE:5:2}; since_m=${since_m#0}
    since_d=${SINCE:8:2}; since_d=${since_d#0}
    if [ "$since_m" -lt 1 ] || [ "$since_m" -gt 12 ] ||
       [ "$since_d" -lt 1 ] || [ "$since_d" -gt 31 ]; then SINCE_BAD=1; fi
    ;;
  *) SINCE_BAD=1 ;;
esac
if [ "$SINCE_BAD" -eq 1 ]; then
  printf 'startup-latency-probe: --since expects a real ISO date (YYYY-MM-DD), got: %s\n' "$SINCE" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Preconditions — fail loudly, never produce silent zeros
# ---------------------------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  cat >&2 <<'ERR'
startup-latency-probe: FATAL — `jq` is not on PATH.

This probe parses JSONL session transcripts and cannot fall back to grep:
BSD grep caps bounded repetition at 255 characters, which silently truncates
the SP-FLOOR-COMPLETE status line the classification depends on.

Install jq (`brew install jq`) and re-run. Refusing to continue — a partial
parse would report zeros that look like a result.
ERR
  exit 3
fi

if [ ! -d "$CORPUS_ROOT" ]; then
  printf 'startup-latency-probe: FATAL — corpus root not found: %s\n' "$CORPUS_ROOT" >&2
  exit 3
fi

if [ -n "$EXCLUDE_MANIFEST" ] && [ ! -f "$EXCLUDE_MANIFEST" ]; then
  printf 'startup-latency-probe: FATAL — --exclude-manifest file not found: %s\n' "$EXCLUDE_MANIFEST" >&2
  exit 3
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sp-latency-probe.XXXXXX") || exit 3
trap 'rm -rf "$WORK"' EXIT

BLOCKS="$WORK/blocks.tsv"
RAW="$WORK/raw.tsv"
DEDUPED="$WORK/deduped.tsv"
RECORDS="$WORK/records.tsv"
MANIFEST="$WORK/manifest.tsv"
FILELIST="$WORK/files.txt"
JQERR="$WORK/jq-stderr.txt"
JQERRLOG="$WORK/jq-errors.txt"

# ---------------------------------------------------------------------------
# 1. Enumerate transcripts (LC_ALL=C sort => deterministic order)
#
# `*/subagents/*` holds sub-agent transcripts. Those are not user sessions —
# nobody is sitting at a prompt waiting for them — so they are excluded.
# ---------------------------------------------------------------------------

find "$CORPUS_ROOT" -name '*.jsonl' -type f 2>/dev/null \
  | grep -v '/subagents/' \
  | LC_ALL=C sort > "$FILELIST"

TOTAL_FILES=$(wc -l < "$FILELIST" | tr -d ' ')
if [ "$TOTAL_FILES" -eq 0 ]; then
  printf 'startup-latency-probe: FATAL — no .jsonl transcripts under %s\n' "$CORPUS_ROOT" >&2
  exit 3
fi

# ---------------------------------------------------------------------------
# 2. Per-file block extraction
#
# Emits an ordered event stream, one per line:
#   FILE   <slug> <session-id>              file boundary
#   FLOOR  <ts> <SP-FLOOR-COMPLETE line>    hook status line injected at entry
#   UCMD   <ts> <command-name> <args> <uuid>  a slash command the user typed
#   UTEXT  <ts> <chars> <first 80 chars>    free text the user typed
#   UTRES  <ts> <chars> <first 80 chars>    a tool result returning to the model
#   ATOOL  <ts> <tool name>                 a tool call
#   ATEXT  <ts> <chars> <non-blank lines>   assistant text the user sees
#   ATHINK <ts>                             assistant thinking block
#
# Dropped: sidechain (sub-agent) lines, meta lines (slash-command expansions and
# caveats), and local-command stdout — none of these are user input or
# user-visible assistant output.
# ---------------------------------------------------------------------------

JQ_BLOCKS='
def clean: gsub("[\r\n\t]"; " ");
def cap($re): [ match($re) | .captures[0].string ] | first // "";

if (.isSidechain == true) then empty

elif .type == "attachment" then
  (((.attachment.content // .attachment.stdout // "") | tostring)) as $c
  | if ($c | test("SP-FLOOR-COMPLETE"))
    then ["FLOOR", (.timestamp // ""),
          (([$c | match("SP-FLOOR-COMPLETE[^\n]*").string] | first // "") | clean), ""]
    else empty end

elif .type == "user" then
  if (.isMeta == true) then empty
  else (.message.content) as $mc
  | if ($mc | type) == "string" then
      if ($mc | test("<command-name>")) then
        ["UCMD", (.timestamp // ""),
         ($mc | cap("<command-name>([^<]*)</command-name>") | clean),
         ($mc | cap("<command-args>([^<]*)</command-args>") | clean),
         ((.uuid // "") | tostring)]
      elif ($mc | test("^<(local-command|command-message|command-contents|command-stdout|task-notification)")) then empty
      else ["UTEXT", (.timestamp // ""), (($mc | length) | tostring), ($mc | clean | .[0:80])]
      end
    elif ($mc | type) == "array" then
      ([$mc[]? | select(.type == "text") | .text] | join("\n")) as $t
      | if ($t | length) > 0
        then ["UTEXT", (.timestamp // ""), (($t | length) | tostring), ($t | clean | .[0:80])]
        else
          ([$mc[]? | select(.type == "tool_result") | (.content | tostring)] | join(" ")) as $r
          | if ($r | length) > 0
            then ["UTRES", (.timestamp // ""), (($r | length) | tostring), ($r | clean | .[0:80])]
            else empty end
        end
    else empty end
  end

elif .type == "assistant" then
  (.timestamp // "") as $ts
  | ((.message.content // []) | if type == "array" then .[]? else empty end)
  | if .type == "text" then
      ((.text // "")) as $t
      | ["ATEXT", $ts, (($t | length) | tostring),
         (($t | split("\n") | map(select(test("[^ \t]"))) | length) | tostring)]
    elif .type == "thinking" then ["ATHINK", $ts, "", ""]
    elif .type == "tool_use" then ["ATOOL", $ts, (.name // "?"), ""]
    else empty end

else empty end
| @tsv
'

: > "$BLOCKS"
: > "$JQERRLOG"
JQ_BAD_FILES=0
while IFS= read -r f; do
  slug=$(basename "$(dirname "$f")")
  sid=$(basename "$f" .jsonl)
  printf 'FILE\t%s\t%s\t\n' "$slug" "$sid" >> "$BLOCKS"
  jq -r "$JQ_BLOCKS" "$f" 2>"$JQERR" >> "$BLOCKS"
  jq_rc=$?
  # A parse failure loses events silently unless it is counted. Report it.
  if [ "$jq_rc" -ne 0 ] || [ -s "$JQERR" ]; then
    JQ_BAD_FILES=$((JQ_BAD_FILES + 1))
    printf '%s (jq exit %s): %s\n' "$f" "$jq_rc" "$(head -1 "$JQERR")" >> "$JQERRLOG"
  fi
done < "$FILELIST"

# ---------------------------------------------------------------------------
# 3. Span state machine -> one record per SP opening
#
# Read twice. Pass 1 counts the events in each transcript so pass 2 can record
# how far a transcript runs on past each opening — the tie-break that decides
# which copy of a forked opening event survives deduplication.
# ---------------------------------------------------------------------------

awk -F'\t' -v OFS='\t' \
    -v MINC="$SUBSTANTIVE_MIN_CHARS" -v MINL="$SUBSTANTIVE_MIN_LINES" \
    -v SPSLUG="$SP_DEV_SLUG" -v HARNESS="$SP_HARNESS_RE" '
# --- civil date -> epoch seconds (BSD awk has no mktime) -------------------
function dfc(y, m, d,   era, yoe, doy, doe) {
  if (m <= 2) y = y - 1
  era = int((y >= 0 ? y : y - 399) / 400)
  yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
  doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return era * 146097 + doe - 719468
}
function ts2ep(s,   y, mo, d, h, mi, se, fr) {
  if (s == "" || length(s) < 19) return -1
  y  = substr(s,  1, 4) + 0; mo = substr(s,  6, 2) + 0; d  = substr(s,  9, 2) + 0
  h  = substr(s, 12, 2) + 0; mi = substr(s, 15, 2) + 0; se = substr(s, 18, 2) + 0
  fr = 0
  if (substr(s, 20, 1) == ".") fr = substr(s, 21, 3) / 1000
  return dfc(y, mo, d) * 86400 + h * 3600 + mi * 60 + se + fr
}
# Read " key=value" out of the SP-FLOOR-COMPLETE line.
function fld(line, key,   re, p, v) {
  re = " " key "="
  p = index(line, re)
  if (p == 0) return "-"
  v = substr(line, p + length(re))
  sub(/[ \t].*$/, "", v)
  sub(/\.$/, "", v)                 # strip the period before ". Full results:"
  return (v == "") ? "-" : v
}
# An opening is the main SP command or the :status recenter briefing.
# Deliberately excluded: copy-prompt, handoff, serena, help, backlog, update,
# switch-to-skill, try-plugin, codex-feedback — mid-session subcommands, not
# session openings.
function is_open(n) {
  return (n ~ /^\/(strategic-partner|advisor|sp)$/) ||
         (n ~ /:(strategic-partner|advisor|sp)$/) ||
         (n ~ /^\/(strategic-partner|advisor|sp)(-[a-z0-9-]+)?:status$/)
}
function form_of(n)    { return (n ~ /:status$/) ? "status" : "main" }
function install_of(n) { return (n ~ /^\/(strategic-partner|advisor|sp)(:|$)/) ? "skill" : "plugin" }
# A menu hands control back to the user exactly as a briefing does.
function is_menu(t)    { return (t == "AskUserQuestion" || t == "ExitPlanMode") }
# Sub-agent dispatch. Claude Code names this tool "Agent" in the transcripts in
# this corpus and "Task" in other versions, so both are recognised. Matched on
# exact equality: TaskCreate and TaskUpdate are todo-list tools, not sub-agent
# dispatch, and a prefix match would silently fold them in.
function is_subagent(t) { return (t == "Agent" || t == "Task") }

function emit(   reasons, green, empt, repo, rt, s_any, s_txt, s_sub, s_brf) {
  if (!open_active) return
  if (after_state == "pending") after_state = "none"

  # "Green" = none of the SEVEN actionable floor fields is at a non-clean value.
  # The field list and the non-clean values are taken verbatim from the table in
  # SKILL.md section Floor-Signal Handling. Values outside those enums
  # (version=ahead, version=unreachable, git=missing) are not actionable per that
  # table and so do not break green; git=missing is captured by the empty-folder
  # category instead.
  reasons = ""; green = "nofloor"; empt = "unknown"
  if (floor_line != "") {
    if (fld(floor_line, "conventions") == "missing") reasons = reasons "conventions,"
    if (fld(floor_line, "memory")      == "missing") reasons = reasons "memory,"
    if (fld(floor_line, "git")         == "dirty")   reasons = reasons "git,"
    if (fld(floor_line, "version")     == "behind")  reasons = reasons "version,"
    rt = fld(floor_line, "routing")
    if (rt == "missing" || rt == "stale")            reasons = reasons "routing,"
    if ((fld(floor_line, "oldschema") + 0) > 0)      reasons = reasons "oldschema,"
    if (fld(floor_line, "commands_registered") == "no") reasons = reasons "commands_registered,"
    sub(/,$/, "", reasons)
    green = (reasons == "") ? "green" : "nonclean"
    empt  = (fld(floor_line, "git") == "missing" && fld(floor_line, "conventions") == "missing") ? "yes" : "no"
  }
  if (reasons == "") reasons = "-"

  repo = "other"
  if (slug == SPSLUG)      repo = "sp-dev"
  else if (slug ~ HARNESS) repo = "sp-harness"

  s_any = (t_first_block > 0 && t0 > 0) ? t_first_block - t0 : -1
  s_txt = (t_first_text  > 0 && t0 > 0) ? t_first_text  - t0 : -1
  s_sub = (t_sub         > 0 && t0 > 0) ? t_sub         - t0 : -1
  s_brf = (t_brief       > 0 && t0 > 0) ? t_brief       - t0 : -1

  print slug, sid, substr(open_ts, 1, 10), form_of(open_cmd), install_of(open_cmd), \
        (open_args ~ /\.handoffs\// ? "continuation" : "fresh"), repo, green, reasons, empt, \
        (found_sub ? tools_sub : -1), (t_first_text > 0 ? tools_any : -1), \
        sprintf("%.3f", s_any), sprintf("%.3f", s_txt), sprintf("%.3f", s_sub), \
        sub_chars, sub_lines, (signal_seen ? "yes" : "no"), signal_chars, \
        (found_sub ? "ok" : "no-opening"), after_state, open_cmd, \
        ordinal, entry_kind, floor_source, end_reason, \
        sprintf("%.3f", (t_after > 0 && t_sub > 0) ? t_after - t_sub : -1), \
        open_uuid, (nev[fidx] - open_idx), ++seq, \
        (found_sub ? tasks_sub : -1), (found_sub ? tools_sub - tasks_sub : -1), \
        sprintf("%.3f", s_brf), \
        (found_brief ? tools_brief : -1), \
        (found_brief ? brief_chars : -1), (found_brief ? brief_lines : -1)
  open_active = 0
}

# Pass 1: how many events does each transcript hold?
NR == FNR {
  if ($1 == "FILE") nfile++; else nev[nfile]++
  next
}

# Pass 2. Event position within the transcript, used to measure how far the
# transcript runs on past an opening.
{ if ($1 != "FILE") ev++ }

$1 == "FILE" {
  if (open_active) emit()
  slug = $2; sid = $3; fidx++; ev = 0
  open_active = 0; ordinal = 0; user_events = 0; floor_line = ""; prev_floor = ""
  next
}

# Track the most recent floor line, in-span or not. The floor hook stays silent
# once it has run for a scope, so the line captured during a first opening is
# still the live classification for a second opening in the same session. Not
# carrying it forward drops that second opening into the unclassified bucket.
$1 == "FLOOR" {
  if (open_active && floor_source != "in-span") { floor_line = $3; floor_source = "in-span" }
  prev_floor = $3
  next
}

$1 == "UCMD" {
  if (open_active) {
    if (after_state == "pending" || after_state == "none") {
      after_state = ($3 == "/exit") ? "exit" : "next-prompt"; t_after = ts2ep($2)
    }
    emit()
  }
  user_events++
  if (is_open($3)) {
    open_active = 1; ordinal++
    open_ts = $2; open_cmd = $3; open_args = $4; open_uuid = $5; open_idx = ev
    entry_kind = (user_events == 1) ? "session-start" : "mid-session"
    t0 = ts2ep($2)
    tools = 0; tasks = 0; tools_any = -1; tools_sub = -1; tasks_sub = -1
    tools_all = 0
    t_first_block = -1; t_first_text = -1; t_sub = -1
    found_sub = 0; signal_seen = 0; signal_chars = 0
    sub_chars = 0; sub_lines = 0
    found_brief = 0; brief_closed = 0; t_brief = -1; tools_brief = -1
    brief_chars = -1; brief_lines = -1
    after_state = "none"; end_reason = "-"; t_after = -1
    floor_line = prev_floor
    floor_source = (prev_floor == "") ? "none" : "prior"
  }
  next
}

$1 == "UTEXT" {
  if (open_active) {
    if (after_state == "pending" || after_state == "none") {
      after_state = ($4 ~ /\[Request interrupted/) ? "interrupt" : \
                    (($4 ~ /^\/exit/) ? "exit" : "next-prompt")
      t_after = ts2ep($2)
    }
    emit()
  }
  user_events++
  next
}

# The answer to an opening menu is a tool result, not a typed prompt. Without
# this, a user who engaged with the menu would be miscounted as "no further
# input" — i.e. as an abandonment.
$1 == "UTRES" {
  if (open_active && found_sub && end_reason == "menu" && after_state == "pending") {
    after_state = ($4 ~ /\[Request interrupted|interrupted by user/) ? "interrupt" : "menu-answered"
    t_after = ts2ep($2)
    # The user has now acted. Anything the model writes next answers the menu;
    # it is no longer a candidate for the opening briefing.
    brief_closed = 1
  }
  next
}

$1 == "ATHINK" {
  if (open_active && t_first_block < 0) t_first_block = ts2ep($2)
  next
}

$1 == "ATOOL" {
  if (!open_active) next
  if (t_first_block < 0) t_first_block = ts2ep($2)
  if (!is_menu($3)) {
    # tools_all keeps running past the control endpoint, because the briefing
    # can land later than the menu that returned control.
    tools_all++
    if (!found_sub) { tools++; if (is_subagent($3)) tasks++ }
  } else if (!found_sub) {
    # The menu IS the returned control, so it is not part of the silent run.
    t_sub = ts2ep($2); tools_sub = tools; tasks_sub = tasks; found_sub = 1
    sub_chars = 0; sub_lines = 0; end_reason = "menu"; after_state = "pending"
  }
  next
}

$1 == "ATEXT" {
  if (!open_active) next
  if (t_first_block < 0) t_first_block = ts2ep($2)
  if (t_first_text < 0 && ($3 + 0) > 0) { t_first_text = ts2ep($2); tools_any = tools }
  # The briefing endpoint. Only substantive text ends it — a menu never does.
  if (!found_brief && !brief_closed &&
      (($4 + 0) >= MINL || (($4 + 0) >= 2 && ($3 + 0) >= MINC))) {
    t_brief = ts2ep($2); tools_brief = tools_all
    brief_chars = $3 + 0; brief_lines = $4 + 0; found_brief = 1
  }
  if (!found_sub) {
    if (($4 + 0) >= MINL || (($4 + 0) >= 2 && ($3 + 0) >= MINC)) {
      t_sub = ts2ep($2); tools_sub = tools; tasks_sub = tasks; found_sub = 1
      sub_chars = $3 + 0; sub_lines = $4 + 0
      end_reason = "text"; after_state = "pending"
    } else if (($3 + 0) > 0) {
      signal_seen = 1
      if (signal_chars == 0) signal_chars = $3 + 0
    }
  }
  next
}

END { if (open_active) emit() }
' "$BLOCKS" "$BLOCKS" > "$RAW"

RAW_OPENINGS=$(wc -l < "$RAW" | tr -d ' ')
if [ "$RAW_OPENINGS" -eq 0 ]; then
  printf 'startup-latency-probe: FATAL — scanned %s transcripts and found zero SP openings.\n' "$TOTAL_FILES" >&2
  printf 'Either the corpus holds no SP sessions or extraction broke. Not reporting zeros as a result.\n' >&2
  exit 4
fi

# ---------------------------------------------------------------------------
# 3b. Deduplicate by the opening's user-event UUID
#
# A forked transcript replays the same opening event — same command timestamp,
# same UUID — into a second file. Those are one wait, not two. Keep the copy
# whose transcript runs furthest past the opening (column 29): the fork that
# stops right after it is a truncated replay, and scoring it as "user never
# responded" is an artefact of the fork, not an observation.
# ---------------------------------------------------------------------------

LC_ALL=C sort -t"$(printf '\t')" -k28,28 -k29,29nr -k2,2 "$RAW" \
  | awk -F'\t' '$28 == "" || !seen[$28]++' \
  | LC_ALL=C sort -t"$(printf '\t')" -k30,30n > "$DEDUPED"

DEDUP_KEPT=$(wc -l < "$DEDUPED" | tr -d ' ')
DEDUP_REMOVED=$((RAW_OPENINGS - DEDUP_KEPT))

# ---------------------------------------------------------------------------
# 3c. Cohort boundary — --since and --exclude-manifest
#
# Without this an after-run rescans the whole growing corpus and dilutes the
# post-change result with the baseline openings.
# ---------------------------------------------------------------------------

cp "$DEDUPED" "$RECORDS"

EXCLUDED_SINCE=0
if [ -n "$SINCE" ]; then
  awk -F'\t' -v S="$SINCE" '($3 "") >= (S "")' "$RECORDS" > "$WORK/since.tsv"
  EXCLUDED_SINCE=$(( $(wc -l < "$RECORDS" | tr -d ' ') - $(wc -l < "$WORK/since.tsv" | tr -d ' ') ))
  mv "$WORK/since.tsv" "$RECORDS"
fi

EXCLUDED_MANIFEST=0
if [ -n "$EXCLUDE_MANIFEST" ]; then
  awk -F'\t' -v EXF="$EXCLUDE_MANIFEST" '
    BEGIN {
      while ((getline line < EXF) > 0) {
        if (line == "") continue
        n = split(line, a, "\t")
        if (n >= 4 && a[4] != "") ex["U" SUBSEP a[4]] = 1
        if (n >= 3) ex["S" SUBSEP a[1] SUBSEP a[2] SUBSEP a[3]] = 1
      }
    }
    { if (("U" SUBSEP $28) in ex) next
      if (("S" SUBSEP $1 SUBSEP $2 SUBSEP $3) in ex) next
      print }
  ' "$RECORDS" > "$WORK/excl.tsv"
  EXCLUDED_MANIFEST=$(( $(wc -l < "$RECORDS" | tr -d ' ') - $(wc -l < "$WORK/excl.tsv" | tr -d ' ') ))
  mv "$WORK/excl.tsv" "$RECORDS"
fi

# ---------------------------------------------------------------------------
# 4. Reporting
#
# records.tsv columns (1-based):
#   1 slug   2 session   3 date   4 form   5 install   6 routing   7 repo
#   8 floor  9 nonclean_reasons  10 emptyfolder  11 tools_before_opening
#  12 tools_before_first_text  13 secs_to_first_output  14 secs_to_first_text
#  15 secs_to_control  16 opening_chars  17 opening_lines  18 signal
#  19 signal_chars  20 outcome  21 after  22 command  23 ordinal  24 entry
#  25 floor_source  26 end_reason  27 secs_from_opening_to_that_action
#  28 opening_uuid  29 transcript_events_after_opening  30 corpus_seq
#  31 task_calls  32 tools_excluding_task  33 secs_to_briefing
#  34 tools_before_briefing  35 briefing_chars  36 briefing_lines
#
# Column 15 is time_to_first_actionable_control (a menu ends it); column 33 is
# time_to_briefing (only substantive text ends it, -1 = ABSENT).
# ---------------------------------------------------------------------------

statline() {   # $1=column  $2=awk filter  $3=printf fmt
  awk -F'\t' -v col="$1" "$2 { v = \$col + 0; if (v >= 0) print v }" "$RECORDS" \
  | LC_ALL=C sort -n \
  | awk -v fmt="$3" '
      function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
      { v[NR] = $1 }
      END {
        if (NR == 0) { printf "%5s %8s %8s %8s %8s\n", "0", "-", "-", "-", "-"; exit }
        printf "%5d " fmt " " fmt " " fmt " " fmt "\n", NR, v[1], v[rank(50, NR)], v[rank(90, NR)], v[NR]
      }'
}

count() { awk -F'\t' "$1 { c++ } END { print c + 0 }" "$RECORDS"; }

trow() { printf '%-36s %s' "$1" "$(statline 11 "$2" '%8d')"; }
srow() { printf '%-36s %s' "$1" "$(statline "$3" "$2" '%8.1f')"; }

# Paired per-opening difference between two columns. Subtracting one column's
# median from another's is not a gap any user experienced; this is.
gaprow() {   # $1=label  $2=awk filter  $3=later column  $4=earlier column
  awk -F'\t' -v a="$3" -v b="$4" "$2 { if (\$a + 0 >= 0 && \$b + 0 >= 0) print \$a - \$b }" "$RECORDS" \
  | LC_ALL=C sort -n \
  | awk -v lbl="$1" '
      function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
      { v[NR] = $1 }
      END {
        if (NR == 0) { printf "%-36s %5s %8s %8s %8s %8s\n", lbl, "0", "-", "-", "-", "-"; exit }
        printf "%-36s %5d %8.1f %8.1f %8.1f %8.1f\n", lbl, NR, v[1], v[rank(50,NR)], v[rank(90,NR)], v[NR]
      }'
}

hr() { printf -- '-------------------------------------------------------------------------------\n'; }

TOTAL_OPENINGS=$(wc -l < "$RECORDS" | tr -d ' ')
if [ "$TOTAL_OPENINGS" -eq 0 ]; then
  # Not a broken run: the corpus yielded openings, the cohort boundary removed
  # them all. That is the expected result of excluding a cohort from itself.
  echo
  echo "STRATEGIC PARTNER — SESSION-OPENING LATENCY PROBE"
  hr
  printf 'corpus root         : %s\n' "$CORPUS_ROOT"
  printf 'transcripts scanned : %s\n' "$TOTAL_FILES"
  printf 'openings found      : %s raw, %s after UUID deduplication\n' "$RAW_OPENINGS" "$DEDUP_KEPT"
  printf 'cohort is EMPTY     : every opening was excluded by the cohort boundary\n'
  hr
  printf 'excluded by --since %s          : %s\n' "${SINCE:-(unset)}" "$EXCLUDED_SINCE"
  printf 'excluded by --exclude-manifest  : %s\n' "$EXCLUDED_MANIFEST"
  hr
  printf 'SP-STARTUP-COHORT-EMPTY corpus_files=%s raw_openings=%s deduped=%s excluded_since=%s excluded_manifest=%s remaining=0\n' \
    "$TOTAL_FILES" "$RAW_OPENINGS" "$DEDUP_KEPT" "$EXCLUDED_SINCE" "$EXCLUDED_MANIFEST"
  if [ -n "$RECORDS_OUT" ];  then cp "$RECORDS" "$RECORDS_OUT"; fi
  if [ -n "$MANIFEST_OUT" ]; then : > "$MANIFEST_OUT"; fi
  exit 0
fi
DATE_MIN=$(cut -f3 "$RECORDS" | LC_ALL=C sort | head -1)
DATE_MAX=$(cut -f3 "$RECORDS" | LC_ALL=C sort | tail -1)
SESSIONS=$(cut -f2 "$RECORDS" | LC_ALL=C sort -u | wc -l | tr -d ' ')

echo
echo "STRATEGIC PARTNER — SESSION-OPENING LATENCY PROBE"
hr
printf 'corpus root         : %s\n' "$CORPUS_ROOT"
printf 'transcripts scanned : %s (sub-agent transcripts excluded)\n' "$TOTAL_FILES"
printf 'raw opening events  : %s\n' "$RAW_OPENINGS"
printf 'duplicate forks     : %s removed by opening-UUID deduplication\n' "$DEDUP_REMOVED"
if [ -n "$SINCE" ] || [ -n "$EXCLUDE_MANIFEST" ]; then
printf 'cohort boundary     : --since %s removed %s, --exclude-manifest removed %s\n' \
  "${SINCE:-(unset)}" "$EXCLUDED_SINCE" "$EXCLUDED_MANIFEST"
fi
printf 'SP openings measured: %s across %s distinct session histories\n' "$TOTAL_OPENINGS" "$SESSIONS"
printf 'opening date range  : %s .. %s\n' "$DATE_MIN" "$DATE_MAX"
printf 'control returns at  : menu (AskUserQuestion/ExitPlanMode) OR text with\n'
printf '                      >= %s non-blank lines, OR >= 2 lines and >= %s chars\n' "$SUBSTANTIVE_MIN_LINES" "$SUBSTANTIVE_MIN_CHARS"
printf 'briefing ends at    : that text rule ONLY — a menu is never a briefing\n'
printf 'percentile method   : nearest-rank (ceil), deterministic. At n=2 the p50\n'
printf '                      IS the minimum; read small-n cells as raw pairs.\n'
printf 'transcripts unparsed: %s (jq errors)\n' "$JQ_BAD_FILES"
hr

echo
echo "A. SILENT TOOL CALLS BEFORE THE OPENING ARRIVES   (headline metric)"
printf '%-36s %5s %8s %8s %8s %8s\n' "category" "n" "min" "median" "p90" "max"
hr
trow "ALL openings"                       '1'; echo
trow "  main command"                     '$4=="main"'; echo
trow "  :status recenter"                 '$4=="status"'; echo
trow "  first opening in the session"     '$23==1'; echo
trow "  opening was the 1st user prompt"  '$24=="session-start"'; echo
hr
trow "NON-SP PROJECTS (user-facing)"      '$7=="other"'; echo
trow "  main command"                     '$7=="other" && $4=="main"'; echo
trow "  :status recenter"                 '$7=="other" && $4=="status"'; echo
trow "  green floor, fresh"               '$7=="other" && $8=="green" && $6=="fresh"'; echo
trow "  green floor, fresh, main cmd"     '$7=="other" && $8=="green" && $6=="fresh" && $4=="main"'; echo
trow "  green floor, fresh, :status"      '$7=="other" && $8=="green" && $6=="fresh" && $4=="status"'; echo
trow "  NON-CLEAN floor, fresh"           '$7=="other" && $8=="nonclean" && $6=="fresh"'; echo
trow "  continuation (.handoffs arg)"     '$7=="other" && $6=="continuation"'; echo
trow "  empty folder / no git repo"       '$7=="other" && $10=="yes"'; echo
trow "  standalone skill install"         '$7=="other" && $5=="skill"'; echo
trow "  plugin install"                   '$7=="other" && $5=="plugin"'; echo
hr
trow "SP DEV REPO (reported separately)"  '$7=="sp-dev"'; echo
trow "  green floor, fresh"               '$7=="sp-dev" && $8=="green" && $6=="fresh"'; echo
trow "  NON-CLEAN floor"                  '$7=="sp-dev" && $8=="nonclean"'; echo
trow "  continuation (.handoffs arg)"     '$7=="sp-dev" && $6=="continuation"'; echo
hr
trow "SP TEST/SMOKE HARNESS (separate)"   '$7=="sp-harness"'; echo
trow "UNCLASSIFIED FLOOR (no floor line)" '$8=="nofloor"'; echo
hr

echo
echo "A2. SUB-AGENT (Agent / Task) CALLS INSIDE THAT COUNT"
echo "    One sub-agent call counts as one tool call however much work it hides,"
echo "    so the total alone can be met by moving work into sub-agents rather"
echo "    than removing it. Both the sub-agent count and the total minus"
echo "    sub-agents are reported so that cannot happen unnoticed."
printf '%-36s %5s %8s %8s %8s %8s\n' "metric" "n" "min" "median" "p90" "max"
hr
printf '%-36s %s' "tool calls TOTAL (non-SP)"         "$(statline 11 '$7=="other"' '%8d')"; echo
printf '%-36s %s' "  of which sub-agent (non-SP)"     "$(statline 31 '$7=="other"' '%8d')"; echo
printf '%-36s %s' "  total EXCL. sub-agent (non-SP)"  "$(statline 32 '$7=="other"' '%8d')"; echo
printf '%-36s %s' "tool calls TOTAL (all)"            "$(statline 11 '1' '%8d')"; echo
printf '%-36s %s' "  of which sub-agent (all)"        "$(statline 31 '1' '%8d')"; echo
printf '%-36s %s' "  total EXCL. sub-agent (all)"     "$(statline 32 '1' '%8d')"; echo
hr
printf '%-52s %5s\n' "openings that dispatched at least one sub-agent" "$(count '$31+0 > 0')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects"               "$(count '$31+0 > 0 && $7=="other"')"
hr

echo
echo "B. WALL-CLOCK SECONDS UNTIL CONTROL RETURNS"
printf '%-36s %5s %8s %8s %8s %8s\n' "category" "n" "min" "median" "p90" "max"
hr
srow "ALL openings"                       '1' 15; echo
srow "NON-SP PROJECTS"                    '$7=="other"' 15; echo
srow "  green floor, fresh"               '$7=="other" && $8=="green" && $6=="fresh"' 15; echo
srow "  NON-CLEAN floor, fresh"           '$7=="other" && $8=="nonclean" && $6=="fresh"' 15; echo
srow "  continuation"                     '$7=="other" && $6=="continuation"' 15; echo
srow "  empty folder"                     '$7=="other" && $10=="yes"' 15; echo
srow "  standalone skill"                 '$7=="other" && $5=="skill"' 15; echo
srow "  plugin"                           '$7=="other" && $5=="plugin"' 15; echo
srow "SP DEV REPO"                        '$7=="sp-dev"' 15; echo
srow "SP TEST/SMOKE HARNESS"              '$7=="sp-harness"' 15; echo
hr
echo "   decomposition (all openings):"
srow "  to first output of ANY kind"      '1' 13; echo
srow "  to first VISIBLE TEXT"            '1' 14; echo
srow "  to the OPENING"                   '1' 15; echo
hr

echo
echo "C. SIZE OF THE OPENING MESSAGE (text-terminated openings only)"
printf '%-36s %5s %8s %8s %8s %8s\n' "metric" "n" "min" "median" "p90" "max"
hr
printf '%-36s %s' "characters (all)"          "$(statline 16 '$26=="text"' '%8d')"; echo
printf '%-36s %s' "non-blank lines (all)"     "$(statline 17 '$26=="text"' '%8d')"; echo
printf '%-36s %s' "characters (non-SP)"       "$(statline 16 '$26=="text" && $7=="other"' '%8d')"; echo
printf '%-36s %s' "non-blank lines (non-SP)"  "$(statline 17 '$26=="text" && $7=="other"' '%8d')"; echo
hr
printf '%-52s %5s\n' "openings that ended in a briefing (text)" "$(count '$26=="text"')"
printf '%-52s %5s\n' "openings that ended in a menu (AskUserQuestion)" "$(count '$26=="menu"')"
printf '%-52s %5s\n' "openings that never arrived" "$(count '$26=="-"')"
hr

echo
echo "C2. CONTROL RETURNED vs USER ACTUALLY BRIEFED"
echo "    A menu returns control without telling the user anything. Splitting"
echo "    the two endpoints is what makes render-before-ask measurable."
hr
printf '%-52s %5s\n' "openings where the briefing WAS the endpoint"  "$(count '$26=="text"')"
printf '%-52s %5s\n' "BRIEFING ABSENT — control returned, nothing said" "$(count '$20=="ok" && $33+0 < 0')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects"             "$(count '$20=="ok" && $33+0 < 0 && $7=="other"')"
printf '%-52s %5s\n' "  ...of those, ended at a menu"                "$(count '$26=="menu" && $33+0 < 0')"
printf '%-52s %5s\n' "briefing landed AFTER control returned"        "$(count '$26=="menu" && $33+0 >= 0')"
hr
printf '%-36s %5s %8s %8s %8s %8s\n' "seconds from the command" "n" "min" "median" "p90" "max"
hr
srow "control returned (all)"              '1' 15; echo
srow "briefing rendered (all)"             '1' 33; echo
srow "control returned (non-SP)"           '$7=="other"' 15; echo
srow "briefing rendered (non-SP)"          '$7=="other"' 33; echo
hr
echo "   paired per-opening gaps (NOT a subtraction of two medians):"
printf '%-36s %5s %8s %8s %8s %8s\n' "gap" "n" "min" "median" "p90" "max"
hr
gaprow "first text -> briefing (all)"      '1' 33 14
gaprow "first text -> briefing (non-SP)"   '$7=="other"' 33 14
gaprow "first text -> control (all)"       '1' 15 14
gaprow "first text -> control (non-SP)"    '$7=="other"' 15 14
hr

echo
echo "D. SIGNAL LINE BEFORE THE SILENT RUN"
hr
printf '%-52s %5s\n' "openings WITH a preceding short signal line" "$(count '$18=="yes"')"
printf '%-52s %5s\n' "openings with NO text at all before the opening" "$(count '$18=="no"')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects" "$(count '$18=="no" && $7=="other"')"
printf '%-52s %s\n'  "tool calls before ANY visible text (n/min/med/p90/max)" "$(statline 12 '1' '%6d')"
printf '%-52s %s\n'  "  ...in non-SP projects" "$(statline 12 '$7=="other"' '%6d')"
hr

echo
echo "E. WHAT THE USER DID AFTER THE OPENING"
hr
echo "   first user action after the opening (whenever it came):"
printf '%-52s %5s\n' "answered the opening menu"              "$(count '$21=="menu-answered"')"
printf '%-52s %5s\n' "continued (typed another prompt)"       "$(count '$21=="next-prompt"')"
printf '%-52s %5s\n' "interrupted (ESC)"                      "$(count '$21=="interrupt"')"
printf '%-52s %5s\n' "/exit"                                  "$(count '$21=="exit"')"
printf '%-52s %5s\n' "no further input at all"                "$(count '$21=="none"')"
printf '%-52s %5s\n' "ABANDONED = interrupt + exit + none"    "$(count '$21=="interrupt" || $21=="exit" || $21=="none"')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects"      "$(count '($21=="interrupt" || $21=="exit" || $21=="none") && $7=="other"')"
hr
echo "   how long AFTER the opening that action came (seconds):"
printf '%-36s %s' "  interrupt"      "$(statline 27 '$21=="interrupt"' '%8.1f')"; echo
printf '%-36s %s' "  /exit"          "$(statline 27 '$21=="exit"' '%8.1f')"; echo
printf '%-36s %s' "  next prompt"    "$(statline 27 '$21=="next-prompt"' '%8.1f')"; echo
printf '%-36s %s' "  menu answered"  "$(statline 27 '$21=="menu-answered"' '%8.1f')"; echo
hr
echo "   the strong signal — abandoned AT the opening, not hours later:"
printf '%-52s %5s\n' "interrupted BEFORE the opening ever arrived" "$(count '$20!="ok" && $21=="interrupt"')"
printf '%-52s %5s\n' "quit (ESC or /exit) within 60s of the opening" "$(count '$20=="ok" && ($21=="interrupt"||$21=="exit") && $27+0 >= 0 && $27+0 <= 60')"
printf '%-52s %5s\n' "opening arrived, user never responded"       "$(count '$20=="ok" && $21=="none"')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects"           "$(count '$20=="ok" && $21=="none" && $7=="other"')"
printf '%-52s %5s\n' "opening never arrived at all"                "$(count '$20!="ok"')"
printf '%-52s %5s\n' "  ...of those, in non-SP projects"           "$(count '$20!="ok" && $7=="other"')"
hr

echo
echo "F. WORST OFFENDERS BY SILENT TOOL COUNT (top 15)"
hr
printf '%5s %7s  %-11s %-6s %-9s %-10s %s\n' "tools" "secs" "repo" "form" "floor" "date" "project / session"
LC_ALL=C sort -t"$(printf '\t')" -k11,11nr -k15,15nr "$RECORDS" | head -15 \
  | awk -F'\t' '{ printf "%5s %7.1f  %-11s %-6s %-9s %-10s %s / %s\n", $11, $15, $7, $4, $8, $3, $1, $2 }'
hr

echo
echo "G. UNCLASSIFIED / EXCLUDED"
hr
printf '%-52s %5s\n' "openings with no floor line (unclassified floor)" "$(count '$8=="nofloor"')"
printf '%-52s %5s\n' "  floor taken from an earlier line in the session" "$(count '$25=="prior"')"
printf '%-52s %5s\n' "openings with unusable timestamps"                "$(count '$15+0 < 0 && $20=="ok"')"
printf '%-52s %5s\n' "openings with no opening (excluded from A/B/C)"   "$(count '$20!="ok"')"
printf '%-52s %5s\n' "duplicate fork copies removed (same opening UUID)" "$DEDUP_REMOVED"
printf '%-52s %5s\n' "transcripts jq could not fully parse"             "$JQ_BAD_FILES"
if [ "$JQ_BAD_FILES" -gt 0 ]; then
  echo "   unparsed transcripts (event loss is possible in these):"
  sed 's/^/     /' "$JQERRLOG"
fi
hr

if [ "$DEDUP_REMOVED" -gt 0 ]; then
  echo
  echo "G2. DUPLICATE OPENING EVENTS REMOVED"
  echo "    Same opening UUID in more than one transcript — one wait, not two."
  hr
  printf '%-38s %-38s %6s %s\n' "opening uuid" "transcript kept / dropped" "events" "kept"
  LC_ALL=C sort -t"$(printf '\t')" -k28,28 -k29,29nr -k2,2 "$RAW" \
    | awk -F'\t' '{ c[$28]++; row[$28 "" NR] = $28 "\t" $2 "\t" $29 "\t" (++o[$28] == 1 ? "KEPT" : "dropped"); ord[NR] = $28 "" NR }
        END { for (i = 1; i <= NR; i++) { k = ord[i]; split(row[k], f, "\t"); if (c[f[1]] > 1) printf "%-38s %-38s %6s %s\n", f[1], f[2], f[3], f[4] } }'
  hr
fi

echo
echo "H. NON-CLEAN FLOOR — WHICH SIGNALS FIRED (non-SP projects)"
hr
awk -F'\t' '$7=="other" && $8=="nonclean" { n = split($9, a, ","); for (i = 1; i <= n; i++) print a[i] }' "$RECORDS" \
  | LC_ALL=C sort | uniq -c | LC_ALL=C sort -rn | awk '{ printf "%-52s %5s\n", $2, $1 }'
hr

# --- machine-comparable summary line ---------------------------------------
#
# The after-run prints the same line over its own cohort; diff them field by
# field. Every field the v8.0 contract is judged on has to be here, or it gets
# argued about from prose instead.

# "n p50 p90 max" for one column under one filter.
pct() {   # $1=column  $2=awk filter  $3=printf fmt
  awk -F'\t' -v col="$1" "$2 { v = \$col + 0; if (v >= 0) print v }" "$RECORDS" \
  | LC_ALL=C sort -n \
  | awk -v fmt="$3" '
      function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
      { v[NR] = $1 }
      END {
        if (NR == 0) { print "0 - - -"; exit }
        printf "%d " fmt " " fmt " " fmt "\n", NR, v[rank(50,NR)], v[rank(90,NR)], v[NR]
      }'
}

# "n p50 p90" for a paired per-opening difference.
gappct() {   # $1=later column  $2=earlier column  $3=awk filter
  awk -F'\t' -v a="$1" -v b="$2" "$3 { if (\$a + 0 >= 0 && \$b + 0 >= 0) print \$a - \$b }" "$RECORDS" \
  | LC_ALL=C sort -n \
  | awk '
      function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
      { v[NR] = $1 }
      END {
        if (NR == 0) { print "0 - -"; exit }
        printf "%d %.1f %.1f\n", NR, v[rank(50,NR)], v[rank(90,NR)]
      }'
}

set -- $(pct 11 '$7=="other" && $8=="green" && $6=="fresh"' '%d')
GF_N=$1; GF_TP50=$2; GF_TP90=$3; GF_TMAX=$4
set -- $(pct 15 '$7=="other" && $8=="green" && $6=="fresh"' '%.1f')
GF_SP50=$2; GF_SP90=$3

set -- $(pct 11 '$7=="other"' '%d')
NS_N=$1; NS_TP50=$2; NS_TP90=$3; NS_TMAX=$4
set -- $(pct 15 '$7=="other"' '%.1f')
NS_SP50=$2; NS_SP90=$3

set -- $(pct 11 '$7=="other" && $4=="main"' '%d')
NSM_N=$1; NSM_TP50=$2; NSM_TP90=$3
set -- $(pct 11 '$7=="other" && $4=="status"' '%d')
NSS_N=$1; NSS_TP50=$2; NSS_TP90=$3

set -- $(pct 31 '$7=="other"' '%d')
NS_TASK_P50=$2; NS_TASK_MAX=$4
set -- $(pct 32 '$7=="other"' '%d')
NS_NOTASK_P50=$2; NS_NOTASK_P90=$3

set -- $(gappct 33 14 '1')
GAP_ALL_N=$1; GAP_ALL_P50=$2; GAP_ALL_P90=$3
set -- $(gappct 33 14 '$7=="other"')
GAP_NS_N=$1; GAP_NS_P50=$2; GAP_NS_P90=$3

BRIEF_ABSENT=$(count '$20=="ok" && $33+0 < 0')
BRIEF_PRESENT=$(count '$33+0 >= 0')
SIGNAL_YES=$(count '$18=="yes"')
TEXT_FIRST=$(count '$12+0 == 0')

awk -F'\t' '{ print $1 "\t" $2 "\t" $3 "\t" $28 }' "$RECORDS" | LC_ALL=C sort -u > "$MANIFEST"
MANIFEST_SHA=$(shasum -a 256 "$MANIFEST" 2>/dev/null | cut -c1-16)
MANIFEST_SHA=${MANIFEST_SHA:--}

echo
printf 'SP-STARTUP-BASELINE openings=%s sessions=%s corpus_files=%s range=%s..%s dedup_removed=%s' \
  "$TOTAL_OPENINGS" "$SESSIONS" "$TOTAL_FILES" "$DATE_MIN" "$DATE_MAX" "$DEDUP_REMOVED"
printf ' green_fresh_nonsp_n=%s tools_p50=%s tools_p90=%s tools_max=%s secs_p50=%s secs_p90=%s' \
  "$GF_N" "$GF_TP50" "$GF_TP90" "$GF_TMAX" "$GF_SP50" "$GF_SP90"
printf ' all_nonsp_n=%s all_nonsp_tools_p50=%s all_nonsp_tools_p90=%s all_nonsp_tools_max=%s all_nonsp_secs_p50=%s all_nonsp_secs_p90=%s' \
  "$NS_N" "$NS_TP50" "$NS_TP90" "$NS_TMAX" "$NS_SP50" "$NS_SP90"
printf ' nonsp_main_n=%s nonsp_main_tools_p50=%s nonsp_main_tools_p90=%s nonsp_status_n=%s nonsp_status_tools_p50=%s nonsp_status_tools_p90=%s' \
  "$NSM_N" "$NSM_TP50" "$NSM_TP90" "$NSS_N" "$NSS_TP50" "$NSS_TP90"
printf ' nonsp_task_calls_p50=%s nonsp_task_calls_max=%s nonsp_tools_extask_p50=%s nonsp_tools_extask_p90=%s' \
  "$NS_TASK_P50" "$NS_TASK_MAX" "$NS_NOTASK_P50" "$NS_NOTASK_P90"
printf ' briefing_present=%s briefing_absent=%s signal_line=%s/%s text_before_any_tool=%s/%s' \
  "$BRIEF_PRESENT" "$BRIEF_ABSENT" "$SIGNAL_YES" "$TOTAL_OPENINGS" "$TEXT_FIRST" "$TOTAL_OPENINGS"
printf ' paired_text_to_brief_n=%s paired_text_to_brief_p50=%s paired_text_to_brief_p90=%s' \
  "$GAP_ALL_N" "$GAP_ALL_P50" "$GAP_ALL_P90"
printf ' paired_text_to_brief_nonsp_n=%s paired_text_to_brief_nonsp_p50=%s paired_text_to_brief_nonsp_p90=%s' \
  "$GAP_NS_N" "$GAP_NS_P50" "$GAP_NS_P90"
printf ' jq_unparsed=%s manifest_sha=%s\n' "$JQ_BAD_FILES" "$MANIFEST_SHA"

if [ -n "$RECORDS_OUT" ];  then cp "$RECORDS" "$RECORDS_OUT"; fi
if [ -n "$MANIFEST_OUT" ]; then cp "$MANIFEST" "$MANIFEST_OUT"; fi

exit 0
