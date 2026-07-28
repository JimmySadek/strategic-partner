#!/usr/bin/env bash
# Regression harness for plugin-native install handling in the plugin's update command.
#
# WHAT THIS SUITE CAN AND CANNOT DO — read before trusting a pass.
#
# commands/update.md is an instruction document. A model reads it and carries
# out what it says. This suite reads the same document and checks which
# contract text is present and which is absent. That is all it does.
#
#   It CAN prove:  the repository-changing git verbs it looks for — fetch,
#                  pull, merge, checkout, rebase, reset — are absent from the
#                  document; the document still names the paths, the staging
#                  discipline, and the health check it must name.
#   It CANNOT prove: that following the document produces correct behaviour,
#                  and it cannot prove that no repository is changed. Those
#                  are different claims. A refresh replaces the entire plugin
#                  directory and recursively deletes the old copy once the new
#                  one verifies. A repository nested inside that directory is
#                  destroyed by directory replacement and cleanup — no git verb
#                  is involved, so the absence of those verbs says nothing
#                  about it. Nothing here executes the update, classifies a
#                  real install, or refreshes a directory.
#
# The invariant these assertions are scoped to, stated narrowly enough to be
# true: the update command never runs a repository-changing git command against
# an existing repository, and a standalone refresh replaces the entire contents
# of the plugin directory, including anything nested inside it. ("standalone",
# not "detached": the update command's own install classification uses
# `standalone` for a plugin directory no repository maintains, and "detached"
# now names the Codex dispatch mechanism in commands/codex-feedback.md. Two
# unrelated meanings for one word in one test directory is a collision worth
# not having.) The absolute form
# of this claim — "never touches any repository" — was wrong, and a guard added
# to rescue it would be the third guard this component has grown to defend an
# overstated claim. The claim was narrowed instead. Unrelated content, a git
# repository included, does not belong inside the plugin directory.
#
# An earlier version of this suite searched for the names of two ownership
# checks and reported a pass. Both checks were forgeable — a review defeated
# them with a purpose-built repository — and the suite passed anyway, because
# the strings were there. A test that cannot fail is worse than no test: it
# manufactures confidence. Those assertions are gone. Read a pass here as
# "the contract text is intact", never as "the update behaves correctly".
#
# The original purpose still holds: the plugin's commands/update.md was copied
# from the root skill and kept two instructions a plugin install cannot honor —
# running a setup script the plugin bundle does not ship, and refreshing command
# symlinks that a plugin install makes obsolete. These assertions lock the
# plugin-native shape in place and guard the reverse mistake — the root skill
# keeping its own setup-driven shape rather than inheriting the plugin's.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PASS=0
FAIL=0

PLUGIN_UPDATE="$ROOT/plugin/strategic-partner/commands/update.md"
ROOT_UPDATE="$ROOT/commands/update.md"

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

# Same shape, but the needle is an extended regular expression and the failure
# message quotes the offending lines — used for the mutating-git check, where
# knowing WHICH line offends is the whole point.
assert_no_match() {
  name="$1"
  actual="$2"
  pattern="$3"
  hits=$(printf '%s' "$actual" | grep -nE "$pattern")
  if [ -n "$hits" ]; then
    record_fail "$name
$(printf '%s' "$hits" | sed 's/^/    /')"
  else
    record_pass "$name"
  fi
}

if [ -f "$PLUGIN_UPDATE" ]; then
  record_pass "plugin update command exists"
else
  record_fail "missing required file: $PLUGIN_UPDATE"
fi

if [ -f "$ROOT_UPDATE" ]; then
  record_pass "root skill update command exists"
else
  record_fail "missing required file: $ROOT_UPDATE"
fi

if [ "$FAIL" -ne 0 ]; then
  printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
  exit 1
fi

plugin_update=$(cat "$PLUGIN_UPDATE")
root_update=$(cat "$ROOT_UPDATE")

# --- Plugin: local-ahead guard present (both the branch label and the message) --
assert_contains "plugin update guards a local build ahead of remote" \
  "$plugin_update" "**If local > remote:**"
assert_contains "plugin update names the local-ahead condition in plain English" \
  "$plugin_update" "newer than the latest GitHub Release"

# --- Plugin: skill-install mechanics removed ---------------------------------
assert_not_contains "plugin update never runs the skill setup script" \
  "$plugin_update" "{skill-dir}/setup"
assert_not_contains "plugin update never refreshes obsolete command symlinks" \
  "$plugin_update" ".claude/commands/strategic-partner"

