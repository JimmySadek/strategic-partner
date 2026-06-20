#!/usr/bin/env bash
# Read-only preflight for proposed context-file snippets or replacements.
# Returns JSON with verdict: allow | reject | needs-extraction.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_SCRIPT="$SCRIPT_DIR/scan.sh"

TARGET="CLAUDE.md"
SNIPPET=""
MODE="append"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -lt 2 ] && { echo "proposal-preflight: --target requires a path" >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
    --snippet)
      [ "$#" -lt 2 ] && { echo "proposal-preflight: --snippet requires a path, or - for stdin" >&2; exit 2; }
      SNIPPET="$2"; shift 2 ;;
    --mode)
      [ "$#" -lt 2 ] && { echo "proposal-preflight: --mode requires append or replacement" >&2; exit 2; }
      MODE="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,12p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *)
      echo "proposal-preflight: unknown argument: $1" >&2
      exit 2 ;;
  esac
done

[ -n "$SNIPPET" ] || { echo "proposal-preflight: pass --snippet <path> or --snippet -" >&2; exit 2; }
[ -r "$SCAN_SCRIPT" ] || { echo "proposal-preflight: scanner not found: $SCAN_SCRIPT" >&2; exit 3; }
case "$MODE" in
  append|replacement) ;;
  *) echo "proposal-preflight: --mode must be append or replacement" >&2; exit 2 ;;
esac

TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

SNIP_FILE="$TMP/snippet.md"
if [ "$SNIPPET" = "-" ]; then
  cat > "$SNIP_FILE"
else
  [ -r "$SNIPPET" ] || { echo "proposal-preflight: snippet not readable: $SNIPPET" >&2; exit 3; }
  cp "$SNIPPET" "$SNIP_FILE"
fi

