#!/usr/bin/env bash
# .scripts/context-file-scan/scan.sh
# Orchestrator for /strategic-partner:context-file-scan per
# scanner-design-spec.md § 2.1.
#
# Pipeline:
#   parse args → resolve target → root.sh → file-discovery.sh →
#   layer-probe.sh → rules/structural.sh → rules/behavioral.sh →
#   assemble JSON → if --release-gate: exceptions.sh → exit code.
#
# Usage:
#   scan.sh [--file PATH] [--report-only] [--release-gate]
#           [--no-suggest-tools]
#           [--serena-available true|false]
#           [--context7-available true|false]

set -euo pipefail

# Resolve script dir, source modules
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=lib/utils.sh
. "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/root.sh
. "$SCRIPT_DIR/lib/root.sh"
# shellcheck source=lib/file-discovery.sh
. "$SCRIPT_DIR/lib/file-discovery.sh"
# shellcheck source=lib/layer-probe.sh
. "$SCRIPT_DIR/lib/layer-probe.sh"
# shellcheck source=lib/output.sh
. "$SCRIPT_DIR/lib/output.sh"
# shellcheck source=lib/exceptions.sh
. "$SCRIPT_DIR/lib/exceptions.sh"
# shellcheck source=rules/structural.sh
. "$SCRIPT_DIR/rules/structural.sh"
# shellcheck source=rules/behavioral.sh
. "$SCRIPT_DIR/rules/behavioral.sh"

# ─────────────────────────────────────────────────────────────────────
# jq dependency check
# ─────────────────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "scanner: jq is required but not found in PATH. Install via 'brew install jq' (macOS) or your package manager (Linux)." >&2
  exit 3
fi

# ─────────────────────────────────────────────────────────────────────
# Argument parsing
# ─────────────────────────────────────────────────────────────────────
FILE_ARG=""
REPORT_ONLY=false
RELEASE_GATE=false
NO_SUGGEST_TOOLS=false
SERENA_FLAG=""
CONTEXT7_FLAG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      [ $# -lt 2 ] && { echo "scanner: --file requires a path" >&2; exit 2; }
      FILE_ARG="$2"; shift 2 ;;
    --report-only) REPORT_ONLY=true; shift ;;
    --release-gate) RELEASE_GATE=true; REPORT_ONLY=true; shift ;;
    --no-suggest-tools) NO_SUGGEST_TOOLS=true; shift ;;
    --serena-available)
      [ $# -lt 2 ] && { echo "scanner: --serena-available requires a value" >&2; exit 2; }
      SERENA_FLAG="$2"; shift 2 ;;
    --context7-available)
      [ $# -lt 2 ] && { echo "scanner: --context7-available requires a value" >&2; exit 2; }
      CONTEXT7_FLAG="$2"; shift 2 ;;
    --help|-h)
      sed -n '4,15p' "$0"; exit 0 ;;
    *)
      echo "scanner: unknown argument: $1" >&2; exit 2 ;;
  esac
done

# ─────────────────────────────────────────────────────────────────────
# Resolve target file (auto-detect if --file not given)
# ─────────────────────────────────────────────────────────────────────
PROJECT_ROOT=$(scanner_project_root)
ROOT_NOTE=$(scanner_root_note)

resolve_target() {
  if [ -n "$FILE_ARG" ]; then
    if [ -d "$FILE_ARG" ]; then
      echo "scanner: $FILE_ARG is a directory, not a file. Did you mean ${FILE_ARG}/CLAUDE.md?" >&2
      exit 2
    fi
    if [ ! -e "$FILE_ARG" ]; then
      echo "scanner: $FILE_ARG not found." >&2
      exit 2
    fi
    if [ ! -r "$FILE_ARG" ]; then
      echo "scanner: $FILE_ARG is not readable." >&2
      exit 3
    fi
    printf '%s' "$FILE_ARG"
    return 0
  fi
  for candidate in CLAUDE.md AGENTS.md GEMINI.md; do
    if [ -f "$PROJECT_ROOT/$candidate" ]; then
      printf '%s' "$PROJECT_ROOT/$candidate"
      return 0
    fi
    if [ -f "$candidate" ]; then
      printf '%s' "$(pwd)/$candidate"
      return 0
    fi
  done
  echo "scanner: No context file found in current directory (looked for CLAUDE.md, AGENTS.md, GEMINI.md). Pass --file <path> to specify." >&2
  exit 2
}

