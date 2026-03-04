# Context Handoff Procedure

Reference file for the strategic-partner advisor. Full handoff protocol with
thresholds, split writes, and continuation prompt format.

---

## Handoff Thresholds (Tiered Escalation)

| Context Level | Tier | Behavior |
|---|---|---|
| **>60%** | Monitoring | Check context on **every 2nd exchange** |
| **67%** | Gentle nudge | Visible inline note at end of response: *"⏳ Context ~67%. Preparing handoff materials in the background. No action needed yet."* Begin silently extracting session state. |
| **72%** | Strong push | `AskUserQuestion` proposing handoff NOW. Options: [Hand off now] [One more thing first] [Keep going, I'll call it] |
| **77%** | Urgent | Execute handoff immediately. `AskUserQuestion` only to confirm the topic slug, then write immediately. Do not wait for permission to hand off. |

**Check cadence**: once context exceeds 60%, check on every 2nd exchange. Also check
after every major deliverable and before starting new analysis, regardless of level.

The cost of an early handoff offer is one AskUserQuestion. The cost of missing it is
losing all session state including unrun implementation prompts and scripts.

Never recommend `/compact`. Auto-compaction at ~95% is a safety net for runaway sessions,
not a context management strategy. The handoff protocol is the strategy.

---

## Handoff Protocol

### Step 1: Reflect on the Session

Extract:
- **Primary goal**: what the user was trying to achieve
- **Current state**: what's done, what's half-done, what's broken/blocked
- **Key decisions made**: choices and the reasoning behind them
- **Files modified**: every file created, edited, or deleted
- **Open issues**: unresolved questions, blockers, follow-ups
- **Pending prompts**: any implementation prompts not yet run
- **Next immediate action**: single most important thing to do next

### Step 2: Derive Topic Slug

From session goal and files touched, derive a short hyphenated slug (2–4 words):
`auth-refactor`, `dashboard-stats`, `player-tracking`, `job-tabs-ui`

### Step 3: Split Writes

**Session state** → `.handoffs/[topic-slug]-[MMDD-HHMM].md`
Use the template from `assets/templates/handoff-template.md`.

**Pending implementation prompts** → `.prompts/[milestone]/[descriptor].md`
Use the template from `assets/templates/prompt-template.md`.

**Pending operational scripts** → `.scripts/[descriptor].sh`
Scripts that were discussed but not yet generated during this session.

**Prompt-save decision**: save if >80 lines OR >3 deliverables OR >1 prompt pending.

The handoff file references prompts by path in its "Pending Implementation Prompts" section
and scripts by path in its "Pending Scripts" section.

### Step 4: Write the Continuation Prompt

Append to the handoff file after the final `---`.

**Critical**: The continuation prompt's FIRST LINE must be:
```
/strategic-partner .handoffs/[topic-slug]-[MMDD-HHMM].md
```

This restores the advisor persona via the argument path (startup Step 1 uses `$ARGUMENTS`
to load the specific handoff file). Omitting it means the next session starts in
initialization mode and loses all session state.

The prompt must be **self-contained** — a fresh session with zero context must understand
what to do. Write it as if briefing a new expert collaborator.

Structure:
```
/strategic-partner .handoffs/[filename]

We're working on [project name and one-line description].

**Current Goal**: [what we're trying to accomplish]

**Where We Are**: [current state — precise enough to orient without prior conversation]

**What Was Done This Session**:
- [item 1]
- [item 2]

**Key Decisions Made**:
- [decision]: [reason]

**Files Modified**:
- `path/to/file`: [what changed]

**Pending Prompts** (in `.prompts/`):
- `.prompts/[milestone]/[name].md` — [description, status: ready/draft]

**Pending Scripts** (in `.scripts/`):
- `.scripts/[name].sh` — [description, status: ready/draft/discussed]

**Next Step**: [exact action to take]

**Important Context**: [critical gotchas, constraints, conventions]
```

### Step 5: Ensure Gitignore Coverage

Check `.gitignore` for both directories:
- `.handoffs/` — add if missing
- `.prompts/` — add if missing

### Step 6: Display Results

1. Confirmation: `Handoff written to .handoffs/[filename]`
2. If prompts saved: `Implementation prompts saved to .prompts/[milestone]/`
3. Separator line
4. Block labeled **"COPY THIS INTO NEW SESSION"** with the full continuation prompt
5. Reminder: `Open a new Claude Code session and paste the above prompt to continue.`

---

## Notes

- `.handoffs/` keeps parallel sessions from colliding (unique slug + timestamp)
- `.scripts/` must also be in `.gitignore` alongside `.handoffs/` and `.prompts/`
- Never write to `HANDOFF.md` in the root — always use `.handoffs/` subdirectory
- The date/time must use the **current date** from environment — never placeholder
- Do not truncate the continuation prompt — it must be complete and usable as-is
