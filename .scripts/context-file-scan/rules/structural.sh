#!/usr/bin/env bash
# .scripts/context-file-scan/rules/structural.sh
# Structural rule detection (S1-S8) per scanner-design-spec.md § 3.
# Sourceable. Each rule function emits zero or more findings (one JSON
# object per line) to stdout; no findings means no output. All findings
# conform to schemas/scanner-findings.json.
#
# Requires: lib/utils.sh + lib/output.sh sourced (and lib/layer-probe.sh
# if S2 needs probe-driven routing — caller passes the probe JSON in).

# ─────────────────────────────────────────────────────────────────────
# S1 — Size breach (spec § 3.S1)
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_S1 ABSOLUTE_FILE SOURCE_FILE
#   ABSOLUTE_FILE is the path to read; SOURCE_FILE is the relative path
#   used in the finding's source_file field (and fingerprint input).
scanner_rule_S1() {
  local abs_file="$1"
  local source_file="$2"
  local n band severity
  n=$(scanner_wc_chars "$abs_file")
  band=$(scanner_size_band "$n")
  [ "$band" = "under-soft" ] && return 0

  severity=$(scanner_s1_severity_for_band "$band")
  local threshold_value
  threshold_value=$(scanner_size_band_threshold "$band")

  # Compute the 3 largest sections for the substitution.
  #
  # Codex finding #1 (BLOCKER, security): the previous implementation
  # built an awk-internal shell command via string-concatenation of the
  # filename, letting metacharacters in the filename execute during
  # section-size calculation. The fix walks the file once with awk's
  # native input handling — filenames are never interpreted by a shell.
  #
  # LC_ALL=C forces awk to count bytes (not multibyte chars) so
  # `length($0)+1` matches the original `wc -c` semantics across
  # macOS BWK awk and gawk.
  local largest_sections_json
  largest_sections_json=$(
    LC_ALL=C awk '
      BEGIN { fence = 0; n_open = 0 }
      # Code-fence toggle line: still counts toward open sections.
      /^[[:space:]]*```/ {
        fence = 1 - fence
        for (i = 0; i < n_open; i++) { sec_chars[i] += length($0) + 1 }
        next
      }
      # H3 heading: closes any H3 currently open (a new H3 ends the
      # previous H3 body but does not close enclosing H2 sections).
      fence == 0 && /^### / {
        while (n_open > 0 && sec_level[n_open - 1] >= 3) {
          printf "%d\t%s\n", sec_chars[n_open - 1], sec_title[n_open - 1]
          n_open--
        }
        title = $0; sub(/^### /, "", title)
        sec_level[n_open] = 3
        sec_title[n_open] = title
        sec_chars[n_open] = 0
        n_open++
        next
      }
      # H2 heading: closes ALL open sections (H2 and H3).
      fence == 0 && /^## / {
        while (n_open > 0) {
          printf "%d\t%s\n", sec_chars[n_open - 1], sec_title[n_open - 1]
          n_open--
        }
        title = $0; sub(/^## /, "", title)
        sec_level[n_open] = 2
        sec_title[n_open] = title
        sec_chars[n_open] = 0
        n_open++
        next
      }
      # Body line: every open section accumulates this line.
      {
        for (i = 0; i < n_open; i++) { sec_chars[i] += length($0) + 1 }
      }
      END {
        while (n_open > 0) {
          printf "%d\t%s\n", sec_chars[n_open - 1], sec_title[n_open - 1]
          n_open--
        }
      }
    ' "$abs_file" \
      | sort -rn -t$'\t' -k1 \
      | head -3 \
      | awk -F'\t' -v total="$n" '
          BEGIN { printf "[" }
          NR > 1 { printf "," }
          {
            pct = (total > 0) ? ($1 * 100.0 / total) : 0
            gsub(/\\/, "\\\\", $2); gsub(/"/, "\\\"", $2)
            printf "{\"name\":\"%s\",\"char_count\":%d,\"pct\":%.1f}", $2, $1, pct
          }
          END { printf "]" }
        '
  )
  [ -z "$largest_sections_json" ] && largest_sections_json='[]'

  local subs
  subs=$(jq -nc \
    --argjson n_chars "$n" \
    --arg threshold_band "$band" \
    --argjson threshold_value "$threshold_value" \
    --argjson largest_sections "$largest_sections_json" \
    '{N_chars: $n_chars, threshold_band: $threshold_band, threshold_value: $threshold_value, largest_sections: $largest_sections}')

  local action
  action=$(scanner_action_json move_to_layer "claudedocs" true false "")

  scanner_emit_finding \
    "S1" "structural" "$severity" "Size breach" \
    "$source_file" "<root>" \
    "$(scanner_norm_subject_S1 "$n")" \
    "$subs" "$action" \
    "[Acknowledge — file is intentionally this size]"
}

# ─────────────────────────────────────────────────────────────────────
# S2 — Layer violation (spec § 3.S2)
# ─────────────────────────────────────────────────────────────────────

# _scanner_S2_section_scores ABSOLUTE_FILE START_LINE
#   Echoes "decision_log_score|architecture_score|narrative_score|narrative_para_count".
_scanner_S2_section_scores() {
  local file="$1"
  local start="$2"
  local body
  body=$(scanner_section_body "$file" "$start")
  # Get the heading title text
  local title
  title=$(awk -v start="$start" 'NR == start { sub(/^### /, "", $0); sub(/^## /, "", $0); print; exit }' "$file")
  local title_lc
  title_lc=$(scanner_lower "$title")

  # Decision-log shape
  local d_score=0
  echo "$title_lc" | grep -qE '\b(decision|decisions|choice|choices|rationale|decided)\b' && d_score=$((d_score + 3))
  local d_dates
  d_dates=$(printf '%s\n' "$body" | grep -cE '\[[0-9]{4}-[0-9]{2}-[0-9]{2}\]' || true)
  [ "$d_dates" -gt 3 ] && d_dates=3
  d_score=$((d_score + d_dates * 2))
  local d_headers
  d_headers=$(printf '%s\n' "$body" | grep -cE '\*\*Decision [0-9]+:|^### Decision|\*\*Decided:|\*\*Choice [0-9]+:' || true)
  [ "$d_headers" -gt 3 ] && d_headers=3
  d_score=$((d_score + d_headers * 2))

  # Architecture/schema shape
  #
  # Codex finding #4: pure pointer/navigation tables (Where-to-Look,
  # Release Process runbook tables) fired S2 because table-row count
  # alone scored ≥5. Two-part gate to suppress these false-positives
  # while still catching real schema/architecture tables:
  #
  #   (a) Count rows whose 2nd column starts with `code` or a
  #       [link](...) — those are navigation-shape rows (link →
  #       description, not field → type).
  #   (b) Count occurrences of schema-like terms — `type`, `schema`,
  #       `interface`, `field`, `property`, `enum` — in the body OR
  #       schema-keyword in the title.
  #
  # Skip the table-row contribution entirely when EITHER:
  #   - schema-term count < 2 AND no schema-keyword title (avoids
  #     incidental single mentions like "version: field" in a
  #     navigation row), OR
  #   - the navigation-shape row count is at least half the data rows
  #     (the table is dominantly link-shaped).
  #
  # Code-block contributions (JSON, YAML, TypeScript, proto) keep
  # firing regardless: those formats are inherently schema-like.
  local a_score=0
  local schema_term_count
  schema_term_count=$(printf '%s\n' "$body" | grep -ciE '\b(type|schema|interface|field|property|enum)\b' || true)
  local title_has_schema_kw=0
  echo "$title_lc" | grep -qE '\b(schema|architecture|data model|entities)\b' && title_has_schema_kw=1

  local a_rows
  a_rows=$(printf '%s\n' "$body" | grep -cE '^\|.*\|' || true)
  [ "$a_rows" -gt 8 ] && a_rows=8

  local nav_rows
  nav_rows=$(printf '%s\n' "$body" | awk '
    /^\|/ {
      if ($0 ~ /^\|[[:space:]]*[-:]+[[:space:]]*\|/) next
      n = split($0, cols, "|")
      if (n < 3) next
      col2 = cols[3]
      sub(/^[[:space:]]+/, "", col2); sub(/[[:space:]]+$/, "", col2)
      if (col2 ~ /^`/ || col2 ~ /^\[/) count++
    }
    END { print count + 0 }
  ')

  local data_rows=$a_rows
  [ "$data_rows" -gt 0 ] && data_rows=$((a_rows - 1))  # exclude header row roughly

  local count_table_rows=1
  if [ "$schema_term_count" -lt 2 ] && [ "$title_has_schema_kw" = "0" ]; then
    count_table_rows=0
  elif [ "$data_rows" -gt 0 ] && [ "$((nav_rows * 2))" -ge "$data_rows" ]; then
    count_table_rows=0
  fi

  if [ "$count_table_rows" = "1" ]; then
    a_score=$((a_score + a_rows))
  fi

  local a_blocks
  a_blocks=$(printf '%s\n' "$body" | awk '
    BEGIN { fence=0; lang=""; lines=0; matched=0 }
    /^[[:space:]]*```/ {
      if (fence == 0) {
        sub(/^[[:space:]]*```/, "", $0)
        lang = tolower($0); fence = 1; lines = 0
      } else {
        if (lang ~ /^(json|yaml|typescript|proto)/ && lines >= 5) matched++
        fence = 0
      }
      next
    }
    fence == 1 { lines++ }
    END { print matched }
  ')
  a_score=$((a_score + a_blocks * 3))
  echo "$title_lc" | grep -qE '\b(schema|architecture|data model|entities)\b' && a_score=$((a_score + 2))

  # Narrative shape
  local n_score=0
  local n_paras
  n_paras=$(printf '%s\n' "$body" | awk '
    BEGIN { fence=0; in_para=0; cur=""; consecutive=0; max_consec=0 }
    /^[[:space:]]*```/ { fence=1-fence; in_para=0; cur=""; consecutive=0; next }
    fence == 1 { next }
    /^[[:space:]]*$/ {
      if (in_para && length(cur) > 200 && cur !~ /^\|/ && cur !~ /^[*-] / && cur !~ /^[0-9]+\. /) {
        consecutive++
        if (consecutive > max_consec) max_consec = consecutive
      } else { consecutive = 0 }
      in_para=0; cur=""; next
    }
    { if (in_para) cur = cur " " $0; else { cur = $0; in_para=1 } }
    END {
      if (in_para && length(cur) > 200 && cur !~ /^\|/ && cur !~ /^[*-] / && cur !~ /^[0-9]+\. /) {
        consecutive++
        if (consecutive > max_consec) max_consec = consecutive
      }
      print max_consec
    }
  ')
  local capped_paras=$n_paras
  [ "$capped_paras" -gt 5 ] && capped_paras=5
  n_score=$((n_score + capped_paras))
  echo "$title_lc" | grep -qE '\b(incident|narrative|story|history|background)\b' && n_score=$((n_score + 2))

  printf '%s|%s|%s|%s' "$d_score" "$a_score" "$n_score" "$n_paras"
}

# scanner_rule_S2 ABSOLUTE_FILE SOURCE_FILE LAYER_PROBE_JSON
scanner_rule_S2() {
  local abs_file="$1"
  local source_file="$2"
  local probe="${3:-{\}}"

  scanner_list_h2_h3 "$abs_file" | while IFS=: read -r line_no _level title_rest; do
    local title="${title_rest}"
    [ -z "$line_no" ] && continue
    [ -z "$title" ] && continue

    local scores
    scores=$(_scanner_S2_section_scores "$abs_file" "$line_no")
    local d_score a_score n_score n_paras
    d_score=${scores%%|*}; scores=${scores#*|}
    a_score=${scores%%|*}; scores=${scores#*|}
    n_score=${scores%%|*}; n_paras=${scores#*|}

    local pattern target_content_type fired=0
    local best_score=0
    if [ "$d_score" -ge 4 ] && [ "$d_score" -gt "$best_score" ]; then
      pattern="decision-log-shape"; target_content_type="decision_log"; best_score=$d_score; fired=1
    fi
    if [ "$a_score" -ge 5 ] && [ "$a_score" -gt "$best_score" ]; then
      pattern="schema-or-architecture-shape"; target_content_type="architecture_facts"; best_score=$a_score; fired=1
    fi
    if [ "$n_score" -ge 4 ] && [ "$n_paras" -ge 3 ] && [ "$n_score" -gt "$best_score" ]; then
      pattern="narrative-paragraph-shape"; target_content_type="reference_material"; best_score=$n_score; fired=1
    fi
    [ "$fired" -eq 0 ] && continue

    local dest fallback_used="false" available="true"
    dest=$(scanner_destination_for "$probe" "$target_content_type")
    if [ -z "$dest" ]; then
      available="false"; fallback_used="true"; dest="keep-in-claude-md"
    fi

    local subs
    subs=$(jq -nc \
      --arg pattern "$pattern" \
      --arg section "$title" \
      --argjson score "$best_score" \
      --arg content_type "$target_content_type" \
      '{detected_pattern: $pattern, section: $section, score: $score, content_type: $content_type}')

    local action
    action=$(scanner_action_json move_to_layer "$dest" "$available" "$fallback_used" "")

    local section_anchor
    section_anchor=$(scanner_slug "$title")
    [ -z "$section_anchor" ] && section_anchor="unnamed-section"

    scanner_emit_finding \
      "S2" "structural" "warn" "Layer violation" \
      "$source_file" "$section_anchor" \
      "$(scanner_norm_subject_S2 "$title" "$pattern")" \
      "$subs" "$action" \
      "[Acknowledge — keep inline for this project]"
  done
}

# ─────────────────────────────────────────────────────────────────────
# S3 — Stale entries (broken paths + removed features), spec § 3.S3
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_S3 ABSOLUTE_FILE SOURCE_FILE PROJECT_ROOT [COMPANION_PATHS]
#   COMPANION_PATHS is a newline-separated list of relative paths to
#   exclude from the existence-grep (per Codex re-review fix). Empty if
#   no companions.
scanner_rule_S3() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"
  local companions="${4:-}"

  # Part A — broken paths
  # Strip fenced code blocks first, then grep for relative-path-with-extension.
  local paths
  paths=$(awk '
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence != 1 { print }
  ' "$abs_file" \
    | grep -oE '(\.\/|\.[a-zA-Z0-9_-]+\/|[a-zA-Z0-9_-]+\/)[a-zA-Z0-9_./-]+\.(md|sh|py|js|ts|tsx|jsx|yml|yaml|toml|json)' \
    | grep -vE '^/(usr|bin|opt|home|tmp|var|etc|root|sbin|lib)/' \
    | grep -vE '^https?://' \
    | grep -vE '<[^>]+>' \
    | grep -vE '\{[^}]+\}' \
    | grep -vE '(^|/)(\.git|node_modules|\.venv|__pycache__)/' \
    | sort -u)

  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
      ./*) p_strip="${p#./}" ;;
      *)   p_strip="$p" ;;
    esac
    if [ ! -e "$project_root/$p_strip" ] && [ ! -e "$project_root/$p" ]; then
      # Find the section anchor where the path appears
      local section_anchor="unknown"
      local first_hit
      first_hit=$(grep -nF "$p" "$abs_file" | head -1 | cut -d: -f1)
      if [ -n "$first_hit" ]; then
        section_anchor=$(_scanner_section_for_line "$abs_file" "$first_hit")
      fi
      local subs action
      subs=$(jq -nc --arg path "$p" '{broken_path: $path}')
      action=$(scanner_action_json remove "" false false "")
      scanner_emit_finding \
        "S3" "structural" "warn" "Stale entries" \
        "$source_file" "$section_anchor" \
        "$(scanner_norm_subject_S3 "$p")" \
        "$subs" "$action" \
        "[Acknowledge — keep for archival reasons]"
    fi
  done <<EOF
$paths
EOF

  # Part B — removed-feature detection (flags, env vars, function names)
  local candidates
  candidates=$(awk '
    BEGIN { fence = 0 }
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence == 1 { next }
    {
      line = $0
      # Inline code spans first: classify each span as FLAG / ENVVAR /
      # FUNC depending on its shape so the per-kind dedup + filters
      # downstream can apply.
      while (match(line, /`[^`]+`/)) {
        seg = substr(line, RSTART + 1, RLENGTH - 2)
        if (seg ~ /^--[a-z]/) {
          print "FLAG\t" seg
        } else if (seg ~ /^\$/) {
          envseg = seg
          gsub(/^\$\{|\}$/, "", envseg); gsub(/^\$/, "", envseg)
          print "ENVVAR\t" envseg
        } else if (seg ~ /^[a-z_][a-z0-9_-]*\(/) {
          print "FUNC\t" seg
        }
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
      # Bare matches outside inline code spans
      while (match(line, /--[a-z][a-z0-9-]+/)) {
        print "FLAG\t" substr(line, RSTART, RLENGTH)
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
      while (match(line, /\$\{?[A-Z][A-Z0-9_]+\}?/)) {
        seg = substr(line, RSTART, RLENGTH)
        gsub(/^\$\{|\}$/, "", seg); gsub(/^\$/, "", seg)
        print "ENVVAR\t" seg
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
    }
  ' "$abs_file" | sort -u)

  # POSIX-flag deny-list
  local _posix_flags=" -h -v -x -l -r -a -A -e -f -n -p -s -t -i -d "
  while IFS=$'\t' read -r kind candidate; do
    [ -z "$candidate" ] && continue
    case "$kind" in
      FLAG)
        # Skip POSIX flags and short single-letter options
        case " $_posix_flags " in *" $candidate "*) continue ;; esac
        [ ${#candidate} -lt 4 ] && continue   # under 3 alnum chars after --
        ;;
      ENVVAR)
        [ ${#candidate} -lt 3 ] && continue
        # Skip very common shell vars
        case "$candidate" in PATH|HOME|USER|SHELL|TMPDIR|PWD|OLDPWD) continue ;; esac
        ;;
      FUNC)
        # FUNC came from an inline code span like `name()`. Strip parens.
        candidate="${candidate%%(*}"
        [ ${#candidate} -lt 3 ] && continue
        echo "$candidate" | grep -qE '^[a-z_][a-z0-9_-]*$' || continue
        ;;
      *) continue ;;
    esac

    # Build the exclusion list for grep: the target file + companions +
    # the scanner's own exception file (meta — references to candidate
    # tokens in `.scanner-exceptions.json` are findings about findings,
    # not "is this feature implemented" evidence).
    local exclude_args=( "--exclude-dir=.git" "--exclude-dir=node_modules" \
                         "--exclude-dir=.venv" "--exclude-dir=__pycache__" \
                         "--exclude=.scanner-exceptions.json" )
    # Run the grep across source files
    local hits
    hits=$(grep -rE --include='*.sh' --include='*.bash' --include='*.zsh' \
                    --include='*.py' --include='*.js' --include='*.ts' \
                    --include='*.go' --include='*.rb' --include='*.toml' \
                    --include='*.yml' --include='*.yaml' --include='*.json' \
                    "${exclude_args[@]}" \
                    -F -- "$candidate" "$project_root" 2>/dev/null | \
            grep -vF "${abs_file}:" || true)
    # Also exclude companion files
    if [ -n "$companions" ]; then
      while IFS= read -r comp; do
        [ -z "$comp" ] && continue
        hits=$(echo "$hits" | grep -vF "${project_root}/${comp}:" || true)
      done <<EOC
$companions
EOC
    fi

    if [ -z "$hits" ]; then
      local section_anchor="unknown"
      local first_hit
      first_hit=$(grep -nF "$candidate" "$abs_file" | head -1 | cut -d: -f1)
      if [ -n "$first_hit" ]; then
        section_anchor=$(_scanner_section_for_line "$abs_file" "$first_hit")
      fi
      local subs action
      subs=$(jq -nc --arg cand "$candidate" --arg kind "$kind" \
        '{candidate: $cand, candidate_kind: $kind}')
      action=$(scanner_action_json remove "" false false "")
      scanner_emit_finding \
        "S3" "structural" "warn" "Stale entries" \
        "$source_file" "$section_anchor" \
        "$(scanner_norm_subject_S3 "$candidate")" \
        "$subs" "$action" \
        "[Acknowledge — keep for archival reasons]"
    fi
  done <<EOF
$candidates
EOF
}

# _scanner_section_for_line FILE LINE_NO
#   Echoes the slugified heading title that contains LINE_NO, or "<root>"
#   if the line precedes the first heading.
_scanner_section_for_line() {
  local file="$1"
  local line_no="$2"
  local title
  title=$(scanner_list_h2_h3 "$file" | awk -F: -v target="$line_no" '
    {
      if ($1+0 <= target+0) {
        last_title = ""
        for (i = 3; i <= NF; i++) last_title = last_title (i == 3 ? "" : ":") $i
      } else {
        print last_title; printed = 1; exit
      }
    }
    END { if (last_title != "" && !printed) print last_title }
  ')
  if [ -z "$title" ]; then
    echo "<root>"
  else
    scanner_slug "$title"
  fi
}

# ─────────────────────────────────────────────────────────────────────
# S4 — Reactive without positive direction (spec § 3.S4)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_S4() {
  local abs_file="$1"
  local source_file="$2"

  awk '
    BEGIN { fence = 0; in_item = 0; item_text = ""; item_start = 0 }
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence == 1 { next }
    /^[*-] / || /^[0-9]+\. / {
      if (in_item) {
        printf "%d\t%s\n", item_start, item_text
      }
      item_text = $0
      item_start = NR
      in_item = 1
      next
    }
    /^[[:space:]]*$/ {
      if (in_item) {
        printf "%d\t%s\n", item_start, item_text
        in_item = 0; item_text = ""
      }
      next
    }
    in_item == 1 { item_text = item_text " " $0 }
    END {
      if (in_item) printf "%d\t%s\n", item_start, item_text
    }
  ' "$abs_file" | while IFS=$'\t' read -r start text; do
    [ -z "$text" ] && continue
    local lc; lc=$(scanner_lower "$text")
    # Prohibition language? (per spec § 3.S4 — narrow set: never / don't /
    # do not / avoid / must not)
    case "$lc" in
      *never*|*"don't"*|*"do not"*|*avoid*|*"must not"*|*"shouldn't"*) ;;
      *) continue ;;
    esac
    # Positive direction within same item?
    case "$lc" in
      *instead*|*"do {"*|*"use the"*|*"use a "*|*"prefer "*|*"choose "*|*"replace with"*) continue ;;
    esac
    # Skip very short items (likely fragments)
    local words
    words=$(echo "$text" | wc -w | tr -d ' ')
    [ "$words" -lt 6 ] && continue

    local section_anchor
    section_anchor=$(_scanner_section_for_line "$abs_file" "$start")
    local prohibition_60
    prohibition_60=$(scanner_norm_subject_S4 "$text")
    local subs action
    subs=$(jq -nc --arg t "$text" --argjson line "$start" \
      '{rule_text: $t, line: $line}')
    action=$(scanner_action_json draft_positive_direction "" false false "")
    scanner_emit_finding \
      "S4" "structural" "info" "Reactive without positive direction" \
      "$source_file" "$section_anchor" \
      "$prohibition_60" \
      "$subs" "$action" \
      "[Mark as accepted exception — this rule is genuinely just a prohibition]"
  done
}