PRIMARY_ABS=$(resolve_target)

# ─────────────────────────────────────────────────────────────────────
# Encoding / size sanity
# ─────────────────────────────────────────────────────────────────────
if file -b --mime-encoding "$PRIMARY_ABS" 2>/dev/null | grep -qi 'binary'; then
  echo "scanner: $PRIMARY_ABS appears to be binary; scanner expects UTF-8 markdown." >&2
  exit 3
fi

# ─────────────────────────────────────────────────────────────────────
# Compute relative path for source_file field
# ─────────────────────────────────────────────────────────────────────
PRIMARY_REL="$PRIMARY_ABS"
case "$PRIMARY_ABS" in
  "$PROJECT_ROOT"/*) PRIMARY_REL="${PRIMARY_ABS#"$PROJECT_ROOT"/}" ;;
esac

PRIMARY_CHARS=$(scanner_wc_chars "$PRIMARY_ABS")
PRIMARY_BAND=$(scanner_size_band "$PRIMARY_CHARS")

# ─────────────────────────────────────────────────────────────────────
# Discover companions
# ─────────────────────────────────────────────────────────────────────
COMPANIONS=$(scanner_discover_companions "$PRIMARY_ABS" "$PROJECT_ROOT" || true)

# Build files_tsv: primary + companions, all rows tab-separated
FILES_TSV="${PRIMARY_ABS}	${PRIMARY_REL}"
COMPANION_FILES_JSON='[]'
if [ -n "$COMPANIONS" ]; then
  while IFS= read -r comp_rel; do
    [ -z "$comp_rel" ] && continue
    comp_abs="$PROJECT_ROOT/$comp_rel"
    comp_chars=$(scanner_wc_chars "$comp_abs")
    comp_band=$(scanner_size_band "$comp_chars")
    FILES_TSV="${FILES_TSV}
${comp_abs}	${comp_rel}"
    COMPANION_FILES_JSON=$(echo "$COMPANION_FILES_JSON" | jq \
      --arg path "$comp_rel" \
      --argjson size "$comp_chars" \
      --arg band "$comp_band" \
      '. + [{path: $path, size_chars: $size, size_band: $band, discovered_via: "stub-pointer"}]')
  done <<EOF
$COMPANIONS
EOF
fi

# ─────────────────────────────────────────────────────────────────────
# Layer probe
# ─────────────────────────────────────────────────────────────────────
LAYER_PROBE_JSON=$(scanner_probe_layers "$PROJECT_ROOT" "$SERENA_FLAG" "$CONTEXT7_FLAG")

# ─────────────────────────────────────────────────────────────────────
# Run detection rules → collect findings
# ─────────────────────────────────────────────────────────────────────
ALL_FINDINGS_RAW=""

# Structural rules per file (single-file behavior)
while IFS=$'\t' read -r abs_path rel_path; do
  [ -z "$abs_path" ] && continue
  out=$(scanner_run_structural "$abs_path" "$rel_path" "$PROJECT_ROOT" "$LAYER_PROBE_JSON" "$COMPANIONS" 2>/dev/null || true)
  if [ -n "$out" ]; then
    ALL_FINDINGS_RAW="${ALL_FINDINGS_RAW}${out}
"
  fi
done <<<"$FILES_TSV"

# Behavioral rules: B1-B4 on primary only, B5-B8 cross-file
behav_out=$(scanner_run_behavioral "$PROJECT_ROOT" "$PRIMARY_ABS" "$PRIMARY_REL" "$FILES_TSV" 2>/dev/null || true)
if [ -n "$behav_out" ]; then
  ALL_FINDINGS_RAW="${ALL_FINDINGS_RAW}${behav_out}
"
fi

# Strip blank lines, package as JSON array
FINDINGS_ARRAY=$(printf '%s\n' "$ALL_FINDINGS_RAW" | grep -v '^$' | scanner_findings_array || echo '[]')
SUMMARY_OBJ=$(scanner_summary_object "$FINDINGS_ARRAY")

# ─────────────────────────────────────────────────────────────────────
# Assemble final JSON
# ─────────────────────────────────────────────────────────────────────
SCAN_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
NOTES_ARR='[]'
if [ -n "$ROOT_NOTE" ]; then
  NOTES_ARR=$(echo '[]' | jq --arg n "$ROOT_NOTE" '. + [$n]')
fi

OUTPUT_JSON=$(jq -n \
  --arg scanner_version "v1.0.0" \
  --arg scan_timestamp "$SCAN_TIMESTAMP" \
  --arg project_root "$PROJECT_ROOT" \
  --arg primary_path "$PRIMARY_REL" \
  --argjson primary_size "$PRIMARY_CHARS" \
  --arg primary_band "$PRIMARY_BAND" \
  --argjson companion_files "$COMPANION_FILES_JSON" \
  --argjson layer_probe "$LAYER_PROBE_JSON" \
  --argjson findings "$FINDINGS_ARRAY" \
  --argjson summary "$SUMMARY_OBJ" \
  --argjson notes "$NOTES_ARR" \
  --argjson report_only "$REPORT_ONLY" \
  --argjson no_suggest_tools "$NO_SUGGEST_TOOLS" \
  '{
    scan_metadata: {
      scanner_version: $scanner_version,
      scan_timestamp: $scan_timestamp,
      project_root: $project_root,
      primary_file: {
        path: $primary_path,
        size_chars: $primary_size,
        size_band: $primary_band
      },
      companion_files: $companion_files,
      files_scanned_count: (1 + ($companion_files | length)),
      notes: $notes,
      flags: {
        report_only: $report_only,
        no_suggest_tools: $no_suggest_tools
      }
    },
    layer_probe: $layer_probe,
    findings: $findings,
    summary: $summary
  }')

# ─────────────────────────────────────────────────────────────────────
# Release-gate path: load exceptions, compute coverage, set exit code
# ─────────────────────────────────────────────────────────────────────
if [ "$RELEASE_GATE" = true ]; then
  EXCEPTIONS_FILE="$PROJECT_ROOT/.scanner-exceptions.json"
  COVERAGE=$(scanner_exceptions_release_gate "$FINDINGS_ARRAY" "$EXCEPTIONS_FILE" 2>/dev/null) || gate_exit=$?
  gate_exit=${gate_exit:-0}
  if [ "$gate_exit" = "5" ]; then
    # Validation failed; pass message via stderr
    scanner_exceptions_validate "$EXCEPTIONS_FILE" >&2 || true
    OUTPUT_JSON=$(echo "$OUTPUT_JSON" | jq --argjson coverage "{}" \
      --arg gate_status "error-malformed-exception-file" \
      '. + {release_gate: {status: $gate_status, coverage: $coverage}}')
    echo "$OUTPUT_JSON"
    exit 5
  fi
  OUTPUT_JSON=$(echo "$OUTPUT_JSON" | jq \
    --argjson coverage "$COVERAGE" \
    --arg gate_status "$( [ "$gate_exit" = "0" ] && echo "pass" || echo "fail" )" \
    '. + {release_gate: {status: $gate_status, coverage: $coverage}}')
  echo "$OUTPUT_JSON"
  exit "$gate_exit"
fi

# ─────────────────────────────────────────────────────────────────────
# Default: emit JSON for the agent to render
# ─────────────────────────────────────────────────────────────────────
echo "$OUTPUT_JSON"
exit 0
