#!/bin/bash
# ============================================================
# Strategic Partner — Backlog Auto-Migration (v6.4)
#
# Migrates a user's .backlog/*.md items from the pre-v6.4 schema
# (status:, trigger: prose, type:/priority:/severity:/added: at
# top level) to the v6.4 schema (state:, triggers: as a list,
# labels: replacing the type/priority/severity fields).
#
# Idempotent — re-runs after a successful migration are no-ops.
# Safe — pre-migration backup is universal (works regardless of git state).
# When .backlog/ is tracked by git, the script also lands a single atomic
# commit you can revert. When .backlog/ is gitignored (the typical case,
# since most projects treat backlog items as local working state), the
# commit is empty / not created and rollback uses the backup directory
# rather than git.
#
# Usage:
#   .scripts/migrate-backlog.sh           # run the migration
#   .scripts/migrate-backlog.sh --dry-run # preview without writing
#
# Companion docs:
#   - references/backlog-cycle.md
#   - .prompts/v6.4/backlog-cycle-design-spec.md § "Auto-migration"
# ============================================================
set -euo pipefail

START_TIME=$(date +%s)

# --------------------------------------------------
# Argument parsing
# --------------------------------------------------
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# --------------------------------------------------
# Pre-flight: .backlog/ presence
# --------------------------------------------------
if [ ! -d .backlog ]; then
  echo "No .backlog/ directory in $(pwd). Nothing to migrate." >&2
  exit 0
fi

# --------------------------------------------------
# Safety preflight 1: working tree check
# --------------------------------------------------
HAS_GIT=0
if [ -d .git ]; then HAS_GIT=1; fi

if [ "$HAS_GIT" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
  DIRTY="$(git status --porcelain 2>/dev/null || true)"
  if [ -n "$DIRTY" ]; then
    echo "Working tree has uncommitted changes." >&2
    echo "Stage and commit, or stash, before running migration." >&2
    exit 1
  fi
fi

# --------------------------------------------------
# Safety preflight 2: git repo mode signal
# --------------------------------------------------
COMMIT_MODE=1
if [ "$HAS_GIT" -eq 0 ]; then
  COMMIT_MODE=0
  echo "Warning: not inside a git repository — running in no-commit mode."
  echo "Rollback path will be the pre-migration backup directory."
fi

# --------------------------------------------------
# Safety preflight 4: archive scope note
# --------------------------------------------------
echo "Archive scope: .backlog/*.md only. .handoffs/backlog-archive/ is intentionally untouched."

# --------------------------------------------------
# Detection: list old-schema items
# --------------------------------------------------
OLD_SCHEMA_FILES=()
for f in .backlog/*.md; do
  [ -e "$f" ] || continue
  # Detect old-schema signatures within the frontmatter region.
  if awk 'BEGIN{infm=0} /^---$/{infm=!infm; next} infm && /^(status|trigger|type|priority|severity|added): /{print "MATCH"; exit}' "$f" | grep -q MATCH; then
    OLD_SCHEMA_FILES+=("$f")
  fi
done

if [ "${#OLD_SCHEMA_FILES[@]}" -eq 0 ]; then
  echo "No old-schema items detected. Nothing to migrate."
  exit 0
fi

echo "Found ${#OLD_SCHEMA_FILES[@]} old-schema item(s)."

# --------------------------------------------------
# Safety preflight 3: pre-migration backup
# --------------------------------------------------
if [ "$DRY_RUN" -eq 0 ]; then
  BACKUP_DIR=".handoffs/pre-migration-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp .backlog/*.md "$BACKUP_DIR/"
  echo "Pre-migration backup: $BACKUP_DIR"
fi

# --------------------------------------------------
# Per-item transformation
# --------------------------------------------------
# Helper: read a frontmatter field by exact key name. Prints value or empty.
read_field() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN { infm=0 }
    /^---$/ { infm=!infm; if (!infm) exit; next }
    infm {
      pat = "^" k ": *"
      if (match($0, pat)) {
        v = substr($0, RLENGTH+1)
        sub(/[[:space:]]+$/, "", v)
        print v
        exit
      }
    }
  ' "$file"
}

# Helper: pick verb prefix from old type: value.
pick_verb_prefix() {
  local type="$1"
  case "$type" in
    bug)         echo "fix-" ;;
    feature)     echo "add-" ;;
    enhancement) echo "improve-" ;;
    idea)        echo "investigate-" ;;
    refactor)    echo "improve-" ;;
    migration)   echo "migrate-" ;;
    "")          echo "add-" ;;
    *)           echo "add-" ;;
  esac
}

# Helper: slugify a string (basic — lower + non-alnum to dash).
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' \
            | tr -c 'a-z0-9' '-' \
            | sed 's/--*/-/g; s/^-//; s/-$//' \
            | cut -c 1-60
}

