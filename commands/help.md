---
name: help
description: "List all strategic-partner subcommands and usage"
category: utility
complexity: low
mcp-servers: []
---

# /strategic-partner:help — Subcommand Reference

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems or decisions.

## Behavioral Flow
1. **Display**: Present complete subcommand list with descriptions
2. **Complete**: End interaction after displaying information

Key behaviors:
- Information display only — no execution or implementation
- Reference documentation mode without action triggers

## Subcommands

| Command | Purpose |
|---|---|
| `/strategic-partner` | Full advisor persona with startup sequence (no colon) |
| `/strategic-partner:help` | List all subcommands and usage (this command) |
| `/strategic-partner:copy-prompt` | Copy a recently emitted fenced prompt to the clipboard |
| `/strategic-partner:handoff` | Trigger context handoff with split writes |
| `/strategic-partner:status` | Recenter briefing — where we stand, what's next |
| `/strategic-partner:update` | Check for updates and self-update to latest version |
| `/strategic-partner:codex-feedback` | Cross-model adversarial review via Codex CLI (GPT-5.5) |
| `/strategic-partner:backlog` | View project backlog — parked ideas, deferred work |

## Usage

```
/strategic-partner                          → Full advisor session (startup sequence)
/strategic-partner .handoffs/file.md        → Continuation mode (load specific handoff)
/strategic-partner:help                     → This reference
/strategic-partner:copy-prompt              → Copy last fenced prompt to clipboard
/strategic-partner:handoff                  → Save session state + continuation prompt
/strategic-partner:status                   → "Where do we stand?" briefing
/strategic-partner:update                   → Check + update to latest version
/strategic-partner:codex-feedback           → Trigger cross-model review of current decision
/strategic-partner:backlog                  → Surface and review parked backlog items
```

## Notes

- **Main invocation** (`/strategic-partner` with no colon) loads the full advisor persona from
  `skills/strategic-partner/SKILL.md`, including startup sequence, mode detection, and skill catalog.
- **Subcommands** (with colon) are preset operations that run within the advisor context.
  They assume the advisor persona is already active or activate it implicitly.
- **Argument passing**: `/strategic-partner .handoffs/[file]` passes the file path as `$ARGUMENTS`
  to the skill, entering continuation mode directly.
- **Aliases**: `/advisor` and `/sp` also invoke the main persona.

## Boundaries

**Will:**
- Display this reference table
- Explain usage patterns

**Will Not:**
- Execute any commands or create files
- Activate implementation modes
- Engage any tools beyond displaying text