# ─────────────────────────────────────────────────────────────────────
# S5 — Provisional Guard expiry (spec § 3.S5)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_S5() {
  local abs_file="$1"
  local source_file="$2"

  # Find the Provisional Guards section (heading containing "provisional")
  local pg_line
  pg_line=$(scanner_list_h2_h3 "$abs_file" \
    | awk -F: '{ title=""; for(i=3;i<=NF;i++) title=title (i==3?"":":") $i; if (tolower(title) ~ /provisional/) { print $1; exit } }')
  [ -z "$pg_line" ] && return 0

  # Get the body, find subsections with Review: dates
  local today_epoch
  today_epoch=$(date +%s)
  local fourteen_days=$((14 * 86400))

  scanner_section_body "$abs_file" "$pg_line" \
    | awk -v today="$today_epoch" -v gate="$fourteen_days" '
        BEGIN { current_guard = "" }
        /^### / {
          current_guard = $0; sub(/^### /, "", current_guard)
          next
        }
        /[Rr]eview[[:space:]*]*:|review:/ {
          line = $0
          if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
            date_str = substr(line, RSTART, RLENGTH)
            cmd = "date -j -f \"%Y-%m-%d\" \"" date_str "\" \"+%s\" 2>/dev/null || date -d \"" date_str "\" \"+%s\" 2>/dev/null"
            cmd | getline review_epoch; close(cmd)
            if (review_epoch != "") {
              days = (review_epoch - today) / 86400
              if (review_epoch <= today) {
                printf "%s\t%s\tpast\t%d\n", current_guard, date_str, int(-days)
              } else if ((review_epoch - today) <= gate) {
                printf "%s\t%s\tnear\t%d\n", current_guard, date_str, int(days)
              }
            }
          }
        }
      ' \
    | while IFS=$'\t' read -r guard date status days; do
        [ -z "$guard" ] && continue
        local subs action
        subs=$(jq -nc --arg g "$guard" --arg d "$date" --arg s "$status" --argjson dy "$days" \
          '{guard_name: $g, review_date: $d, status: $s, days: $dy}')
        action=$(scanner_action_json extend_or_graduate "" false false "")
        scanner_emit_finding \
          "S5" "structural" "info" "Provisional Guard expiry" \
          "$source_file" "$(scanner_slug "$guard")" \
          "$(scanner_norm_subject_S5 "$guard")" \
          "$subs" "$action" \
          "[Defer — review next session]"
      done
}

