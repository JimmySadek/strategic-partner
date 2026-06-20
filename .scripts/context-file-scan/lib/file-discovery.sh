#!/usr/bin/env bash
# .scripts/context-file-scan/lib/file-discovery.sh
# Depth-1 pointer-following for companion context files. Runtime policy lives
# in references/context-file-stewardship.md. Sourceable.
#
# Heuristic: from the primary file's Behavioral-Guardrails section (or
# equivalent — "Behavioral Rules", "Coding Behavior", "Source-Editing
# Rules"), extract any relative .md pointer mentions, deduplicate, resolve
# them under the project root, drop pointers that escape the root or
# don't exist, and emit the surviving companion paths. Companion-file
# pointers are ignored (depth 1 only).
#
# Requires: lib/utils.sh sourced (for scanner_list_h2_h3 + scanner_section_body).

# Headings that mark a behavioral baseline section. Case-insensitive,
# substring match (allows decorative prefixes like emoji or bullet glyphs).
_SCANNER_BG_HEADINGS_RE='(behavioral guardrails|behavioral rules|coding behavior|source.editing rules)'

# scanner_realpath PATH
#   Echoes the canonical absolute path with all symlinks resolved.
#   Empty (and exit 1) on invalid path or symlink loop.
scanner_realpath() {
  local path="$1"
  [ -e "$path" ] || return 1
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path" 2>/dev/null
    return $?
  fi
  # Portable fallback (macOS without coreutils): cd into the parent and
  # use pwd -P for symlink resolution. ELOOP from the OS terminates loops.
  local dir base
  dir=$(dirname -- "$path")
  base=$(basename -- "$path")
  ( cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base" ) || return 1
}

# _scanner_path_under_root ROOT PATH
#   Echoes "yes" if PATH (already canonicalized) is at or under ROOT,
#   else "no". Both must be absolute.
_scanner_path_under_root() {
  local root="$1"
  local path="$2"
  case "$path" in
    "$root"|"$root"/*) echo yes ;;
    *) echo no ;;
  esac
}

# scanner_find_bg_section_line FILE
#   Echoes the line number of the first heading whose text matches the
#   behavioral-baseline pattern. Empty if none found.
scanner_find_bg_section_line() {
  local file="$1"
  [ -r "$file" ] || return 0
  scanner_list_h2_h3 "$file" \
    | awk -F: -v re="$_SCANNER_BG_HEADINGS_RE" '
        {
          title = ""
          for (i = 3; i <= NF; i++) {
            title = title (i == 3 ? "" : ":") $i
          }
          tlower = tolower(title)
          if (tlower ~ re) {
            print $1
            exit
          }
        }
      '
}

# scanner_extract_companion_pointers FILE
#   Emits one raw pointer per line — relative .md paths mentioned in the
#   FILE'\''s behavioral-baseline section body, deduplicated. Empty when
#   there is no BG section or no pointers in it.
#   Pointer shapes recognized:
#     - bare paths in inline code:   `.claude/rules/source-editing.md`
#     - markdown links:              [...](.claude/rules/source-editing.md)
#     - bare relative paths:         .claude/rules/source-editing.md
scanner_extract_companion_pointers() {
  local file="$1"
  [ -r "$file" ] || return 0
  local bg_line
  bg_line=$(scanner_find_bg_section_line "$file")
  [ -z "$bg_line" ] && return 0
  scanner_section_body "$file" "$bg_line" \
    | grep -oE '(\./|\.[a-zA-Z0-9_-]+/)[a-zA-Z0-9_./-]+\.md' \
    | sort -u
}

# scanner_resolve_companion PROJECT_ROOT POINTER
#   Echoes the resolved absolute path under PROJECT_ROOT for the relative
#   POINTER. Exit codes:
#     0  resolved + exists + under root → echo absolute path
#     1  pointer is missing (broken) → echo empty
#     2  pointer escapes project root → echo empty
#     3  pointer is unreadable (perm) → echo empty
scanner_resolve_companion() {
  local root="$1"
  local pointer="$2"
  local candidate="$root/$pointer"

  # If the candidate doesn'\''t exist as written, try one path normalization:
  # strip leading ./ if any, and check again.
  if [ ! -e "$candidate" ]; then
    case "$pointer" in
      ./*) candidate="$root/${pointer#./}" ;;
    esac
  fi

  if [ ! -e "$candidate" ]; then
    return 1
  fi

  local resolved
  resolved=$(scanner_realpath "$candidate")
  [ -z "$resolved" ] && return 1

  # Resolve project root canonically too (for fair string comparison).
  local resolved_root
  resolved_root=$(scanner_realpath "$root")
  [ -z "$resolved_root" ] && return 1

  if [ "$(_scanner_path_under_root "$resolved_root" "$resolved")" != "yes" ]; then
    return 2
  fi

  if [ ! -r "$resolved" ]; then
    return 3
  fi

  printf '%s\n' "$resolved"
}

# scanner_discover_companions PRIMARY_FILE PROJECT_ROOT
#   Emits one resolved-existing companion path per line, relative to
#   PROJECT_ROOT. Skips broken / escaping / unreadable pointers without
#   error (those become B2 findings during structural detection). Depth
#   1 only — companion-file pointers are not followed.
scanner_discover_companions() {
  local primary="$1"
  local root="$2"
  local pointer rel_resolved abs_resolved status
  local resolved_root
  resolved_root=$(scanner_realpath "$root")
  [ -z "$resolved_root" ] && resolved_root="$root"

  # Track unique companions. Bash 3.2: no associative array, use a
  # newline-separated string and grep.
  local seen=""

  while IFS= read -r pointer; do
    [ -z "$pointer" ] && continue
    abs_resolved=$(scanner_resolve_companion "$root" "$pointer")
    status=$?
    [ $status -ne 0 ] && continue
    [ -z "$abs_resolved" ] && continue
    case "$abs_resolved" in
      "$resolved_root"/*) rel_resolved="${abs_resolved#"$resolved_root"/}" ;;
      *) rel_resolved="$abs_resolved" ;;
    esac
    # Dedup
    case $'\n'"$seen"$'\n' in
      *$'\n'"$rel_resolved"$'\n'*) continue ;;
    esac
    seen="$seen"$'\n'"$rel_resolved"
    printf '%s\n' "$rel_resolved"
  done < <(scanner_extract_companion_pointers "$primary")
}
