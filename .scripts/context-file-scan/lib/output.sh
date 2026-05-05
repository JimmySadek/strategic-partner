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

  # Codex finding #8: every Apply-suggestion action needs a copy-paste-
  # ready preview_command (diff or snippet). When the rule didn't pass
  # an explicit preview, fill in the default per spec § 1.4 mini-decision
  # 13 and the policy C6 templates.
  if [ "$(echo "$suggested_action_json" | jq -r '.preview_command // "null"')" = "null" ]; then
    local default_preview
    default_preview=$(_scanner_default_preview_for_rule \
      "$rule_id" "$source_file" "$section_anchor" \
      "$template_subs_json" "$suggested_action_json")
    if [ -n "$default_preview" ]; then
      suggested_action_json=$(echo "$suggested_action_json" | jq \
        --arg pc "$default_preview" \
        '.preview_command = $pc')
    fi
  fi

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

# _scanner_default_preview_for_rule RULE_ID SOURCE_FILE SECTION_ANCHOR
#                                    SUBS_JSON ACTION_JSON
#
# Emits a copy-paste-ready snippet for the rule's Apply-suggestion
# action. The snippet is rule-specific and includes the file path and
# any relevant template substitutions so the user can apply it
# manually. Empty output means the rule has no canonical snippet.
_scanner_default_preview_for_rule() {
  local rid="$1"
  local src="$2"
  local _anchor="$3"
  local subs="$4"
  local action="$5"

  local layer
  layer=$(echo "$action" | jq -r '.layer_target // ""')

  case "$rid" in
    S1)
      local largest slug
      largest=$(echo "$subs" | jq -r '.largest_sections[0].name // "<largest section>"')
      slug=$(scanner_slug "$largest")
      [ -z "$slug" ] && slug="extracted-section"
      printf '# Extract "%s" from %s to claudedocs/%s.md:\n#   1. Create claudedocs/%s.md with the section content\n#   2. Replace the section in %s with: See [claudedocs/%s.md](claudedocs/%s.md).' \
        "$largest" "$src" "$slug" "$slug" "$src" "$slug" "$slug"
      ;;
    S2)
      local section pattern target
      section=$(echo "$subs" | jq -r '.section // "<section>"')
      pattern=$(echo "$subs" | jq -r '.detected_pattern // "schema"')
      target="$layer"
      [ -z "$target" ] && target="claudedocs/"
      printf '# Move "%s" (%s) to %s:\n#   1. Append the section content to %s\n#   2. Replace the section in %s with a one-line pointer.' \
        "$section" "$pattern" "$target" "$target" "$src"
      ;;
    S3)
      local subj
      subj=$(echo "$subs" | jq -r '.candidate // .path // .feature // "<broken-reference>"')
      printf '# Diff to apply manually in %s — remove the broken reference:\n-   See `%s` for ...' \
        "$src" "$subj"
      ;;
    S4)
      local prohib
      prohib=$(echo "$subs" | jq -r '.prohibition_text // "<prohibition>"')
      printf '# Convert "%s" to a positive-bullet form in %s:\n# Replace the prohibition with a bullet stating what the user SHOULD do\n# instead, keeping the prohibition as supporting context if helpful.' \
        "$prohib" "$src"
      ;;
    S5)
      local guard date status
      guard=$(echo "$subs" | jq -r '.guard_name // "<guard>"')
      date=$(echo "$subs" | jq -r '.review_date // "<date>"')
      status=$(echo "$subs" | jq -r '.status // "near"')
      if [ "$status" = "past" ]; then
        printf '# Provisional Guard "%s" review date %s has passed. Either:\n#   1. Extend: bump the Review: date forward (revisit in 90 days)\n#   2. Graduate: promote to a permanent Behavioral Guardrail\n#   3. Retire: remove if the guard is no longer relevant' \
          "$guard" "$date"
      else
        printf '# Provisional Guard "%s" review date %s is approaching.\n# Review the guard before %s to decide: extend / graduate / retire.' \
          "$guard" "$date" "$date"
      fi
      ;;
    S6)
      local sl el
      sl=$(echo "$subs" | jq -r '.start_line // 0')
      el=$(echo "$subs" | jq -r '.end_line // 0')
      printf '# Extract inline shell at %s:%s-%s to scripts/<name>.sh:\n#   1. Create scripts/<name>.sh with the block content\n#   2. Replace the block in %s with a reference to the script.' \
        "$src" "$sl" "$el" "$src"
      ;;
    S7)
      local skill
      skill=$(echo "$subs" | jq -r '.skill_name // "<skill>"')
      printf '# Skill "%s" already provides this behavior; remove the re-assertion in %s.\n# The skill'\''s SKILL.md is the canonical source — re-stating its rules in\n# %s adds tokens without adding behavior.' \
        "$skill" "$src" "$src"
      ;;
    S8)
      local path
      path=$(echo "$subs" | jq -r '.import_path // .path // "<path>"')
      printf '# `@%s` import is large. Either:\n#   1. Break the imported file into smaller focused files and @-import only what is needed\n#   2. Replace the @-import with a one-line pointer: See [%s](%s) for details' \
        "$path" "$path" "$path"
      ;;
    B1)
      printf '# Add a Behavioral Guardrails section to %s:\n\n## Behavioral Guardrails\n\nWhen editing source files in this project:\n\n  1. **Think Before Coding** → surface assumptions; ask if uncertain\n  2. **Simplicity First** → minimum that solves the problem\n  3. **Surgical Changes** → touch only what was asked\n  4. **Verification, not Specification** → test-first; declarative outcomes\n\n📁 Full rules: [.claude/rules/source-editing.md](.claude/rules/source-editing.md)' \
        "$src"
      ;;
    B2)
      local target
      target=$(echo "$subs" | jq -r '.stub_target // ".claude/rules/source-editing.md"')
      printf '# Create the missing companion file at %s:\n#   1. mkdir -p $(dirname %s)\n#   2. Add the worked-example content to %s\n#   3. The stub in %s already references this path; no further change there.' \
        "$target" "$target" "$target" "$src"
      ;;
    B3)
      local rules_file
      rules_file=$(echo "$subs" | jq -r '.rules_file // ".claude/rules/source-editing.md"')
      printf '# Add a stub pointer to %s:\n\n## Behavioral Guardrails\n\nWhen editing source files in this project, follow [`%s`](%s).' \
        "$src" "$rules_file" "$rules_file"
      ;;
    B4)
      printf '# Extract worked examples from %s into .claude/rules/source-editing.md:\n#   1. Move each rule'\''s worked-example block to the rules file\n#   2. Keep a brief stub in %s under Behavioral Guardrails\n#   3. Reference: [.claude/rules/source-editing.md](.claude/rules/source-editing.md)' \
        "$src" "$src"
      ;;
    B5)
      local rule
      rule=$(echo "$subs" | jq -r '.rule_name // .heading // "<rule>"')
      printf '# Add a worked example to "%s" in %s:\n\n### %s\n\n[principle]\n\n❌ Anti-pattern: ...\n✅ Corrected: ...\n\nWorked example: ...' \
        "$rule" "$src" "$rule"
      ;;
    B6)
      local rule cat
      rule=$(echo "$subs" | jq -r '.rule_name // "<rule>"')
      cat=$(echo "$subs" | jq -r '.enforceability_category // "lint-detectable"')
      printf '# Move "%s" to enforcement (%s):\n# This rule is mechanically enforceable. Add it to the appropriate config\n# (linter / pre-commit hook / formatter / type checker / CI / etc.) and\n# either remove it from %s or keep a one-line pointer to the new layer.' \
        "$rule" "$cat" "$src"
      ;;
    B7)
      local rule
      rule=$(echo "$subs" | jq -r '.rule_name // "<rule>"')
      printf '# Consolidate "%s" to a single canonical location:\n#   1. Pick one location as canonical (typically the rules file)\n#   2. Replace other occurrences with a brief stub pointing at the canonical one' \
        "$rule"
      ;;
    B8)
      local rule principle
      rule=$(echo "$subs" | jq -r '.rule_name // "<rule>"')
      principle=$(echo "$subs" | jq -r '.principle // "<principle>"')
      printf '# Re-frame "%s" to align with %s:\n# Review the rule body for contradictions with the Karpathy principle.\n# Either tighten the rule body or remove the rule if the principle\n# is already covered.' \
        "$rule" "$principle"
      ;;
    *)
      printf ''
      ;;
  esac
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
