---
name: switch-to-skill
description: "Switch from the plugin install back to the skill install"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner-plugin:switch-to-skill — Switch Back to the Skill

> The reverse of `/strategic-partner:try-plugin`. Restores the skill install
> (`/strategic-partner:*`, the current production voice) and removes the
> plugin registration, so only one install shape is ever active at once.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems or decisions.

## Context Inheritance

This subcommand can run standalone or within an active advisor session.
It does not require the full startup sequence.

## Behavioral Flow

### Step 1 — Locate the Repo

1. Resolve `~/.claude/skills/strategic-partner-plugin` — it should be a symlink
   into `<repo>/plugin/strategic-partner`. Follow it (`readlink`) to get the
   real path.
2. The repo root is two directories up from that path (`plugin/strategic-partner`
   → repo root).
3. If the symlink doesn't exist or doesn't resolve to a `plugin/strategic-partner`
   suffix, stop and tell the user: "Couldn't find the plugin's source repo —
   run this from a normal plugin install, not a manual copy."

### Step 2 — Confirm

Present via `AskUserQuestion`:

- **Question**: "Switch your active install back to the skill? This replaces
  `/strategic-partner-plugin:*` with `/strategic-partner:*` and restores the
  production voice."
- **Options**:
  - [Switch back now] (Recommended) — Perform the switch described below
  - [Not now] — Stop, no changes

### Step 3 — Execute the Switch (on confirmation)

Run as a single sequence, stopping and reporting if any step fails:

```bash
ln -snf "${REPO_ROOT}" "${HOME}/.claude/skills/strategic-partner"
bash "${REPO_ROOT}/setup"
rm -f "${HOME}/.claude/skills/strategic-partner-plugin"
```

`setup` re-creates the `~/.claude/commands/strategic-partner/*` symlinks and
handles the output-style install — the same idempotent logic
`/strategic-partner:update` already relies on, run here in the other direction.

### Step 4 — Confirm and Direct

```
✅ Switched back to the skill install.
Restart Claude Code, then use /strategic-partner:* as before.
Switch to the plugin again anytime with /strategic-partner:try-plugin.
```

## Boundaries

**Will:**
- Symlink the repo into `~/.claude/skills/strategic-partner`
- Re-run `setup` to restore command registrations
- Remove the plugin registration
- Require explicit confirmation before changing anything

**Will Not:**
- Delete any repo content — both install shapes read the same repo root
- Modify anything if the repo root can't be confidently resolved

## See Also

- `/strategic-partner:try-plugin` — the reverse of this command, run from the skill side.
