---
name: update
description: "Check for a newer release and name the update route that matches how this plugin was installed"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:update — Update Check

> Report which version is installed, whether a newer one exists, and the update
> route that matches how this plugin got here. This command changes nothing on
> disk — it moves, replaces, and deletes nothing, and runs no git command against
> anything already installed.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems or decisions.

## Context Inheritance

This subcommand can run standalone or within an active advisor session.
It does not require the full startup sequence.

## Behavioral Flow

### Step 1 — Determine Versions

1. Read SKILL.md frontmatter in the skill directory → extract `version:` (local) and `repo:` (GitHub path)
2. Fetch latest release from GitHub:
   ```
   curl -sf "https://api.github.com/repos/{repo}/releases/latest"
   ```
3. Extract `tag_name` from response → strip leading `v` if present → this is the remote version
4. If no GitHub Releases exist (404), fall back to tags:
   ```
   curl -sf "https://api.github.com/repos/{repo}/tags?per_page=1"
   ```
5. If both fail → "❌ Could not reach GitHub to check for updates. Try again later."

### Step 2 — Inspect The Bundle

1. Determine `{plugin-root}` as the parent of the directory containing this
   command file (`{plugin-root}/commands/update.md` → `{plugin-root}`).

2. Confirm this really is Strategic Partner before reporting anything about it:
   ```
   grep -q '^name: strategic-partner$' "{plugin-root}/skills/strategic-partner/SKILL.md"
   ```
   If this fails, stop: "❌ I could not verify this as the Strategic Partner plugin directory."

3. Check the supporting bundle files:
   ```
   test -f "{plugin-root}/skills/strategic-partner/SKILL.md"
   test -f "{plugin-root}/skills/strategic-partner/references/startup-checklist.md"
   test -f "{plugin-root}/commands/update.md"
   test -f "{plugin-root}/hooks/guard-impl.sh"
   test -f "{plugin-root}/output-styles/strategic-partner-voice.md"
   test -f "{plugin-root}/.claude-plugin/plugin.json"
   test -x "{plugin-root}/.scripts/serena-doctor.sh"
   ```
   The bundle is **complete** only when all seven pass. The Serena doctor script
   is on the list because Step 5 runs it — without it a bundle could be called
   complete and then immediately fail the health check this command prescribes.
   A plugin bundle ships no setup script, so never check for one.

### Step 3 — Classify The Install

Two probes, in this order. The first that answers `yes` decides the state.

1. **Does Claude Code manage this plugin?** Ask Claude Code, rather than
   inferring it from the filesystem:
   ```
   claude plugin list 2>/dev/null | grep -i 'strategic-partner-plugin@'
   ```
   An entry naming `strategic-partner-plugin@strategic-partner` means yes.

   ⚠️ **Do not substitute a check for a registered marketplace.** Registration
   and provenance are different facts — a user can register the listing while
   running a copy they cloned or symlinked themselves, and those two need
   different advice. Do not look for a marketplace directory under a hardcoded
   `~/.claude` either; a config root can live elsewhere via `CLAUDE_CONFIG_DIR`.

2. **Does the plugin sit inside a git working copy?**
   ```
   git -C "{plugin-root}" rev-parse --is-inside-work-tree
   ```
   A zero exit printing `true` means yes. Anything else means no.

   This asks only about `{plugin-root}` itself. It does not look for
   repositories nested underneath, and does not need to: this command changes
   nothing, so nothing nested there is at risk from it.

| State | Signal | The route this command names |
|---|---|---|
| `managed` | `claude plugin list` reports this plugin | Claude Code's own update commands |
| `working-copy` | not managed, and the plugin sits in a git working copy | The user's own repository operation |
| `unmanaged` | neither probe answered yes | Install through Claude Code to get managed updates |

If the first probe cannot run at all — no `claude` on PATH, or the command errors
rather than returning an empty list — do not fall through to a guess. Say the
install shape could not be determined, present the version comparison anyway, and
name all three routes so the user can pick the one matching what they know.

### Step 4 — Compare And Present

**If versions match and the bundle is complete:**
```
✅ You're on the latest version (v{local})
```
Done. End interaction.

**If versions match and the bundle is incomplete:** name the missing files, then
the repair route for the install's state — reinstalling through Claude Code for
`managed`, the owning repository for `working-copy`, or whatever route put it
there for `unmanaged`.