# ─────────────────────────────────────────────────────────────────────
# S6 — Inline shell (spec § 3.S6)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_S6() {
  local abs_file="$1"
  local source_file="$2"

  awk '
    BEGIN { fence = 0; lang = ""; start = 0; line_count = 0; annotated = 0 }
    /^[[:space:]]*```/ {
      if (fence == 0) {
        sub(/^[[:space:]]*```/, "", $0)
        lang = tolower($0); fence = 1; start = NR; line_count = 0; annotated = 0
      } else {
        if (lang ~ /^(bash|sh|shell|zsh)([[:space:]]|$)/ && line_count >= 4 && !annotated) {
          printf "%d\t%d\t%d\n", start, NR, line_count
        }
        fence = 0; lang = ""
      }
      next
    }
    fence == 1 {
      line_count++
      if ($0 ~ /# example only|# docs-only|# illustrative/) annotated = 1
    }
  ' "$abs_file" | while IFS=$'\t' read -r start_line end_line lines; do
    [ -z "$start_line" ] && continue
    local section_anchor
    section_anchor=$(_scanner_section_for_line "$abs_file" "$start_line")
    local subs action
    subs=$(jq -nc --argjson sl "$start_line" --argjson el "$end_line" --argjson lines "$lines" \
      '{start_line: $sl, end_line: $el, line_count: $lines}')
    action=$(scanner_action_json move_to_layer "scripts" true false "")
    scanner_emit_finding \
      "S6" "structural" "info" "Inline shell" \
      "$source_file" "$section_anchor" \
      "$(scanner_norm_subject_S6 "$start_line" "$end_line")" \
      "$subs" "$action" \
      "[Acknowledge — keep inline for visibility]"
  done
}