# --- Plugin: nested plugin layout used --------------------------------------
assert_contains "plugin update resolves the nested plugin skill path" \
  "$plugin_update" "skills/strategic-partner/SKILL.md"

# --- Plugin: no command that changes a repository ---------------------------
# The load-bearing guarantee, and the reason the ownership assertions above it
# are gone. The update command owns a standalone directory outright and refreshes
# it from a published tag; it has no business moving anyone's repository, and no
# filesystem check can make moving one safe. Two shapes are checked: a command
# line beginning with `git`, and the `git <verb>` form anywhere in the file.
# A shallow clone into a temporary directory is permitted — it reads a published
# tag into scratch space and changes nothing that already exists.
mutating_verbs='fetch|pull|merge|checkout|rebase|reset|push|clean|stash|apply|revert'
assert_no_match "plugin update runs no repository-changing git command" \
  "$plugin_update" "^[[:space:]]*git[[:space:]].*[[:space:]]($mutating_verbs)([[:space:]]|\$)"
assert_no_match "plugin update never writes the inline \"git <verb>\" form either" \
  "$plugin_update" "git[[:space:]]+($mutating_verbs)([[:space:]]|\$)"
assert_contains "plugin update reads the release tag into a temporary directory only" \
  "$plugin_update" 'git clone --depth 1 --branch "v{remote}" "https://github.com/{repo}.git" "$tmp/src"'

# --- Plugin: the two states left after the pull path was deleted ------------
assert_contains "plugin update stops rather than touching a git working copy" \
  "$plugin_update" "Report the version gap and stop"

# --- Plugin: the staged refresh keeps the backup unless verification passes --
assert_contains "plugin update discards the backup only on a passing verification" \
  "$plugin_update" "The backup is discarded ONLY if this passes"
assert_contains "plugin update stages into a directory mktemp created" \
  "$plugin_update" 'mktemp -d "$parent/.strategic-partner-update.XXXXXX"'
assert_not_contains "plugin update derives no staging path from the process id" \
  "$plugin_update" '.strategic-partner.new.$$'

# --- Plugin: none of the root's four states ---------------------------------
for root_only_state in skills-tracked-complete skills-tracked-incomplete git-clone manual-copy; do
  assert_not_contains "plugin update drops the root-only \"$root_only_state\" state" \
    "$plugin_update" "$root_only_state"
done

# --- Plugin: Serena stewardship step preserved ------------------------------
assert_contains "plugin update still checks Serena after updating" \
  "$plugin_update" ".scripts/serena-doctor.sh"

# --- Root skill: reverse regression guard -----------------------------------
# The root skill is a skills-CLI install with a setup script. Applying the
# plugin-native shape to it would be the opposite mistake.
assert_contains "root update keeps its own local-ahead guard" \
  "$root_update" "newer than the latest GitHub Release"
assert_contains "root update keeps its setup script step" \
  "$root_update" "{skill-dir}/setup"

# --- Failure injection: the swap and rollback path --------------------------
#
# Everything above this line is text assertion. This section is NOT. It lifts
# the marked swap region out of the markdown, substitutes a staged directory
# tree for the placeholders, and RUNS it — once per rename, with that rename
# forced to fail.
#
# Why it exists: a cross-model review found the four renames unchecked, so a
# failed restore still printed "Your previous version is back in place." The
# user could be left with no plugin at the expected path while being told
# recovery had succeeded. Text assertions could confirm the guards were written;
# only execution confirms what gets printed when a rename actually fails.
#
# `mv` is shadowed by a shell function that fails when its destination ends with
# $SP_FAIL_DST, or its source ends with $SP_FAIL_SRC, and otherwise defers to the
# real binary. That makes each rename injectable without touching permissions or
# filling a disk.
#
# BOTH dimensions are needed, and this is not over-generality — a
# destination-only version of this harness reported four green scenarios while
# never once reaching the step-6 rollback it was written to test. Step 5's second
# rename and step 6's restoring rename share a destination (the live path), so a
# destination-keyed injection always trips the earlier one and exits before step
# 6 runs. Their SOURCES differ ($staging versus $backup), so keying on the source
# is what reaches step 6. Suffix matching, not substring: mktemp's random
# component could otherwise collide with a marker by chance.

extract_swap_region() {
  awk '/^# sp-swap-region: begin$/{f=1; next} /^# sp-swap-region: end$/{f=0} f' \
    "$ROOT/plugin/strategic-partner/commands/update.md"
}

SWAP_REGION=$(extract_swap_region)
if [ -z "$SWAP_REGION" ]; then
  record_fail "swap region markers missing from plugin/strategic-partner/commands/update.md"