**If local > remote:**
```
⚠️ This local copy is newer than the latest GitHub Release (v{local} local, v{remote} remote).
```
Report and stop. Name no update route: every one of them would replace newer work
with an older published release.

**If remote > local:**

1. Show the gap:
   ```
   ⚡ Update available: v{local} → v{remote}
   ```
2. Fetch the release body from the GitHub API response → display as changelog
   highlights. If the body is empty: "See CHANGELOG.md in the repo for details."
3. Name the route for the state classified in Step 3.

**For `managed` — name Claude Code's own commands.**

```
Claude Code manages this plugin, so it handles updates — including in the
background shortly after a session starts, though that is switched OFF by
default for listings that do not come from Anthropic.

To update now, both commands, in this order:
  /plugin marketplace update strategic-partner
  /plugin update strategic-partner-plugin@strategic-partner

Then restart Claude Code.

To have it happen automatically from now on:
  /plugin → Marketplaces → strategic-partner → Enable auto-update
```

🚨 **Both commands are needed, in that order, and they are not interchangeable.**
`marketplace update` refreshes the catalog — it learns a newer version exists. It
does NOT touch the installed plugin. `plugin update` is what moves the install.
Verified against the CLI's own help: `claude plugin marketplace update` is
"Update marketplace(s) from their source", while `claude plugin update` is
"Update a plugin to the latest version (restart required to apply)". Naming only
the first leaves the user on the old version.

⚠️ Note "restart required to apply" — a plugin *update* needs Claude Code
restarted, not `/reload-plugins`. Reload activates newly installed or enabled
plugins; it does not swap a running plugin for a newer copy on disk.

**For `working-copy` — report and stop.**

```
This plugin lives inside a git working copy, so Strategic Partner leaves it
alone. Updating it is your own repository operation — run it yourself in
{plugin-root} whenever you're ready.
```

End the interaction there. No question follows: the user's repository is theirs
to move, and no check performed here could make moving it on their behalf safe.

**For `unmanaged` — point at Claude Code.**

```
Nothing updates this copy automatically. Installing through Claude Code fixes
that for every future update:

  /plugin marketplace add JimmySadek/strategic-partner
  /plugin install strategic-partner-plugin@strategic-partner
  /reload-plugins
```

Say plainly that this creates a separate managed copy rather than adopting the
directory that is there — otherwise the user expects this one to start updating
itself, and it will not.

### Step 5 — After The User Updates

This command performs no update, so this step runs only when the user says they
have updated and asks for a check.

1. Re-verify the seven bundle paths from Step 2, and confirm
   `{plugin-root}/skills/strategic-partner/SKILL.md` now reports `v{remote}`.
   If either check fails, stop and report it instead of claiming success.
2. Run `{plugin-root}/.scripts/serena-doctor.sh --field state`. If the state is
   `healthy`, stay silent. Otherwise offer `/strategic-partner-plugin:serena`;
   never repair Serena as an unannounced side effect of an update.
3. Final message: "Start a new session to use the updated plugin."

## Boundaries

**Will:**
- Check versions against GitHub releases, falling back to tags
- Display changelog highlights from release notes
- Verify the bundle's seven paths and report what is missing
- Classify the install as `managed`, `working-copy`, or `unmanaged`, and say so
  plainly when it cannot tell
- Name the update route matching that state, and stop there
- Refuse to name any route when the local build is newer than the published release
- Re-check the bundle and the Serena state after the user reports updating

**Will Not:**
- **Change anything on disk.** No file, directory, or symlink is created, moved,
  replaced, or deleted — inside the plugin directory or anywhere else. No
  confirmation unlocks this, because there is no code path behind it.
- **Run any git command against anything already on disk.** No fetch, pull,
  merge, checkout, rebase, reset, or clone. Updating a repository that happens to
  hold the plugin is the user's own operation; no filesystem check could make
  doing it for them safe.
- Run an update command on the user's behalf, in any of the three states
- Run a setup script or create command symlinks — a plugin install has neither
- Implement source code changes

## See Also

- `/strategic-partner-plugin:serena` — diagnose or repair the Serena setup, offered
  by Step 5 when the health check does not report `healthy`.
