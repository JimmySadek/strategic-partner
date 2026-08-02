#!/usr/bin/env bash
# Release-time lint: do the DOCUMENTED dispatch-confirmation labels still match
# the strings the dispatch guard actually enforces?
#
# WHAT THIS LINT CAN AND CANNOT DO — read before trusting a pass.
#
# hooks/guard-impl.sh blocks an Agent/Task dispatch unless the selected
# AskUserQuestion option label equals, character for character, "Dispatch now - "
# followed by the exact subagent_type, and unless the option list also carries
# "Hold - let me review the brief first" and "Wrong agent - let me pick". That
# contract is restated in prose across a dozen-odd Markdown files. Nothing used
# to verify those restatements against the enforcer, and two of them drifted:
# references/fast-lane.md documented a "(borderline)" suffix on the score-3
# dispatch label, and references/prompt-crafting-guide.md documented
# "[Hold - review brief first]" and "[Wrong agent]". Both forms are rejected by
# the guard, so following either document produced a deterministic dispatch
# failure.
#
#   It CAN prove:  the two guard copies state the same three labels as each
#                  other; and every bracketed [Dispatch now …] / [Hold …] /
#                  [Wrong agent …] statement in the scanned Markdown matches the
#                  guard's strings after the same dash-and-whitespace
#                  normalization the guard itself applies.
#   It CANNOT prove: that a real dispatch succeeds. Nothing here runs a dispatch,
#                  reads a transcript, executes the guard, or observes
#                  AskUserQuestion. It compares documentation text against
#                  enforcer text; that is the whole of what it does.
#
# Read a pass as "the documented labels match the enforcer's strings", never as
# "dispatch confirmation works".
#
# THE GUARD IS THE SOURCE OF TRUTH. The expected labels are extracted FROM
# hooks/guard-impl.sh at run time rather than hardcoded here, so a deliberate
# change to the guard's strings retargets this lint automatically instead of
# turning it into a second, drifting copy of the contract.
#
# TWO DELIBERATE CARVE-OUTS, both narrow, both counted and reported on success
# so they stay auditable rather than silent.
#
#   1. An ellipsis form — "[Dispatch now …]", "[Hold …]", "[Wrong agent …]" —
#      is a reference to the SHAPE of a label with its content explicitly
#      elided, not an assertion about what the label says. Prose describing
#      what this lint scans for is written that way, including in
#      claudedocs/release-process.md.
#   2. A bare "[Dispatch now]" with no separator and no agent slot. Every
#      occurrence is a counterexample — prose citing the generic form as the
#      WRONG label, or asserting that no dispatch option appears at all.
#
# Nothing else is excused. In particular the Hold and Wrong-agent labels carry
# no variable slot, so outside the ellipsis form any statement of them must
# match the guard exactly.
#
# FAILS CLOSED. Zero files scanned, or zero label statements found, exits 1. A
# lint that silently scans nothing and reports success is worse than no lint —
# the same hardening tests/lint-voice.sh already carries.
#
# WHY THIS FILE IS FORCE-TRACKED DESPITE `tests/` BEING IGNORED.
# `.gitignore` excludes `tests/`, so an untracked lint would be absent from a
# fresh clone and could not gate a release run there. It is force-added
# (`git add -f`), matching the settled practice for the other contract suites in
# this directory: codex-dispatch-contract.sh, floor-startup-contract.sh,
# floor-version-tristate.sh, plugin-update-contract.sh,
# startup-reference-contract.sh, validation-launcher-contract.sh.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ROOT_GUARD="$ROOT/hooks/guard-impl.sh"
PLUGIN_GUARD="$ROOT/plugin/strategic-partner/hooks/guard-impl.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Normalizer, mirroring the guard's own jq `norm`: em/en dash to ASCII
# hyphen, whitespace runs collapsed, ends trimmed. The ellipsis character is
# folded to three dots so the generic-form carve-out below sees one spelling.
normalize() {
  perl -e '
    undef $/; my $t = <STDIN>; $t = "" unless defined $t;
    $t =~ s/\xe2\x80\x94|\xe2\x80\x93/-/g;
    $t =~ s/\xe2\x80\xa6/.../g;
    $t =~ s/\s+/ /g; $t =~ s/^ //; $t =~ s/ $//;
    print $t;
  '
}

# The dispatch label is a PREFIX the guard concatenates the agent name onto, so
# its trailing space is part of the contract and must survive normalization.
# Same dash folding and whitespace collapsing, no trimming.
normalize_prefix() {
  perl -e '
    undef $/; my $t = <STDIN>; $t = "" unless defined $t;
    $t =~ s/\xe2\x80\x94|\xe2\x80\x93/-/g;
    $t =~ s/\n//g;
    $t =~ s/[ \t]+/ /g;
    print $t;
  '
}