else
  record_pass "swap region markers present and extractable"
fi

# Builds a staged tree and runs the extracted region against it.
# $1 = rename destination to fail on ("" = fail nothing). Prints the output;
# the run's exit status is appended as a final "EXIT=<n>" line.
run_swap() {
  fail_dst="$1"
  fail_src="${3:-}"
  stage=$(mktemp -d)
  mkdir -p "$stage/work/new" "$stage/live"
  # Marker files stand in for a bundle. sp_verify below just checks the marker.
  printf 'NEW\n'  > "$stage/work/new/marker"
  printf 'OLD\n'  > "$stage/live/marker"

  script="$stage/run.sh"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -u'
    printf '%s\n' 'SP_FAIL_DST="$1"'
    printf '%s\n' 'SP_FAIL_SRC="$5"'
    printf '%s\n' 'mv() {'
    printf '%s\n' '  eval dest=\$$#'
    printf '%s\n' '  src="$1"'
    printf '%s\n' '  if [ -n "$SP_FAIL_DST" ]; then'
    printf '%s\n' '    case "$dest" in *"$SP_FAIL_DST") return 1 ;; esac'
    printf '%s\n' '  fi'
    printf '%s\n' '  if [ -n "$SP_FAIL_SRC" ]; then'
    printf '%s\n' '    case "$src" in *"$SP_FAIL_SRC") return 1 ;; esac'
    printf '%s\n' '  fi'
    printf '%s\n' '  command mv "$@"'
    printf '%s\n' '}'
    printf '%s\n' 'work="$2"; staging="$work/new"; backup="$work/old"; tmp="$3"'
    printf '%s\n' 'SP_VERIFY_LIVE_OK="${4:-yes}"'
    # sp_verify judges the bundle by its CONTENT, not by where it sits — which
    # is what the real one does. It has to: after a rollback the OLD bundle is
    # at the live path, and a stub keyed on the path would fail the restored
    # copy for the downloaded copy's sin and make a correct rollback look broken.
    printf '%s\n' 'sp_verify() {'
    printf '%s\n' '  [ -f "$1/marker" ] || { echo "missing marker"; return 1; }'
    printf '%s\n' '  if [ "$(cat "$1/marker")" = "NEW" ] && [ "$SP_VERIFY_LIVE_OK" != yes ]; then'
    printf '%s\n' '    echo "bad bundle"; return 1'
    printf '%s\n' '  fi'
    printf '%s\n' '  return 0'
    printf '%s\n' '}'
    printf '%s\n' "$SWAP_REGION"
  } > "$script"

  # Substitute the placeholder with the staged live path.
  sed -i.bak "s|{plugin-root}|$stage/live|g" "$script" && rm -f "$script.bak"

  # Fail closed on a harness bug. A script that will not parse exits 2 and runs
  # nothing, which would let every "did NOT say X" assertion pass vacuously —
  # the harness would look green precisely when it tested nothing.
  if ! bash -n "$script" 2>/dev/null; then
    printf 'HARNESS-BROKEN: extracted swap region does not parse\n%s\nEXIT=2\nSTAGE=%s\n' \
      "$(bash -n "$script" 2>&1 | sed 's/^/  /')" "$stage"
    return
  fi

  out=$(bash "$script" "$fail_dst" "$stage/work" "$stage/tmp" "${2:-yes}" "$fail_src" 2>&1)
  rc=$?
  printf '%s\nEXIT=%s\nSTAGE=%s\n' "$out" "$rc" "$stage"
}

# Every scenario runs this first. It turns "the harness broke" into a failure
# instead of a silent pass on the absence assertions.
assert_ran() {
  name="$1"; out="$2"
  if printf '%s' "$out" | grep -F 'HARNESS-BROKEN' >/dev/null; then
    record_fail "$name — harness did not execute:
$(printf '%s' "$out" | sed 's/^/      /')"
    return 1
  fi
  record_pass "$name"
  return 0
}

assert_run() {
  name="$1"; out="$2"; needle="$3"
  if printf '%s' "$out" | grep -F "$needle" >/dev/null; then
    record_pass "$name"
  else
    record_fail "$name (missing: $needle)
$(printf '%s' "$out" | sed 's/^/      /')"
  fi
}

assert_run_absent() {
  name="$1"; out="$2"; needle="$3"
  if printf '%s' "$out" | grep -F "$needle" >/dev/null; then
    record_fail "$name (unexpected: $needle)
$(printf '%s' "$out" | sed 's/^/      /')"
  else
    record_pass "$name"
  fi
}

