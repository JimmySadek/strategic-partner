---
name: update
description: "Report the installed version, whether a newer release exists, and where updating lives"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:update — Update Check

> Report which version is installed and whether a newer one has been published,
> then say where updating happens. This command reads and reports: it performs no
> update and no filesystem change, and invokes no git command. It does read the
> disk — `grep` and `test` inspect the bundle, and the Serena doctor runs on
> request — so "no command at all" would be false. The accurate boundary is that
> nothing it runs modifies anything.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems.

## Context Inheritance

This subcommand can run standalone or within an active advisor session.
It does not require the full startup sequence.

## 🚫 What this command deliberately does not do

It does not work out how the plugin was installed, and it does not pick an
update route for the user.

That is a removal, not an omission. Earlier versions probed the install and
branched on the result, and that machinery drew a blocking review finding in
seven consecutive rounds — a probe that could not tell a failed command from an
empty result, a classification that proved a plugin was managed *somewhere*
rather than *here*, and branch text that disagreed with the table above it. The
routes are listed below instead, and the reader picks. A list cannot select the
wrong one.

See `claudedocs/INCIDENTS.md` (INC-2026-07-29) for the full history.

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
   is on the list because Step 4 runs it — without it a bundle could be called
   complete and then immediately fail the health check this command prescribes.
   A plugin bundle ships no setup script, so never check for one.

### Step 3 — Report

Four cases, decided entirely by comparing two version strings and the bundle
result. Nothing else is inspected.

**Versions match, bundle complete:**
```
✅ You're on the latest version (v{local})
```
Done. End interaction.

**Versions match, bundle incomplete:** name the missing files, then show the
routes below — reinstalling is what restores them.

**Local is newer than remote:**
```
⚠️ This local copy is newer than the latest GitHub Release (v{local} local, v{remote} remote).
```
Report and stop. Do not show the routes: every one of them would replace newer
work with an older published release.

**Remote is newer than local:**

1. Show the gap:
   ```
   ⚡ Update available: v{local} → v{remote}
   ```
2. Fetch the release body from the GitHub API response → display as changelog
   highlights. If the body is empty: "See CHANGELOG.md in the repo for details."
3. Show the routes below, verbatim.

### 📍 Where updating happens

Present this list as-is. Do not attempt to work out which line applies — say
that the matching one depends on how the plugin was installed, and let the
reader choose.

```
Installed through Claude Code (/plugin install)
  Claude Code updates it, including in the background shortly after a session
  starts — though that is OFF by default for listings not from Anthropic.
  To update now, both commands, in this order, then restart Claude Code:
      /plugin marketplace update strategic-partner
      /plugin update strategic-partner-plugin@strategic-partner
  To make it automatic:
      /plugin → Marketplaces → strategic-partner → Enable auto-update

Running from your own git clone
  Update it the way you update any repository you maintain. Strategic Partner
  will not run git commands against it.

Copied or symlinked into Claude Code's skills directory yourself
  This is a supported install and nothing updates it automatically. Two options.

  Keep managing it yourself: replace the directory's contents from the release
  the same way you put them there.

  Or move to a managed install, which handles every future update:
      /plugin marketplace add JimmySadek/strategic-partner
      /plugin install strategic-partner-plugin@strategic-partner
  This creates a SEPARATE managed copy — it does not adopt yours. Retire the old
  one before reloading, or both will load and their commands will collide:
      remove (or move aside) the copy or symlink you created under
      ~/.claude/skills/, then run /reload-plugins
  Removing it is your action, not this command's.
```

🚨 **The first route needs both commands, in that order.** `marketplace update`
refreshes the catalog — it learns a newer version exists. It does NOT touch the
installed plugin. `plugin update` is what moves the install. Verified against the
CLI's own help: `claude plugin marketplace update` is "Update marketplace(s) from
their source", `claude plugin update` is "Update a plugin to the latest version
(restart required to apply)". Naming only the first leaves the user on the old
version.

⚠️ "Restart required to apply" is literal — a plugin *update* needs Claude Code
restarted, not `/reload-plugins`. Reload activates newly installed or enabled
plugins; it does not swap a running plugin for a newer copy on disk.

### Step 4 — After The User Updates

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
- Show the same three update routes every time, and let the reader pick
- Withhold the routes when the local build is newer than the published release
- Re-check the bundle and the Serena state after the user reports updating

**Will Not:**
- **Modify anything on disk.** No file, directory, or symlink is created, moved,
  replaced, or deleted. No confirmation unlocks this, because there is no code
  path behind it. The command does READ the disk — the bundle check runs `grep`
  and `test`, and Step 4 runs the Serena doctor on request — and none of those
  writes anything.
- **Run any git command at all.** Not against the plugin, not against anything
  else, not even a read-only one. Updating a repository that happens to hold the
  plugin is the user's own operation.
- Inspect how the plugin was installed, or choose an update route on the user's
  behalf
- Run an update command for the user
- Run a setup script or create command symlinks — a plugin install has neither
- Implement source code changes

## See Also

- `/strategic-partner-plugin:serena` — diagnose or repair the Serena setup, offered
  by Step 4 when the health check does not report `healthy`.
