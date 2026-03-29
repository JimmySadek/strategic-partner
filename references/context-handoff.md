# ⏳ Context Handoff Procedure

Reference file for the strategic-partner advisor. Full handoff protocol with
environment-based thresholds, handoff protocol, and continuation prompt format.

```
🟢 0-60%        🟡 60-70%        🔴 70%+
Normal       →  Monitor      →  Full Handoff
operation       every 2nd       AskUserQuestion
                exchange

════════════════════════════════════════════════
🚨 PreCompact hook fires at 70% (env var override)
   → Emergency handoff preparation (authoritative signal)
════════════════════════════════════════════════

Handoff Flow:
Reflect → Slug → Split Writes → Continuation Prompt → Display
```

---

## 🔧 Environment Baseline

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70`

Set during startup (see `startup-checklist.md`, Step 1). This lowers the
auto-compaction trigger from the default (~95%) to 70%, giving the SP a
**reliable system signal** instead of relying on self-assessed context estimates.

```
┌─ Why This Matters ───────────────────────────────────────────┐
│                                                               │
│  ❌ Without env var:                                          │
│     Claude guesses its own context % → variance is HIGH       │
│     Session with many file reads: real 80%, estimate 60%      │
│     Compaction at ~95% = too late for structured handoff      │
│                                                               │
│  ✅ With env var:                                             │
│     Unreliable self-assessment → reliable platform event      │
│     Context hits 70% → PreCompact hook fires                  │
│     SP intercepts → handoff preparation begins                │
│     Ample room for clean state preservation                   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

**⚠️ Limitation acknowledged**: Self-assessment is still used for the intermediate
threshold (60-70%) below. This is an **advisory signal**, not a hard gate.
The PreCompact hook at 70% serves as the **authoritative backstop** — even if
self-assessment is wrong, the system will trigger handoff preparation at the
real 70% mark.

---

## 🚨 PreCompact Hook Integration

When the PreCompact hook fires (at the configured 70% threshold):

