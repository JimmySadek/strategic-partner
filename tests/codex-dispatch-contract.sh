#!/usr/bin/env bash
# Regression harness for the Codex review dispatch contract.
#
# WHAT THIS SUITE CAN AND CANNOT DO — read before trusting a pass.
#
# commands/codex-feedback.md is an instruction document, mirrored into the
# plugin bundle. A model reads one of them and carries out what it says. This
# suite reads both documents and checks which contract TEXT is present and
# which is absent. That is the whole of what it does.
#
#   It CAN prove:  the execution-discipline block is still there; the block
#                  still forbids skill loading and memory reads, and those
#                  prohibitions still cover the whole audit rather than
#                  expiring after the first command; the model and
#                  reasoning-effort prohibitions survived the rewrite; stdin
#                  closure is still required; completion is still authored by
#                  the launcher and not by the prompt, with the status captured
#                  and the sentinel renamed into place; the watcher still
#                  re-reads the sentinel before declaring a crash and still has
#                  a stall rule; the contract still specifies a launch that
#                  returns immediately and a watcher that does the waiting;
#                  the detachment claim is still bounded rather than absolute;
#                  every `codex exec` invocation still sits inside the wrapper;
#                  `--add-dir` is still described as granting write access; the
#                  stale advice to proceed without the review after a timeout is
#                  gone; and the two copies still agree.
#   It CANNOT prove: that following either document produces correct behaviour.
#                  Nothing here launches a Codex process, detaches one, watches
#                  a sentinel, or reads a verdict. No assertion below has ever
#                  observed a real dispatch, and none can.
#
# Read a pass as "the contract text is intact", never as "the dispatch works".
#
# WHY THIS FILE IS FORCE-TRACKED DESPITE `tests/` BEING IGNORED.
#
# `.gitignore` excludes `tests/`, and a cross-model review pointed out that this
# suite therefore could not do the one job its own comments claimed: locking the
# contract against future edits in a fresh clone. A suite absent from the
# release tree protects nothing and cannot serve as reproducible evidence.
#
# Of the two ways to resolve that — force-track it, or delete every claim that
# it locks anything and call it a local convenience — force-tracking is the one
# taken, because the alternative removes a guard from the mechanism every
# cross-model review now depends on. It also matches settled practice rather
# than inventing an exception: `floor-startup-contract.sh`,
# `floor-version-tristate.sh`, `startup-reference-contract.sh`, and
# `validation-launcher-contract.sh` are all force-tracked contract suites
# already, and this one is the same genre.
#
# `tests/plugin-update-contract.sh` is force-tracked on the same grounds, so both
# contract suites now travel with the release.
#
# That distinction is not pedantry. A sibling suite in this directory
# (tests/plugin-update-contract.sh) was found asserting that the NAMES of two
# ownership checks appeared in a document, while its labels implied the checks
# themselves had been verified. A review defeated both checks with a
# purpose-built repository and the suite passed anyway, because the strings were
# present. Those assertions were deleted. Every label below therefore names the
# phrase it looks for, and says so when presence is all it can establish.
#
# Why the contract needed a guard at all: the document prescribed review
# timeouts of up to 40 minutes while mandating a blocking transport that caps at
# 10, so the upper tiers were unreachable from the day they shipped. The fix was
# a detached launch plus a mandatory execution-discipline block — detaching
# alone would have let a misdirected review burn 40 minutes instead of 10. These
# assertions lock both halves in place, in both copies.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

ROOT_CMD_FILE="$ROOT/commands/codex-feedback.md"
PLUGIN_CMD_FILE="$ROOT/plugin/strategic-partner/commands/codex-feedback.md"

record_pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

record_fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$1"
}

assert_contains() {
  name="$1"
  actual="$2"
  expected="$3"
  if printf '%s' "$actual" | grep -F "$expected" >/dev/null; then
    record_pass "$name"
  else
    record_fail "$name (missing: $expected)"
  fi
}

assert_not_contains() {
  name="$1"
  actual="$2"
  unexpected="$3"
  if printf '%s' "$actual" | grep -F "$unexpected" >/dev/null; then
    record_fail "$name (unexpected: $unexpected)"
  else
    record_pass "$name"
  fi
}

# Every contract assertion runs against BOTH copies, and the copy is named in
# the label. This is how "the two copies agree on every one of the above" is
# enforced per-phrase: a phrase present in one copy and missing from the other
# produces exactly one failure, naming the copy that lost it.
assert_both_contain() {
  assert_contains "root copy: $1" "$root_cmd" "$2"
  assert_contains "plugin copy: $1" "$plugin_cmd" "$2"
}

