#!/usr/bin/env bash
# .scripts/context-file-scan/lib/output.sh
# JSON formatting for scanner findings + size-band determination per
# scanner-design-spec.md § 2.2 + § 3. Sourceable.
#
# Each emitted finding conforms to schemas/scanner-findings.json (11
# required fields). Fingerprint is computed via lib/utils.sh's
# scanner_fingerprint per spec § 1.4.
#
# Requires: jq, plus lib/utils.sh sourced.

# ─────────────────────────────────────────────────────────────────────
# Size-band determination per spec § 3.S1 thresholds
# ─────────────────────────────────────────────────────────────────────

# scanner_size_band CHAR_COUNT
#   Echoes the band: under-soft / soft-warn / warn / surface-loudly.
scanner_size_band() {
  local n="$1"
  if [ "$n" -lt 16384 ]; then
    echo under-soft
  elif [ "$n" -lt 24576 ]; then
    echo soft-warn
  elif [ "$n" -lt 36864 ]; then
    echo warn
  else
    echo surface-loudly
  fi
}

# scanner_size_band_threshold BAND
#   Echoes the lower-bound char count of BAND (used for the
#   threshold_value substitution in S1 findings).
scanner_size_band_threshold() {
  case "$1" in
    under-soft)     echo 0 ;;
    soft-warn)      echo 16384 ;;
    warn)           echo 24576 ;;
    surface-loudly) echo 36864 ;;
    *)              echo 0 ;;
  esac
}

# scanner_s1_severity_for_band BAND
#   Maps S1 size bands to the severity enum per spec § 3.S1
#   "Severity mapping" — soft-warn → info, warn → warn,
#   surface-loudly → surface-loudly. under-soft never emits a finding.
scanner_s1_severity_for_band() {
  case "$1" in
    soft-warn)      echo info ;;
    warn)           echo warn ;;
    surface-loudly) echo surface-loudly ;;
    *)              echo info ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────
# Finding emission
# ─────────────────────────────────────────────────────────────────────

# scanner_emit_finding RULE_ID RULE_CLASS SEVERITY TITLE SOURCE_FILE
#                       SECTION_ANCHOR NORMALIZED_SUBJECT
#                       TEMPLATE_SUBSTITUTIONS_JSON SUGGESTED_ACTION_JSON
#                       EXCEPTION_LABEL
#
#   Echoes one finding JSON object on stdout. Computes the fingerprint
#   from (rule_id, source_file, section_anchor, normalized_subject) per
#   spec § 1.4. The TEMPLATE_SUBSTITUTIONS_JSON and SUGGESTED_ACTION_JSON
#   args must be valid JSON literals (use jq -n / scanner_json_string to
#   build them).
scanner_emit_finding() {
  local rule_id="$1"
  local rule_class="$2"
  local severity="$3"
  local title="$4"
  local source_file="$5"
  local section_anchor="$6"
  local normalized_subject="$7"
  local template_subs_json="$8"
  local suggested_action_json="$9"
  local exception_label="${10}"

  local fingerprint
  fingerprint=$(scanner_fingerprint "$rule_id" "$source_file" "$section_anchor" "$normalized_subject")

  jq -nc \
    --arg rule_id "$rule_id" \
    --arg rule_class "$rule_class" \
    --arg severity "$severity" \
    --arg title "$title" \
    --arg source_file "$source_file" \
    --arg section_anchor "$section_anchor" \
    --arg fingerprint "$fingerprint" \
    --argjson template_substitutions "$template_subs_json" \
    --arg normalized_subject "$normalized_subject" \
    --argjson suggested_action "$suggested_action_json" \
    --arg exception_label "$exception_label" \
    '{
      rule_id: $rule_id,
      rule_class: $rule_class,
      severity: $severity,
      title: $title,
      source_file: $source_file,
      section_anchor: $section_anchor,
      fingerprint: $fingerprint,
      template_substitutions: $template_substitutions,
      normalized_subject: $normalized_subject,
      suggested_action: $suggested_action,
      exception_label: $exception_label
    }'
}

# ─────────────────────────────────────────────────────────────────────
# Suggested-action helper
# ─────────────────────────────────────────────────────────────────────

# scanner_action_json TYPE LAYER_TARGET LAYER_TARGET_AVAILABLE FALLBACK_USED [PREVIEW_COMMAND]
#   Builds the suggested_action JSON object. LAYER_TARGET may be "" for
#   actions that don't move content. AVAILABLE / FALLBACK are "true"/"false"
#   strings. PREVIEW_COMMAND optional — empty string becomes JSON null.
scanner_action_json() {
  local type="$1"
  local layer_target="$2"
  local layer_target_available="${3:-false}"
  local fallback_used="${4:-false}"
  local preview_command="${5:-}"

  local lt_arg='null'
  if [ -n "$layer_target" ]; then
    lt_arg=$(scanner_json_string "$layer_target")
  fi
  local pc_arg='null'
  if [ -n "$preview_command" ]; then
    pc_arg=$(scanner_json_string "$preview_command")
  fi

  jq -nc \
    --arg type "$type" \
    --argjson layer_target "$lt_arg" \
    --argjson layer_target_available "$layer_target_available" \
    --argjson fallback_used "$fallback_used" \
    --argjson preview_command "$pc_arg" \
    '{
      type: $type,
      layer_target: $layer_target,
      layer_target_available: $layer_target_available,
      fallback_used: $fallback_used,
      preview_command: $preview_command
    }'
}

# ─────────────────────────────────────────────────────────────────────
# Findings array assembly
# ─────────────────────────────────────────────────────────────────────

# scanner_findings_array
#   Reads one JSON-encoded finding per stdin line, emits a single JSON
#   array containing them all. Empty input → empty array.
scanner_findings_array() {
  jq -sc '.'
}

# scanner_summary_object FINDINGS_JSON_ARRAY
#   Computes the summary object (total_findings, by_severity, by_class,
#   by_source_file) per spec Appendix B sample shape.
scanner_summary_object() {
  local findings="$1"
  echo "$findings" | jq -c '
    {
      total_findings: length,
      by_severity: (
        reduce (group_by(.severity)[] | { (.[0].severity): length }) as $g
          ({ "info": 0, "warn": 0, "surface-loudly": 0 }; . + $g)
      ),
      by_class: (
        reduce (group_by(.rule_class)[] | { (.[0].rule_class): length }) as $g
          ({ "structural": 0, "behavioral": 0 }; . + $g)
      ),
      by_source_file: (
        reduce (group_by(.source_file)[] | { (.[0].source_file): length }) as $g
          ({}; . + $g)
      )
    }
  '
}