target_rel=$(basename "$TARGET")
target_kind="root"
case "$TARGET" in
  *.claude/rules/*.md)
    target_rel=".claude/rules/$(basename "$TARGET")"
    target_kind="rules"
    mkdir -p "$TMP/.claude/rules"
    ;;
  *CLAUDE.md|*AGENTS.md|*GEMINI.md)
    target_rel=$(basename "$TARGET")
    target_kind="root"
    ;;
  *)
    target_rel="CLAUDE.md"
    target_kind="root"
    ;;
esac
cp "$SNIP_FILE" "$TMP/$target_rel"

target_lines=0
target_chars=0
if [ -r "$TARGET" ]; then
  target_lines=$(wc -l < "$TARGET" | tr -d ' \t\n')
  target_chars=$(wc -c < "$TARGET" | tr -d ' \t\n')
fi
snippet_lines=$(wc -l < "$SNIP_FILE" | tr -d ' \t\n')
snippet_chars=$(wc -c < "$SNIP_FILE" | tr -d ' \t\n')
projected_lines=$((target_lines + snippet_lines))
projected_chars=$((target_chars + snippet_chars))
if [ "$MODE" = "replacement" ]; then
  projected_lines=$snippet_lines
  projected_chars=$snippet_chars
fi
delta_lines=$((projected_lines - target_lines))
delta_chars=$((projected_chars - target_chars))

scan_json=$(cd "$TMP" && bash "$SCAN_SCRIPT" --file "$target_rel" --report-only --no-suggest-tools 2>/dev/null) || scan_json=""
if [ -z "$scan_json" ]; then
  jq -n \
    --arg verdict "reject" \
    --arg reason "scanner failed on proposed snippet" \
    '{verdict: $verdict, reason: $reason, destination: null}'
  exit 0
fi

s10_count=$(echo "$scan_json" | jq '[.findings[] | select(.rule_id == "S10")] | length')

snippet_lc=$(tr 'A-Z' 'a-z' < "$SNIP_FILE")
has_extraction_pointer=0
if printf '%s' "$snippet_lc" | grep -qE '(\.claude/rules/|references/[a-z0-9_./-]+\.md|claudedocs/[a-z0-9_./-]+\.md|docs/[a-z0-9_./-]+\.md|commands/[a-z0-9_./-]+\.md)'; then
  has_extraction_pointer=1
fi
destination="$target_rel"
reason="snippet looks like a concise project-wide instruction"
verdict="allow"

if [ "$s10_count" -gt 0 ]; then
  verdict="reject"
  destination=".handoffs/"
  reason="snippet looks like a session journey or implementation report, not always-loaded instructions"
elif [ "$target_kind" = "root" ] && [ "$MODE" = "replacement" ] && [ "$target_lines" -ge 50 ] && [ $((projected_lines * 2)) -lt "$target_lines" ] && [ "$has_extraction_pointer" = "0" ]; then
  verdict="reject"
  destination="restore original or extraction-shaped replacement"
  reason="replacement deletes most existing root context without durable pointers"
elif [ "$target_kind" = "root" ] && [ "$MODE" = "append" ] && printf '%s' "$snippet_lc" | grep -qE '(^|[^a-z0-9])([a-z0-9_-]+/)+[a-z0-9_.-]+|\.(tsx|ts|js|jsx|css|py|sh|md)([^a-z0-9]|$)'; then
  verdict="needs-extraction"
  destination=".claude/rules/"
  reason="snippet appears path-scoped or file-specific"
elif [ "$target_kind" = "root" ] && printf '%s' "$snippet_lc" | grep -qE '\b(decided|decision|rationale|we chose|known gotcha|lesson learned|architecture)\b'; then
  verdict="needs-extraction"
  destination="memory or reference docs"
  reason="snippet is decision/gotcha/rationale material, not a root instruction"
elif [ "$target_kind" = "root" ] && [ "$MODE" = "append" ] && { [ "$target_lines" -gt 200 ] || [ "$projected_lines" -gt 200 ] || [ "$projected_chars" -ge 24576 ]; }; then
  verdict="needs-extraction"
  destination="replacement or .claude/rules/"
  reason="target is already over the preferred CLAUDE.md size; prefer replacement or extraction over net append"
elif [ "$target_kind" = "root" ] && [ "$MODE" = "replacement" ] && { [ "$projected_lines" -gt 200 ] || [ "$projected_chars" -ge 24576 ]; } && { [ "$delta_lines" -ge 0 ] || [ "$delta_chars" -ge 0 ]; }; then
  verdict="needs-extraction"
  destination="replacement or extraction"
  reason="replacement keeps or worsens an oversized root context file; shrink it or extract detail"
fi

receipt=$(printf '%s|%s|%s|%s|%s|%s|%s' \
  "$target_rel" "$MODE" "$verdict" "$destination" "$target_lines" "$projected_lines" "$s10_count" \
  | shasum -a 256 2>/dev/null | awk '{print $1}' | cut -c1-16)

jq -n \
  --arg verdict "$verdict" \
  --arg destination "$destination" \
  --arg reason "$reason" \
  --arg mode "$MODE" \
  --arg target_kind "$target_kind" \
  --arg receipt "$receipt" \
  --argjson target_lines "$target_lines" \
  --argjson target_chars "$target_chars" \
  --argjson snippet_lines "$snippet_lines" \
  --argjson snippet_chars "$snippet_chars" \
  --argjson projected_lines "$projected_lines" \
  --argjson projected_chars "$projected_chars" \
  --argjson delta_lines "$delta_lines" \
  --argjson delta_chars "$delta_chars" \
  --argjson s10_count "$s10_count" \
  '{
    verdict: $verdict,
    destination: $destination,
    reason: $reason,
    mode: $mode,
    target_kind: $target_kind,
    receipt: $receipt,
    target: {lines: $target_lines, chars: $target_chars},
    snippet: {lines: $snippet_lines, chars: $snippet_chars},
    projected: {lines: $projected_lines, chars: $projected_chars},
    size_delta: {lines: $delta_lines, chars: $delta_chars},
    scanner: {s10_findings: $s10_count}
  }'