assert_neither_contains() {
  assert_not_contains "root copy: $1" "$root_cmd" "$2"
  assert_not_contains "plugin copy: $1" "$plugin_cmd" "$2"
}

if [ -f "$ROOT_CMD_FILE" ]; then
  record_pass "root skill codex-feedback command exists"
else
  record_fail "missing required file: $ROOT_CMD_FILE"
fi

if [ -f "$PLUGIN_CMD_FILE" ]; then
  record_pass "plugin codex-feedback command exists"
else
  record_fail "missing required file: $PLUGIN_CMD_FILE"
fi

if [ "$FAIL" -ne 0 ]; then
  printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
  exit 1
fi

root_cmd=$(cat "$ROOT_CMD_FILE")
plugin_cmd=$(cat "$PLUGIN_CMD_FILE")

# --- Execution-discipline block present -------------------------------------
# The block is the half of the fix that keeps a review on its subject. Without
# it a detached review is free to spend 40 minutes on the wrong thing.
assert_both_contain "execution-discipline block header phrase is present" \
  "EXECUTION DISCIPLINE — read this before anything else."

# Presence of the fill-in slot only. Nothing here checks that a dispatcher
# actually substitutes a real command into it — that happens at dispatch time,
# in a prompt this suite never sees.
assert_both_contain "discipline block carries a first-command slot (phrase presence only)" \
  "<the first command"
assert_both_contain "discipline block phrase orders the first command ahead of all else" \
  "Your first action is to run this command, ahead of every other action:"

# --- Discipline block forbids the orientation detour ------------------------
assert_both_contain "discipline block forbids skill loading (phrase presence)" \
  "load, consult, or invoke any skill, for any reason"
assert_both_contain "discipline block forbids memory file reads (phrase presence)" \
  "read any memory file, session file, or agent instruction file"
assert_both_contain "discipline block forbids exploratory orientation (phrase presence)" \
  "explore this repository for orientation or general context"

# The stated reason travels with the rule. A prohibition carrying the failure it
# prevents survives a model that decides it knows better; a bare one does not.
# Single-line needle on purpose: grep -F treats an embedded newline as a pattern
# separator, so a two-line needle would silently weaken to "either line matches".
assert_both_contain "discipline block keeps its rationale attached (phrase presence)" \
  "entire budget auto-loading an unrelated frontend design skill"

# --- The prohibitions do not expire after the first command -----------------
# The block used to bind them "until that command has run", which freed the
# review to load skills, read memory, and orient the moment it opened the diff —
# the exact failure the block exists to prevent, postponed by one action. Naming
# the first command and forbidding the detour are separate instructions with
# separate lifetimes, and the second one lasts the whole audit.
assert_neither_contains "prohibitions are no longer scoped to the first command" \
  "Until that command has run, do NOT:"
assert_both_contain "prohibitions are scoped to the whole audit (phrase presence)" \
  "For the WHOLE of this audit"
assert_both_contain "running the first command does not lift them (phrase presence)" \
  "Running the first command does not lift these prohibitions."

# --- Pre-existing override prohibitions survived the rewrite ----------------
# These are NOT new. They exist because the failure mode was an assistant
# selecting a cheaper model or a lower reasoning effort to save time, silently
# weakening an adversarial review. Asserted here so a future dispatch rewrite
# cannot quietly drop them.
assert_both_contain "model-override prohibition survived (phrase presence)" \
  "**No model overrides EVER.**"
assert_both_contain "reasoning-effort-override prohibition survived (phrase presence)" \
  "**No effort overrides EVER.**"

# --- stdin closure still required -------------------------------------------
# Detaching does not remove this requirement: a detached process that hangs on
# an open stdin hangs just as long, out of sight.
assert_both_contain "stdin closure is still required in the launch (phrase presence)" \
  "< /dev/null"
assert_both_contain "stdin closure still carries its hang rationale (phrase presence)" \
  "Closes stdin to prevent hangs"

# --- Completion signalled by a file sentinel --------------------------------
# The sentinel is what makes completion detectable without a blocking call.
assert_both_contain "a completion sentinel file is named (phrase presence)" \
  "verdict.done"
