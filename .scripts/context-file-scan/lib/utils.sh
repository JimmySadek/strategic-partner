#!/usr/bin/env bash
# .scripts/context-file-scan/lib/utils.sh
# Shared helpers for the context-file scanner.
# Sourceable — defines functions only; no top-level side effects.
# Bash 3.2 compatible (macOS default): no associative arrays, no namerefs,
# no `${var,,}` / `${var^^}`.

# ─────────────────────────────────────────────────────────────────────
# Char counting
# ─────────────────────────────────────────────────────────────────────

# scanner_wc_chars FILE
#   Echoes the byte count of FILE (treated as char count for ASCII/UTF-8).
#   Wraps `wc -c` to strip whitespace and handle absent files (echoes 0).
scanner_wc_chars() {
  local file="$1"
  if [ ! -r "$file" ]; then
    echo 0
    return 0
  fi
  wc -c <"$file" | tr -d ' \t\n'
}

# ─────────────────────────────────────────────────────────────────────
# Lowercasing + slug normalization (bash-3.2 safe)
# ─────────────────────────────────────────────────────────────────────

# scanner_lower TEXT...
#   Echoes lowercase form. Uses `tr` (bash 3.2 has no `${var,,}`).
scanner_lower() {
  printf '%s' "$*" | tr 'A-Z' 'a-z'
}

