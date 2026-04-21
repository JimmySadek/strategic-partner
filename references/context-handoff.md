# ⏳ Context Handoff Procedure

Reference file for the strategic-partner advisor. Full handoff protocol with
environment-based thresholds, handoff protocol, and continuation prompt format.

```
🟢 0-60%        🟡 60-70%        🔴 70%+
Normal       →  Monitor      →  Full Handoff
operation       every 2nd       AskUserQuestion
                exchange

════════════════════════════════════════════════
🚨 If the user has configured a PreCompact hook in
   their own ~/.claude/settings.json, it fires when
   Claude Code hits the effective autocompact
   threshold (default ~95%, or the user's own
   CLAUDE_AUTOCOMPACT_PCT_OVERRIDE value).
   → Emergency handoff preparation (backstop signal)
   The SP does NOT ship or set this value.
════════════════════════════════════════════════

Handoff Flow:
Reflect → Slug → Split Writes → Continuation Prompt → Display
```

---

## 🔧 Environment Baseline

### Autocompact threshold — an advisory concern, not a managed setting

Claude Code's autocompact threshold is controlled by the harness env var
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (documented at
https://code.claude.com/docs/en/env-vars.md), which is read from the launching
shell at session start. The default threshold is approximately 95% of the
session's context window.

The SP does NOT set or recommend changes to this value. Changing it globally
would cause surprise compaction in long sessions users want to keep running.
The SP's role regarding autocompact is purely informational:

- **Detect** the active model and context window at startup (Opus 4.7 → 1M,
  other current models → 200K by default)
- **Surface** a session-start advisory on 1M-context sessions noting that
  retrieval reliability degrades above ~256K tokens — known Anthropic
  autocompact bugs on 1M make the default ~95% threshold behave
  inconsistently above that point
- **Defer** the decision to the user — whether to wrap up a session earlier,
  to trigger a handoff sooner, or to accept the risk on a given run

The SP's session-end detection and handoff protocol (see SKILL.md §
Continuity Stewardship) are the mechanisms that translate this awareness
into action: when the user signals wrap-up — whether driven by the 256K
advisory or by natural session completion — the SP packages the handoff,
syncs memory, updates the backlog, and delivers a continuation prompt
that carries all relevant state into a fresh session.

**💡 Self-assessment threshold**: The SP still uses self-assessment for the
intermediate 60-70% threshold below — this is a behavioral advisory signal,
not a hard gate. If the user has independently configured a PreCompact hook
in their `~/.claude/settings.json`, that hook serves as an additional
backstop when their configured threshold fires. The SP does not depend on
that hook being present.

### Known Caveats

Anthropic's Claude Code has open autocompact bugs on 1M-context sessions —
autocompact has been observed to misfire at ~6% or ~400K of the window
regardless of the configured threshold. These are Anthropic-side issues,
outside SP's control:

- https://github.com/anthropics/claude-code/issues/34332
- https://github.com/anthropics/claude-code/issues/42375
- https://github.com/anthropics/claude-code/issues/43989
- https://github.com/anthropics/claude-code/issues/50204

The SP's advisory note at session start (see Environment Baseline above) and
session-end handoff protocol together mitigate the impact — the user is
informed about the 1M retrieval cliff, and the SP proactively detects
session-end signals so handoff happens before upstream autocompact
inconsistency can strand the session.

If the user notices autocompact firing unexpectedly, the above GH issues are
the right place to check. Nothing in SP configuration causes this behavior.

---

## 🚨 PreCompact Hook Integration (user-owned, if configured)

PreCompact is a user-owned Claude Code lifecycle hook (not shipped by the SP —
see `hooks-integration.md` § 🚨 PreCompact). If the user has configured one in
`~/.claude/settings.json`, it fires when the session hits the effective
autocompact threshold (default ~95%, or the user's own
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` value). When that happens, the SP treats it
as an emergency handoff signal:

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

When a PreCompact hook is present, it is the **last reliable opportunity** to
preserve session state. The system will compact regardless — the SP's job is
to preserve state BEFORE that happens. After compaction, earlier context is
summarized and detail is lost.

Users who have not configured a PreCompact hook rely entirely on the SP's
behavioral session-end detection (SKILL.md § Continuity Stewardship). On
1M-context sessions, the orientation context advisory surfaces the
~256K retrieval cliff so the user can plan handoff timing without waiting for
an autocompact trigger.

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
> If auto-compaction fires — whether from the user's configured
> `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` or the default ~95% threshold — the SP
> treats it as an emergency handoff signal, NOT as an opportunity to extend
> the session.

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

**No automated backstop:** Session-end detection relies entirely on the SP's
behavioral protocol — keyword detection for session-end signals and periodic
behavioral keyword and pattern detection (see SKILL.md). There is no automated hook fallback.
The SP must catch session-end signals proactively.

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
| `startup-checklist.md` | Step 5 context advisory on 1M-window sessions |
| `hooks-integration.md` | Hook delivery rules (PreToolUse shipped; SessionStart incompatible; PreCompact user-owned) |
| `companion-script-spec.md` | Historical spec — deprecated in v5.9.0, retained for reference |
