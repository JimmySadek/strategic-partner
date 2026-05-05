#!/usr/bin/env bash
# .scripts/context-file-scan/lib/exceptions.sh
# Release-gate coverage logic per scanner-design-spec.md § 1.4 + § 7.5.
# Sourceable.
#
# Exit codes (per spec § 1.1):
#   0 — gate passes (no warn+ findings, OR all warn+ findings covered).
#   4 — gate fails (uncovered warn+ findings).
#   5 — exception file is malformed (parse error, missing required fields,
#       fingerprint mismatch, unknown schema_version).
#
# Requires: jq, plus lib/utils.sh sourced.

# Required schema_version for v1 exception files.
_SCANNER_EXCEPTIONS_SCHEMA_VERSION="v1"

# Required fields per spec § 1.4 schema table (excluding optional review_at).
_SCANNER_EXCEPTION_REQUIRED_FIELDS="fingerprint rule_id source_file section_anchor normalized_subject subject reason accepted_at"

# scanner_exceptions_validate FILE
#   Parses + validates FILE. Echoes a one-line error message on stderr and
#   returns 5 on any structural problem. Returns 0 on success. Returns 0
#   (no error) when FILE doesn't exist — the missing-file case is "zero
#   exceptions" per spec § 7.5, not a failure.
scanner_exceptions_validate() {
  local file="$1"
  if [ ! -e "$file" ]; then
    return 0
  fi
  if [ ! -r "$file" ]; then
    echo "scanner: exception file is unreadable: $file" >&2
    return 5
  fi
  if ! jq -e . "$file" >/dev/null 2>&1; then
    echo "scanner: exception file is malformed JSON: $file" >&2
    return 5
  fi

  local schema_version
  schema_version=$(jq -r '.schema_version // ""' "$file")
  if [ "$schema_version" != "$_SCANNER_EXCEPTIONS_SCHEMA_VERSION" ]; then
    echo "scanner: exception file schema_version mismatch — expected '$_SCANNER_EXCEPTIONS_SCHEMA_VERSION', got '$schema_version'" >&2
    return 5
  fi

  if ! jq -e '.exceptions | type == "array"' "$file" >/dev/null 2>&1; then
    echo "scanner: exception file missing 'exceptions' array" >&2
    return 5
  fi

  # Required-field check + fingerprint sanity check, per entry.
  local count
  count=$(jq -r '.exceptions | length' "$file")
  local i=0
  while [ "$i" -lt "$count" ]; do
    local entry
    entry=$(jq -c --argjson i "$i" '.exceptions[$i]' "$file")

    # Required fields.
    local f
    for f in $_SCANNER_EXCEPTION_REQUIRED_FIELDS; do
      if ! echo "$entry" | jq -e --arg f "$f" 'has($f) and (.[$f] | type == "string") and (.[$f] != "")' >/dev/null 2>&1; then
        echo "scanner: exception entry $i missing or empty required field: $f" >&2
        return 5
      fi
    done

    # Fingerprint sanity: recompute and compare.
    local rule_id source_file section_anchor normalized_subject stored_fp expected_fp
    rule_id=$(echo "$entry" | jq -r '.rule_id')
    source_file=$(echo "$entry" | jq -r '.source_file')
    section_anchor=$(echo "$entry" | jq -r '.section_anchor')
    normalized_subject=$(echo "$entry" | jq -r '.normalized_subject')
    stored_fp=$(echo "$entry" | jq -r '.fingerprint')
    expected_fp=$(scanner_fingerprint "$rule_id" "$source_file" "$section_anchor" "$normalized_subject")
    if [ "$stored_fp" != "$expected_fp" ]; then
      echo "scanner: exception entry $i fingerprint mismatch — stored '$stored_fp', recomputed '$expected_fp' from documented fields" >&2
      return 5
    fi

    i=$((i + 1))
  done

  return 0
}

# scanner_exceptions_fingerprints FILE
#   Echoes one fingerprint per line for every exception in FILE.
#   Empty when FILE doesn't exist or contains no exceptions. Caller is
#   expected to have run scanner_exceptions_validate first.
scanner_exceptions_fingerprints() {
  local file="$1"
  [ -e "$file" ] || return 0
  jq -r '.exceptions[].fingerprint' "$file"
}

# scanner_exceptions_coverage FINDINGS_JSON EXCEPTIONS_FILE
#   FINDINGS_JSON is the findings array (single JSON value). Emits a
#   single JSON object on stdout:
#     {
#       "findings_with_status": [
#         { ...finding..., "exception_status": "accepted" | "unaccepted" | "info-not-gated" }
#       ],
#       "unused_exceptions": [ ...exception entries with no matching finding... ],
#       "uncovered_count": N         // number of warn+ findings without coverage
#     }
#   Caller decides exit code from uncovered_count.
scanner_exceptions_coverage() {
  local findings_json="$1"
  local exceptions_file="$2"

  local exceptions_array='[]'
  if [ -e "$exceptions_file" ]; then
    exceptions_array=$(jq -c '.exceptions' "$exceptions_file")
  fi

  echo "$findings_json" | jq -c \
    --argjson excs "$exceptions_array" '
      def gate_severities: ["warn", "surface-loudly"];
      ($excs | map(.fingerprint)) as $fps_in_excs |
      . as $findings |
      ($findings | map(
        .fingerprint as $fp |
        . + {
          exception_status: (
            if (.severity | IN(gate_severities[])) then
              (if ($fps_in_excs | index($fp)) then "accepted" else "unaccepted" end)
            else "info-not-gated" end
          )
        }
      )) as $annotated |
      ($findings | map(.fingerprint)) as $finding_fps |
      ($excs | map(. as $e | select(($finding_fps | index($e.fingerprint)) | not))) as $unused |
      ($annotated | map(select(.exception_status == "unaccepted")) | length) as $uncovered |
      {
        findings_with_status: $annotated,
        unused_exceptions: $unused,
        uncovered_count: $uncovered
      }
    '
}

# scanner_exceptions_release_gate FINDINGS_JSON EXCEPTIONS_FILE
#   End-to-end release-gate decision. Validates the file, computes
#   coverage, prints the coverage object on stdout. Returns:
#     0 — gate passes (no warn+ findings, or all are accepted)
#     4 — gate fails (uncovered warn+ findings)
#     5 — exception file is malformed
scanner_exceptions_release_gate() {
  local findings_json="$1"
  local exceptions_file="$2"

  scanner_exceptions_validate "$exceptions_file" || return 5

  local coverage
  coverage=$(scanner_exceptions_coverage "$findings_json" "$exceptions_file")
  printf '%s\n' "$coverage"

  local uncovered
  uncovered=$(echo "$coverage" | jq -r '.uncovered_count')
  if [ "$uncovered" -eq 0 ]; then
    return 0
  fi
  return 4
}