assert_both_contain "the watcher polls for the sentinel (phrase presence)" \
  'while [ ! -f "$run_dir/verdict.done" ]; do'

# --- Completion is authored by the LAUNCHER, not by the prompt ---------------
# This reverses an earlier contract decision, on purpose. Measured on Codex CLI
# 0.144.0: under `--sandbox read-only` with approvals off, every write the model
# attempted was refused; with approvals on-request the same write succeeded in
# one run and was refused in another. So a prompt-authored result file left a
# Mode A review with two outcomes — no verdict, or a verdict obtained by
# escalating out of the sandbox. Neither is acceptable, and neither could ever
# have produced the process exit status the failure table requires.
#
# These are the assertions that lock the reversal in. The absence checks matter
# most: re-adding an output contract to the brief is the regression.
assert_neither_contains "the brief no longer carries an output contract" \
  "OUTPUT CONTRACT"
assert_neither_contains "the prompt is no longer told to write the verdict file" \
  "Write your complete verdict to this file"
assert_neither_contains "the prompt is no longer told to create the sentinel" \
  "touch <run_dir>/verdict.done"

assert_both_contain "the wrapper redirects Codex stdout to the verdict file (phrase presence)" \
  '> "$run_dir/verdict.md" 2> "$run_dir/raw.log" < /dev/null'
assert_both_contain "the wrapper waits and captures the exit status (phrase presence)" \
  'status=$?'
assert_both_contain "the sentinel is written to a temporary name first (phrase presence)" \
  'printf '"'"'%s\n'"'"' "$status" > "$run_dir/verdict.done.tmp"'
assert_both_contain "the sentinel is moved into place atomically (phrase presence)" \
  'mv "$run_dir/verdict.done.tmp" "$run_dir/verdict.done"'
assert_both_contain "the reversal is recorded rather than made silently (phrase presence)" \
  "This reverses an earlier decision in this same file, deliberately."

# The watcher half of the race fix. A wrapper that signals and exits between the
# watcher's two tests was reported as a crash; re-reading the sentinel after the
# liveness test fails is what closes that window.
assert_both_contain "the watcher re-reads the sentinel before declaring a crash (phrase presence)" \
  '[ -f "$run_dir/verdict.done" ] && break'

# --- A wedged review has a terminal rule ------------------------------------
# Without one, every live process reads as healthy forever and an authenticated
# but hung Codex burns resources indefinitely. The rule reports; it never kills.
assert_both_contain "a stall threshold is defined (phrase presence)" \
  "stall_windows=20"
assert_both_contain "a stalled review is surfaced rather than killed (phrase presence)" \
  "SP never kills a review on its own."

# Ten silent minutes on stderr is evidence of a wedge, not proof of one — a slow
# verification command or a long reasoning block looks identical from outside.
# The watcher must therefore report a suspicion, not a finding.
assert_both_contain "the stall is reported as suspected, not established (phrase presence)" \
  "SUSPECTED STALL"
assert_neither_contains "the bare established-fact stall label is gone" \
  "printf 'STALLED"
assert_both_contain "the limits of the stall evidence are stated (phrase presence)" \
  "is the accurate word, and the watcher says so"

# --- The sandbox mode is filled in per review mode, never hard-coded ---------
# The wrapper takes the sandbox as a parameter and always did. The published
# launcher, however, passed `workspace-write` as a constant in every copyable
# block, while the prose claimed the sandbox flag was the only thing that varied
# by mode. A user selecting Mode A — the STRICTER review — copied a launcher
# granting project-write access, and the release notes said the opposite. A
# mode-dependent value written as a constant silently deletes the mode
# distinction, so these assertions require the placeholder AND both exact lines.
assert_both_contain "the launch leaves the sandbox mode to be filled in (phrase presence)" \
  'SP_RUN_DIR="$run_dir" SP_SANDBOX=<sandbox-mode> SP_PROJECT="<project-dir>"'
assert_both_contain "the sandbox mode is stated to have no default (phrase presence)" \
  "There is no default, and the two"
assert_both_contain "Mode A's exact launch line names read-only (phrase presence)" \
  'SP_SANDBOX=read-only SP_PROJECT="<project-dir>"'
assert_both_contain "Mode B's exact launch line names workspace-write (phrase presence)" \
  'SP_SANDBOX=workspace-write SP_PROJECT="<project-dir>"'

