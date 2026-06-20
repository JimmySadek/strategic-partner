#!/usr/bin/env bash
# .scripts/context-file-scan/rules/behavioral.sh
# Behavioral rule detection (B1-B8) for the context-file scanner.
# Sourceable. Each rule function emits zero or more findings (one JSON
# object per line) to stdout.
#
# Cross-file rules (B5, B7) take a list of files (primary + companions);
# rules look across all of them as one merged behavioral surface.
#
# Requires: lib/utils.sh + lib/output.sh sourced. Caller is expected to
# also have file-discovery findings available.

# ─────────────────────────────────────────────────────────────────────
# Headings recognized as behavioral baselines (same set as file-discovery)
# ─────────────────────────────────────────────────────────────────────
_SCANNER_BG_HEADINGS_RE_BEHAV='(behavioral guardrails|behavioral rules|coding behavior|source.editing rules)'

# scanner_bg_section_line FILE — emits the line number of the BG heading
# (substring-match, case-insensitive). Empty when none found.
scanner_bg_section_line() {
  local file="$1"
  [ -r "$file" ] || return 0
  scanner_list_h2_h3 "$file" \
    | awk -F: -v re="$_SCANNER_BG_HEADINGS_RE_BEHAV" '
        {
          title = ""
          for (i = 3; i <= NF; i++) title = title (i == 3 ? "" : ":") $i
          if (tolower(title) ~ re) { print $1; exit }
        }
      '
}

