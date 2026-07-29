---
name: update
description: "Check for a newer release and name the update route that matches how this plugin was installed"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:update — Update Check

> Check for a newer strategic-partner release and name the update route that
> matches how this plugin was installed. Claude Code updates marketplace plugins
> itself; this command reports the gap and points at the right route. It never
> moves, replaces, or deletes anything on disk.

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

### Step 2 — Inspect Install Shape

Before naming an update route, inspect the installed plugin bundle. This command
changes nothing on disk, so the install shape decides only one thing: which
route to name.

1. Determine `{plugin-root}` as the parent of the directory containing this
   command file (`{plugin-root}/commands/update.md` → `{plugin-root}`).
2. Confirm this really is Strategic Partner before any repair:
   ```
   grep -q '^name: strategic-partner$' "{plugin-root}/skills/strategic-partner/SKILL.md"
   ```
   If this fails, stop: "❌ I could not verify this as the Strategic Partner plugin directory."
3. Check for the supporting bundle files:
   ```
   test -f "{plugin-root}/skills/strategic-partner/SKILL.md"
   test -f "{plugin-root}/skills/strategic-partner/references/startup-checklist.md"
   test -f "{plugin-root}/commands/update.md"
   test -f "{plugin-root}/hooks/guard-impl.sh"
   test -f "{plugin-root}/output-styles/strategic-partner-voice.md"
   test -f "{plugin-root}/.claude-plugin/plugin.json"
   test -x "{plugin-root}/.scripts/serena-doctor.sh"
   ```
   Bundle is **complete** only when every one of those seven checks passes. The
   Serena doctor script is on the list because Step 5 runs it — without it, a
   bundle could be called complete and then immediately fail the health check
   this command prescribes. A plugin bundle ships no setup script, so never
   check for one.
4. Determine whether the plugin sits inside a git working copy — a directory
   that some repository has checked out:
   ```
   git -C "{plugin-root}" rev-parse --is-inside-work-tree
   ```
   A zero exit printing `true` means yes. Anything else — a non-zero exit, no
   output, `false` — means no.

   This is the simplest test available, and it is now the right one. An earlier
   version tried to prove the enclosing repository was Strategic Partner's own,
   by checking that the repository tracked the plugin's files and that the
   plugin sat where this project puts it. A review defeated both checks with a
   purpose-built repository in minutes: any repository can track any path, so
   neither check proved what it claimed. "Is it safe to change this repository"
   cannot be answered from the filesystem, so this command stopped asking and
   stopped running repository-changing git commands altogether. No step below
   runs one, which is what makes a coarse test safe — misreading a plain copy
   as a working copy now costs an unhelpful message, not an unwanted git
   operation.

   The test asks only whether `{plugin-root}` sits inside a work tree. It does
   not look for repositories nested *underneath* the plugin directory, and it
   does not need to: this command changes nothing on disk, so nothing nested
   there is at risk from it. If the user later reinstalls through the
   marketplace, Claude Code replaces the plugin's own directory — worth
   mentioning to anyone who keeps unrelated files inside it.

5. Determine whether Claude Code installed this plugin from a marketplace —
   the case that owns its own updates:
   ```
   ls "${HOME}/.claude/plugins/marketplaces/strategic-partner" 2>/dev/null
   ```
   A directory here means the marketplace is registered and Claude Code manages
   this install.

6. Classify the install:

| State | Signal | The route this command names |
|---|---|---|
| `marketplace` | the `strategic-partner` marketplace is registered | Claude Code's own update path — see below |
| `working-copy` | the plugin sits inside a git working copy | The user's repository operation; report the gap and stop |
| `standalone` | anything else | Add the marketplace, or reinstall by whatever route put it there |

🔑 **`marketplace` is the route worth having, and the one to steer users toward.**
Claude Code refreshes marketplace data and updates installed plugins on its own,
in the background shortly after a session starts. It does that far better than
this command could: nothing here moves a directory, so nothing here can fail
half-way. Auto-update is **off by default for third-party marketplaces**, so a
user who wants it hands-free has to turn it on once — that is worth telling
them, because most will assume it is already on.

| What the user wants | What to tell them |
|---|---|
| Update now | `/plugin marketplace update strategic-partner`, then `/reload-plugins` |
| Update automatically from now on | `/plugin` → **Marketplaces** → `strategic-partner` → **Enable auto-update** |
| Not installed from the marketplace yet | `/plugin marketplace add JimmySadek/strategic-partner`, then `/plugin install strategic-partner-plugin@strategic-partner` |

A `working-copy` install already has an upstream that someone maintains. Report
what is available and leave the repository alone — moving it is the user's own
operation, and no filesystem check performed here could make doing it on their
behalf safe.

