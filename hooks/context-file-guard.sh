#!/usr/bin/env bash
# Hard guard for edits to always-loaded context files. Used by PreToolUse.

set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFLIGHT="${SCRIPT_DIR}/../.scripts/context-file-scan/proposal-preflight.sh"

block() {
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 2
}

is_root_context_path() {
  path_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  case "$path_lc" in
    claude.md|*/claude.md|agents.md|*/agents.md|gemini.md|*/gemini.md)
      return 0 ;;
    *) return 1 ;;
  esac
}

is_context_path() {
  path_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  case "$path_lc" in
    claude.md|*/claude.md|agents.md|*/agents.md|gemini.md|*/gemini.md|.claude/rules/*.md|*/.claude/rules/*.md)
      return 0 ;;
    *) return 1 ;;
  esac
}

shell_command_mutates_context_file() {
  cmd_lc=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  context_path_re='(([^[:space:];|&<>]*/)?(claude|agents|gemini)\.md|([^[:space:];|&<>]*/)?\.claude/rules/[^[:space:];|&<>]+\.md)'
  quoted_context_path_re="['\"]?${context_path_re}['\"]?"
  var_ref_re='['"'"'"]?\$[a-z_][a-z0-9_]*['"'"'"]?'

  # Redirection only counts when the redirection target is the context file.
  # This allows read-only commands such as `grep CLAUDE.md >/dev/null`.
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[^0-9])([0-9]?>>|[0-9]?>|&>|>\|)[[:space:]]*${quoted_context_path_re}([[:space:];|&]|$)"; then
    return 0
  fi

  # Common literal file replacement commands where the destination is last.
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)(command[[:space:]]+)?(cp|mv|install)([[:space:]][^;&|<>]+)*[[:space:]]${quoted_context_path_re}([[:space:]]*(#.*)?$|[;&|])"; then
    return 0
  fi

  # Commands that write to named file arguments.
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)tee([[:space:]]+-a)?([[:space:]][^;&|<>]+)*[[:space:]]${quoted_context_path_re}([[:space:]]*(#.*)?$|[;&|])"; then
    return 0
  fi
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)dd([[:space:]][^;&|]+)*[[:space:]]of=${quoted_context_path_re}([[:space:]]|[;&|]|$)"; then
    return 0
  fi
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)(sed|perl)([[:space:]][^;&|]*)?[[:space:]]-[^[:space:];|&]*i[^[:space:];|&]*([^;&|]*)[[:space:]]${quoted_context_path_re}([[:space:]]*(#.*)?$|[;&|])"; then
    return 0
  fi

  # One-hop variable form: f=CLAUDE.md; echo junk > "$f".
  if printf '%s' "$cmd_lc" | grep -Eq "(^|[;[:space:]])[a-z_][a-z0-9_]*=${quoted_context_path_re}([[:space:];]|$)"; then
    if printf '%s' "$cmd_lc" | grep -Eq "(^|[^0-9])([0-9]?>>|[0-9]?>|&>|>\|)[[:space:]]*${var_ref_re}([[:space:];|&]|$)"; then
      return 0
    fi
    if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)(command[[:space:]]+)?(cp|mv|install|tee)([[:space:]][^;&|<>]+)*[[:space:]]${var_ref_re}([[:space:]]*(#.*)?$|[;&|])"; then
      return 0
    fi
    if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)dd([[:space:]][^;&|]+)*[[:space:]]of=${var_ref_re}([[:space:]]|[;&|]|$)"; then
      return 0
    fi
    if printf '%s' "$cmd_lc" | grep -Eq "(^|[;&|][[:space:]]*)(sed|perl)([[:space:]][^;&|]*)?[[:space:]]-[^[:space:];|&]*i[^[:space:];|&]*([^;&|]*)[[:space:]]${var_ref_re}([[:space:]]*(#.*)?$|[;&|])"; then
      return 0
    fi
  fi

  return 1
}

raw_mentions_context_mutation() {
  input_lc=$(printf '%s' "$INPUT" | tr 'A-Z' 'a-z')
  if printf '%s' "$input_lc" | grep -qE '"(file_path|relative_path)"[[:space:]]*:[[:space:]]*"[^"]*((claude|agents|gemini)\.md|\.claude/rules/[^"]+\.md)'; then
    return 0
  fi
  raw_command=$(printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$raw_command" ] && shell_command_mutates_context_file "$raw_command"; then
    return 0
  fi
  return 1
}

if ! command -v jq >/dev/null 2>&1 || ! printf '%s' "$INPUT" | jq -e type >/dev/null 2>&1; then
  if raw_mentions_context_mutation; then
    block "jq is required for context-file stewardship preflight; refusing context-file mutation instead of allowing it blind"
  fi
  exit 0
fi

json_get() {
  printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null
}

normalize_path() {
  case "$1" in
    [A-Za-z]:\\*|\\\\*) printf '%s' "$1" | tr '\\' '/' ;;
    *) printf '%s' "$1" ;;
  esac
}

apply_literal_edit() {
  old_file="$1"
  new_file="$2"
  in_file="$3"
  out_file="$4"
  replace_all="${5:-false}"
  REPLACE_ALL="$replace_all" perl -0pe '
    BEGIN {
      local $/;
      open my $ofh, "<", $ARGV[0] or die "old";
      $old = <$ofh>;
      close $ofh;
      open my $nfh, "<", $ARGV[1] or die "new";
      $new = <$nfh>;
      close $nfh;
      shift @ARGV;
      shift @ARGV;
      $all = $ENV{"REPLACE_ALL"} || "false";
    }
    if ($all eq "true") { s/\Q$old\E/$new/g; }
    else { s/\Q$old\E/$new/; }
  ' "$old_file" "$new_file" "$in_file" > "$out_file"
}

write_added_snippet() {
  old_file="$1"
  new_file="$2"
  out_file="$3"
  perl -0e '
    local $/;
    open my $ofh, "<", $ARGV[0] or die "old";
    my $old = <$ofh>;
    close $ofh;
    open my $nfh, "<", $ARGV[1] or die "new";
    my $new = <$nfh>;
    close $nfh;
    my $idx = index($new, $old);
    if ($idx >= 0) {
      substr($new, $idx, length($old)) = "";
    }
    print $new;
  ' "$old_file" "$new_file" > "$out_file"
}

should_preflight_added_snippet() {
  target="$1"
  old_file="$2"
  new_file="$3"
  target_lines=0
  if [ -r "$target" ]; then
    target_lines=$(wc -l < "$target" | tr -d ' \t\n')
  fi
  old_lines=$(wc -l < "$old_file" | tr -d ' \t\n')
  new_lines=$(wc -l < "$new_file" | tr -d ' \t\n')
  old_chars=$(wc -c < "$old_file" | tr -d ' \t\n')
  new_chars=$(wc -c < "$new_file" | tr -d ' \t\n')

  # The added-snippet classifier is only for growth. Pure shrink/cleanup
  # edits may retain path references from the old file; those are not new
  # instructions and should be judged only by full-file replacement preflight.
  if [ "$new_lines" -le "$old_lines" ] && [ "$new_chars" -le "$old_chars" ]; then
    return 1
  fi

  # Large shrink/extraction edits are judged by full replacement preflight.
  # Running append preflight on the whole new stub would mistake durable
  # reference pointers for newly appended path-scoped rules.
  if [ "$target_lines" -ge 50 ] && [ $((old_lines * 2)) -ge "$target_lines" ] && [ $((new_lines * 2)) -lt "$target_lines" ]; then
    return 1
  fi
  return 0
}

run_preflight() {
  target="$1"
  proposed="$2"
  mode="${3:-replacement}"
  [ -x "$PREFLIGHT" ] || block "context-file preflight is unavailable; refusing risky context-file mutation"
  out=$(bash "$PREFLIGHT" --target "$target" --snippet "$proposed" --mode "$mode" 2>/dev/null) || out=""
  [ -n "$out" ] || block "context-file preflight failed; refusing risky context-file mutation"
  verdict=$(printf '%s' "$out" | jq -r '.verdict // "reject"' 2>/dev/null)
  reason=$(printf '%s' "$out" | jq -r '.reason // "no reason returned"' 2>/dev/null)
  destination=$(printf '%s' "$out" | jq -r '.destination // "unknown"' 2>/dev/null)
  receipt=$(printf '%s' "$out" | jq -r '.receipt // "none"' 2>/dev/null)
  if [ "$verdict" != "allow" ]; then
    block "context-file stewardship gate returned ${verdict} (${reason}). Safer destination: ${destination}. Receipt: ${receipt}"
  fi
}

TOOL_NAME=$(json_get '.tool_name')
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

if [ "$TOOL_NAME" = "Bash" ]; then
  command_text=$(json_get '.tool_input.command')
  if shell_command_mutates_context_file "$command_text"; then
    block "direct shell mutation of context files must go through the context-file write guard"
  fi
  exit 0
fi

case "$TOOL_NAME" in
  Edit|Write|MultiEdit|NotebookEdit)
    file_path=$(normalize_path "$(json_get '.tool_input.file_path')")
    [ -n "$file_path" ] || exit 0
    is_context_path "$file_path" || exit 0
    ;;
  *)
    exit 0 ;;
