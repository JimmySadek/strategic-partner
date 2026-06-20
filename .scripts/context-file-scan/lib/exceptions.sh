#!/usr/bin/env bash
# .scripts/context-file-scan/lib/exceptions.sh
# Release-gate coverage logic for scanner exceptions.
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
  # Also (Codex finding #12) — warn-and-skip for unknown future
  # rule_ids (forward compat) and warn-but-accept for unknown extra
  # fields (forward compat). Both warnings go to stderr; neither
  # produces exit 5.
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

    # Codex finding #12 — unknown rule_id: warn-and-skip.
    local rule_id_val
    rule_id_val=$(echo "$entry" | jq -r '.rule_id')
    case "$rule_id_val" in
      S[1-8]|B[1-8])
        # Fingerprint sanity: recompute and compare.
        local source_file section_anchor normalized_subject stored_fp expected_fp
        source_file=$(echo "$entry" | jq -r '.source_file')
        section_anchor=$(echo "$entry" | jq -r '.section_anchor')
        normalized_subject=$(echo "$entry" | jq -r '.normalized_subject')
        stored_fp=$(echo "$entry" | jq -r '.fingerprint')
        expected_fp=$(scanner_fingerprint "$rule_id_val" "$source_file" "$section_anchor" "$normalized_subject")
        if [ "$stored_fp" != "$expected_fp" ]; then
          echo "scanner: exception entry $i fingerprint mismatch — stored '$stored_fp', recomputed '$expected_fp' from documented fields" >&2
          return 5
        fi
        ;;
      *)
        echo "scanner: exception entry $i has unknown rule_id '$rule_id_val' — skipping (forward compatibility per spec § 7.5)" >&2
        ;;
    esac

    # Codex finding #12 — unknown extra fields: warn-and-accept.
    local known_keys=" schema_version fingerprint rule_id source_file section_anchor normalized_subject subject reason accepted_at review_at "
    local entry_keys unknown_keys
    entry_keys=$(echo "$entry" | jq -r 'keys[]')
    unknown_keys=""
    while IFS= read -r k; do
      [ -z "$k" ] && continue
      case "$known_keys" in
        *" $k "*) ;;
        *) unknown_keys="${unknown_keys}$k " ;;
      esac
    done <<EOK
$entry_keys
EOK
    if [ -n "$unknown_keys" ]; then
      echo "scanner: exception entry $i has unknown field(s): ${unknown_keys}— accepting (forward compatibility per spec § 7.5)" >&2
    fi

    i=$((i + 1))
  done

  return 0
}

# scanner_exceptions_past_review_findings EXCEPTIONS_FILE SOURCE_FILE
#   Emits one info finding per stdin line for every exception with a
#   review_at date in the past. SOURCE_FILE is the primary file's
#   relative path, used as the source_file field on each emitted
#   finding (the past-review entry isn't tied to a real rule firing,
#   it's a meta-finding about exception housekeeping).
#
#   Codex finding #12 / spec § 7.5: emit "Exception ${rule_id} on
#   ${file} has past review date ${date}; consider re-evaluating."
#   Severity info; does NOT auto-expire the exception.
scanner_exceptions_past_review_findings() {
  local file="$1"
  local source_file="$2"
  [ -e "$file" ] || return 0
  local today
  today=$(date -u +"%Y-%m-%d")
  local count
  count=$(jq -r '.exceptions | length' "$file" 2>/dev/null || echo 0)
  local i=0
  while [ "$i" -lt "$count" ]; do
    local entry review_at rule_id exc_source
    entry=$(jq -c --argjson i "$i" '.exceptions[$i]' "$file")
    review_at=$(echo "$entry" | jq -r '.review_at // ""')
    if [ -n "$review_at" ] && [ "$review_at" \< "$today" ]; then
      rule_id=$(echo "$entry" | jq -r '.rule_id')
      exc_source=$(echo "$entry" | jq -r '.source_file')
      local subs action
      subs=$(jq -nc \
        --arg rid "$rule_id" \
        --arg ef "$exc_source" \
        --arg d "$review_at" \
        --arg msg "Exception $rule_id on $exc_source has past review date $review_at; consider re-evaluating." \
        '{exception_rule_id: $rid, exception_source_file: $ef, review_date: $d, message: $msg}')
      action=$(scanner_action_json acknowledge "" false false "")
      scanner_emit_finding \
        "S5" "structural" "info" "Exception past review date" \
        "$source_file" "scanner-exceptions" \
        "exception-past-review-${i}" \
        "$subs" "$action" \
        "[Acknowledge — review next session]"
    fi
    i=$((i + 1))
  done
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
