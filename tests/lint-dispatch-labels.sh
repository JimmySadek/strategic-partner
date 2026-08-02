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
# HOW MUCH THIS RETARGETS ON ITS OWN — stated precisely, because an earlier
# version of this comment overstated it as automatic.
#
# The guard is the source of truth for the label STRINGS: all three are read out
# of hooks/guard-impl.sh at run time, and the keyword each bracketed statement is
# matched by is derived from those same strings rather than written out a second
# time here. Change a label's wording in the guard and this lint follows.
#
# What does NOT follow is LOCATING them. The extraction below depends on the
# guard's current structure — the dispatch prefix is found by its concatenation
# onto $subject, and the other two by their block("missing_hold_label") /
# block("missing_wrong_agent_label") call sites. Rename those call sites, or
# build the labels a different way, and extraction fails. It fails CLOSED (the
# lint exits 1 rather than passing on a contract it can no longer read), but the
# fix is a hand edit here. A structural rename of the guard requires updating
# this lint.
#
# THE CARVE-OUT RULE FOR EXAMPLE TEXT — shape PLUS context, never spelling.
#
# Two label shapes are not assertions about what a label says:
#
#   * an explicit elision — "[Dispatch now …]", "[Hold …]", "[Wrong agent …]" —
#     which references the SHAPE of a label with its content elided;
#   * the bare form with no separator and no agent slot — "[Dispatch now]" —
#     which is normally cited as the WRONG label.
#
# Excusing either on SPELLING alone was the first defect: a real normative
# statement written in either shape was skipped silently. Excusing either on
# STRUCTURE alone — sitting inside a fenced block, or sharing a line with a
# correct label — was the second: a fence is an indentation convention, and a
# correct label beside an incorrect one is exactly how a normative "either form
# works" list reads too. Neither is evidence that the author meant an example.
#
# So a carve-out now needs one of these two justifications:
#
#   A. AUTHOR DECLARATION. The line carrying the bracket, or the line
#      immediately above it, carries  <!-- dispatch-label-lint: example -->  —
#      a deliberate, greppable statement by the author. Stands on its own.
#
#   B. STRUCTURE **AND** AN EXAMPLE MARKER. Both halves must hold:
#
#        structure — the bracket sits inside a fenced (```) code block, OR the
#                    same line also carries a guard-CONFORMANT label of the
#                    same keyword;
#        marker    — a line inside the window below carries an example marker.
#
# The MARKER SET, matched case-insensitively:
#
#     bad · wrong (but not "wrong agent") · incorrect · counterexample ·
#     instead of · do not · dont · never · example · e.g. · illustrat…
#
# Every line is stripped of its [...] spans before the match, so the text of a
# [Wrong agent …] label can never justify itself. "wrong" additionally excludes
# a following "agent" for the same reason — "Wrong agent" is a label keyword,
# not a verdict on the label beside it.
#
# The MARKER WINDOW, stated exactly, because a window is only as good as its
# edges:
#
#     bracket NOT in a fence  →  the bracket line, plus the 3 lines above it
#     bracket IN a fence      →  the bracket line, the fence's OPENING line,
#                                plus the 3 lines above that opening line
#
# The fence case looks above the opener rather than above the bracket because
# prose cannot be written inside a fence — the introducing sentence is the only
# place a marker can go. Context is read from the line the bracket OPENS on; a
# statement that wraps is judged by its first line.
#
# A bare or elided label with neither justification is treated as a normative
# statement and checked against the guard, which it fails. Nothing else is
# excused: outside these shapes the Hold and Wrong-agent labels carry no
# variable slot, so any statement of them must match exactly.
#
# Every carve-out is counted in the PASS summary, and `--verbose` lists each one
# with file:line, which justification excused it, and the line the marker was
# found on — so a reviewer can audit the whole set by eye.
#
# FAILS CLOSED. Zero files scanned, or zero label statements found, exits 1. A
# lint that silently scans nothing and reports success is worse than no lint —
# the same hardening tests/lint-voice.sh already carries.
#
# KNOWN LIMITATION — a single unreadable file is skipped quietly. If the scanner
# cannot open a Markdown file it moves to the next one without recording a
# failure, and the run still passes as long as at least one other file opened.
# So a pass means "every file that could be read agrees with the guard", not
# "every Markdown file in the tree was checked". The zero-files and zero-labels
# gates above catch the total-failure case; they do not catch one bad file.
#
# Usage:
#   bash tests/lint-dispatch-labels.sh                  # lint the repo
#   bash tests/lint-dispatch-labels.sh --verbose        # …and list the carve-outs
#   bash tests/lint-dispatch-labels.sh --root <dir>     # lint a fixture tree
#
# Self-test fixtures (see tests/fixtures/dispatch-labels/README.md), run as
#   bash tests/lint-dispatch-labels.sh --root tests/fixtures/dispatch-labels/<tree>
#
#   hidden-drift/       -> MUST exit 1: normative statements in the bare and
#                          elided shapes carrying no example context at all.
#   fence-drift/        -> MUST exit 1: a normative bare label inside a fence
#                          that no marker introduces.
#   sameline-drift/     -> MUST exit 1: an incorrect label sharing a line with a
#                          correct one, with no marker anywhere near it.
#   marked-fence/       -> MUST exit 0: a genuine counterexample inside a fence
#                          the prose above it marks as one.
#   honored-carveouts/  -> MUST exit 0: each accepted justification, once each.
#
# That fixture directory is excluded from the default repo scan, because half of
# it exists to hold text this lint is supposed to reject.
#
# WHY THIS FILE IS FORCE-TRACKED DESPITE `tests/` BEING IGNORED.
# `.gitignore` excludes `tests/`, so an untracked lint would be absent from a
# fresh clone and could not gate a release run there. It is force-added
# (`git add -f`), matching the settled practice for the other contract suites in
# this directory: codex-dispatch-contract.sh, floor-startup-contract.sh,
# floor-version-tristate.sh, plugin-update-contract.sh,
# startup-reference-contract.sh, validation-launcher-contract.sh.