```
┌─ Emergency Handoff Sequence ─────────────────────────────────┐
│                                                               │
│  1. 🛑 Interrupt current work (priority signal)              │
│  2. 📝 Execute emergency handoff (protocol below)            │
│  3. 🧠 Save to Serena memory via write_memory                │
│  4. 💬 Present continuation prompt via AskUserQuestion       │
│  5. 🏷️ Suggest user run: /rename sp-[topic]-MMDD            │
│  6. ✅ System compacts regardless — SP's job is done          │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

The PreCompact hook is the **last reliable opportunity** to preserve session
state. The system will compact regardless — the SP's job is to preserve state
BEFORE that happens. After compaction, earlier context is summarized and detail is lost.

📎 See `hooks-integration.md` for hook configuration details.

---

## 📊 Handoff Thresholds (Two-Tier Escalation)

| Context Level | Tier | Behavior |
|---|---|---|
| 🟢 **0-60%** | Normal | Normal operation. Context is healthy. |
| 🟡 **60-70%** | Monitor | Check every 2nd exchange. Mention handoff is approaching. Begin mentally organizing session state for handoff. |
| 🔴 **70%+** | Full handoff | `AskUserQuestion` proposing handoff NOW. Options: `[Hand off now]` `[One more thing first]` `[Keep going, I'll call it]` |

**Check cadence**: Once context exceeds 60%, check on **every 2nd exchange**. Also check
after every major deliverable and before starting new analysis, regardless of level.

> **Why the SP never suggests `/compact`:** Compaction produces lossy summaries —
> focus instructions are best-effort, not enforcement. The SP's handoff protocol
> writes state to files (`.handoffs/`, Serena memories, git commits), which is
> lossless and cross-session durable. A clean handoff is always preferable to
> a degraded session.
>
> If auto-compaction fires (PreCompact hook at 70%), the SP treats it as an
> emergency handoff signal, NOT as an opportunity to extend the session.

> 💡 The cost of an early handoff offer is one `AskUserQuestion`.
> The cost of missing it is losing **all session state** including unrun
> implementation prompts and scripts.

---

## 🛑 Session End Trigger

Session-end signals trigger the **same handoff protocol** as context pressure.
When the user indicates they are finishing, the SP executes Steps 1-6 below —
identical to context-pressure handoffs. There is no separate "session end" flow.

**Signal patterns** (keywords and intent indicators):
- Explicit: "done", "done for now", "closing", "stopping", "that's it"
- Wrap-up: "let's wrap up", "let's stop", "wrapping up", "ending session"
- Intent: any clear indication the user is finishing work for this session

```
┌─ Two Trigger Paths, One Protocol ──────────────────────────────────┐
│                                                                     │
│  Path 1: Context Pressure              Path 2: Session End          │
│  ┌────────────────────────┐           ┌────────────────────────┐   │
│  │ 🟡 60-70%: monitor     │           │ User signals "done",   │   │
│  │ 🔴 70%+: full handoff  │           │ "wrapping up", etc.    │   │
│  │ 🚨 PreCompact fires    │           │                        │   │
│  └──────────┬─────────────┘           └──────────┬─────────────┘   │
│             │                                     │                 │
│             └──────────────┬──────────────────────┘                 │
│                            ▼                                        │
│              ┌──────────────────────────┐                           │
│              │  SAME Handoff Protocol   │                           │
│              │  Steps 1-6 (below)       │                           │
│              │                          │                           │
│              │  1. Reflect (/insights)  │                           │
│              │  2. Derive slug          │                           │
│              │  3. Split writes         │                           │
│              │  4. Continuation prompt  │                           │
│              │  5. Gitignore coverage   │                           │
│              │  6. Display ══ fences    │                           │
│              └──────────────────────────┘                           │
└─────────────────────────────────────────────────────────────────────┘
```

> **🚨 Anti-pattern:** The SP summarized the session and said goodbye without
> writing a handoff file. This is the exact failure mode this trigger prevents.
> A summary is NOT a handoff. Without the handoff file and continuation prompt,
> all session state is lost when the session closes.

**Backstop:** The Stop hook (`hooks-integration.md`) fires when the session ends
and will trigger the handoff protocol if the SP missed the user's signal. This is
a safety net — the SP should catch session-end signals proactively, not rely on
the hook.

---

## 📋 Handoff Protocol

### Step 1: 🔍 Reflect on the Session

**First**: Run `/insights` to get Claude Code's automated session analysis.
Extract relevant items for the handoff file's `/insights Analysis` section.

**Then** extract:
- **Primary goal**: what the user was trying to achieve
- **Current state**: what's done, what's half-done, what's broken/blocked
- **Key decisions made**: choices and the reasoning behind them
- **Files modified**: every file created, edited, or deleted
- **Open issues**: unresolved questions, blockers, follow-ups
- **Pending prompts**: any implementation prompts not yet run
- **Serena memory changes**: memories created, updated, or deleted this session
- **Next immediate action**: single most important thing to do next

### Step 2: 🏷️ Derive Topic Slug

From session goal and files touched, derive a short hyphenated slug (2-4 words):
`auth-refactor`, `dashboard-stats`, `player-tracking`, `job-tabs-ui`

### Step 3: 📂 Split Writes

| Artifact | Destination | Template |
|---|---|---|
| Session state | `.handoffs/[topic-slug]-[MMDD-HHMM].md` | `assets/templates/handoff-template.md` |
| Pending prompts | `.prompts/[milestone]/[descriptor].md` | `assets/templates/prompt-template.md` |
| Pending scripts | `.scripts/[descriptor].sh` | — |

**Prompt-save decision**: save if >250 lines OR >5 deliverables OR >1 prompt pending.

The handoff file references prompts by path in its "Pending Implementation Prompts" section
and scripts by path in its "Pending Scripts" section.

### Step 4: ✍️ Write the Continuation Prompt

Append to the handoff file after the final `---`.

**🔴 Critical**: The continuation prompt's **FIRST LINE** must be:
```
/strategic-partner .handoffs/[topic-slug]-[MMDD-HHMM].md
```

This restores the advisor persona via the argument path (startup uses `$ARGUMENTS`
to load the specific handoff file). Omitting it means the next session starts in
initialization mode and loses all session state.

The prompt must be **self-contained** — a fresh session with zero context must understand
what to do. Write it as if briefing a new expert collaborator.

**Structure:**
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

**Git State**: Branch `[name]`, [clean/dirty], [ahead/behind], last commit: `[hash] [message]`

**Pending Prompts** (in `.prompts/`):
- `.prompts/[milestone]/[name].md` — [description, status: ready/draft]

**Pending Scripts** (in `.scripts/`):
- `.scripts/[name].sh` — [description, status: ready/draft/discussed]

**Serena Memory Updates**:
- `[memory_name]`: [created/updated/deleted] — [what changed]
- (or "None — no memory changes this session.")

**Next Step**: [exact action to take]

**Important Context**: [critical gotchas, constraints, conventions]
```

### Step 5: 🛡️ Ensure Gitignore Coverage (Auto-Add)

`.gitignore` coverage for `.handoffs/`, `.prompts/`, and `.scripts/` should be
verified at startup. By the time a handoff occurs, coverage should already be in place.

If for any reason it wasn't done at startup, add all three entries **without asking**:
- `.handoffs/`
- `.prompts/`
- `.scripts/`

This is an enforced guardrail, not a discretionary decision — ❌ never ask before adding.

### Step 6: 📤 Display Results

1. ✅ Confirmation: `Handoff written to .handoffs/[filename]`
2. 📄 If prompts saved: `Implementation prompts saved to .prompts/[milestone]/`
3. 📋 Label: **COPY THIS INTO NEW SESSION:**
4. Fenced continuation prompt:

```
══════════════════════ START 🟢 COPY ══════════════════════
/strategic-partner .handoffs/[topic-slug]-[MMDD-HHMM].md

[Full continuation prompt from Step 4]
══════════════════════= END 🛑 COPY ═══════════════════════
```

5. 💡 Reminder: `Open a new Claude Code session and paste the above prompt to continue.`
6. **STOP.** Do not add commentary, praise, or editorial after the fence.

**🚨 Anti-patterns at handoff display:**
- ❌ "Copy the continuation prompt from the handoff file" — NEVER redirect the
  user to the file. The `══` fenced prompt above IS what they copy. Always show it.
- ❌ "Good session!" / "Great work!" / sycophantic summaries — state what was
  accomplished factually. No praise, no "coming alive", no editorial.
- ❌ Omitting the `══` fences — even if context is strained, the fences are mandatory.
- ❌ Skipping `/insights` — must be run in Step 1 (Reflect) before writing the file.

The label is always **outside** the `══` fence. Nothing else surrounds the fence — no
backtick wrappers, no markdown headers between the label and the fence.

---

## 📌 Notes

- `.handoffs/` keeps parallel sessions from colliding (unique slug + timestamp)
- `.scripts/` must also be in `.gitignore` alongside `.handoffs/` and `.prompts/`
- ❌ Never write to `HANDOFF.md` in the root — always use `.handoffs/` subdirectory
- The date/time must use the **current date** from environment — never placeholder
- Do not truncate the continuation prompt — it must be complete and usable as-is
- The `/resume` note in Step 6 reminds users of native session continuity as a fast path

---

## 📎 Cross-Reference

| Reference | Relationship |
|---|---|
| `startup-checklist.md` | Step 3 sets `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` |
| `hooks-integration.md` | PreCompact hook configuration and behavior |
| `companion-script-spec.md` | External monitoring for advanced threshold estimation |
