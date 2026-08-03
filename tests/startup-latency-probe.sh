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
# The span ends at the first USER-ACTIONABLE output, whichever comes first:
#   (a) an assistant text block that is a structured briefing rather than a
#       one-sentence progress note, or
#   (b) an AskUserQuestion / ExitPlanMode menu — SP's opening menu is an
#       AskUserQuestion, and it hands control back to the user just as a
#       briefing does.
# One-line progress narration ("Starting the session by loading...") does NOT
# end the span; it is recorded separately as a signal line.
#
# Every opening is classified (floor green / non-clean, fresh / continuation,
# plugin / standalone skill, SP's own repo vs other projects, empty folder,
# session-start vs mid-session) and the distribution (n / min / median / p90 /
# max) is printed per category, followed by one machine-comparable summary line
# so an after-measurement can be diffed against this run.
#
# The corpus is READ-ONLY. This script never writes inside it.
#
# Usage:
#   tests/startup-latency-probe.sh [--corpus DIR] [--records FILE] [--manifest FILE]
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

while [ $# -gt 0 ]; do
  case "$1" in
    --corpus)   CORPUS_ROOT=$2; shift 2 ;;
    --records)  RECORDS_OUT=$2; shift 2 ;;
    --manifest) MANIFEST_OUT=$2; shift 2 ;;
    -h|--help)  sed -n '2,44p' "$0"; exit 0 ;;
    *) printf 'startup-latency-probe: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

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

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sp-latency-probe.XXXXXX") || exit 3
trap 'rm -rf "$WORK"' EXIT

BLOCKS="$WORK/blocks.tsv"
RECORDS="$WORK/records.tsv"
FILELIST="$WORK/files.txt"

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
#   UCMD   <ts> <command-name> <args>       a slash command the user typed
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
         ($mc | cap("<command-args>([^<]*)</command-args>") | clean)]
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
while IFS= read -r f; do
  slug=$(basename "$(dirname "$f")")
  sid=$(basename "$f" .jsonl)
  {
    printf 'FILE\t%s\t%s\t\n' "$slug" "$sid"
    jq -r "$JQ_BLOCKS" "$f" 2>/dev/null
  } >> "$BLOCKS"
done < "$FILELIST"

# ---------------------------------------------------------------------------
# 3. Span state machine -> one record per SP opening
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

