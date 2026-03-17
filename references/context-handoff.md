# ⏳ Context Handoff Procedure

Reference file for the strategic-partner advisor. Full handoff protocol with
environment-based thresholds, strategic compaction, and continuation prompt format.

```
┌─────────────────────────────────────────────────────────────────────┐
│  Context Lifecycle                                                   │
│                                                                      │
│  🟢 0-50%        🟡 50-65%       🟠 65-72%        🔴 72%+           │
│  Normal       →  Monitor     →  Compact w/    →  Full Handoff       │
│  operation       every 2nd      focus instrs     AskUserQuestion    │
│                  exchange                                            │
│                                                                      │
│  ════════════════════════════════════════════════════                 │
│  🚨 PreCompact hook fires at 70% (env var override)                 │
│     → Emergency handoff preparation (authoritative signal)           │
│  ════════════════════════════════════════════════════                 │
│                                                                      │
│  Handoff Flow:                                                       │
│  Reflect → Slug → Split Writes → Continuation Prompt → Display      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Environment Baseline

### `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70`

Set during startup (see `startup-checklist.md`, Step 3). This lowers the
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
thresholds (50-65%, 65-72%) below. These are **advisory signals**, not hard gates.
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
│  6. ✅ Allow compaction to proceed                           │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

The PreCompact hook is the **last reliable opportunity** to preserve session
state. After compaction, earlier context is summarized and detail is lost.

📎 See `hooks-integration.md` for hook configuration details.

---

## 📊 Handoff Thresholds (Tiered Escalation)

| Context Level | Tier | Behavior |
|---|---|---|
| 🟢 **50-65%** | No action | Normal operation. Context is healthy. |
| 🟡 **65-72%** | Strategic compact | Suggest `/compact` with focus instructions (see below). Extends session life without a full handoff. |
| 🔴 **72%+** | Full handoff | `AskUserQuestion` proposing handoff NOW. Options: `[Hand off now]` `[One more thing first]` `[Keep going, I'll call it]` |

**Check cadence**: Once context exceeds 50%, check on **every 2nd exchange**. Also check
after every major deliverable and before starting new analysis, regardless of level.

> 💡 The cost of an early handoff offer is one `AskUserQuestion`.
> The cost of missing it is losing **all session state** including unrun
> implementation prompts and scripts.

---

## 🟡 Strategic Compaction Protocol (65-72%)

`/compact` is allowed **only with mandatory focus instructions**. Bare `/compact`
(without focus) is ❌ **never acceptable** — it discards context indiscriminately.

### When to Suggest Compaction

- Context is between 65-72% (self-assessed)
- The session has significant remaining work
- A full handoff would be disruptive to the current workflow
- The user has not yet indicated readiness to wrap up

### Focus Instruction Template

```
═══════════════════════ COMPACT FOCUS ═══════════════════════
/compact focus on preserving:
- All decisions made and their rationale
- Pending implementation prompts (full content or .prompts/ paths)
- Current goal and working state
- Files modified this session with what changed
- Active conventions and constraints
- Any unresolved questions or blockers
═════════════════════════════════════════════════════════════
```

### ⚠️ Compaction Guardrails

1. **Always via `AskUserQuestion`**: SP suggests compaction with proposed focus, user decides
2. **Never auto-compact**: The SP does not execute `/compact` without explicit user consent
3. **Verify after compaction**: After `/compact` completes, confirm critical state survived
4. **One compaction per session**: If context pressure returns after compaction, escalate to full handoff

### Example Suggestion

> "⏳ Context is around 68%. We still have work to do on the auth middleware.
> I can compact the session while preserving our decisions and pending prompts,
> which should buy us another 20-30% of context. Alternatively, we can hand off now.
>
> Options: `[Compact with focus]` `[Hand off now]` `[Keep going]`"

---

## 📋 Handoff Protocol

### Step 1: 🔍 Reflect on the Session

Extract:
- **Primary goal**: what the user was trying to achieve
- **Current state**: what's done, what's half-done, what's broken/blocked
- **Key decisions made**: choices and the reasoning behind them
- **Files modified**: every file created, edited, or deleted
- **Open issues**: unresolved questions, blockers, follow-ups
- **Pending prompts**: any implementation prompts not yet run
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

**Next Step**: [exact action to take]

**Important Context**: [critical gotchas, constraints, conventions]
```

### Step 5: 🛡️ Ensure Gitignore Coverage (Auto-Add)

`.gitignore` coverage for `.handoffs/`, `.prompts/`, and `.scripts/` is handled
automatically as a fire-and-verify operation during startup (see `startup-checklist.md`,
Step 4, Agent C). By the time a handoff occurs, coverage should already be in place.

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
6. 🔄 Note: `This session is also named sp-[topic]-MMDD — you can use /resume to return to it.`

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
