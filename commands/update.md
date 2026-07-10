---
name: update
description: "Check for updates and self-update to latest version"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner:update — Self-Update

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

Before choosing an update method, inspect the installed bundle. The skills CLI
listing is a tracking signal only; it does not prove the supporting Strategic
Partner files were installed.

1. Determine `{skill-dir}` as the directory containing this command's
   Strategic Partner `SKILL.md`.
2. Confirm `{skill-dir}/SKILL.md` is actually Strategic Partner before any
   repair:
   ```
   grep -q '^name: strategic-partner$' "{skill-dir}/SKILL.md"
   ```
   If this fails, stop: "❌ I could not verify this as the Strategic Partner install directory."
3. Check for the supporting bundle files:
   ```
   test -f "{skill-dir}/SKILL.md"
   test -f "{skill-dir}/setup"
   test -f "{skill-dir}/commands/update.md"
   test -f "{skill-dir}/hooks/guard-impl.sh"
   test -f "{skill-dir}/references/startup-checklist.md"
   test -f "{skill-dir}/output-styles/strategic-partner-voice.md"
   ```
   Bundle is **complete** only when every check passes.
4. Check whether the skills CLI tracks this install:
   ```
   npx skills ls -g -a claude-code 2>/dev/null | grep -E '(^|[[:space:]])strategic-partner([[:space:]]|$)'
   ```
   If the global list is unavailable, also try `npx skills ls 2>/dev/null`.
5. Check whether the install is a git clone:
   ```
   git -C "{skill-dir}" rev-parse --is-inside-work-tree
   ```
6. Classify the install:

| State | Signals | Allowed path |
|---|---|---|
| `skills-tracked-complete` | Listed by the skills CLI and bundle complete | Skills CLI update, then setup |
| `skills-tracked-incomplete` | Listed by the skills CLI but missing setup, commands, hooks, references, or output style | Safe clone and sync repair, then setup |
| `git-clone` | Not a tracked-complete install, and `git -C` confirms a work tree | Git update, then setup |
| `manual-copy` | Not tracked by the skills CLI and no git metadata | Safe clone and sync repair, then setup |

### Step 3 — Compare and Present

**If versions match:**

- If the bundle is complete:
```
✅ You're on the latest version (v{local})
```
  Done. End interaction.
- If the bundle is incomplete:
  ```
  ⚠️ You're on v{local}, but this copy is missing supporting files.
  ```
  Offer repair from the latest release tag.

**If local > remote:**

```
⚠️ This local copy is newer than the latest GitHub Release (v{local} local, v{remote} remote).
```

Do not update from GitHub, because that could replace a newer local release
candidate with an older published release. If the bundle is incomplete, explain
that repair from GitHub is unsafe until the matching release exists.

**If remote > local:**

1. Display version diff:
   ```
   ⚡ Update available: v{local} → v{remote}
   ```

2. Fetch release body from the GitHub API response → display as changelog highlights.
   If release body is empty, show: "See CHANGELOG.md in the repo for details."

3. Display install status:

| State | User-facing status |
|---|---|
| `skills-tracked-complete` | "This is a complete skills-managed install, so I can update it through the skills CLI and rerun setup." |
| `skills-tracked-incomplete` | "This copy is tracked by the skills CLI, but it only has the main instruction file. Strategic Partner needs supporting files, so I will repair it from the latest release." |
| `git-clone` | "This is a git clone, so I can update it from GitHub and rerun setup." |
| `manual-copy` | "This looks like a copied install, so I will repair it from the latest release and rerun setup." |

4. Present via `AskUserQuestion`:
   - **Question**: "Update to v{remote}?"
   - **Options**:
     - [Update now] (Recommended) — Run the safe path for this install state
     - [Show full changelog] — Fetch and display the full CHANGELOG.md from the repo
     - [Not now] — Skip this update

For an incomplete same-version install, change the question to
"Repair this Strategic Partner install from v{remote}?"

### Step 4 — Execute Update Or Repair (if confirmed)

Run only the command path allowed by the install-state classification.

**For `skills-tracked-complete`:**

```
npx skills update strategic-partner -g
```

Then verify the bundle files still exist. If the update leaves the bundle
incomplete, stop and offer the repair path instead of reporting success.

**For `git-clone`:**

```
git -C "{skill-dir}" fetch --tags --prune
git -C "{skill-dir}" pull --ff-only
```

Then verify the local `SKILL.md` version matches `v{remote}`. If it does not,
stop and report what happened instead of guessing.

**For `skills-tracked-incomplete` and `manual-copy`:**

Use the latest release tag, not an unqualified branch:

```
tmp="$(mktemp -d)"
git clone --depth 1 --branch "v{remote}" "https://github.com/{repo}.git" "$tmp/strategic-partner"
rsync -a --delete --exclude='.git' "$tmp/strategic-partner/" "{skill-dir}/"
rm -rf "$tmp"
```

Before running `rsync`, confirm all of these are true:

- `{skill-dir}` exists and contains Strategic Partner `SKILL.md`
- `{skill-dir}` is the intended skill install directory shown to the user
- the user approved replacing the contents of that skill directory from the latest release

After success:
   ```
   ✅ Updated to v{remote}.
   ```

### Step 5 — Run Setup (after update or repair)

After any successful update or repair, re-run the setup script to refresh command registrations:

1. Determine the skill directory path (where SKILL.md lives)
2. Run: `bash {skill-dir}/setup`
3. The setup script handles:
   - Creating/updating command symlinks in ~/.claude/commands/strategic-partner/
   - Detecting stale legacy installations
   - Installing the voice output style if absent, or warning if the
     installed copy is stale (a different `style-version` than the
     shipped one) — your copy is preserved, not overwritten
4. Run `{skill-dir}/.scripts/serena-doctor.sh --field state`. If the state is
   `healthy`, stay silent. Otherwise, offer `/strategic-partner:serena`; never
   repair Serena as an unannounced side effect of updating SP.
5. Final message: "Start a new session to use the updated skill."

## Boundaries

**Will:**
- Check versions against GitHub releases/tags
- Display changelog highlights from release notes
- Inspect the actual installed bundle before choosing an update method
- Classify installs as skills-tracked-complete, skills-tracked-incomplete, git-clone, or manual-copy
- Execute update commands (skills CLI update, git update, or safe clone and sync repair)
- Re-link command files after update

**Will Not:**
- Implement source code changes
- Auto-update without explicit user confirmation
- Modify any project files beyond the skill itself
- Claim the skills CLI is globally broken; the known issue is that the current
  root-layout Strategic Partner install can be incomplete for this supporting bundle

## See Also

- `/strategic-partner:codex-feedback` — adversarial review of the next release. Use after updating to check whether the new version's behavior matches what the CHANGELOG entry promised.
- `/strategic-partner:help` — full subcommand reference. Use when you want to see what changed alongside the version bump.
- `/strategic-partner:serena` — check or repair Serena after an SP compatibility update.
