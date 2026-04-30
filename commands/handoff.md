---
name: handoff
description: "Trigger context handoff with split writes and continuation prompt"
category: session
complexity: standard
mcp-servers: [serena]
---

# /strategic-partner:handoff — Context Handoff

> Direct trigger for the context handoff procedure. Run when you want to save session
> state and generate a continuation prompt — either proactively or when context is getting full.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Use ASCII diagrams for any workflow or relationship that has >3 steps.
Default to concise mode; expand for problems or decisions.

## Context Inheritance

This subcommand inherits the active advisor context. It knows what happened in the current
session — it doesn't need its own startup sequence or mode detection.

If invoked outside an active advisor session, it still works but will have less context
to draw from (it will do its best with what's available in conversation history).

## Behavioral Flow

### Step 1 — Load Procedure and Templates

Read these files (parallel) from the skill directory (where SKILL.md lives — resolve
from the skill invocation context, not a hardcoded path):
- `{skill-dir}/references/context-handoff.md` — full procedure
- `{skill-dir}/assets/templates/handoff-template.md` — handoff structure
- `{skill-dir}/assets/templates/prompt-template.md` — for prompts if needed

### Step 2 — Ensure Directory and Gitignore Coverage

Check and create if needed:
- `.handoffs/` directory exists
- `.prompts/` directory exists
- `.scripts/` directory exists
- `.gitignore` contains `.handoffs/` entry — add if missing
- `.gitignore` contains `.prompts/` entry — add if missing
- `.gitignore` contains `.scripts/` entry — add if missing

Auto-add `.gitignore` entries silently — this is an enforced guardrail, not a
discretionary edit (consistent with SKILL.md fire-and-forget and context-handoff.md).

### Step 3 — Execute Handoff Protocol

Follow the procedure from `references/context-handoff.md` exactly:

1. **Reflect** — Extract from session context:
   - Primary goal
   - Current state (done, in-progress, blocked)
   - Key decisions made with reasoning
   - Files modified
   - Open issues / blockers
   - Pending implementation prompts
   - Next immediate action

2. **Derive topic slug** — 2-4 word hyphenated slug from session goal and files touched
   (e.g., `auth-refactor`, `subcommand-setup`, `dashboard-stats`)

3. **Split writes**:

   **Session state** → `.handoffs/[topic-slug]-[MMDD-HHMM].md`
   Use the handoff template structure.

   **Pending implementation prompts** (if any) → `.prompts/[milestone]/[descriptor].md`
   Save if: >250 lines OR >5 deliverables OR >1 prompt pending.

   **Pending operational scripts** (if any) → `.scripts/[descriptor].sh`
   Scripts that were discussed or partially designed during this session.

   The handoff file references saved prompts and scripts by path.

4. **Write continuation prompt** — Append after the final `---` in the handoff file.

   **CRITICAL**: The continuation prompt's FIRST LINE must be:
   ```
   /strategic-partner .handoffs/[topic-slug]-[MMDD-HHMM].md
   ```

   The prompt must be self-contained — a fresh session with zero prior context must
   understand what to do. Write it as if briefing a new expert collaborator.

### Step 4 — Display Results

Present in this exact format:

```
✅ Handoff written to `.handoffs/[filename]`
📁 Implementation prompts saved to `.prompts/[milestone]/` (if applicable)
```

Then a separator, followed by a clearly labeled block:

```
📋 COPY THIS INTO A NEW SESSION:

══════════════════ START 🟢 COPY ══════════════════
[The full continuation prompt — complete and usable as-is]
══════════════════= END 🛑 COPY ═══════════════════

Open a new Claude Code session and paste the above prompt to continue.
```

## Thresholds Reference (Tiered Escalation)

For awareness (the advisor monitors these during normal operation):

| Context Level | Tier | Action |
|---|---|---|
| **>60%** | Monitoring | Check context on every 2nd exchange |
| **67%** | Gentle nudge | Visible inline note, begin extracting session state |
| **72%** | Strong push | AskUserQuestion proposing handoff NOW |
| **77%** | Urgent | Execute handoff immediately (confirm slug only) |

## Backlog Stewardship

Closure includes a backlog scan. As part of the closure flow (per
SKILL.md § Closure Evidence Ledger, the Backlog row), the SP surfaces
items in `.backlog/*.md` whose `trigger` field has fired against current
project state, and offers to promote unresolved findings from this
session if the user wants to park them as backlog items rather than let
them carry forward in the next session's findings file.

Two layers, distinct purposes:

- **Findings** — lightweight, automatic, session-scoped. Captured as
  the SP encounters issues during the session and written to
  `.handoffs/findings-MMDD.md`. Carry forward to the next session's
  orientation by default.
- **Backlog** — curated, selective, project-scoped. Items live in
  `.backlog/*.md` with structured frontmatter (`title`, `status`,
  `priority`, `trigger`). Reviewed via `/strategic-partner:backlog` or
  surfaced at startup when triggers fire.

Handoff bridges them: at session-end, the SP looks at unresolved
findings and asks (via `AskUserQuestion`, only when the promotion scope
is unclear) whether any should become backlog items. Items with clear
"park this" / "for later" intent already ratified during the session
are filed automatically (RESOLVED-AUTO on the Backlog ledger row); the
AUQ only fires when the SP has no signal whether a finding belongs in
backlog or should stay as a session note.

See SKILL.md § Backlog Stewardship for the canonical spec, including
proactive trigger signals during normal advisory flow.

## Boundaries

**Will:**
- Read session context and synthesize state
- Write handoff file to `.handoffs/`
- Write implementation prompts to `.prompts/` (if applicable)
- Update `.gitignore` (with confirmation)
- Display the continuation prompt for copy-paste

**Will Not:**
- Push to git or create commits (that's a separate ask-before-act decision)
- Delete or overwrite existing handoff files
- Implement any source code changes

## See Also

- `/strategic-partner:status` — mid-session check on where things stand. Use before triggering handoff if you want a sanity check on what state will be captured.
- `/strategic-partner:backlog` — review parked items and defer unresolved findings before closing. Use during the closure flow when the SP asks about backlog promotion.
- `/strategic-partner:copy-prompt` — pull the continuation prompt this command emitted into the OS clipboard. Use immediately after handoff when you're about to open a new session.