# Shape check, not phrase presence. Every copyable launch block must carry the
# placeholder; only the two mode-table rows may name a concrete mode. A block
# that hard-codes a mode outside that table is the exact regression above.
assert_no_hardcoded_launch_mode() {
  label="$1"
  body="$2"
  offenders=$(printf '%s\n' "$body" \
    | grep -E '^\s*(#\s*)?SP_RUN_DIR="\$run_dir" SP_SANDBOX=' \
    | grep -vF '<sandbox-mode>')
  if [ -n "$offenders" ]; then
    record_fail "$label (launch block hard-codes a mode: $(printf '%s' "$offenders" | head -1))"
  else
    record_pass "$label"
  fi
}

# A path containing spaces splits when unquoted, and only its first piece ever
# reaches the wrapper — so Codex silently gets a truncated working directory.
# Plausible under WSL, where Windows profile paths routinely contain a space.
assert_launch_quotes_project_dir() {
  label="$1"
  body="$2"
  offenders=$(printf '%s\n' "$body" \
    | grep -E 'SP_PROJECT=' \
    | grep -vF 'SP_PROJECT="<project-dir>"')
  if [ -n "$offenders" ]; then
    record_fail "$label (unquoted project path: $(printf '%s' "$offenders" | head -1))"
  else
    record_pass "$label"
  fi
}

# The transcript-audit launch passes a SECOND path. Quoting the project path and
# leaving its neighbour bare splits on the same spaces; the wrapper quoting
# "$SP_EXTRA" is too late, the split already happened. A tilde is used nowhere
# here because a tilde inside quotes is not expanded.
assert_launch_quotes_extra_dir() {
  label="$1"
  body="$2"
  offenders=$(printf '%s\n' "$body" | grep -E '\.claude/projects/<encoded-project-dir>' | grep -vF '"$HOME/.claude/projects/<encoded-project-dir>"')
  if [ -n "$offenders" ]; then
    record_fail "$label (unquoted or tilde-form extra path: $(printf '%s' "$offenders" | head -1))"
  else
    record_pass "$label"
  fi
}

assert_launch_quotes_extra_dir \
  "root copy: the --add-dir launch path is quoted too" "$root_cmd"
assert_launch_quotes_extra_dir \
  "plugin copy: the --add-dir launch path is quoted too" "$plugin_cmd"

assert_launch_quotes_project_dir \
  "root copy: every launch line quotes the project path" "$root_cmd"
assert_launch_quotes_project_dir \
  "plugin copy: every launch line quotes the project path" "$plugin_cmd"

assert_no_hardcoded_launch_mode \
  "root copy: no copyable launch block hard-codes a sandbox mode" "$root_cmd"
assert_no_hardcoded_launch_mode \
  "plugin copy: no copyable launch block hard-codes a sandbox mode" "$plugin_cmd"

# The stall check MUST sample raw.log, never verdict.md. Measured over a
# 300-second review sampled every ten seconds: verdict.md held 0 bytes for the
# whole run (Codex delivers standard output at the end, not as a stream) while
# raw.log grew continuously and was never flat for more than ~40 seconds. A
# stall rule pointed at verdict.md therefore reports every healthy review past
# the threshold as stalled — firing on exactly the long audits this contract
# exists to enable. This assertion exists so a future edit cannot quietly swap
# the file back.
assert_both_contain "the stall check samples the live trace, not the verdict (phrase presence)" \
  'size=$(wc -c < "$run_dir/raw.log" 2>/dev/null | tr -d '"'"' '"'"')'
assert_neither_contains "the stall check does not sample the verdict file" \
  'size=$(wc -c < "$run_dir/verdict.md"'
assert_both_contain "the buffering measurement is recorded as the reason (phrase presence)" \
  "Why the stall check watches"

# --- Detachment itself -------------------------------------------------------
# Detachment is the primary property this change exists to deliver, and until
# now nothing asserted it — every mention of detaching in this file was a
# comment. The omission was in the assertion list, not in the contract.
#
# These are phrase-presence checks like every other assertion here. This suite
# reads a markdown document; it cannot launch a process, cannot detach one, and
# cannot observe a review outliving anything. A pass means the contract still
# SAYS these things.
assert_both_contain "launch returns immediately rather than blocking (phrase presence)" \
  "The launch runs detached and returns immediately"
assert_both_contain "review survives the caller's turn ending (phrase presence)" \
  "it survives the launching shell exiting and is not waited on when the caller's turn ends"
assert_both_contain "the watcher, not the launch, is what waits (phrase presence)" \
  "the WATCHER is the piece dispatched"
