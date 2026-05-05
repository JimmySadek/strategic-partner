#!/usr/bin/env bash
# Shared helpers for release-gate tests.
. "$(dirname "${BASH_SOURCE[0]}")/../unit/_helpers.sh"

# run_gate FIXTURE EXCEPTIONS_FILE_OR_EMPTY
#   Sets up a tmp project, copies the fixture as CLAUDE.md, optionally
#   places .scanner-exceptions.json, runs --release-gate, prints
#   "EXIT=N\n<scan-json>".
run_gate() {
  local fixture="$1"
  local exceptions_file="${2:-}"
  local tmp
  tmp=$(mktemp -d)
  cp "$fixture" "$tmp/CLAUDE.md"
  [ -n "$exceptions_file" ] && cp "$exceptions_file" "$tmp/.scanner-exceptions.json"
  ( cd "$tmp" && bash "$SCAN_SCRIPT" --release-gate 2>&1 )
  local ec=$?
  echo "EXIT=$ec"
  \rm -rf "$tmp"
}

# build_exception RULE_ID SOURCE_FILE SECTION_ANCHOR NORMALIZED_SUBJECT [REASON]
build_exception() {
  local rule_id="$1" source_file="$2" anchor="$3" subject="$4" reason="${5:-test exception}"
  local fp
  fp=$(bash -c "
    . '${PROJECT_ROOT}/.scripts/context-file-scan/lib/utils.sh'
    scanner_fingerprint '$rule_id' '$source_file' '$anchor' '$subject'
  ")
  jq -nc \
    --arg fp "$fp" \
    --arg rid "$rule_id" \
    --arg src "$source_file" \
    --arg anchor "$anchor" \
    --arg subject "$subject" \
    --arg reason "$reason" \
    '{schema_version: "v1", exceptions: [{
      fingerprint: $fp,
      rule_id: $rid,
      source_file: $src,
      section_anchor: $anchor,
      normalized_subject: $subject,
      subject: $subject,
      reason: $reason,
      accepted_at: "2026-05-05"
    }]}'
}
