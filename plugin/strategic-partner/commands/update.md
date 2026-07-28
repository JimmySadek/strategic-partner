---
name: update
description: "Check for a newer release, then refresh a standalone plugin directory or report the gap and stop"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:update — Update Check

> Check for a newer strategic-partner release. A standalone plugin directory is
> refreshed from that release; a plugin sitting inside a git working copy is
> reported and left alone.

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

Before choosing an update path, inspect the installed plugin bundle. This
command never runs a repository-changing git command against an existing
repository, so the install shape decides only one thing: whether this directory
can be refreshed from the published release, or whether it belongs to a
repository the user maintains themselves.

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
   does not need to: a refresh replaces that directory's entire contents, so
   anything stored inside it — a nested repository included — is replaced along
   with everything else. That is the reason the warning before the refresh says
   so plainly, rather than the reason for another guard.

5. Classify the install:

| State | Signal | What this command does |
|---|---|---|
| `working-copy` | the plugin sits inside a git working copy | Report the version gap and stop — updating it is the user's own repository operation |
| `standalone` | anything else | Refresh from the latest release tag |

A `standalone` directory has no upstream of its own, so the published release
is the only thing that can refresh it. That is all the absence of an enclosing
work tree establishes — the directory is *eligible* for a refresh from the
release. It says nothing about what else may be sitting inside it, which is
exactly why the warning above spells out that a refresh replaces everything
nested there. A `working-copy` directory already has an upstream, maintained by
whoever set the repository up. Strategic Partner reports what is available
there and leaves the repository untouched.

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

⚠️ **Why this command does not refresh the directory itself.** Replacing a
directory in place means moving the live copy aside, moving a new one in, and
moving the old one back if anything fails. Each of those is a rename that can
fail on its own, and a recovery path built from them reported success after a
failed restore in three consecutive review rounds — the last time by printing a
command that nested the backup inside the broken copy rather than replacing it.
The capability was removed rather than guarded a fourth time, for the same
reason the repository-pull path was removed earlier in this release: a
mechanism that keeps producing the same class of defect is the wrong mechanism.

The replacement is designed and filed, not improvised here. A published release
should be unpacked into its own directory beside the current one, with the
plugin path a symbolic link pointed at whichever release is live. Rollback then
costs one flip of that link, the previous release is never moved, and the
failure branches this command grew simply do not exist. See
`.backlog/redesign-plugin-refresh-as-symlinked-generations.md`.

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
  rebase, or reset anything already on disk. The single repository operation it
  performs is a shallow read-only clone of the published release tag into a
  temporary directory it just created. Updating a repository that happens to
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
