---
name: try-plugin
description: "Switch from the skill install to the plugin install (leaner voice, faster startup)"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner:try-plugin — Switch to the Plugin

> Strategic Partner ships two install shapes with the same underlying repo:
> the skill (what you're running now) and a plugin packaging with a leaner
> voice and a true session-start hook. This switches your active install
> from one to the other — never both at once, so `/strategic-partner` and
> `/strategic-partner-plugin` never show up side by side in autocomplete.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems or decisions.

## Context Inheritance

This subcommand can run standalone or within an active advisor session.
It does not require the full startup sequence.

## Behavioral Flow

### Step 1 — Locate the Skill and the Plugin

1. Determine `SKILL_DIR` the same way `/strategic-partner:update` does: resolve
   the real path behind `~/.claude/commands/strategic-partner/*.md`, then walk
   up two directories.
2. Check `"${SKILL_DIR}/plugin/strategic-partner/.claude-plugin/plugin.json"`
   exists. If it doesn't, this install predates the plugin packaging —
   tell the user to run `/strategic-partner:update` first, then stop.
3. Check whether `~/.claude/skills/strategic-partner-plugin` already exists.
   If so: "The plugin is already installed. Restart Claude Code if you
   haven't already, then use `/strategic-partner-plugin:strategic-partner`." Stop.

### Step 2 — Confirm

Present via `AskUserQuestion`:

- **Question**: "Switch your active install to the plugin? Same repo, a leaner
  voice, a true session-start hook — but this replaces `/strategic-partner:*`
  with `/strategic-partner-plugin:*` until you switch back."
- **Options**:
  - [Switch now] (Recommended) — Perform the switch described below
  - [Tell me more first] — Summarize the behavior differences (Presence Over
    Protocol, compact orientation, voice v5 — see `plugin/strategic-partner/README.md`)
    then re-ask
  - [Not now] — Stop, no changes

### Step 3 — Execute the Switch (on confirmation)

Run as a single sequence. Some environments alias `rm` to a safety wrapper
that prints a warning and returns non-zero instead of deleting — never call
`rm` directly; use `trash` if present, falling back to alias-bypassing
`\rm` (the leading backslash skips shell alias expansion) if not. Verify
each removal actually happened before reporting success — do not assume it
worked just because the command didn't error.

```bash
ln -snf "${SKILL_DIR}/plugin/strategic-partner" \
  "${HOME}/.claude/skills/strategic-partner-plugin"
if command -v trash >/dev/null 2>&1; then
  trash "${HOME}/.claude/commands/strategic-partner"
else
  \rm -rf "${HOME}/.claude/commands/strategic-partner"
fi
if [ -L "${HOME}/.claude/skills/strategic-partner" ]; then
  if command -v trash >/dev/null 2>&1; then
    trash "${HOME}/.claude/skills/strategic-partner"
  else
    \rm -f "${HOME}/.claude/skills/strategic-partner"
  fi
fi
```

The skill-symlink removal only fires if it's actually a symlink — never a
real directory, matching the existing legacy-install safety check in
`setup`. After running this, check `[ ! -e ~/.claude/commands/strategic-partner ] && [ ! -e ~/.claude/skills/strategic-partner ]`
— if either still exists, the removal failed (likely an `rm`-alias
environment where `trash` is also missing); report that plainly instead of
claiming the switch succeeded.

### Step 4 — Confirm and Direct

```
✅ Switched to the plugin install.
Restart Claude Code, then use /strategic-partner-plugin:strategic-partner
(or just start typing — natural-language triggering still works).
Switch back anytime with /strategic-partner-plugin:switch-to-skill.
```

## Boundaries

**Will:**
- Symlink the plugin into `~/.claude/skills/`
- Remove the skill's own command and skill registrations (not the repo — the
  underlying files are untouched either way)
- Require explicit confirmation before changing anything

**Will Not:**
- Delete any repo content, backlog items, handoffs, or findings — both
  install shapes read the same repo root
- Touch the plugin install if `/strategic-partner-plugin:switch-to-skill`
  is what the user actually wants (see that command instead)
- Auto-restart Claude Code — the user restarts manually

## See Also

- `/strategic-partner-plugin:switch-to-skill` — the reverse of this command, run from the plugin side.
- `/strategic-partner:update` — run this first if `plugin/strategic-partner` doesn't exist yet in your install.
