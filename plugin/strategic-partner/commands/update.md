---
name: update
description: "Check for updates and self-update to latest version"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:update — Self-Update

> Check for newer versions of the strategic-partner skill and update in place.

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

Before choosing an update path, inspect the installed plugin bundle. A plugin
install carries no external tracking record, so the only question that decides
the update path is whether pulling a repository refreshes these files.

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
4. Decide whether the enclosing repository actually **owns** this plugin
   directory. Sitting inside somebody's git checkout is not ownership: a plugin
   copied into an unrelated repository — a dotfiles repo, say — also sits
   inside one, and pulling that repository would mutate something the user
   never meant to touch. Ownership requires **both** of these:

   a. **The repository tracks this plugin's own files.** Treat a non-zero exit
      as untracked:
      ```
      git -C "{plugin-root}" ls-files --error-unmatch -- skills/strategic-partner/SKILL.md
      ```
   b. **The plugin sits where the Strategic Partner repository puts it** —
      exactly `plugin/strategic-partner` below the repository root, not at
      some arbitrary depth:
      ```
      repo_root="$(cd "$(git -C "{plugin-root}" rev-parse --show-toplevel)" && pwd -P)"
      plugin_real="$(cd "{plugin-root}" && pwd -P)"
      test "$plugin_real" = "$repo_root/plugin/strategic-partner"
      ```
      Resolving both sides with `pwd -P` keeps a symlinked install working —
      the symlink and the checkout resolve to the same real path.

   If no work tree encloses the plugin at all, or either check above fails,
   the enclosing repository does not own this plugin.

5. Classify the install:

| State | Signal | Allowed path |
|---|---|---|
| `repo-tracked` | a work tree encloses the plugin, that repository tracks the plugin's own files, and the plugin sits at `plugin/strategic-partner` below the repository root | Pull the containing repository; nothing needs re-copying |
| `detached-copy` | anything else — no enclosing work tree, or an enclosing repository that does not track or does not own this path | Refresh from the latest release tag |

`repo-tracked` means pulling that repository genuinely updates this plugin,
which holds both for a directory reached straight from the checkout and one
reached through a symlink into it. `detached-copy` covers two shapes that share
the same problem — no upstream of their own: a bundle copied out of a
repository, and a bundle sitting inside an unrelated repository that merely
encloses it. For both, the only safe refresh comes from the published release.
**Never pull a repository that does not track this plugin.**

6. If the install is `detached-copy`, confirm the file-copying tool the refresh
   depends on is present — before offering the update, not partway through it:
   ```
   command -v rsync
   ```
   If it is missing, stop and say so plainly: "❌ This refresh needs `rsync`,
   which is not installed here. Install it and run this command again — `apt
   install rsync` on Debian or Ubuntu, `dnf install rsync` on Fedora, or
   `brew install rsync` on macOS." Do not begin the refresh without it; a
   refresh that dies halfway leaves temporary files behind and the plugin
   unfinished.

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
Offer repair from the latest release tag.

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

3. Display the install state classified in Step 2:

| State | User-facing status |
|---|---|
| `repo-tracked` | "This plugin is tracked by the repository it lives in, so updating that repository updates the plugin — nothing needs re-copying." |
| `detached-copy` | "No repository tracks this plugin, so the update refreshes it from the latest release. Anything edited locally inside the plugin directory is replaced." |

4. Present via `AskUserQuestion`:
   - **Question**: "Update to v{remote}?"
   - **Options**:
     - [Update now] (Recommended) — Run the safe path for this install state
     - [Show full changelog] — Fetch and display the full CHANGELOG.md from the repo
     - [Not now] — Skip this update

For an incomplete same-version install, change the question to
"Repair this Strategic Partner plugin from v{remote}?"

### Step 4 — Execute Update Or Repair (if confirmed)

Run only the path allowed by the install-state classification.

**For `repo-tracked`:**

```
git -C "{plugin-root}" fetch --tags --prune
git -C "{plugin-root}" pull --ff-only
```

Then verify `{plugin-root}/skills/strategic-partner/SKILL.md` reports
`v{remote}`. If it does not, stop and report what happened instead of guessing.

**For `detached-copy`:**

Build the new content beside the live directory, verify it there, and only then
swap it in. Nothing touches the live plugin until a fully verified replacement
is ready, so an interruption can never leave a half-updated install.

```
parent="$(dirname "{plugin-root}")"
staging="$parent/.strategic-partner.new.$$"
backup="$parent/.strategic-partner.old.$$"
tmp="$(mktemp -d)"

# 1. Fetch the release tag, never an unqualified branch.
git clone --depth 1 --branch "v{remote}" "https://github.com/{repo}.git" "$tmp/src"

# 2. Assemble the new bundle in staging. Staging sits beside the live
#    directory so the swap in step 4 is a same-directory rename. No --delete
#    is needed or wanted: staging starts empty.
mkdir -p "$staging"
rsync -a --exclude='.git' "$tmp/src/plugin/strategic-partner/" "$staging/"

# 3. Verify staging while the live plugin is still untouched: all seven bundle
#    paths from Step 2, the strategic-partner name, and version v{remote}.
#    On any failure, delete staging and stop — nothing live has changed.

# 4. Swap: two renames in the same directory. The previous content stays
#    intact under $backup.
mv "{plugin-root}" "$backup"
mv "$staging" "{plugin-root}"

# 5. Re-verify the live directory. Only once it checks out, discard the backup.
rm -rf "$backup" "$tmp"
```

Before starting, confirm all of these are true:

- `{plugin-root}` exists and contains `skills/strategic-partner/SKILL.md`
- `{plugin-root}` is the plugin directory shown to the user
- the user approved replacing that directory's contents from the release

**What happens if it is interrupted.** Verification in step 3 runs before
anything live is touched, so a failure there means deleting staging and
reporting what was missing — the installed plugin never changed and needs no
recovery. The two renames in step 4 run one after the other, so a crash
between them leaves the plugin directory missing and its previous content
sitting beside it under a name starting with `.strategic-partner.old.`.
Nothing is deleted and nothing is half-written: renaming that directory back
to the plugin's own name restores the previous version exactly. If anything
fails from step 4 onward, tell the user that path — never leave them guessing
where their install went.

After success:
   ```
   ✅ Updated to v{remote}.
   ```

### Step 5 — After Update Or Repair

A plugin install has no setup script and no command symlinks to refresh —
Claude Code reads the commands, hooks, and voice style out of the plugin
directory itself. So the only work left is confirming the update landed.

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
- Inspect the plugin bundle before choosing an update path
- Prove the enclosing repository tracks and owns the plugin before pulling it
- Classify the install as `repo-tracked` or `detached-copy`
- Refuse to update when the local build is newer than the latest published release
- Execute update commands (repository pull, or staged clone-and-swap refresh)

**Will Not:**
- Implement source code changes
- Auto-update without explicit user confirmation
- Pull an enclosing repository that does not track this plugin — a repository
  that merely contains the directory is never treated as its upstream
- Modify any project files beyond the skill itself
- Run a setup script or create command symlinks — a plugin install has neither

## See Also

- `/strategic-partner-plugin:codex-feedback` — adversarial review of the next release. Use after updating to check whether the new version's behavior matches what the CHANGELOG entry promised.
- `/strategic-partner-plugin:help` — full subcommand reference. Use when you want to see what changed alongside the version bump.
- `/strategic-partner-plugin:serena` — check or repair Serena after an SP compatibility update.