# --- Extract the three enforced labels from a guard copy. -----------------
# Prints three lines: dispatch prefix, hold label, wrong-agent label. Any line
# may come back empty; the caller checks, NOT this function. A `fail` here would
# run inside the caller's command substitution and exit only that subshell,
# letting the script sail past a guard it could not read.
extract_labels() {
  guard_file="$1"

  g_dispatch=$(grep -o '"Dispatch now[^"]*"[[:space:]]*+[[:space:]]*\$subject' "$guard_file" 2>/dev/null \
    | head -1 | sed 's/^"//; s/"[[:space:]]*+[[:space:]]*\$subject$//' | normalize_prefix)
  g_hold=$(grep 'block("missing_hold_label")' "$guard_file" 2>/dev/null \
    | grep -o 'index("[^"]*")' | head -1 | sed 's/^index("//; s/")$//' | normalize)
  g_wrong=$(grep 'block("missing_wrong_agent_label")' "$guard_file" 2>/dev/null \
    | grep -o 'index("[^"]*")' | head -1 | sed 's/^index("//; s/")$//' | normalize)

  printf '%s\n%s\n%s\n' "$g_dispatch" "$g_hold" "$g_wrong"
}

# Runs in the parent shell so `fail` actually terminates the lint.
assert_labels_complete() {
  labels="$1"
  guard_file="$2"
  [ -n "$(printf '%s\n' "$labels" | sed -n '1p')" ] \
    || fail "could not extract the dispatch label prefix from $guard_file"
  [ -n "$(printf '%s\n' "$labels" | sed -n '2p')" ] \
    || fail "could not extract the hold label from $guard_file"
  [ -n "$(printf '%s\n' "$labels" | sed -n '3p')" ] \
    || fail "could not extract the wrong-agent label from $guard_file"
}

[ -r "$ROOT_GUARD" ]   || fail "guard not readable: $ROOT_GUARD"
[ -r "$PLUGIN_GUARD" ] || fail "guard not readable: $PLUGIN_GUARD"

ROOT_LABELS=$(extract_labels "$ROOT_GUARD")
PLUGIN_LABELS=$(extract_labels "$PLUGIN_GUARD")

assert_labels_complete "$ROOT_LABELS" "$ROOT_GUARD"
assert_labels_complete "$PLUGIN_LABELS" "$PLUGIN_GUARD"

if [ "$ROOT_LABELS" != "$PLUGIN_LABELS" ]; then
  printf 'FAIL: the two guard copies do not state the same dispatch labels.\n' >&2
  printf '  hooks/guard-impl.sh:\n%s\n' "$ROOT_LABELS" >&2
  printf '  plugin/strategic-partner/hooks/guard-impl.sh:\n%s\n' "$PLUGIN_LABELS" >&2
  exit 1
fi

EXP_DISPATCH=$(printf '%s\n' "$ROOT_LABELS" | sed -n '1p')
EXP_HOLD=$(printf '%s\n' "$ROOT_LABELS" | sed -n '2p')
EXP_WRONG=$(printf '%s\n' "$ROOT_LABELS" | sed -n '3p')
export EXP_DISPATCH EXP_HOLD EXP_WRONG ROOT

# --- Build the scan set. --------------------------------------------------
# .backlog/ and .handoffs/ hold working notes, .prompts/ holds executor briefs
# that quote broken labels on purpose while describing a fix, and CHANGELOG.md
# is an append-only history whose past entries must stay as written.
FILE_LIST=$(find "$ROOT" -name '*.md' -type f \
  ! -path "$ROOT/.git/*" \
  ! -path "$ROOT/.backlog/*" \
  ! -path "$ROOT/.handoffs/*" \
  ! -path "$ROOT/.prompts/*" \
  ! -path "$ROOT/CHANGELOG.md" \
  | sort)

if [ -z "$FILE_LIST" ]; then
  fail "scanned zero Markdown files under $ROOT — the repo layout moved or the glob broke"
fi