set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
ROOT_GUARD="$REPO/hooks/guard-impl.sh"
PLUGIN_GUARD="$REPO/plugin/strategic-partner/hooks/guard-impl.sh"

SCAN_ROOT="$REPO"
VERBOSE=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1; shift ;;
    --root) [ "$#" -ge 2 ] || fail "--root needs a directory"; SCAN_ROOT="$2"; shift 2 ;;
    --root=*) SCAN_ROOT="${1#--root=}"; shift ;;
    -h|--help) sed -n '2,147p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[ -d "$SCAN_ROOT" ] || fail "scan root not found: $SCAN_ROOT"
SCAN_ROOT=$(cd "$SCAN_ROOT" && pwd)

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

# --- Derive the scanner's keywords FROM the extracted labels. --------------
# One source, not two. A label's keyword is everything before its " - "
# separator; the dispatch prefix is nothing but keyword plus separator, so the
# same rule covers all three. A label with no separator contributes whole.
lead_word() {
  printf '%s' "${1%% - *}" | sed 's/[[:space:]]*$//'
}
LEAD_DISPATCH=$(lead_word "$EXP_DISPATCH")
LEAD_HOLD=$(lead_word "$EXP_HOLD")
LEAD_WRONG=$(lead_word "$EXP_WRONG")

[ -n "$LEAD_DISPATCH" ] || fail "could not derive a keyword from the dispatch label \"$EXP_DISPATCH\""
[ -n "$LEAD_HOLD" ]     || fail "could not derive a keyword from the hold label \"$EXP_HOLD\""
[ -n "$LEAD_WRONG" ]    || fail "could not derive a keyword from the wrong-agent label \"$EXP_WRONG\""

export EXP_DISPATCH EXP_HOLD EXP_WRONG LEAD_DISPATCH LEAD_HOLD LEAD_WRONG SCAN_ROOT

