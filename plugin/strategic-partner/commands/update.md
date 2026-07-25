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
   ```
   Bundle is **complete** only when every one of those six checks passes. A
   plugin bundle ships no setup script, so never check for one.
4. Check whether the plugin directory sits inside a git checkout:
   ```
   git -C "{plugin-root}" rev-parse --show-toplevel
   ```
5. Classify the install:

| State | Signal | Allowed path |
|---|---|---|
| `repo-live` | the `git -C` check above resolves a work tree root | Pull the containing repository; nothing needs re-copying |
| `detached-copy` | that same check fails | Refresh from the latest release tag |

`repo-live` — the plugin directory sits inside a git checkout — covers both a
directory reached straight from the checkout and one reached through a symlink
into it. In either shape, updating that repository updates the plugin.
`detached-copy` means the bundle was copied out of a repository and has no
upstream to pull, so the only safe refresh comes from the published release.

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
| `repo-live` | "This plugin lives inside a git checkout, so updating that repository updates the plugin — nothing needs re-copying." |
| `detached-copy` | "This is a copied plugin with no repository behind it, so the update refreshes it from the latest release." |

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

**For `repo-live`:**

```
git -C "{plugin-root}" fetch --tags --prune
git -C "{plugin-root}" pull --ff-only
```

Then verify `{plugin-root}/skills/strategic-partner/SKILL.md` reports
`v{remote}`. If it does not, stop and report what happened instead of guessing.

**For `detached-copy`:**

Use the latest release tag, not an unqualified branch, and sync only the
plugin subtree:

```
tmp="$(mktemp -d)"
git clone --depth 1 --branch "v{remote}" "https://github.com/{repo}.git" "$tmp/strategic-partner"
rsync -a --delete --exclude='.git' "$tmp/strategic-partner/plugin/strategic-partner/" "{plugin-root}/"
rm -rf "$tmp"
```

Before running `rsync`, confirm all of these are true:

- `{plugin-root}` exists and contains `skills/strategic-partner/SKILL.md`
- `{plugin-root}` is the plugin directory shown to the user
- the user approved replacing that directory's contents from the release

After success:
   ```
   ✅ Updated to v{remote}.
   ```

### Step 5 — After Update Or Repair

A plugin install has no setup script and no command symlinks to refresh —
Claude Code reads the commands, hooks, and voice style out of the plugin
directory itself. So the only work left is confirming the update landed.

1. Re-verify the six bundle paths from Step 2, and confirm
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
- Classify the install as `repo-live` or `detached-copy`
- Refuse to update when the local build is newer than the latest published release
- Execute update commands (repository pull, or safe clone and sync repair)

**Will Not:**
- Implement source code changes
- Auto-update without explicit user confirmation
- Modify any project files beyond the skill itself
- Run a setup script or create command symlinks — a plugin install has neither

## See Also

- `/strategic-partner-plugin:codex-feedback` — adversarial review of the next release. Use after updating to check whether the new version's behavior matches what the CHANGELOG entry promised.
- `/strategic-partner-plugin:help` — full subcommand reference. Use when you want to see what changed alongside the version bump.
- `/strategic-partner-plugin:serena` — check or repair Serena after an SP compatibility update.
