---
name: help
description: "List all strategic-partner subcommands and usage"
category: utility
complexity: low
mcp-servers: []
---

# /strategic-partner-plugin:help — Subcommand Reference

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
| `/strategic-partner-plugin:strategic-partner` | Full advisor persona with startup sequence |
| `/strategic-partner-plugin:help` | List all subcommands and usage (this command) |
| `/strategic-partner-plugin:copy-prompt` | Copy a recently emitted fenced prompt to the clipboard |
| `/strategic-partner-plugin:handoff` | Trigger context handoff with split writes |
| `/strategic-partner-plugin:status` | Recenter briefing — where we stand, what's next |
| `/strategic-partner-plugin:update` | Check for updates and self-update to latest version |
| `/strategic-partner-plugin:serena` | Check, install, repair, verify, or roll back Serena safely |
| `/strategic-partner-plugin:codex-feedback` | Cross-model adversarial review via Codex CLI; also the Codex reviewer step for cross-model build/review |
| `/strategic-partner-plugin:context-file-scan` | Detect drift in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` (18 patterns, interactive or report mode) |
| `/strategic-partner-plugin:backlog` | View project backlog — parked ideas, deferred work |
| `/strategic-partner-plugin:switch-to-skill` | Switch back to the skill install |

## Usage

```
/strategic-partner-plugin:strategic-partner              → Full advisor session (startup sequence)
/strategic-partner-plugin:strategic-partner .handoffs/file.md
                                                         → Continuation mode (load specific handoff)
/strategic-partner-plugin:help                           → This reference
/strategic-partner-plugin:copy-prompt                    → Copy last fenced prompt to clipboard
/strategic-partner-plugin:handoff                        → Save session state + continuation prompt
/strategic-partner-plugin:status                         → "Where do we stand?" briefing
/strategic-partner-plugin:update                         → Check + update to latest version
/strategic-partner-plugin:serena                         → Check or repair Serena with a preview and rollback
/strategic-partner-plugin:codex-feedback                 → Trigger Codex review of a decision, claim, or cross-model build
/strategic-partner-plugin:context-file-scan              → Scan CLAUDE.md / AGENTS.md / GEMINI.md for drift
/strategic-partner-plugin:backlog                        → Surface and review parked backlog items
```

## Notes

- **Main invocation** (`/strategic-partner-plugin:strategic-partner`) loads the full advisor persona from
  `skills/strategic-partner/SKILL.md`, including startup sequence, mode detection, and skill catalog.
- **Subcommands** (with colon) are preset operations that run within the advisor context.
  They assume the advisor persona is already active or activate it implicitly.
- **Argument passing**: `/strategic-partner-plugin:strategic-partner .handoffs/[file]` passes the file path as `$ARGUMENTS`
  to the skill, entering continuation mode directly.
- **Aliases**: `/advisor` and `/sp` are standalone-skill shortcuts; typed plugin commands use the plugin namespace.

## Boundaries

**Will:**
- Display this reference table
- Explain usage patterns

**Will Not:**
- Execute any commands or create files
- Activate implementation modes
- Engage any tools beyond displaying text

## See Also

All SP subcommands are listed above. Each subcommand's own page includes a "See Also" section linking to logically related commands — start with `:status` for orientation, `:handoff` for closing, `:serena` for memory setup, `:backlog` for parked work, `:codex-feedback` for adversarial review or Codex-side review, `:update` for version checks, and `:copy-prompt` for clipboard support.