esac

TMP=$(mktemp -d)
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
PROPOSED="$TMP/proposed.md"

case "$TOOL_NAME" in
  Write)
    printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null > "$PROPOSED" ||
      block "could not read proposed context-file content"
    ;;
  Edit|NotebookEdit)
    [ -f "$file_path" ] || block "cannot reconstruct edit for missing context file: $file_path"
    cp "$file_path" "$PROPOSED" || block "cannot read context file for preflight: $file_path"
    printf '%s' "$INPUT" | jq -e '.tool_input | has("old_string") and has("new_string")' >/dev/null 2>&1 ||
      block "context-file edit is missing old_string/new_string"
    old_file="$TMP/old"
    new_file="$TMP/new"
    added_file="$TMP/added"
    next_file="$TMP/next"
    printf '%s' "$INPUT" | jq -r '.tool_input.old_string' > "$old_file"
    printf '%s' "$INPUT" | jq -r '.tool_input.new_string' > "$new_file"
    if is_root_context_path "$file_path" && should_preflight_added_snippet "$file_path" "$old_file" "$new_file"; then
      write_added_snippet "$old_file" "$new_file" "$added_file" ||
        block "could not compute context-file edit addition for preflight"
      if [ -s "$added_file" ]; then
        run_preflight "$file_path" "$added_file" append
      fi
    fi
    replace_all=$(printf '%s' "$INPUT" | jq -r '.tool_input.replace_all // false')
    apply_literal_edit "$old_file" "$new_file" "$PROPOSED" "$next_file" "$replace_all" ||
      block "could not reconstruct context-file edit for preflight"
    mv "$next_file" "$PROPOSED"
    ;;
  MultiEdit)
    [ -f "$file_path" ] || block "cannot reconstruct multi-edit for missing context file: $file_path"
    cp "$file_path" "$PROPOSED" || block "cannot read context file for preflight: $file_path"
    count=$(printf '%s' "$INPUT" | jq -r '.tool_input.edits | length' 2>/dev/null)
    case "$count" in ''|null) block "context-file multi-edit has no edits array" ;; esac
    i=0
    while [ "$i" -lt "$count" ]; do
      old_file="$TMP/old-$i"
      new_file="$TMP/new-$i"
      added_file="$TMP/added-$i"
      next_file="$TMP/next-$i"
      printf '%s' "$INPUT" | jq -r ".tool_input.edits[$i].old_string" > "$old_file"
      printf '%s' "$INPUT" | jq -r ".tool_input.edits[$i].new_string" > "$new_file"
      if is_root_context_path "$file_path" && should_preflight_added_snippet "$file_path" "$old_file" "$new_file"; then
        write_added_snippet "$old_file" "$new_file" "$added_file" ||
          block "could not compute context-file multi-edit addition for preflight"
        if [ -s "$added_file" ]; then
          run_preflight "$file_path" "$added_file" append
        fi
      fi
      replace_all=$(printf '%s' "$INPUT" | jq -r ".tool_input.edits[$i].replace_all // false")
      apply_literal_edit "$old_file" "$new_file" "$PROPOSED" "$next_file" "$replace_all" ||
        block "could not reconstruct context-file multi-edit for preflight"
      mv "$next_file" "$PROPOSED"
      i=$((i + 1))
    done
    ;;
esac

run_preflight "$file_path" "$PROPOSED" replacement
exit 0