assert_both_contain "the detaching mechanism is still named (phrase presence)" \
  'nohup sh "$run_dir/run.sh"'

# The detachment claim is bounded. `nohup` plus `disown` defeat a hangup signal
# and the shell's job table; they do not defeat a process-group signal or an
# unconditional kill. The contract used to claim "nothing kills Codex", which
# would make a legitimately-killed review look impossible rather than
# explicable. These lock the narrowed claim and forbid the old absolute one.
assert_both_contain "the limits of detaching are stated (phrase presence)" \
  "What detaching does and does not survive."
assert_both_contain "process-group signals are named as NOT survivable (phrase presence)" \
  "the wrapper stays in the caller's process group"
assert_neither_contains "the absolute 'nothing kills Codex' claim is gone" \
  "nothing kills Codex"
assert_neither_contains "the absolute 'any caller-side timeout' survival claim is gone" \
  "survives the launching shell exiting and any caller-side timeout"

# Negative counterpart. The checks above would still pass if a blocking
# foreground launch were added back ALONGSIDE the detached prose — which is the
# likeliest shape of a regression, since prose tends to survive edits that
# change commands.
#
# The shape this guards moved when completion moved. `codex exec` is no longer
# detached directly; it runs INSIDE the wrapper, whose stdout redirect is what
# produces the verdict file, and the wrapper is what gets detached. So the
# property to assert is containment: every line that actually invokes
# `codex exec` with flags must sit inside a wrapper heredoc. One outside it is
# either a foreground launch or a second, unredirected path to the same model —
# both regressions. Prose mentions of `codex exec` carry no flags and are not
# matched.
#
# Phrase-shape check on document text. Nothing here runs a launch.
assert_codex_only_inside_wrapper() {
  label="$1"
  body="$2"
  outside=$(printf '%s\n' "$body" \
    | awk "/<<'SP_WRAPPER'/{inside=1; next} /^SP_WRAPPER\$/{inside=0; next} !inside" \
    | grep -E 'codex exec --' | grep -v 'codex exec --help')
  if [ -n "$outside" ]; then
    record_fail "$label (invocation outside the wrapper: $(printf '%s' "$outside" | head -1))"
  else
    record_pass "$label"
  fi
}

assert_codex_only_inside_wrapper \
  "root copy: every codex exec invocation sits inside the wrapper (phrase presence)" \
  "$root_cmd"
assert_codex_only_inside_wrapper \
  "plugin copy: every codex exec invocation sits inside the wrapper (phrase presence)" \
  "$plugin_cmd"

# The containment check above is vacuously true if the wrapper markers vanish,
# so require at least one wrapper heredoc and at least one invocation in it.
assert_wrapper_actually_present() {
  label="$1"
  body="$2"
  n=$(printf '%s\n' "$body" \
    | awk "/<<'SP_WRAPPER'/{inside=1; next} /^SP_WRAPPER\$/{inside=0; next} inside" \
    | grep -cE 'codex exec --')
  if [ "$n" -ge 1 ]; then
    record_pass "$label ($n invocation(s) inside a wrapper heredoc)"
  else
    record_fail "$label (no codex exec invocation found inside any wrapper heredoc)"
  fi
}

assert_wrapper_actually_present \
  "root copy: the wrapper heredoc exists and carries the invocation" "$root_cmd"
assert_wrapper_actually_present \
  "plugin copy: the wrapper heredoc exists and carries the invocation" "$plugin_cmd"

# --- --add-dir is described as what it actually grants -----------------------
# The contract called this flag one that "only extends read access". The
# installed CLI's own help says the opposite: "Additional directories that
# should be writable alongside the primary workspace". Under the old wording a
# transcript audit was silently granted write access to the records it audits.
assert_neither_contains "the false read-only description of --add-dir is gone" \
  "only extends read access"
assert_both_contain "--add-dir is described as granting write access (phrase presence)" \
  "grants WRITE access, not read access"
assert_both_contain "the CLI's own wording is quoted as the evidence (phrase presence)" \
  "Additional directories that should be writable alongside the primary workspace"
assert_both_contain "narrow scoping is required rather than habitual use (phrase presence)" \
  "Scope it as narrowly as the audit allows"