# --- Scan. ----------------------------------------------------------------
# Bracketed label statements may wrap across lines, so each file is slurped
# whole rather than read line by line; the line number is recovered from the
# match offset. Byte-level dash handling avoids any dependence on the locale.
REPORT=$(printf '%s\n' "$FILE_LIST" | perl -e '
  my $exp_dispatch = $ENV{EXP_DISPATCH};
  my $exp_hold     = $ENV{EXP_HOLD};
  my $exp_wrong    = $ENV{EXP_WRONG};
  my $root         = $ENV{ROOT};
  my ($files, $checked, $generic, $violations) = (0, 0, 0, 0);

  sub norm {
    my $s = shift;
    $s =~ s/\xe2\x80\x94|\xe2\x80\x93/-/g;
    $s =~ s/\xe2\x80\xa6/.../g;
    $s =~ s/\s+/ /g; $s =~ s/^ //; $s =~ s/ $//;
    return $s;
  }

  while (my $path = <STDIN>) {
    chomp $path;
    next unless length $path;
    open(my $fh, "<", $path) or next;
    local $/; my $body = <$fh>; close $fh;
    $body = "" unless defined $body;
    $files++;
    my $rel = $path; $rel =~ s/^\Q$root\E\///;

    while ($body =~ /\[((?:Dispatch now|Hold|Wrong agent)[^\]]*)\]/g) {
      my $raw   = $1;
      my $start = $-[0];
      my $line  = 1 + (() = (substr($body, 0, $start) =~ /\n/g));
      my $label = norm($raw);

      # Carve-out 1: an explicit elision marker means the text references the
      # shape of a label, not its content. Applies to all three keywords.
      if ($label =~ /^(?:Dispatch now|Hold|Wrong agent) \.\.\.$/) {
        $generic++;
        next;
      }

      if ($label =~ /^Dispatch now\b/) {
        # Carve-out 2: the bare generic form, cited only as a counterexample.
        if ($label eq "Dispatch now") {
          $generic++;
          next;
        }
        $checked++;
        if (index($label, $exp_dispatch) != 0) {
          $violations++;
          print "VIOLATION\t$rel:$line\t[$label]\tdoes not begin with the guard prefix \"$exp_dispatch\"\n";
          next;
        }
        my $slot = substr($label, length($exp_dispatch));
        next if $slot eq "<subagent_type>";
        next if $slot =~ /^[A-Za-z0-9][A-Za-z0-9_.:-]*$/;
        $violations++;
        print "VIOLATION\t$rel:$line\t[$label]\tunexpected content in the agent slot: \"$slot\"\n";
      } elsif ($label =~ /^Hold\b/) {
        $checked++;
        next if $label eq $exp_hold;
        $violations++;
        print "VIOLATION\t$rel:$line\t[$label]\tdoes not match the guard label \"$exp_hold\"\n";
      } elsif ($label =~ /^Wrong agent\b/) {
        $checked++;
        next if $label eq $exp_wrong;
        $violations++;
        print "VIOLATION\t$rel:$line\t[$label]\tdoes not match the guard label \"$exp_wrong\"\n";
      }
    }
  }
  print "COUNT\t$files\t$checked\t$generic\t$violations\n";
' 2>/dev/null)

[ -n "$REPORT" ] || fail "the scanner produced no output — perl is unavailable or the scan aborted"

COUNT_LINE=$(printf '%s\n' "$REPORT" | grep '^COUNT	' | head -1)
[ -n "$COUNT_LINE" ] || fail "the scanner produced no summary line — the scan aborted partway"

FILES_SCANNED=$(printf '%s\n' "$COUNT_LINE" | cut -f2)
LABELS_CHECKED=$(printf '%s\n' "$COUNT_LINE" | cut -f3)
GENERIC_SKIPPED=$(printf '%s\n' "$COUNT_LINE" | cut -f4)
VIOLATIONS=$(printf '%s\n' "$COUNT_LINE" | cut -f5)

if [ "$FILES_SCANNED" -eq 0 ] 2>/dev/null; then
  fail "opened zero Markdown files — the file list resolved but nothing could be read"
fi

if [ "$LABELS_CHECKED" -eq 0 ] 2>/dev/null; then
  fail "found zero dispatch-label statements across $FILES_SCANNED files — the contract is stated in the docs, so scanning none means this lint checked nothing"
fi

if [ "$VIOLATIONS" -ne 0 ] 2>/dev/null; then
  printf '\n' >&2
  printf '%s\n' "$REPORT" | grep '^VIOLATION	' \
    | awk -F'\t' '{ printf "  %s\n    found:    %s\n    problem:  %s\n", $2, $3, $4 }' >&2
  printf '\n' >&2
  printf 'FAIL: %s documented dispatch label(s) disagree with hooks/guard-impl.sh.\n' "$VIOLATIONS" >&2
  printf '      The guard compares option labels by exact string equality, so each\n' >&2
  printf '      mismatch above is a dispatch that blocks when the doc is followed.\n' >&2
  printf '      Expected forms: [%s<subagent_type>]  [%s]  [%s]\n' "$EXP_DISPATCH" "$EXP_HOLD" "$EXP_WRONG" >&2
  exit 1
fi

printf 'PASS: %s label statement(s) across %s Markdown file(s) match hooks/guard-impl.sh (%s generic-form mention(s) skipped).\n' \
  "$LABELS_CHECKED" "$FILES_SCANNED" "$GENERIC_SKIPPED"
exit 0