# scanner_slug TEXT...
#   Lowercase, ASCII letters/digits/dash-only slug. Spaces and punctuation
#   collapse to dashes; multiple dashes collapse to one; leading/trailing
#   dashes are stripped. Used by the normalized-subject helpers below.
scanner_slug() {
  printf '%s' "$*" \
    | tr 'A-Z' 'a-z' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# scanner_collapse_ws TEXT...
#   Collapses runs of whitespace to single spaces; trims ends.
scanner_collapse_ws() {
  printf '%s' "$*" | tr '\t\r\n' '   ' | sed -E 's/  +/ /g; s/^ +//; s/ +$//'
}

# ─────────────────────────────────────────────────────────────────────
# Section parsing
# ─────────────────────────────────────────────────────────────────────

# scanner_list_h2_h3 FILE
#   Emits one heading per line: "<line_no>:<level>:<title>" where
#   level is 2 or 3 (matching ## or ### at start of line). Code-fenced
#   headings are skipped — fenced blocks bracketed by ``` are ignored.
scanner_list_h2_h3() {
  local file="$1"
  [ -r "$file" ] || return 0
  awk '
    BEGIN { fence = 0 }
    /^[[:space:]]*```/ { fence = 1 - fence; next }
    fence == 1 { next }
    /^### / { sub(/^### /, "", $0); printf "%d:3:%s\n", NR, $0; next }
    /^## /  { sub(/^## /, "", $0);  printf "%d:2:%s\n", NR, $0; next }
  ' "$file"
}

# scanner_section_body FILE LINE_NO
#   Echoes the body of the section whose heading is at LINE_NO. Body
#   ends at the next ## or ### heading at or above the section's level,
#   or at end-of-file. Fenced blocks inside the section are preserved.
scanner_section_body() {
  local file="$1"
  local start="$2"
  [ -r "$file" ] || return 0
  awk -v start="$start" '
    BEGIN { fence = 0; in_section = 0 }
    NR == start {
      if ($0 ~ /^### /) { lvl = 3 }
      else if ($0 ~ /^## /) { lvl = 2 }
      else { lvl = 0 }
      in_section = 1
      next
    }
    in_section == 1 {
      if ($0 ~ /^[[:space:]]*```/) { fence = 1 - fence; print; next }
      if (fence == 0) {
        if (lvl == 2 && $0 ~ /^## /)  { exit }
        if (lvl == 3 && ($0 ~ /^## / || $0 ~ /^### /)) { exit }
      }
      print
    }
  ' "$file"
}

# scanner_section_char_count FILE LINE_NO
#   Char count of the section body at LINE_NO.
scanner_section_char_count() {
  local file="$1"
  local start="$2"
  scanner_section_body "$file" "$start" | wc -c | tr -d ' \t\n'
}

# ─────────────────────────────────────────────────────────────────────
# Fenced-code-block detection
# ─────────────────────────────────────────────────────────────────────

# scanner_in_fenced_block FILE LINE_NO
#   Echoes "yes" if LINE_NO falls inside a ```-fenced block, else "no".
scanner_in_fenced_block() {
  local file="$1"
  local target="$2"
  [ -r "$file" ] || { echo no; return 0; }
  awk -v target="$target" '
    BEGIN { fence = 0 }
    /^[[:space:]]*```/ { fence = 1 - fence; if (NR == target) { print "yes"; exit } next }
    NR == target { print (fence == 1 ? "yes" : "no"); exit }
  ' "$file"
}

# ─────────────────────────────────────────────────────────────────────
# Normalized subject per rule (spec § 1.4 canonical table)
# ─────────────────────────────────────────────────────────────────────

# scanner_norm_subject_S1 N_CHARS
scanner_norm_subject_S1() {
  printf 'size-%s' "$1"
}

# scanner_norm_subject_S2 SECTION_HEADING DETECTED_PATTERN
scanner_norm_subject_S2() {
  printf '%s-%s' "$(scanner_slug "$1")" "$(scanner_slug "$2")"
}

# scanner_norm_subject_S3 PATH_OR_FEATURE
scanner_norm_subject_S3() {
  scanner_slug "$1"
}

# scanner_norm_subject_S4 PROHIBITION_TEXT
#   First 60 chars of prohibition, lowercased, whitespace-collapsed.
scanner_norm_subject_S4() {
  local text
  text=$(scanner_collapse_ws "$1" | tr 'A-Z' 'a-z')
  printf '%s' "${text:0:60}"
}

# scanner_norm_subject_S5 GUARD_NAME
scanner_norm_subject_S5() {
  scanner_slug "$1"
}

# scanner_norm_subject_S6 START_LINE END_LINE
scanner_norm_subject_S6() {
  printf 'lines-%s-%s' "$1" "$2"
}

# scanner_norm_subject_S7 SKILL_NAME
scanner_norm_subject_S7() {
  scanner_slug "$1"
}

# scanner_norm_subject_S8 IMPORT_PATH
scanner_norm_subject_S8() {
  scanner_slug "$1"
}

# scanner_norm_subject_B1 SECTION_NAME
scanner_norm_subject_B1() {
  printf 'missing-%s' "$(scanner_slug "${1:-behavioral-baseline}")"
}

# scanner_norm_subject_B2_B3 STUB_STATE RULES_STATE
#   STUB_STATE in {present, missing}; RULES_STATE in {present, missing}.
scanner_norm_subject_B2_B3() {
  printf 'stub-%s-rules-%s' "$1" "$2"
}

# scanner_norm_subject_B4
scanner_norm_subject_B4() {
  printf 'inlined-instead-of-hybrid'
}

# scanner_norm_subject_B5 RULE_NAME
scanner_norm_subject_B5() {
  scanner_slug "$1"
}

# scanner_norm_subject_B6 RULE_NAME ENFORCEABILITY_CATEGORY
scanner_norm_subject_B6() {
  printf '%s--%s' "$(scanner_slug "$1")" "$(scanner_slug "$2")"
}

# scanner_norm_subject_B7 RULE_NAME LOC1[,LOC2,...]
#   Locations are sorted+joined; rule name appended.
scanner_norm_subject_B7() {
  local rule="$1"; shift
  local sorted
  sorted=$(printf '%s\n' "$@" | sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+//; s/-+$//' | tr 'A-Z' 'a-z' | sort | paste -sd '+' -)
  printf '%s--%s' "$sorted" "$(scanner_slug "$rule")"
}

# scanner_norm_subject_B8 RULE_NAME PRINCIPLE_NAME
scanner_norm_subject_B8() {
  printf '%s--vs-%s' "$(scanner_slug "$1")" "$(scanner_slug "$2")"
}

# ─────────────────────────────────────────────────────────────────────
# Fingerprint computation
# ─────────────────────────────────────────────────────────────────────

# _scanner_sha256
#   Emits sha256 of stdin as hex on stdout. Wraps macOS shasum / Linux
#   sha256sum. Picks whichever is in PATH.
_scanner_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "scanner: no sha256 tool found (need sha256sum or shasum)" >&2
    return 1
  fi
}

# scanner_fingerprint RULE_ID SOURCE_FILE SECTION_ANCHOR NORMALIZED_SUBJECT
#   Echoes 16-hex-char fingerprint per spec § 1.4:
#     sha256(rule_id|source_file|section_anchor|normalized_subject)[:16]
scanner_fingerprint() {
  local rule_id="$1"
  local source_file="$2"
  local section_anchor="$3"
  local normalized_subject="$4"
  printf '%s|%s|%s|%s' "$rule_id" "$source_file" "$section_anchor" "$normalized_subject" \
    | _scanner_sha256 \
    | cut -c1-16
}

# ─────────────────────────────────────────────────────────────────────
# JSON helpers (Bash 3.2 + jq)
# ─────────────────────────────────────────────────────────────────────

# scanner_json_string TEXT
#   Echoes a JSON-quoted string for arbitrary TEXT (handles backslashes,
#   quotes, newlines, control chars). Wraps `jq -Rsa .`.
scanner_json_string() {
  printf '%s' "$1" | jq -Rsa .
}