NEEDS_REVIEW=()
RENAMES=()

migrate_one() {
  local file="$1"
  local base
  base="$(basename "$file" .md)"

  # If the filename already starts with one of the verb prefixes, keep it.
  local has_verb=0
  case "$base" in
    fix-*|add-*|improve-*|investigate-*|migrate-*|redesign-*) has_verb=1 ;;
  esac

  local old_status old_type old_priority old_severity old_added old_origin old_trigger old_title old_status_updated
  old_status="$(read_field "$file" status)"
  old_type="$(read_field "$file" type)"
  old_priority="$(read_field "$file" priority)"
  old_severity="$(read_field "$file" severity)"
  old_added="$(read_field "$file" added)"
  old_origin="$(read_field "$file" origin)"
  old_trigger="$(read_field "$file" trigger)"
  old_title="$(read_field "$file" title)"
  old_status_updated="$(read_field "$file" status_updated)"

  # Map status to state.
  local new_state="parked"
  local is_partial=0
  case "$old_status" in
    parked|promoted) new_state="parked" ;;
    partial) new_state="parked"; is_partial=1 ;;
    completed|stale|superseded)
      echo "ERROR: $file has status: $old_status — closed-state markers should not appear in active .backlog/." >&2
      echo "Move this file to .handoffs/backlog-archive/ and re-run the migration." >&2
      exit 1
      ;;
    "") new_state="parked" ;;
    *) new_state="parked" ;;
  esac

  # Build labels list.
  local labels=""
  case "$old_type" in
    bug)         labels="bug" ;;
    feature)     labels="feature" ;;
    enhancement) labels="enhancement" ;;
    idea)        labels="research" ;;
    refactor)    labels="enhancement" ;;
    migration)   labels="migration" ;;
    "")          labels="feature" ;;
    *)           labels="$old_type" ;;
  esac
  labels="$labels, area:unknown"
  if [ -n "$old_priority" ]; then labels="$labels, priority:$old_priority"; fi
  if [ -n "$old_severity" ]; then labels="$labels, severity:$old_severity"; fi

  # Pick new filename.
  local new_name="$base"
  if [ "$has_verb" -eq 0 ]; then
    local verb
    verb="$(pick_verb_prefix "$old_type")"
    local slug
    slug="$(slugify "$base")"
    new_name="${verb}${slug}"
    new_name="$(echo "$new_name" | cut -c 1-60)"
  fi
  local new_path=".backlog/${new_name}.md"

  # Build new frontmatter.
  local title_line
  if [ -n "$old_title" ]; then
    title_line="title: $old_title"
  else
    title_line="title: $base"
  fi

  # Convert trigger prose to a structured triggers list. Best-effort: split
  # on the literal " OR " connector, default each entry to type: event.
  local triggers_block=""
  if [ -n "$old_trigger" ]; then
    triggers_block="triggers:"
    # Split on " OR " (case-insensitive) using awk — portable across BSD (macOS
    # default) and GNU. awk's gsub treats "\n" in the replacement as a literal
    # newline, so we get one trigger per line, then read line-by-line below.
    # (The earlier sed-with-\x01-sentinel approach failed on BSD sed, which
    # passed the literal four-character string "\x01" through to IFS-splitting.)
    local trigger_text
    trigger_text="$(echo "$old_trigger" | awk '{gsub(/ [Oo][Rr] /, "\n"); print}')"
    while IFS= read -r piece; do
      piece="$(echo "$piece" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^,//; s/,$//')"
      [ -z "$piece" ] && continue
      # Escape double-quotes in the piece.
      piece_escaped="$(echo "$piece" | sed 's/"/\\"/g')"
      triggers_block="$triggers_block
  - type: event
    when: \"$piece_escaped\""
    done <<< "$trigger_text"
  fi

  # Compose new frontmatter.
  local progress_line=""
  if [ "$is_partial" -eq 1 ]; then
    progress_line="progress: \"(legacy partial state — please review and update with what shipped and what remains)\""
    NEEDS_REVIEW+=("$new_path")
  fi

  local status_updated_line=""
  if [ -n "$old_status_updated" ]; then
    status_updated_line="status_updated: $old_status_updated"
  fi

  local opened_line=""
  if [ -n "$old_added" ]; then
    opened_line="opened: $old_added"
  fi

  local origin_line=""
  if [ -n "$old_origin" ]; then
    # Escape any double-quotes
    local origin_escaped
    origin_escaped="$(echo "$old_origin" | sed 's/"/\\"/g')"
    origin_line="origin: $origin_escaped"
  fi

  # Read the body (everything after the second --- line).
  local body
  body="$(awk 'BEGIN{infm=0; afterfm=0} /^---$/{infm=!infm; if (!infm) afterfm=1; next} afterfm {print}' "$file")"

  # Compose the new file.
  local new_file_content
  new_file_content="$(printf '%s\n' \
    "---" \
    "$title_line" \
    "state: $new_state" \
    "labels: [$labels]" \
    ${opened_line:+"$opened_line"} \
    ${status_updated_line:+"$status_updated_line"} \
    ${origin_line:+"$origin_line"} \
    ${progress_line:+"$progress_line"} \
    ${triggers_block:+"$triggers_block"} \
    "---" \
    "")"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "----- DRY RUN: $file -> $new_path -----"
    echo "$new_file_content"
    echo "(body unchanged — $(echo "$body" | wc -l | tr -d ' ') lines)"
    return 0
  fi

  # Write new file content.
  {
    echo "$new_file_content"
    echo "$body"
  } > "$new_path.tmp"

  # If renaming, use git mv to preserve history (in commit mode).
  if [ "$new_path" != "$file" ]; then
    if [ "$COMMIT_MODE" -eq 1 ]; then
      git mv "$file" "$new_path" 2>/dev/null || mv "$file" "$new_path"
    else
      mv "$file" "$new_path"
    fi
    RENAMES+=("$file -> $new_path")
  fi
  mv "$new_path.tmp" "$new_path"
}