# ─────────────────────────────────────────────────────────────────────
# B1 — Missing behavioral baseline (spec § 4.B1)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_B1() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"

  # Code-production heuristic
  local is_code_project=false
  for marker in src lib tests test app pkg; do
    if [ -d "$project_root/$marker" ]; then
      is_code_project=true; break
    fi
  done
  if [ "$is_code_project" = "false" ]; then
    for f in package.json Cargo.toml pyproject.toml go.mod Gemfile pom.xml build.gradle; do
      if [ -f "$project_root/$f" ]; then
        is_code_project=true; break
      fi
    done
    if [ "$is_code_project" = "false" ]; then
      # Any *.csproj file
      if ls "$project_root"/*.csproj >/dev/null 2>&1; then
        is_code_project=true
      fi
    fi
  fi
  [ "$is_code_project" = "false" ] && return 0

  # BG section present?
  local bg_line
  bg_line=$(scanner_bg_section_line "$abs_file")
  [ -n "$bg_line" ] && return 0

  # Identify the marker that fired (for substitutions)
  local detected_markers="[]"
  local m
  for m in src lib tests test app pkg; do
    [ -d "$project_root/$m" ] && \
      detected_markers=$(echo "$detected_markers" | jq --arg m "$m/" '. + [$m]')
  done
  for f in package.json Cargo.toml pyproject.toml go.mod Gemfile pom.xml build.gradle; do
    [ -f "$project_root/$f" ] && \
      detected_markers=$(echo "$detected_markers" | jq --arg m "$f" '. + [$m]')
  done

  # Determine the platform-aware suggestion text per spec § 1.5
  local platform_target=".claude/rules/source-editing.md"
  case "$source_file" in
    AGENTS.md) platform_target="<platform-rules-dir>/source-editing.md" ;;
    GEMINI.md) platform_target="<platform-rules-dir>/source-editing.md" ;;
  esac

  local subs action
  subs=$(jq -nc \
    --argjson markers "$detected_markers" \
    --arg target "$platform_target" \
    '{detected_markers: $markers, suggested_target: $target}')
  action=$(scanner_action_json add_section "claude-rules" true false "")
  scanner_emit_finding \
    "B1" "behavioral" "warn" "Missing behavioral baseline" \
    "$source_file" "<root>" \
    "$(scanner_norm_subject_B1 "behavioral-guardrails")" \
    "$subs" "$action" \
    "[Doesn't apply here — this project is not code-producing]"
}

# ─────────────────────────────────────────────────────────────────────
# B2 — Hybrid broken — stub without rules file (spec § 4.B2)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_B2() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"

  # Has BG section?
  local bg_line
  bg_line=$(scanner_bg_section_line "$abs_file")
  [ -z "$bg_line" ] && return 0

  # Section length < 60 lines AND references a companion-file pointer
  # → stub pattern. Codex finding #5: pointer extraction must be
  # platform-agnostic — `.claude/rules/*.md`, `.codex/rules/*.md`,
  # `.gemini/rules/*.md`, etc. Same regex as
  # scanner_extract_companion_pointers in lib/file-discovery.sh.
  local body
  body=$(scanner_section_body "$abs_file" "$bg_line")
  local line_count
  line_count=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  [ "$line_count" -ge 60 ] && return 0

  local pointers
  pointers=$(printf '%s\n' "$body" \
    | grep -oE '(\./|\.[a-zA-Z0-9_-]+/)[a-zA-Z0-9_./-]+\.md' \
    | sort -u)
  [ -z "$pointers" ] && return 0

  while IFS= read -r ptr; do
    [ -z "$ptr" ] && continue
    if [ ! -e "$project_root/$ptr" ]; then
      local subs action
      subs=$(jq -nc --arg p "$ptr" '{stub_target: $p, stub_state: "present", rules_file_state: "missing"}')
      action=$(scanner_action_json add_section "claude-rules" true false "")
      scanner_emit_finding \
        "B2" "behavioral" "warn" "Hybrid broken — stub without rules file" \
        "$source_file" "behavioral-guardrails" \
        "$(scanner_norm_subject_B2_B3 present missing)" \
        "$subs" "$action" \
        "[Acknowledge — the stub alone is sufficient for this project]"
    fi
  done <<EOF
$pointers
EOF
}

# ─────────────────────────────────────────────────────────────────────
# B3 — Hybrid broken — rules file without stub (spec § 4.B3)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_B3() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"

  # Find any .claude/rules/*.md present
  local rules_files
  rules_files=$(ls "$project_root/.claude/rules"/*.md 2>/dev/null)
  [ -z "$rules_files" ] && return 0

  while IFS= read -r rules_path; do
    [ -z "$rules_path" ] && continue
    local rel="${rules_path#"$project_root/"}"
    # Is the rules file referenced in the target file?
    if grep -qF "$rel" "$abs_file" 2>/dev/null; then
      continue
    fi
    # Also accept just the basename mention with ".claude/rules" prefix
    local subs action
    subs=$(jq -nc --arg p "$rel" '{rules_file: $p, stub_state: "missing", rules_file_state: "present"}')
    action=$(scanner_action_json add_pointer "claude-rules" true false "")
    scanner_emit_finding \
      "B3" "behavioral" "warn" "Hybrid broken — rules file without stub" \
      "$source_file" "<root>" \
      "$(scanner_norm_subject_B2_B3 missing present)" \
      "$subs" "$action" \
      "[Acknowledge — path-scoped loading is sufficient for our workflow]"
  done <<EOF
$rules_files
EOF
}

# ─────────────────────────────────────────────────────────────────────
# B4 — Full content inlined when hybrid would be cleaner (spec § 4.B4)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_B4() {
  local abs_file="$1"
  local source_file="$2"

  local bg_line
  bg_line=$(scanner_bg_section_line "$abs_file")
  [ -z "$bg_line" ] && return 0

  local body
  body=$(scanner_section_body "$abs_file" "$bg_line")
  local body_lines body_chars
  body_lines=$(printf '%s\n' "$body" | wc -l | tr -d ' ')
  body_chars=$(printf '%s' "$body" | wc -c | tr -d ' ')

  # Worked-example markers
  local example_markers
  example_markers=$(printf '%s\n' "$body" \
    | grep -cE '(❌ Anti-pattern|✅ Corrected|^### Example|^### Worked example|^Example:|^### In practice)' || true)

  # Fire if section is large AND has worked-example structure
  if [ "$body_lines" -ge 60 ] || [ "$example_markers" -ge 2 ]; then
    local subs action
    subs=$(jq -nc \
      --argjson lines "$body_lines" \
      --argjson chars "$body_chars" \
      --argjson examples "$example_markers" \
      '{section_lines: $lines, section_chars: $chars, example_markers: $examples}')
    action=$(scanner_action_json move_to_layer "claude-rules" true false "")
    scanner_emit_finding \
      "B4" "behavioral" "info" "Full content inlined when hybrid would be cleaner" \
      "$source_file" "behavioral-guardrails" \
      "$(scanner_norm_subject_B4)" \
      "$subs" "$action" \
      "[Keep inline — visibility is more important here than token cost]"
  fi
}

# ─────────────────────────────────────────────────────────────────────
# Behavioral-rule-definition extractor (shared by B5, B7)
# ─────────────────────────────────────────────────────────────────────

# _scanner_extract_rules ABS_FILE SOURCE_FILE
#   Emits one rule definition per line:
#     SOURCE_FILE\tSECTION_ANCHOR\tRULE_NAME\tRULE_NAME_NORM\tBODY_START\tBODY_END
#
#   Two extraction modes:
#   - "rules-file" mode (path under .claude/rules/, or filename
#     source-editing.md / coding-behavior.md): every H2 heading is a rule.
#   - "bg-section" mode (default): find the BG section heading; rule
#     definitions are either ### subheadings beneath it OR numbered /
#     bulleted lead-phrases of the form "1. **Rule Name**" / "- **Rule**".
_scanner_extract_rules() {
  local abs_file="$1"
  local source_file="$2"

  case "$abs_file" in
    */.claude/rules/*|*/source-editing.md|*/coding-behavior.md|*/source-editing-rules.md)
      _scanner_extract_rules_h2 "$abs_file" "$source_file"
      return 0
      ;;
  esac

  local bg_line
  bg_line=$(scanner_bg_section_line "$abs_file")
  [ -z "$bg_line" ] && return 0

  # Get the line range of the BG section
  local bg_end
  bg_end=$(awk -v start="$bg_line" '
    NR > start && /^## / { print NR - 1; found = 1; exit }
    END { if (!found) print NR }
  ' "$abs_file")

  # Try ### subheadings first
  local hash_rules
  hash_rules=$(awk -v start="$bg_line" -v end="$bg_end" '
    NR <= start || NR > end { next }
    /^### / { print NR "\t" $0 }
  ' "$abs_file")

  if [ -n "$hash_rules" ]; then
    # ### subheading mode
    awk -v start="$bg_line" -v end="$bg_end" '
      BEGIN { state = 0; printed = 0 }
      NR <= start { next }
      NR > end {
        if (state == 1 && !printed) { printf "RULE\t%d\t%d\t%s\n", curr_start, NR - 1, curr; printed = 1 }
        state = 0
        exit
      }
      /^### / {
        if (state == 1) printf "RULE\t%d\t%d\t%s\n", curr_start, NR - 1, curr
        curr = $0; sub(/^### /, "", curr)
        curr_start = NR
        state = 1
        printed = 0
        next
      }
      END {
        if (state == 1 && !printed) printf "RULE\t%d\t%d\t%s\n", curr_start, NR, curr
      }
    ' "$abs_file" \
      | while IFS=$'\t' read -r tag start_line end_line heading; do
          [ "$tag" != "RULE" ] && continue
          local rule_norm
          rule_norm=$(scanner_canonical_rule_name "$heading")
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$source_file" "behavioral-guardrails" "$heading" "$rule_norm" "$start_line" "$end_line"
        done
    return 0
  fi

  # Fallback: numbered / bulleted lead-phrases
  awk -v start="$bg_line" -v end="$bg_end" '
    BEGIN { state = 0; printed = 0 }
    NR <= start { next }
    NR > end {
      if (state == 1 && !printed) { printf "RULE\t%d\t%d\t%s\n", curr_start, NR - 1, curr; printed = 1 }
      state = 0
      exit
    }
    /^[[:space:]]*([0-9]+\.|[*-])[[:space:]]+\*\*[^*]+\*\*/ {
      if (state == 1) printf "RULE\t%d\t%d\t%s\n", curr_start, NR - 1, curr
      curr = $0
      sub(/^[[:space:]]*([0-9]+\.|[*-])[[:space:]]+\*\*/, "", curr)
      sub(/\*\*.*$/, "", curr)
      curr_start = NR
      state = 1
      printed = 0
      next
    }
    END {
      if (state == 1 && !printed) printf "RULE\t%d\t%d\t%s\n", curr_start, NR, curr
    }
  ' "$abs_file" \
    | while IFS=$'\t' read -r tag start_line end_line heading; do
        [ "$tag" != "RULE" ] && continue
        local rule_norm
        rule_norm=$(scanner_canonical_rule_name "$heading")
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$source_file" "behavioral-guardrails" "$heading" "$rule_norm" "$start_line" "$end_line"
      done
}

# scanner_canonical_rule_name TEXT
#   Strips leading "N." / "N)" numeric prefixes and slugifies. Used for
#   cross-file matching of rules between CLAUDE.md (numbered list) and
#   .claude/rules/source-editing.md (numbered H2). Both forms reduce to
#   the same canonical key.
scanner_canonical_rule_name() {
  local text
  text=$(echo "$1" | sed -E 's/^[[:space:]]*[0-9]+[.)][[:space:]]*//')
  scanner_slug "$text"
}

# _scanner_extract_rules_h2 ABS_FILE SOURCE_FILE
#   Rules-file mode: each ## heading is a rule. Body extends until next ##.
_scanner_extract_rules_h2() {
  local abs_file="$1"
  local source_file="$2"

  awk '
    BEGIN { state = 0 }
    /^## / {
      if (state == 1) printf "RULE\t%d\t%d\t%s\n", curr_start, NR - 1, curr
      curr = $0; sub(/^## /, "", curr)
      curr_start = NR
      state = 1
      next
    }
    END {
      if (state == 1) printf "RULE\t%d\t%d\t%s\n", curr_start, NR, curr
    }
  ' "$abs_file" \
    | while IFS=$'\t' read -r tag start_line end_line heading; do
        [ "$tag" != "RULE" ] && continue
        local rule_norm
        rule_norm=$(scanner_canonical_rule_name "$heading")
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$source_file" "$(scanner_slug "$heading")" "$heading" "$rule_norm" "$start_line" "$end_line"
      done
}

# _scanner_rule_has_example ABS_FILE START_LINE END_LINE
#   Echoes "yes" if the body lines [START..END] contain an example
#   indicator per spec § 4.B5 acceptance list, else "no".
_scanner_rule_has_example() {
  local abs_file="$1"
  local start_line="$2"
  local end_line="$3"

  awk -v s="$start_line" -v e="$end_line" '
    NR < s || NR > e { next }
    NR == s { next }  # the heading itself
    /(^|[[:space:]])(Example|Worked example|In practice|Anti-pattern|Corrected approach)([[:space:]]|:|$)/ { print "yes"; exit }
    /❌|✅/ { print "yes"; exit }
  ' "$abs_file"
}

# ─────────────────────────────────────────────────────────────────────
# B5 — Behavioral rule without example (CROSS-FILE) — spec § 4.B5
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_B5 PROJECT_ROOT FILES_TSV
#   FILES_TSV: one tab-delimited line per file: ABS_PATH\tSOURCE_FILE
#   Aggregates rules across all files; for each rule, fires if NO file
#   contains an example for that rule.
scanner_rule_B5() {
  local project_root="$1"
  local files_tsv="$2"
  [ -z "$files_tsv" ] && return 0

  # Build aggregated rule list: rule_name_norm → list of (abs_path|source_file|start|end|original_name)
  local rules_index=""
  while IFS=$'\t' read -r abs_path source_file; do
    [ -z "$abs_path" ] && continue
    local entries
    entries=$(_scanner_extract_rules "$abs_path" "$source_file")
    while IFS=$'\t' read -r src section heading rule_norm s e; do
      [ -z "$rule_norm" ] && continue
      rules_index="$rules_index"$'\n'"${abs_path}|${src}|${s}|${e}|${heading}|${rule_norm}|${section}"
    done <<EOR
$entries
EOR
  done <<<"$files_tsv"

  # Group by rule_norm
  local norms
  norms=$(printf '%s\n' "$rules_index" | awk -F'|' 'NF >= 6 { print $6 }' | sort -u)

  while IFS= read -r norm; do
    [ -z "$norm" ] && continue
    # Check ALL entries with this norm — if any has an example, skip
    local has_example=no
    local first_entry=""
    while IFS='|' read -r abs_path src start end heading r_norm section; do
      [ "$r_norm" != "$norm" ] && continue
      [ -z "$first_entry" ] && first_entry="${abs_path}|${src}|${heading}|${section}"
      local result
      result=$(_scanner_rule_has_example "$abs_path" "$start" "$end")
      [ "$result" = "yes" ] && { has_example=yes; break; }
    done <<EOI
$rules_index
EOI

    [ "$has_example" = "yes" ] && continue
    [ -z "$first_entry" ] && continue

    local rest="${first_entry#*|}"
    local fe_src="${rest%%|*}"; rest="${rest#*|}"
    local fe_heading="${rest%%|*}"
    local fe_section="${rest#*|}"

    local subs action
    subs=$(jq -nc --arg name "$fe_heading" '{rule_name: $name}')
    action=$(scanner_action_json add_example "" false false "")
    scanner_emit_finding \
      "B5" "behavioral" "info" "Behavioral rule without example" \
      "$fe_src" "$fe_section" \
      "$(scanner_norm_subject_B5 "$fe_heading")" \
      "$subs" "$action" \
      "[Defer — add example later]"
  done <<EOK
$norms
EOK
}

# ─────────────────────────────────────────────────────────────────────
# B6 — Rule belongs in enforcement layer (catalog of 6 categories)
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_B6 PROJECT_ROOT FILES_TSV
scanner_rule_B6() {
  local _project_root="$1"
  local files_tsv="$2"

  while IFS=$'\t' read -r abs_path source_file; do
    [ -z "$abs_path" ] && continue
    local rules
    rules=$(_scanner_extract_rules "$abs_path" "$source_file")
    while IFS=$'\t' read -r src section heading rule_norm s e; do
      [ -z "$heading" ] && continue
      local body
      body=$(awk -v s="$s" -v e="$e" 'NR>=s && NR<=e' "$abs_path")
      # Codex finding #6: strip inline-code backticks from the
      # lowercased body before matching catalog phrases. The spec
      # § 4.B6 catalog shows phrases with backticks
      # (`No \`console.log\``, `No \`print()\``, etc.); without
      # stripping, the literal backticks defeat the regex.
      local body_lc
      body_lc=$(scanner_lower "$body" | tr -d '`')

      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "lint-detectable" \
        "no console\\.log|no print\\(\\)|no debugger|max line length|max function length|no unused imports|no circular imports|all exports must be typed|no magic numbers"

      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "pre-commit-hook-detectable" \
        "never commit|no secrets in|no \\.env files in|all commits must|before commit|block commit if"

      # Codex finding #6: "always use {format-rule-name}" is a spec
      # § 4.B6 canonical phrase that the previous regex omitted.
      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "format-style-enforcement" \
        "tabs vs spaces|indent with|consistent spacing|max trailing newlines|always use [a-z]+"

      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "type-check-detectable" \
        "all functions must be typed|no implicit any|strict null checks|exhaustiveness check"

      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "test-coverage-detectable" \
        "all public functions must have tests|minimum coverage|no untested code paths"

      _scanner_B6_check "$src" "$section" "$heading" "$rule_norm" \
        "$body_lc" "path-structure-detectable" \
        "no files in.*can|all files in.*must|directory.*only contains"

    done <<EOR
$rules
EOR
  done <<<"$files_tsv"
}

_scanner_B6_check() {
  local src="$1" section="$2" heading="$3" rule_norm="$4" body_lc="$5" category="$6" pattern="$7"
  echo "$body_lc" | grep -qE "$pattern" || return 0
  local subs action
  subs=$(jq -nc --arg n "$heading" --arg cat "$category" \
    '{rule_name: $n, enforceability_category: $cat}')
  action=$(scanner_action_json move_to_layer "claude-hooks" false false "")
  scanner_emit_finding \
    "B6" "behavioral" "info" "Rule belongs in enforcement layer" \
    "$src" "$section" \
    "$(scanner_norm_subject_B6 "$heading" "$category")" \
    "$subs" "$action" \
    "[Acknowledge — no enforcement layer available, kept advisory]"
}

# ─────────────────────────────────────────────────────────────────────
# B7 — Behavioral rule duplication (CROSS-FILE) — spec § 4.B7
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_B7 PROJECT_ROOT FILES_TSV
scanner_rule_B7() {
  local _project_root="$1"
  local files_tsv="$2"
  [ -z "$files_tsv" ] && return 0

  # Aggregate
  local rules_index=""
  while IFS=$'\t' read -r abs_path source_file; do
    [ -z "$abs_path" ] && continue
    local entries
    entries=$(_scanner_extract_rules "$abs_path" "$source_file")
    while IFS=$'\t' read -r src section heading rule_norm s e; do
      [ -z "$rule_norm" ] && continue
      rules_index="$rules_index"$'\n'"${rule_norm}|${src}|${section}|${heading}"
    done <<EOR
$entries
EOR
  done <<<"$files_tsv"

  local norms_with_count
  norms_with_count=$(printf '%s\n' "$rules_index" | awk -F'|' 'NF >= 4 { print $1 }' | sort | uniq -c | awk '$1 >= 2 { print $2 }')

  while IFS= read -r norm; do
    [ -z "$norm" ] && continue
    local entries
    entries=$(printf '%s\n' "$rules_index" | awk -F'|' -v n="$norm" '$1 == n')

    # Skip the canonical hybrid pattern: the same rule in BOTH a
    # rules-file (.claude/rules/* or similar) AND a non-rules file
    # (CLAUDE.md, AGENTS.md, GEMINI.md). This is the policy-recommended
    # stub+full split; flagging it as duplication would punish the
    # canonical structure.
    #
    # Codex finding #7 isolation reveals: relative paths from a fixture
    # root start with `.claude/rules/...` (no leading slash). The
    # absolute-prefix glob `*/.claude/rules/*` won't match those. Add
    # the bare-prefix forms so the hybrid-skip works for project-root-
    # relative paths.
    local has_rules_file=0 has_primary=0
    while IFS='|' read -r r_norm src section heading; do
      [ -z "$src" ] && continue
      case "$src" in
        */.claude/rules/*|.claude/rules/*|*/source-editing.md|source-editing.md|*/coding-behavior.md|coding-behavior.md|*/source-editing-rules.md|source-editing-rules.md)
          has_rules_file=1 ;;
        CLAUDE.md|AGENTS.md|GEMINI.md|*/CLAUDE.md|*/AGENTS.md|*/GEMINI.md)
          has_primary=1 ;;
      esac
    done <<EOH