function emit(   reasons, green, empt, repo, rt, s_any, s_txt, s_sub) {
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

  print slug, sid, substr(open_ts, 1, 10), form_of(open_cmd), install_of(open_cmd), \
        (open_args ~ /\.handoffs\// ? "continuation" : "fresh"), repo, green, reasons, empt, \
        (found_sub ? tools_sub : -1), (t_first_text > 0 ? tools_any : -1), \
        sprintf("%.3f", s_any), sprintf("%.3f", s_txt), sprintf("%.3f", s_sub), \
        sub_chars, sub_lines, (signal_seen ? "yes" : "no"), signal_chars, \
        (found_sub ? "ok" : "no-opening"), after_state, open_cmd, \
        ordinal, entry_kind, floor_source, end_reason, \
        sprintf("%.3f", (t_after > 0 && t_sub > 0) ? t_after - t_sub : -1)
  open_active = 0
}

$1 == "FILE" {
  if (open_active) emit()
  slug = $2; sid = $3
  open_active = 0; ordinal = 0; user_events = 0; floor_line = ""; prev_floor = ""
  next
}

# Track the most recent floor line even outside a span: when the floor hook has
# already run for this scope it stays silent, and the prior line still describes
# the same session and cwd.
$1 == "FLOOR" {
  if (open_active && floor_source != "in-span") { floor_line = $3; floor_source = "in-span" }
  else if (!open_active) prev_floor = $3
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
    open_ts = $2; open_cmd = $3; open_args = $4
    entry_kind = (user_events == 1) ? "session-start" : "mid-session"
    t0 = ts2ep($2)
    tools = 0; tools_any = -1; tools_sub = -1
    t_first_block = -1; t_first_text = -1; t_sub = -1
    found_sub = 0; signal_seen = 0; signal_chars = 0
    sub_chars = 0; sub_lines = 0
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
  if (!found_sub) {
    if (is_menu($3)) {
      # The menu IS the opening deliverable, so it is not part of the silent run.
      t_sub = ts2ep($2); tools_sub = tools; found_sub = 1
      sub_chars = 0; sub_lines = 0; end_reason = "menu"; after_state = "pending"
    } else {
      tools++
    }
  }
  next
}

$1 == "ATEXT" {
  if (!open_active) next
  if (t_first_block < 0) t_first_block = ts2ep($2)
  if (t_first_text < 0 && ($3 + 0) > 0) { t_first_text = ts2ep($2); tools_any = tools }
  if (!found_sub) {
    if (($4 + 0) >= MINL || (($4 + 0) >= 2 && ($3 + 0) >= MINC)) {
      t_sub = ts2ep($2); tools_sub = tools; found_sub = 1
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
' "$BLOCKS" > "$RECORDS"

# ---------------------------------------------------------------------------
# 4. Reporting
#
# records.tsv columns (1-based):
#   1 slug   2 session   3 date   4 form   5 install   6 routing   7 repo
#   8 floor  9 nonclean_reasons  10 emptyfolder  11 tools_before_opening
#  12 tools_before_first_text  13 secs_to_first_output  14 secs_to_first_text
#  15 secs_to_opening  16 opening_chars  17 opening_lines  18 signal
#  19 signal_chars  20 outcome  21 after  22 command  23 ordinal  24 entry
#  25 floor_source  26 end_reason  27 secs_from_opening_to_that_action
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

hr() { printf -- '-------------------------------------------------------------------------------\n'; }

TOTAL_OPENINGS=$(wc -l < "$RECORDS" | tr -d ' ')
if [ "$TOTAL_OPENINGS" -eq 0 ]; then
  printf 'startup-latency-probe: FATAL — scanned %s transcripts and found zero SP openings.\n' "$TOTAL_FILES" >&2
  printf 'Either the corpus holds no SP sessions or extraction broke. Not reporting zeros as a result.\n' >&2
  exit 4
fi
DATE_MIN=$(cut -f3 "$RECORDS" | LC_ALL=C sort | head -1)
DATE_MAX=$(cut -f3 "$RECORDS" | LC_ALL=C sort | tail -1)
SESSIONS=$(cut -f2 "$RECORDS" | LC_ALL=C sort -u | wc -l | tr -d ' ')

echo
echo "STRATEGIC PARTNER — SESSION-OPENING LATENCY PROBE"
hr
printf 'corpus root         : %s\n' "$CORPUS_ROOT"
printf 'transcripts scanned : %s (sub-agent transcripts excluded)\n' "$TOTAL_FILES"
printf 'SP openings measured: %s across %s distinct sessions\n' "$TOTAL_OPENINGS" "$SESSIONS"
printf 'opening date range  : %s .. %s\n' "$DATE_MIN" "$DATE_MAX"
printf 'opening ends at     : menu (AskUserQuestion/ExitPlanMode) OR text with\n'
printf '                      >= %s non-blank lines, OR >= 2 lines and >= %s chars\n' "$SUBSTANTIVE_MIN_LINES" "$SUBSTANTIVE_MIN_CHARS"
printf 'percentile method   : nearest-rank (ceil), deterministic\n'
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
echo "B. WALL-CLOCK SECONDS UNTIL THE OPENING ARRIVES"
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
hr

echo
echo "H. NON-CLEAN FLOOR — WHICH SIGNALS FIRED (non-SP projects)"
hr
awk -F'\t' '$7=="other" && $8=="nonclean" { n = split($9, a, ","); for (i = 1; i <= n; i++) print a[i] }' "$RECORDS" \
  | LC_ALL=C sort | uniq -c | LC_ALL=C sort -rn | awk '{ printf "%-52s %5s\n", $2, $1 }'
hr

# --- machine-comparable summary line ---------------------------------------
SUMMARY=$(awk -F'\t' '
  function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
  $7 == "other" && $8 == "green" && $6 == "fresh" && $20 == "ok" { t[++nt] = $11 + 0; s[nt] = $15 + 0 }
  END {
    n = nt
    if (n == 0) { print "0 - - - - -"; exit }
    for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) {
      if (t[j] < t[i]) { x = t[i]; t[i] = t[j]; t[j] = x }
      if (s[j] < s[i]) { y = s[i]; s[i] = s[j]; s[j] = y }
    }
    printf "%d %d %d %d %.1f %.1f\n", n, t[rank(50,n)], t[rank(90,n)], t[n], s[rank(50,n)], s[rank(90,n)]
  }' "$RECORDS")

ALLNONSP=$(awk -F'\t' '
  function rank(p, n,   i) { i = int((p * n + 99) / 100); if (i < 1) i = 1; if (i > n) i = n; return i }
  $7 == "other" && $20 == "ok" { t[++nt] = $11 + 0; s[nt] = $15 + 0 }
  END {
    n = nt
    if (n == 0) { print "0 - - -"; exit }
    for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) {
      if (t[j] < t[i]) { x = t[i]; t[i] = t[j]; t[j] = x }
      if (s[j] < s[i]) { y = s[i]; s[i] = s[j]; s[j] = y }
    }
    printf "%d %d %d %.1f\n", n, t[rank(50,n)], t[rank(90,n)], s[rank(50,n)]
  }' "$RECORDS")

set -- $SUMMARY $ALLNONSP
echo
printf 'SP-STARTUP-BASELINE openings=%s sessions=%s corpus_files=%s range=%s..%s green_fresh_nonsp_n=%s tools_p50=%s tools_p90=%s tools_max=%s secs_p50=%s secs_p90=%s all_nonsp_n=%s all_nonsp_tools_p50=%s all_nonsp_tools_p90=%s all_nonsp_secs_p50=%s\n' \
  "$TOTAL_OPENINGS" "$SESSIONS" "$TOTAL_FILES" "$DATE_MIN" "$DATE_MAX" \
  "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"

if [ -n "$RECORDS_OUT" ]; then cp "$RECORDS" "$RECORDS_OUT"; fi
if [ -n "$MANIFEST_OUT" ]; then
  awk -F'\t' '{ print $1 "\t" $2 "\t" $3 }' "$RECORDS" | LC_ALL=C sort -u > "$MANIFEST_OUT"
fi

exit 0
