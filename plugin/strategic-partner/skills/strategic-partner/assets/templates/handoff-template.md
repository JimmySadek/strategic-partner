# Session Handoff — [date]

## Goal
[The primary objective of this session — one or two sentences]

## Current State
[Precise description of where we are. What's complete, what's in progress,
what's broken or blocked]

## Progress Made
- [completed item 1]
- [completed item 2]
- [...]

## Key Decisions
- [decision]: [reason]
- [...]

## Files Modified
- `path/to/file`: [what changed and why]
- [...]

## Git State
- **Branch**: [current branch name]
- **Status**: [clean / N uncommitted changes — list key files]
- **Ahead/behind**: [e.g., "2 ahead, 0 behind" or "not tracking remote"]
- **Last commit**: [short hash + message of most recent commit]

## Ecosystem Changes
- [Any skills/MCPs that appeared or disappeared during session]
- [Registry updates needed]
- [Or "None" if stable]

## Serena Memory Updates

List any Serena memories written, updated, or deleted during this session.
The continuation session will use this to verify memory state is current.

| Memory | Action | What Changed |
|---|---|---|
| `[memory_name]` | created / updated / deleted | [brief description] |

> If no memories were modified: "None — no memory changes this session."

## Pending Implementation Prompts
- `.prompts/[milestone]/[name].md` — [description, status: ready/draft]
- [... or "None" if all prompts were run]

## Pending Scripts
- `.scripts/[name].sh` — [description, status: ready/draft/discussed]
- [... or "None" if no scripts pending]

## 🔍 /insights Analysis

Run `/insights` before writing this file, then extract relevant items below.

- **Project areas touched**: [areas Claude Code identified as significant]
- **Patterns observed**: [recurring patterns or approaches flagged]
- **Friction points**: [anything /insights flagged as slow, costly, or problematic]

*If /insights produced nothing relevant, write "None significant."*

---

## Open Questions / Blockers
- [anything unresolved or needing follow-up]

## Closure Walk Status

| Group | Status | Detail |
|---|---|---|
| 🧠 1. Staleness verification     | [STATUS_EMOJI] | [one-line outcome] |
| 🏗️ 2. Architecture drift scan   | [STATUS_EMOJI] | [one-line outcome] |
| 🗺️ 3. Routing matrix verification | [STATUS_EMOJI] | [one-line outcome] |
| 💾 4. Persistent memory ledger    | [STATUS_EMOJI] | [one-line outcome] |
| 📝 5. Project conventions ledger  | [STATUS_EMOJI] | [one-line outcome] |
| 📋 6. Working memory ledger       | [STATUS_EMOJI] | [one-line outcome] |
| 📦 7a. Backlog hygiene            | [STATUS_EMOJI] | [one-line outcome] |
| 📄 7b. Pending prompts            | [STATUS_EMOJI] | [one-line outcome] |
| 🔧 7c. Pending scripts            | [STATUS_EMOJI] | [one-line outcome] |
| 🔀 8. Working tree closure        | [STATUS_EMOJI] | [one-line outcome] |

State emoji legend (rendered plain-English; internal names live in `SKILL.md`
§ Closure Evidence Ledger and `references/closure-floor.md`):
- ✅ Checked, all clean — group passed verification, no action needed
- ✅ Already handled — group passed; SP took hygiene action automatically
- 🟡 Needs your input — user input required for this group's resolution
- ⏭️ Skipped (you declined) — user explicitly declined this group's action
- ➖ Doesn't apply this session — group not applicable this session
- 🚨 Uncommitted source changes — git tree has source-edit blockers; handoff blocks until resolved

> If invoked outside the 8-group walk (e.g., manual handoff at
> context-pressure trigger), write "Walk not run — manual handoff path."

## Deferred Floor Signals

List any startup-floor signals (`SP-FLOOR-COMPLETE` summary line) that were
acknowledged but not addressed during the session. Format: `<field>=<value>`
followed by a one-line description of what was deferred and why.

Example: `version=behind (5.14.0 → 5.15.0) — release ceremony scheduled
for tomorrow's session.`

If no signals were deferred, write "None."

## Session Findings
- **Findings file**: `.handoffs/findings-MMDD.md` (or "None — no issues identified")
- **Unresolved**: N items not yet promoted to backlog
- **Promoted**: N items moved to `.backlog/`
- **Action needed**: [describe any findings requiring attention in next session]

## Context Level
[Approximate context usage when handoff triggered, e.g., "~75% — hard trigger"]

## Next Action
[Single concrete next step. Be specific: name the file, function, command,
or UI element to act on]

## FRESH THREAD STARTING PROMPT

══════════════════ START 🟢 COPY ══════════════════
[THE CONTINUATION PROMPT — first line must be /strategic-partner .handoffs/[filename]]
══════════════════= END 🛑 COPY ═══════════════════
