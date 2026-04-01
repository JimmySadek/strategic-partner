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

### Step 2 — Compare and Present

**If versions match:**
```
✅ You're on the latest version (v{local})
```
Done. End interaction.

**If remote > local:**

1. Display version diff:
   ```
   ⚡ Update available: v{local} → v{remote}
   ```

2. Fetch release body from the GitHub API response → display as changelog highlights.
   If release body is empty, show: "See CHANGELOG.md in the repo for details."

3. Detect install method:
   - Run `npx skills ls 2>/dev/null` and check if `strategic-partner` appears in output:
     → If listed: Update command: `npx skills update`
   - If not listed (manual git clone install):
     → Update command: `cd {skill-directory} && git pull`

4. Present via `AskUserQuestion`:
   - **Question**: "Update to v{remote}?"
   - **Options**:
     - [Update now] (Recommended) — Run the update command
     - [Show full changelog] — Fetch and display the full CHANGELOG.md from the repo
     - [Not now] — Skip this update

### Step 3 — Execute Update (if confirmed)

1. Run the detected update command via Bash
2. After success:
   ```
   ✅ Updated to v{remote}.
   ```

### Step 4 — Run Setup (after update)

After updating, re-run the setup script to refresh command registrations:

1. Determine the skill directory path (where SKILL.md lives)
2. Run: `bash {skill-dir}/setup`
3. The setup script handles:
   - Creating/updating command symlinks in ~/.claude/commands/strategic-partner/
   - Detecting stale legacy installations
4. Final message: "Start a new session to use the updated skill."

## Boundaries

**Will:**
- Check versions against GitHub releases/tags
- Display changelog highlights from release notes
- Execute update commands (npx skills update or git pull)
- Re-link command files after update

**Will Not:**
- Implement source code changes
- Auto-update without explicit user confirmation
- Modify any project files beyond the skill itself