A `standalone` directory has no upstream and no marketplace behind it. That is
all the absence of an enclosing work tree establishes; it says nothing about
what else may be sitting inside the directory. Point the user at the marketplace
route above, which replaces the manual reinstall going forward.

### Step 3 — Compare and Present

**If versions match and the bundle is complete:**
```
✅ You're on the latest version (v{local})
```
Done. End interaction.

**If versions match and the bundle is incomplete:**
```
⚠️ You're on v{local}, but this copy is missing supporting files.
```
For a `standalone` install, offer repair from the latest release tag. For a
`working-copy` install, name the missing files and stop — they belong to a
repository someone else maintains, and restoring them is that repository's job.

**If local > remote:**

```
⚠️ This local copy is newer than the latest GitHub Release (v{local} local, v{remote} remote).
```

Do not update from GitHub, because that would replace a newer local build with
an older published release. If the bundle is also incomplete, explain that
repair from GitHub is unsafe until the matching release exists.

**If remote > local:**

1. Display version diff:
   ```
   ⚡ Update available: v{local} → v{remote}
   ```

2. Fetch release body from the GitHub API response → display as changelog highlights.
   If release body is empty, show: "See CHANGELOG.md in the repo for details."

3. Branch on the install state classified in Step 2.

**For `working-copy` — report and stop. Do not offer to update.**

```
This plugin lives inside a git working copy, so Strategic Partner leaves it
alone. Updating it is your own repository operation — run it yourself in
{plugin-root} whenever you're ready.
```

End the interaction there. No question follows, because there is nothing for
this command to do: the user's repository is theirs to move, and no check
performed here could make moving it on their behalf safe.

**For `standalone` — report the gap and hand the update to the user.**

```
⚡ Update available: v{local} → v{remote}

This plugin directory does not sit inside a checked-out repository, so nothing
here maintains it automatically. Reinstall it from the v{remote} release when
you're ready.
```

Name the reinstall route that matches how the directory was put there — the
plugin marketplace entry, or whatever command originally installed it — and
stop. Do not offer to replace the directory on this command's behalf.

⚠️ **Why this command performs no refresh of its own.** It used to. Replacing a
directory in place means moving the live copy aside, moving a new one in, and
moving the old one back if anything fails — three renames that can each fail
independently, and a recovery path assembled from them reported success after a
failed restore in three consecutive review rounds. The capability was removed
rather than guarded a fourth time.

What replaced it is not a safer version of the same surgery. Claude Code already
updates marketplace plugins itself, so the right move was to stop hand-rolling a
mechanism the platform owns and point at that one instead — the same delegation
the skill install has always used, handing its updates to the skills CLI.

### Step 4 — After The User Reinstalls

This command performs no refresh, so this step runs only when the user says
they have reinstalled and asks for a check.

1. Re-verify the seven bundle paths from Step 2, and confirm
   `{plugin-root}/skills/strategic-partner/SKILL.md` now reports `v{remote}`.
   If either check fails, stop and report it instead of claiming success.
2. Resolve the plugin root and run
   `{plugin-root}/.scripts/serena-doctor.sh --field state`. If the state is
   `healthy`, stay silent. Otherwise, offer `/strategic-partner-plugin:serena`;
   never repair Serena as an unannounced side effect of updating SP.
3. Final message: "Start a new session to use the updated plugin."

## Boundaries

**Will:**
- Check versions against GitHub releases/tags
- Display changelog highlights from release notes
- Inspect the plugin bundle before choosing a path
- Classify the install as `working-copy` or `standalone`
- Report the version gap and stop, whichever way the install is classified
- Name the reinstall route that matches how the directory was installed
- Re-check the bundle and version after the user reinstalls, on request
- Refuse to report an update as available when the local build is newer than
  the latest published release

**Will Not:**
- **Run a repository-changing git command against an existing repository.**
  Under no classification does this command fetch, pull, merge, check out,
  rebase, or reset anything already on disk. It performs no repository operation
  of any kind — not even a read-only clone. Updating a repository that happens to
  hold the plugin is the user's own operation, and this command will not run it
  for them — there is no filesystem check that could make doing so safe, which
  is why the capability was removed rather than guarded.
- **Replace, delete, or move the plugin directory, or anything inside it.** This
  command reads and reports. It performs no staging, no swap, and no rollback,
  because it performs no refresh. Reinstalling is the user's own action.
- Implement source code changes
- Auto-update without explicit user confirmation
- Modify any project files beyond the plugin directory itself
- Run a setup script or create command symlinks — a plugin install has neither

## See Also

- `/strategic-partner-plugin:codex-feedback` — adversarial review of the next release. Use after updating to check whether the new version's behavior matches what the CHANGELOG entry promised.
- `/strategic-partner-plugin:help` — full subcommand reference. Use when you want to see what changed alongside the version bump.
- `/strategic-partner-plugin:serena` — check or repair Serena after an SP compatibility update.