$entries
EOH
    if [ "$has_rules_file" = "1" ] && [ "$has_primary" = "1" ]; then
      continue
    fi

    local locations=""
    local first_src="" first_section="" first_heading=""
    local sources_array='[]'
    while IFS='|' read -r r_norm src section heading; do
      [ -z "$src" ] && continue
      [ -z "$first_src" ] && { first_src="$src"; first_section="$section"; first_heading="$heading"; }
      sources_array=$(echo "$sources_array" | jq --arg src "$src" --arg sec "$section" \
        '. + [{"source_file": $src, "section_anchor": $sec}]')
      locations="$locations $section"
    done <<EOE
$entries
EOE

    local subs action
    subs=$(jq -nc \
      --arg name "$first_heading" \
      --argjson sources "$sources_array" \
      '{rule_name: $name, locations: $sources}')
    action=$(scanner_action_json consolidate "" false false "")
    scanner_emit_finding \
      "B7" "behavioral" "warn" "Behavioral rule duplication" \
      "$first_src" "$first_section" \
      "$(scanner_norm_subject_B7 "$first_heading" $locations)" \
      "$subs" "$action" \
      "[Acknowledge — duplicates are intentional for emphasis]"
  done <<EOK
$norms_with_count
EOK
}

# ─────────────────────────────────────────────────────────────────────
# B8 — Drift from Karpathy baseline (spec § 4.B8)
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_B8 PROJECT_ROOT FILES_TSV
scanner_rule_B8() {
  local _project_root="$1"
  local files_tsv="$2"

  while IFS=$'\t' read -r abs_path source_file; do
    [ -z "$abs_path" ] && continue
    local rules
    rules=$(_scanner_extract_rules "$abs_path" "$source_file")
    while IFS=$'\t' read -r src section heading rule_norm s e; do
      [ -z "$heading" ] && continue
      local heading_lc
      heading_lc=$(scanner_lower "$heading")
      local body
      body=$(awk -v s="$s" -v e="$e" 'NR>=s && NR<=e' "$abs_path")
      local body_lc
      body_lc=$(scanner_lower "$body")

      _scanner_B8_check "$src" "$section" "$heading" "$body_lc" \
        "$heading_lc" "Think Before Coding" \
        "(think before coding|thinking before coding|think first)" \
        "act first|ship first then think|skip the analysis|don't surface assumptions|agree with user without verification|don't push back"

      _scanner_B8_check "$src" "$section" "$heading" "$body_lc" \
        "$heading_lc" "Simplicity First" \
        "(simplicity first|keep it simple|minimal code)" \
        "comprehensive coverage|extensive abstraction|configurability for future use|anticipate all use cases|more abstraction layers|build for flexibility"

      _scanner_B8_check "$src" "$section" "$heading" "$body_lc" \
        "$heading_lc" "Surgical Changes" \
        "(surgical changes|minimal changes|targeted edits)" \
        "improve adjacent code|reformat while editing|comprehensive refactor|drive-by improvements"

      _scanner_B8_check "$src" "$section" "$heading" "$body_lc" \
        "$heading_lc" "Verification not Specification" \
        "(verification.{0,5}not.{0,5}specification|goal-driven|outcome-driven)" \
        "imperative steps|step-by-step prescription|specify every step|no testing required|skip verification"

    done <<EOR
$rules
EOR
  done <<<"$files_tsv"
}