if [ -n "$SWAP_REGION" ]; then
  # 1. Happy path — both renames succeed, live verifies. Nothing is claimed
  #    about recovery because no recovery happened.
  out=$(run_swap "" yes)
  assert_ran "swap: happy path executed" "$out"
  assert_run "swap: happy path exits 0" "$out" "EXIT=0"
  assert_run_absent "swap: happy path claims no restore" "$out" "back in place"
  stage=$(printf '%s' "$out" | sed -n 's/^STAGE=//p')
  if [ -f "$stage/live/marker" ] && [ "$(cat "$stage/live/marker")" = "NEW" ]; then
    record_pass "swap: happy path leaves the NEW bundle live"
  else
    record_fail "swap: happy path did not leave the NEW bundle live"
  fi
  rm -rf "$stage"

  # 2. Moving the live copy aside fails — nothing changed, no restore claimed.
  out=$(run_swap "/old" yes)
  assert_ran "swap: first-rename-failure scenario executed" "$out"
  assert_run "swap: first rename failure exits non-zero" "$out" "EXIT=1"
  assert_run "swap: first rename failure says nothing was changed" "$out" "Nothing was changed."
  assert_run_absent "swap: first rename failure claims no restore" "$out" "back in place"
  stage=$(printf '%s' "$out" | sed -n 's/^STAGE=//p')
  if [ "$(cat "$stage/live/marker" 2>/dev/null)" = "OLD" ]; then
    record_pass "swap: first rename failure leaves the original bundle untouched"
  else
    record_fail "swap: first rename failure disturbed the original bundle"
  fi
  rm -rf "$stage"

  # 3. Live copy fails verification, rollback SUCCEEDS — the success message is
  #    allowed, and the restored bundle must actually be the old one.
  out=$(run_swap "" no)
  assert_ran "rollback: successful-restore scenario executed" "$out"
  assert_run "rollback: failed verification exits non-zero" "$out" "EXIT=1"
  assert_run "rollback: successful restore is reported" "$out" "Your previous version is back in place."
  assert_run_absent "rollback: successful restore raises no alarm" "$out" "RESTORE FAILED"
  stage=$(printf '%s' "$out" | sed -n 's/^STAGE=//p')
  if [ "$(cat "$stage/live/marker" 2>/dev/null)" = "OLD" ]; then
    record_pass "rollback: successful restore really puts the old bundle back"
  else
    record_fail "rollback: reported success but the old bundle is not live"
  fi
  rm -rf "$stage"

  # 4. THE FINDING ITSELF, in step 6. Live copy fails verification AND the
  #    restoring rename fails. The pre-fix code printed "back in place"
  #    regardless, leaving the user with no plugin and a success message.
  #
  #    Keyed on the SOURCE ($backup, ending "/old"), not the destination. A
  #    destination-keyed injection trips step 5's second rename instead and
  #    never reaches step 6 — which is exactly how an earlier version of this
  #    harness passed while testing nothing here.
  out=$(run_swap "" no "/old")
  assert_ran "rollback: step-6 failed-restore scenario executed" "$out"
  assert_run "rollback: step-6 failed restore exits non-zero" "$out" "EXIT=1"
  assert_run_absent "rollback: step-6 failed restore does NOT claim the previous version is back" \
    "$out" "Your previous version is back in place."
  assert_run "rollback: step-6 failed restore says so loudly" "$out" "RESTORE FAILED"
  assert_run "rollback: step-6 failed restore names where the backup is" \
    "$out" "Your previous version is intact at:"
  assert_run "rollback: step-6 failed restore gives the manual command" "$out" "Put it back with:"
  stage=$(printf '%s' "$out" | sed -n 's/^STAGE=//p')
  rm -rf "$stage"

  # 5. The same failure one step earlier: the new copy cannot be moved into
  #    place, and the restore of the backup also fails. Step 5 owns this path.
  out=$(run_swap "/live" yes)
  assert_ran "swap: step-5 failed-restore scenario executed" "$out"
  assert_run "swap: step-5 failed restore exits non-zero" "$out" "EXIT=1"
  assert_run_absent "swap: step-5 failed restore does NOT claim the previous version is back" \
    "$out" "Your previous version is back in place."
  assert_run "swap: step-5 failed restore says so loudly" "$out" "RESTORE FAILED"
  stage=$(printf '%s' "$out" | sed -n 's/^STAGE=//p')
  rm -rf "$stage"
fi

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