# --- The stale timeout advice is gone --------------------------------------
# The replaced row told the reader to proceed without the review and to offer a
# retry. Under a detached launch both instructions are wrong: the review is
# still running, and relaunching discards what it has already spent. This is an
# absence check, and absence is the one thing text matching establishes cleanly.
assert_neither_contains "stale advice to proceed without the review is gone" \
  "Review timed out. Proceeding with SP recommendation."
assert_neither_contains "stale 300-second timeout row label is gone" \
  "Timeout >300s"

# --- No command file carries a command-argument placeholder -----------------
# WHAT THIS LOCKS OUT. Claude Code replaces `$0`-`$9` and `$ARGUMENTS[N]` in a
# command's content with the words typed after the command name, and it does so
# before the model receives the content. A shell snippet written with positional
# parameters therefore arrives already rewritten. This launcher's wrapper once
# read `run_dir="$1"; sandbox="$2"; project="$3"` and a real invocation
# delivered it as `run_dir="B"; sandbox="evidence"; project="audit."` — three
# words lifted out of the arguments. Following that verbatim dispatches
# `--sandbox evidence -C audit.`, which is neither a sandbox mode nor a
# directory. Recorded at .handoffs/guard-scoping-verdict-0729-2030.md.
#
# The substitution routine was read out of the shipped Claude Code 2.1.220
# binary rather than inferred. Three lines of it matter here:
#
#   if (t === void 0 || t === null) return e;                      // (1)
#   c = e.replace(new RegExp(`(?<!\\\\)\\\\\\$(?=${l})`,"g"), Ifo) // (2)
#   e = e.replace(/\$(\d+)(?!\w)/g, ...)                           // (3)
#
# (3) is the defect. (2) is the documented backslash escape, which consumes the
# backslash and restores a bare `$` afterwards.
#
# WHY THE ESCAPED FORM IS BANNED TOO, NOT JUST THE BARE ONE. Line (1) returns
# before (2) ever runs when a command is invoked with no arguments — which is
# how this command is normally invoked. The backslash then survives into the
# wrapper, and `run_dir="\$1"` assigns the two-character string `$1`, so the
# review writes its verdict into a directory of that name and the watcher waits
# on a sentinel that will never appear. The bare form fails loudly on the
# with-arguments path; the escaped form fails silently on the without-arguments
# path. A grep for `$N` catches both, because `\$1` contains `$1`.
#
# The replacement is a distinctly-named environment variable. `$SP_RUN_DIR` and
# its siblings match none of the passes above, so they render identically
# whether or not arguments were typed.
#
# Both command trees are scanned in full, not just this file: the hazard belongs
# to the rendering mechanism, so any command file that grows a shell block
# inherits it.
assert_no_argument_placeholders() {
  label="$1"
  reldir="$2"
  hits=$(cd "$ROOT" && grep -nE '\$[0-9]|\$ARGUMENTS\[' "$reldir"/*.md 2>/dev/null)
  if [ -n "$hits" ]; then
    record_fail "$label
$(printf '%s\n' "$hits" | sed 's/^/    /')"
  else
    record_pass "$label"
  fi
}

assert_no_argument_placeholders \
  "no root command file carries a command-argument placeholder" \
  "commands"
assert_no_argument_placeholders \
  "no plugin command file carries a command-argument placeholder" \
  "plugin/strategic-partner/commands"

# The absence check above is satisfied by deleting the wrapper as surely as by
# fixing it, so pin the replacement mechanism by name in both copies.
assert_both_contain "the wrapper reads its parameters from named environment variables" \
  'run_dir="$SP_RUN_DIR"; sandbox="$SP_SANDBOX"; project="$SP_PROJECT"'
assert_both_contain "the launch line puts those variables into the wrapper's environment" \
  'SP_RUN_DIR="$run_dir"'

# --- Whole-file parity between the two copies ------------------------------
# Stronger than the per-phrase parity above, and the reason a phrase cannot be
# added to one copy alone: after normalizing the command namespace, the two
# files must be byte-identical. The namespace is the only divergence the mirror
# is allowed to carry.
normalized_plugin=$(printf '%s' "$plugin_cmd" | sed 's|/strategic-partner-plugin:|/strategic-partner:|g')
if [ "$normalized_plugin" = "$root_cmd" ]; then
  record_pass "root and plugin copies are identical after namespace normalization"
else
  record_fail "root and plugin copies diverge beyond the command namespace
$(diff <(printf '%s\n' "$root_cmd") <(printf '%s\n' "$normalized_plugin") | head -20 | sed 's/^/    /')"
fi

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