_scanner_B8_check() {
  local src="$1" section="$2" heading="$3" body_lc="$4" heading_lc="$5"
  local principle="$6" name_pattern="$7" contradiction_pattern="$8"
  echo "$heading_lc" | grep -qE "$name_pattern" || return 0

  # Strip anti-pattern blocks from the body before matching: these
  # blocks ILLUSTRATE the contradiction the rule is teaching against.
  # Match-skip from "❌ Anti-pattern" / "anti-pattern (" / "what NOT to do"
  # to the next "✅ Corrected" / "Corrected approach" / blank-line+heading.
  local filtered_body
  filtered_body=$(echo "$body_lc" | awk '
    BEGIN { skip = 0 }
    /^### anti-pattern|^### what this means|❌|anti-pattern[[:space:]]*\(|what not to do|never[[:space:]]+do[[:space:]]+this/ { skip = 1; next }
    /^### corrected approach|^### worked example|^### in practice|^## |✅|corrected approach|corrected:/ { skip = 0; next }
    skip == 0 { print }
  ')

  echo "$filtered_body" | grep -qE "$contradiction_pattern" || return 0
  local matched_signal
  matched_signal=$(echo "$filtered_body" | grep -oE "$contradiction_pattern" | head -1)
  local subs action
  subs=$(jq -nc --arg n "$heading" --arg p "$principle" --arg s "$matched_signal" \
    '{rule_name: $n, principle: $p, signal: $s}')
  action=$(scanner_action_json document_deviation "" false false "")
  scanner_emit_finding \
    "B8" "behavioral" "info" "Drift from Karpathy baseline" \
    "$src" "$section" \
    "$(scanner_norm_subject_B8 "$heading" "$principle")" \
    "$subs" "$action" \
    "[Document deviation rationale and keep the project-specific guardrail]"
}

# ─────────────────────────────────────────────────────────────────────
# Convenience entry: run all B1-B8
# ─────────────────────────────────────────────────────────────────────

# scanner_run_behavioral PROJECT_ROOT PRIMARY_ABS PRIMARY_SRC FILES_TSV
#   PRIMARY_ABS / PRIMARY_SRC: the primary context file under scrutiny.
#   FILES_TSV: full list (primary + discovered companions), one line per
#   file as "abs_path<TAB>source_file".
#
#   Single-file rules B1-B4 run ONLY on the primary (companion files are
#   the answer to those rules, not subject to them). Cross-file rules
#   B5-B8 run across the whole TSV.
scanner_run_behavioral() {
  local project_root="$1"
  local primary_abs="$2"
  local primary_src="$3"
  local files_tsv="$4"

  scanner_rule_B1 "$primary_abs" "$primary_src" "$project_root"
  scanner_rule_B2 "$primary_abs" "$primary_src" "$project_root"
  scanner_rule_B3 "$primary_abs" "$primary_src" "$project_root"
  scanner_rule_B4 "$primary_abs" "$primary_src"

  scanner_rule_B5 "$project_root" "$files_tsv"
  scanner_rule_B6 "$project_root" "$files_tsv"
  scanner_rule_B7 "$project_root" "$files_tsv"
  scanner_rule_B8 "$project_root" "$files_tsv"
}
