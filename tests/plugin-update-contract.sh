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
#                  document, and so is every clone; the refresh machinery removed
#                  from this release has not drifted back in; the document names
#                  the native marketplace update route and the paths and health
#                  check it must name.
#   It CANNOT prove: that following the document produces correct behaviour.
#                  Nothing here executes the update or classifies a real install.
#
# The invariant these assertions are scoped to, stated narrowly enough to be
# true: the update command runs no repository-changing git command against an
# existing repository, performs no staging, swap, rollback, delete, or clone of
# any kind, and changes nothing on disk. It reports the version gap and names the
# update route that matches the install — for a marketplace install, Claude
# Code's own, which is the same delegation the skill install has always used with
# the skills CLI.
#
# That second half used to read differently. This suite previously described a
# staged refresh that replaced the plugin directory wholesale, and carried
# failure-injection coverage for its rollback path. Cross-model review found a
# new hole in that recovery path in three consecutive rounds, the last being a
# printed recovery command that nested the backup inside the broken copy instead
# of replacing it — and a harness that claimed per-rename coverage while missing
# one of the four renames. The capability was removed rather than guarded a
# fourth time. The replacement design is filed at
# a marketplace manifest at .claude-plugin/marketplace.json. Claude Code updates
# marketplace plugins itself, so the failure branches stop existing because the
# surgery stops existing — not because a safer version of it was written. (An
# interim design that rebuilt the refresh around symlinked release generations
# was filed and then superseded, unbuilt; it is not referenced here, because it
# lived in an untracked directory that never reaches a fresh clone.)
#
# "standalone", not "detached": the update command's install classification uses
# `standalone` for a plugin directory that does not sit inside a checked-out
# repository — which is all the classifier tests, and less than "no repository
# maintains it" would claim. "detached" now names the Codex dispatch mechanism in
# commands/codex-feedback.md, and two meanings for one word in one test directory
# is a collision worth not having.
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
# No clone of any kind is permitted any more: the refresh that needed one was
# removed, so a clone reappearing means the machinery is drifting back.
mutating_verbs='fetch|pull|merge|checkout|rebase|reset|push|clean|stash|apply|revert'
assert_no_match "plugin update runs no repository-changing git command" \
  "$plugin_update" "^[[:space:]]*git[[:space:]].*[[:space:]]($mutating_verbs)([[:space:]]|\$)"
assert_no_match "plugin update never writes the inline \"git <verb>\" form either" \
  "$plugin_update" "git[[:space:]]+($mutating_verbs)([[:space:]]|\$)"

# --- Plugin: the two states left after the pull path was deleted ------------
assert_contains "plugin update stops rather than touching a git working copy" \
  "$plugin_update" "Updating it is your own repository operation"

assert_not_contains "plugin update derives no staging path from the process id" \
  "$plugin_update" '.strategic-partner.new.$$'

# --- Plugin: none of the root's four states ---------------------------------
for root_only_state in skills-tracked-complete skills-tracked-incomplete git-clone manual-copy; do
  assert_not_contains "plugin update drops the root-only \"$root_only_state\" state" \
    "$plugin_update" "$root_only_state"
done

# --- Plugin: Serena stewardship step preserved ------------------------------
assert_contains "plugin update still checks Serena after a user-run reinstall" \
  "$plugin_update" ".scripts/serena-doctor.sh"

# --- Root skill: reverse regression guard -----------------------------------
# The root skill is a skills-CLI install with a setup script. Applying the
# plugin-native shape to it would be the opposite mistake.
assert_contains "root update keeps its own local-ahead guard" \
  "$root_update" "newer than the latest GitHub Release"
assert_contains "root update keeps its setup script step" \
  "$root_update" "{skill-dir}/setup"

# --- The refresh capability is gone, and must stay gone ---------------------
#
# The staged in-place refresh was removed from this release. It replaced a
# directory by moving the live copy aside, moving a new one in, and moving the
# old one back on failure — a recovery path that reported success after a failed
# restore in three consecutive review rounds. The replacement design is filed at
# .backlog/redesign-plugin-refresh-as-symlinked-generations.md.
#
# These are absence assertions, and absence is the one thing text matching
# establishes cleanly. They exist so the removed machinery cannot drift back in
# without the redesign behind it: no staging, no swap, no rollback, no
# recursive delete, no clone.
for banned in 'rm -rf' 'rsync -a' 'sp_verify' '$staging' '$backup' 'git clone'; do
  assert_not_contains "plugin update no longer carries refresh machinery ($banned)" \
    "$plugin_update" "$banned"
done

assert_contains "plugin update names the route rather than performing it" \
  "$plugin_update" "Name the update route matching that state, and stop there"
assert_contains "plugin update states plainly that it performs no update" \
  "$plugin_update" "This command performs no update"
# Both commands, in order. `marketplace update` refreshes the catalog only;
# `plugin update` is what moves the install. Verified against the CLI's own help:
# "Update marketplace(s) from their source" vs "Update a plugin to the latest
# version (restart required to apply)". An earlier version of this suite asserted
# the first alone as the update route, locking in a documented route that leaves
# the user on the old version.
assert_contains "plugin update names the catalog refresh" \
  "$plugin_update" "/plugin marketplace update strategic-partner"
assert_contains "plugin update names the command that actually moves the install" \
  "$plugin_update" "/plugin update strategic-partner-plugin@strategic-partner"
assert_contains "plugin update says both are needed and why" \
  "$plugin_update" "Both commands are needed, in that order"
assert_contains "plugin update says a restart applies it, not a reload" \
  "$plugin_update" "restart required to apply"
assert_contains "plugin update detects provenance rather than mere registration" \
  "$plugin_update" "claude plugin list"
assert_not_contains "plugin update no longer infers provenance from a hardcoded config path" \
  "$plugin_update" '${HOME}/.claude/plugins/marketplaces'
assert_contains "plugin update tells the user auto-update is off by default" \
  "$plugin_update" "switched OFF by"
assert_contains "plugin update names the add+install route for a fresh install" \
  "$plugin_update" "/plugin marketplace add JimmySadek/strategic-partner"

# The manifest is what makes the native route possible. Without it the command
# names a route no user can take.
MARKETPLACE_FILE="$ROOT/.claude-plugin/marketplace.json"
if [ -f "$MARKETPLACE_FILE" ]; then
  record_pass "marketplace manifest exists at .claude-plugin/marketplace.json"
  mp_source=$(grep -o '"source": *"[^"]*"' "$MARKETPLACE_FILE" | head -1 | cut -d'"' -f4)
  if [ -f "$ROOT/$mp_source/.claude-plugin/plugin.json" ]; then
    record_pass "marketplace source path resolves to a real plugin bundle ($mp_source)"
  else
    record_fail "marketplace source path does not resolve: $mp_source"
  fi
  mp_version=$(grep -o '"version": *"[^"]*"' "$MARKETPLACE_FILE" | head -1 | cut -d'"' -f4)
  pl_version=$(grep -o '"version": *"[^"]*"' "$ROOT/$mp_source/.claude-plugin/plugin.json" | head -1 | cut -d'"' -f4)
  if [ "$mp_version" = "$pl_version" ]; then
    record_pass "marketplace and plugin manifests agree on the version ($mp_version)"
  else
    record_fail "version mismatch: marketplace $mp_version vs plugin $pl_version"
  fi
else
  record_fail "missing marketplace manifest — the update command names a route users cannot take"
fi

printf '\nResult: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
