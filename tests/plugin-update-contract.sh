#!/usr/bin/env bash
# Regression harness for plugin-native install handling in the plugin's update command.
#
# WHAT THIS SUITE CAN AND CANNOT DO — read before trusting a pass.
#
# commands/update.md is an instruction document. A model reads it and carries
# out what it says. This suite reads the same document and checks which
# contract text is present and which is absent. That is all it does.
#
#   It CAN prove:  no git verb of any kind appears in the document; the refresh
#                  machinery removed from this release has not drifted back in;
#                  the document still names the bundle paths, the three update
#                  routes, and the two-command ordering the platform requires.
#   It CANNOT prove: that following the document produces correct behaviour.
#                  Nothing here executes the update.
#
# The invariant these assertions are scoped to: the update command reads and
# reports. It runs no command against anything on disk, inspects nothing about
# how the plugin was installed, and chooses no route on the user's behalf — it
# prints the same three routes every time and lets the reader pick.
#
# That last clause is the point, and it is why this suite no longer has a
# coherence sibling. A previous version of this command classified the install
# into states and branched on the result. That machinery drew a blocking review
# finding in SEVEN consecutive rounds. A coherence suite was written to guard it
# and was then defeated by six deliberately broken documents, every one of which
# passed 14/0 — including a classification table with every cell left empty. The
# state machine and its guard were both deleted rather than repaired: a document
# with no states cannot have inconsistent ones, which is a stronger property than
# any suite could have asserted about them. See claudedocs/INCIDENTS.md,
# INC-2026-07-29.
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
  "$plugin_update" "**Local is newer than remote:**"
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
for banned in 'rm -rf' 'rsync -a' 'sp_verify' '$staging' '$backup' 'git clone --'; do
  assert_not_contains "plugin update no longer carries refresh machinery ($banned)" \
    "$plugin_update" "$banned"
done

# Stronger than the token list: no line may INVOKE git at all. The command's
# boundary says so absolutely, and a previous version contradicted itself by
# running `git rev-parse` three sections above that promise. The English phrase
# "your own git clone" is prose, not an invocation, so the check is anchored to
# a command-shaped line.
# The regex must survive the forms a review already used to defeat a weaker one:
# `git -C /tmp rev-parse` passed an earlier version because only a lowercase word
# was accepted immediately after `git`. Global options, and wrappers such as
# `command git`, `env git`, `sudo git`, `if git` and `! git`, are all covered now.
assert_no_match "plugin update invokes no git command anywhere" \
  "$plugin_update" "^[[:space:]]*(command|env|sudo|exec|if|!|then|else)?[[:space:]]*git([[:space:]]|\$)"

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
  "$plugin_update" "The first route needs both commands, in that order"
assert_contains "plugin update says a restart applies it, not a reload" \
  "$plugin_update" "restart required to apply"
assert_contains "plugin update tells the user auto-update is off by default" \
  "$plugin_update" "OFF by default for listings not from Anthropic"
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