# ─────────────────────────────────────────────────────────────────────
# S7 — Re-asserted skill behavior (spec § 3.S7)
# ─────────────────────────────────────────────────────────────────────

# scanner_rule_S7 ABSOLUTE_FILE SOURCE_FILE [SKILLS_LIST_NEWLINE_SEP]
#   SKILLS_LIST defaults to scanning ~/.claude/skills/ for installed
#   skill names if not provided.
#
# Codex finding #3: the previous implementation spawned 4 subprocesses
# per skill (~78 skills typical) just for matching, dominating the
# 100K-fixture scan with ~420ms of S7 overhead. This rewrite collapses
# the per-skill loop into a single awk pass that reads skill names
# from stdin and walks the first 50 lines of the target file once.
# Subshells are spawned only for headings that match (very rare path).
scanner_rule_S7() {
  local abs_file="$1"
  local source_file="$2"
  local skills="${3:-}"

  if [ -z "$skills" ] && [ -d "$HOME/.claude/skills" ]; then
    skills=$(ls -1 "$HOME/.claude/skills/" 2>/dev/null)
  fi
  [ -z "$skills" ] && return 0

  # Single awk pass: read skill names from stdin, then walk the first
  # 50 lines of the target file. For each heading, check (in awk) every
  # skill name via index() against the lowercased heading text. Output
  # matches as "<line_no>\t<skill_name>" — bash iterates only the
  # matched headings (which is empty for most files).
  local matches
  matches=$(printf '%s\n' "$skills" | LC_ALL=C awk -v file="$abs_file" '
    { skill_lc[NR] = tolower($0); skill_orig[NR] = $0; n_skills = NR }
    END {
      lineno = 0
      while ((getline line < file) > 0) {
        lineno++
        if (lineno > 50) break
        if (line !~ /^#+[[:space:]]/) continue
        h = tolower(line); sub(/^#+[[:space:]]+/, "", h)
        for (i = 1; i <= n_skills; i++) {
          if (skill_lc[i] != "" && index(h, skill_lc[i]) > 0) {
            printf "%d\t%s\n", lineno, skill_orig[i]
            break
          }
        }
      }
      close(file)
    }
  ')
  [ -z "$matches" ] && return 0

  # Rare path: matched headings get the section-body behavioral check.
  while IFS=$'\t' read -r heading_line skill; do
    [ -z "$heading_line" ] && continue
    local body
    body=$(scanner_section_body "$abs_file" "$heading_line")
    case "$(scanner_lower "$body")" in
      *always*|*never*|*"must "*|*"should "*) ;;
      *) continue ;;
    esac
    local subs action
    subs=$(jq -nc --arg s "$skill" '{skill_name: $s}')
    action=$(scanner_action_json remove "" false false "")
    scanner_emit_finding \
      "S7" "structural" "info" "Re-asserted skill behavior" \
      "$source_file" "$(scanner_slug "$skill")" \
      "$(scanner_norm_subject_S7 "$skill")" \
      "$subs" "$action" \
      "[Acknowledge — kept intentionally for visibility]"
  done <<EOF
$matches
EOF
}

# ─────────────────────────────────────────────────────────────────────
# S8 — `@` imports of large files (spec § 3.S8)
# ─────────────────────────────────────────────────────────────────────

scanner_rule_S8() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"

  grep -nE '^@[^[:space:]]+' "$abs_file" 2>/dev/null | while IFS=: read -r line_no rest; do
    local path
    path=$(echo "$rest" | sed -E 's/^@//' | awk '{print $1}')
    [ -z "$path" ] && continue
    local resolved_path="$path"
    case "$path" in
      /*) ;;
      *) resolved_path="$project_root/$path" ;;
    esac
    [ ! -r "$resolved_path" ] && continue
    local size
    size=$(scanner_wc_chars "$resolved_path")
    [ "$size" -lt 2048 ] && continue

    local section_anchor
    section_anchor=$(_scanner_section_for_line "$abs_file" "$line_no")
    local subs action
    subs=$(jq -nc --arg p "$path" --argjson n "$size" \
      '{import_path: $p, size_chars: $n}')
    action=$(scanner_action_json convert_to_pointer "" false false "")
    scanner_emit_finding \
      "S8" "structural" "info" "\`@\` imports of large files" \
      "$source_file" "$section_anchor" \
      "$(scanner_norm_subject_S8 "$path")" \
      "$subs" "$action" \
      "[Acknowledge — file is small enough OR genuinely needed every session]"
  done
}

# ─────────────────────────────────────────────────────────────────────
# Convenience entry: run all S1-S8
# ─────────────────────────────────────────────────────────────────────

# scanner_run_structural ABS_FILE SOURCE_FILE PROJECT_ROOT LAYER_PROBE_JSON [COMPANION_PATHS] [SKILLS]
scanner_run_structural() {
  local abs_file="$1"
  local source_file="$2"
  local project_root="$3"
  local probe="$4"
  local companions="${5:-}"
  local skills="${6:-}"

  scanner_rule_S1 "$abs_file" "$source_file"
  scanner_rule_S2 "$abs_file" "$source_file" "$probe"
  scanner_rule_S3 "$abs_file" "$source_file" "$project_root" "$companions"
  scanner_rule_S4 "$abs_file" "$source_file"
  scanner_rule_S5 "$abs_file" "$source_file"
  scanner_rule_S6 "$abs_file" "$source_file"
  scanner_rule_S7 "$abs_file" "$source_file" "$skills"
  scanner_rule_S8 "$abs_file" "$source_file" "$project_root"
}