# --------------------------------------------------
# Apply transformation to each detected file
# --------------------------------------------------
for f in "${OLD_SCHEMA_FILES[@]}"; do
  migrate_one "$f"
done

# --------------------------------------------------
# Atomic commit (commit mode only, non-dry-run)
# --------------------------------------------------
COMMIT_HASH=""
if [ "$DRY_RUN" -eq 0 ] && [ "$COMMIT_MODE" -eq 1 ]; then
  git add -A .backlog/ "$BACKUP_DIR" 2>/dev/null || true
  if ! git diff --cached --quiet; then
    git commit -m "migrate(backlog): upgrade to v6.4 schema" >/dev/null
    COMMIT_HASH="$(git rev-parse --short HEAD)"
  fi
fi

# --------------------------------------------------
# Summary
# --------------------------------------------------
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "========================================"
echo "Migration summary"
echo "========================================"
echo "Items migrated: ${#OLD_SCHEMA_FILES[@]}"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Mode: DRY RUN (no changes written)"
else
  if [ "$COMMIT_MODE" -eq 1 ] && [ -n "$COMMIT_HASH" ]; then
    echo "Commit: $COMMIT_HASH"
  elif [ "$COMMIT_MODE" -eq 0 ]; then
    echo "Mode: no-commit (changes written in place; backup at $BACKUP_DIR)"
  fi
fi
echo "Needs review: ${#NEEDS_REVIEW[@]} item(s)"
if [ "${#NEEDS_REVIEW[@]}" -gt 0 ]; then
  for n in "${NEEDS_REVIEW[@]}"; do
    echo "  - $n"
  done
fi
echo "Elapsed: ${ELAPSED}s"