# --- Build the scan set. --------------------------------------------------
# .backlog/ and .handoffs/ hold working notes, .prompts/ holds executor briefs
# that quote broken labels on purpose while describing a fix, CHANGELOG.md is an
# append-only history whose past entries must stay as written, and
# tests/fixtures/dispatch-labels/ holds this lint's own self-test material —
# text it is supposed to reject. When --root points INSIDE the fixture tree the
# exclusion below matches nothing, which is what makes the self-test possible.
FILE_LIST=$(find "$SCAN_ROOT" -name '*.md' -type f \
  ! -path "$SCAN_ROOT/.git/*" \
  ! -path "$SCAN_ROOT/.backlog/*" \
  ! -path "$SCAN_ROOT/.handoffs/*" \
  ! -path "$SCAN_ROOT/.prompts/*" \
  ! -path "$SCAN_ROOT/tests/fixtures/dispatch-labels/*" \
  ! -path "$SCAN_ROOT/CHANGELOG.md" \
  | sort)

if [ -z "$FILE_LIST" ]; then
  fail "scanned zero Markdown files under $SCAN_ROOT — the repo layout moved or the glob broke"
fi

# --- Scan. ----------------------------------------------------------------
# Bracketed label statements may wrap across lines, so each file is slurped
# whole rather than read line by line; the line number is recovered from the
# match offset. Byte-level dash handling avoids any dependence on the locale.
REPORT=$(printf '%s\n' "$FILE_LIST" | perl -e '
  my $exp_dispatch = $ENV{EXP_DISPATCH};
  my $exp_hold     = $ENV{EXP_HOLD};
  my $exp_wrong    = $ENV{EXP_WRONG};
  my $root         = $ENV{SCAN_ROOT};
  my %lead = (
    dispatch => $ENV{LEAD_DISPATCH},
    hold     => $ENV{LEAD_HOLD},
    wrong    => $ENV{LEAD_WRONG},
  );
  my ($files, $checked, $generic, $violations) = (0, 0, 0, 0);

  # An example marker: a word or phrase in the surrounding prose saying the
  # nearby label is being SHOWN rather than prescribed. Matched against a line
  # whose [...] spans have been removed, so a label never justifies itself.
  # "wrong" excludes a following "agent" because that is a label keyword.
  my $MARKER = qr/\bbad\b|\bwrong\b(?!\s+agent)|\bincorrect\b|\bcounter-?examples?\b|\binstead\s+of\b|\bdo\s+not\b|\bdon\x27t\b|\bnever\b|\bexamples?\b|\be\.g\.|\billustrat/i;

  # Returns the line number carrying a marker, or undef. Window: the bracket
  # line plus the 3 lines above it; when the bracket sits inside a fence, the
  # 3 lines above the fence OPENER instead, since prose cannot go in a fence.
  sub marker_line {
    my ($lines, $line, $fence_start) = @_;
    my $anchor = defined $fence_start ? $fence_start : $line;
    for my $n ($line, $anchor, $anchor - 1, $anchor - 2, $anchor - 3) {
      next if $n < 1 || $n > scalar(@$lines);
      my $t = $lines->[$n - 1];
      next unless defined $t;
      $t =~ s/\[[^\]]*\]//g;
      return $n if $t =~ $MARKER;
    }
    return undef;
  }

  sub norm {
    my $s = shift;
    $s =~ s/\xe2\x80\x94|\xe2\x80\x93/-/g;
    $s =~ s/\xe2\x80\xa6/.../g;
    $s =~ s/\s+/ /g; $s =~ s/^ //; $s =~ s/ $//;
    return $s;
  }

  # Does this normalized label conform to the guard for its kind?
  sub conformant {
    my ($label, $kind) = @_;
    if ($kind eq "dispatch") {
      return 0 unless index($label, $exp_dispatch) == 0;
      my $slot = substr($label, length($exp_dispatch));
      return 1 if $slot eq "<subagent_type>";
      return 1 if $slot =~ /^[A-Za-z0-9][A-Za-z0-9_.:-]*$/;
      return 0;
    }
    return $label eq $exp_hold  if $kind eq "hold";
    return $label eq $exp_wrong if $kind eq "wrong";
    return 0;
  }

  # Signal 2: does this line carry a conformant label of the same kind?
  sub line_has_conformant {
    my ($line, $kind) = @_;
    return 0 unless defined $line;
    while ($line =~ /\[([^\]]*)\]/g) {
      return 1 if conformant(norm($1), $kind);
    }
    return 0;
  }

  my $ANNOTATION = qr/<!--\s*dispatch-label-lint:\s*example\s*-->/;

  # Keyword alternation, built from the guard-derived keywords rather than
  # written out again. Longest first so no keyword shadows another.
  my @kinds = sort { length($lead{$b}) <=> length($lead{$a}) } keys %lead;
  my $alt = join("|", map { quotemeta($lead{$_}) } @kinds);

  while (my $path = <STDIN>) {
    chomp $path;
    next unless length $path;
    open(my $fh, "<", $path) or next;
    local $/; my $body = <$fh>; close $fh;
    $body = "" unless defined $body;
    $files++;
    my $rel = $path; $rel =~ s/^\Q$root\E\///;

    my @lines = split /\n/, $body, -1;

    # Fence structure precomputed: for every line inside a ``` fence, the line
    # number of that fence OPENER. The opener is where the marker window is
    # anchored, so it has to be carried, not just a yes/no flag.
    my %fence_start;
    my $open = 0;
    my $opener = 0;
    for my $i (0 .. $#lines) {
      if ($lines[$i] =~ /^\s*```/) {
        if ($open) { $open = 0; } else { $open = 1; $opener = $i + 1; }
        next;
      }
      $fence_start{$i + 1} = $opener if $open;
    }

    while ($body =~ /\[((?:$alt)[^\]]*)\]/g) {
      my $raw   = $1;
      my $start = $-[0];
      my $line  = 1 + (() = (substr($body, 0, $start) =~ /\n/g));
      my $label = norm($raw);

      my $kind;
      for my $k (@kinds) {
        if ($label eq $lead{$k} || index($label, $lead{$k} . " ") == 0) { $kind = $k; last; }
      }
      next unless defined $kind;
      my $lw = $lead{$kind};

      # Shapes that MAY be excused: the bare keyword, or the keyword with an
      # explicit elision. Shape alone is not enough, and neither is structure
      # alone — an author declaration, or structure PLUS a marker, justifies it.
      if ($label eq $lw || $label eq "$lw ...") {
        my $why;
        if (($lines[$line - 1] // "") =~ $ANNOTATION
              || ($line >= 2 && (($lines[$line - 2] // "") =~ $ANNOTATION))) {
          $why = "explicit dispatch-label-lint: example annotation";
        } else {
          my $fs = $fence_start{$line};
          my $structure;
          if (defined $fs) {
            $structure = "inside the fenced block opened on line $fs";
          } elsif (line_has_conformant($lines[$line - 1], $kind)) {
            $structure = "contrasting guard-conformant label on the same line";
          }
          if (defined $structure) {
            my $mk = marker_line(\@lines, $line, $fs);
            $why = "$structure, marked as an example on line $mk" if defined $mk;
          }
        }
        if (defined $why) {
          $generic++;
          print "SKIPPED\t$rel:$line\t[$label]\t$why\n";
          next;
        }
        # No context signal: fall through and judge it as a real statement.
      }

      $checked++;
      if ($kind eq "dispatch") {
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
      } elsif ($kind eq "hold") {
        next if $label eq $exp_hold;
        $violations++;
        print "VIOLATION\t$rel:$line\t[$label]\tdoes not match the guard label \"$exp_hold\"\n";
      } else {
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

if [ "$VERBOSE" -eq 1 ] && [ "$GENERIC_SKIPPED" -ne 0 ] 2>/dev/null; then
  printf 'Example-text carve-outs skipped (%s):\n' "$GENERIC_SKIPPED"
  printf '%s\n' "$REPORT" | grep '^SKIPPED	' \
    | awk -F'\t' '{ printf "  %s  %s\n    excused by: %s\n", $2, $3, $4 }'
fi

printf 'PASS: %s label statement(s) across %s Markdown file(s) match hooks/guard-impl.sh (%s example-text carve-out(s) skipped%s).\n' \
  "$LABELS_CHECKED" "$FILES_SCANNED" "$GENERIC_SKIPPED" \
  "$([ "$VERBOSE" -eq 1 ] || printf '%s' '; --verbose lists them')"
exit 0
