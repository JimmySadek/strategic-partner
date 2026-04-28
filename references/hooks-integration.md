# 🔗 Hooks Integration Guide

Reference file for the strategic-partner advisor. Comprehensive hooks strategy
for proactive session management. Phased rollout from essential to advanced.

```
┌─────────────────────────────────────────────────────────────────────┐
│  SP Hooks Rollout (v5.14.0)                                          │
│                                                                      │
│  Phase 1 (Essential)     Phase 2 (Monitoring)    Phase 3 (Advanced) │
│  ┌──────────────────┐   ┌──────────────────┐    ┌────────────────┐  │
│  │ 🛡️ PreToolUse    │   │ 🤖 SubagentStart │    │ 🔧 ConfigChange│  │
│  │    (identity) ✅ │   │ 🤖 SubagentStop  │    │ ❌ PostToolUse │  │
│  │ 📝 PostToolUse   │   │ 💬 UserPrompt    │    │    Failure     │  │
│  │  (tracker)    ✅ │   │    Submit        │    │ 🔌 Custom      │  │
│  │ 🛑 Stop          │   └──────────────────┘    └────────────────┘  │
│  │  (validator)  ✅ │                                               │
│  │ 🚨 PreCompact    │                                               │
│  │    (user-owned)  │                                               │
│  │ 🚀 SessionStart  │                                               │
│  │  (incompatible)  │                                               │
│  └──────────────────┘                                               │
│  ✅ = shipping in SKILL.md frontmatter                               │
│  ◄── implement first    ◄── visibility      ◄── power users        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Hook Delivery

Hooks are delivered via **SKILL.md frontmatter** (skill-scoped — see limitations
below). Claude Code reads the `hooks:` section at skill load time and registers
them for the **active lifecycle of that skill**. Per Anthropic's hooks
documentation (https://code.claude.com/docs/en/hooks), these hooks are scoped
to the component's lifecycle and only run while that component is active.

This is appropriate for PreToolUse / PostToolUse hooks that fire during tool
calls made while the skill is invoked (the SP's identity guard is exactly this
pattern — see Phase 1 below), but **NOT for SessionStart hooks**, which fire
once at Claude Code session start before any skill activates. v5.9.0 investigated
shipping a SessionStart hook via SKILL.md frontmatter, confirmed empirically that
it never fires (the skill is not yet active at session start), and removed it —
see the 🚀 SessionStart section below for the full write-up.

### Why Frontmatter (not settings.json)

| Approach | Ships with skill? | Scope | Maintenance |
|---|---|---|---|
| SKILL.md frontmatter ✅ | Yes — travels with the skill file | Session (active while skill is loaded) | Zero — automatic on skill load |
| `.claude/settings.json` ❌ | No — gitignored, per-machine | Persistent (all sessions) | Manual install + update |

Frontmatter hooks are the correct mechanism for skill-owned behavior. Settings.json
hooks are appropriate for user-owned customizations that should persist independently
of any skill.

### Skill-dir resolution (there is no `CLAUDE_SKILL_DIR`)

`${CLAUDE_SKILL_DIR}` is **NOT** a real Claude Code runtime variable. v5.4.1
confirmed it is unset in hook execution contexts (which is why the PreToolUse
guard was inlined into SKILL.md frontmatter rather than delegated to an external
script). Empirical testing in the SP model's Bash runtime confirms it is also
unset there — `echo "$CLAUDE_SKILL_DIR"` returns an empty string. `CLAUDE_PROJECT_DIR`
and `CLAUDE_PLUGIN_ROOT` are similarly unset in both contexts.

Two patterns work in place of it:

1. **Inside SKILL.md frontmatter hooks** — INLINE the hook logic directly in the
   `command: |` block. Do NOT reference external scripts via any env var. The
   PreToolUse guard in SKILL.md follows this pattern. A standalone script file
   may coexist in `hooks/` for testing and documentation (see
   `hooks/guard-impl.sh`), but the inline version is the execution path.

2. **Inside prose Bash snippets the SP model runs at startup** — resolve the
   install dir via the stable command symlinks created by `setup`:

   ```bash
   SP_ANY_CMD=$(ls "${HOME}/.claude/commands/strategic-partner/"*.md 2>/dev/null | head -1)
   if [ -n "$SP_ANY_CMD" ]; then
     SP_SKILL_DIR=$(dirname "$(dirname "$(readlink -f "$SP_ANY_CMD")")")
     # ... use $SP_SKILL_DIR ...
   fi
   ```

   The positive-if-block wrapper (rather than an early-exit guard with a
   bare `return`) keeps the snippet copy-safe: `return` only works inside a
   function or a sourced script, so a user pasting it into a standalone
   `bash script.sh` invocation would hit an error. This is the same pattern
   used by `references/startup-checklist.md`.

   `readlink -f` resolves the symlink chain to the actual command file path;
   two `dirname` calls walk up from `commands/some.md` to the install dir. This
   works on all install paths (skillshare, git clone, alternate dirs) because
   `setup` always creates the symlinks at that canonical `$HOME/.claude/commands/strategic-partner/`
   location.

> **Historical note:** CHANGELOG v5.4.1 documents the discovery that
> `${CLAUDE_SKILL_DIR}` is not honored by Claude Code; the PreToolUse guard was
> inlined that release. CHANGELOG v5.9.0 documents the completion of its removal
> from all non-historical references (startup-checklist.md prose snippets and
> this section) and the investigation/removal of the SessionStart hook
> attempt — see the 🚀 SessionStart section below.

---

## 🔴 Phase 1: Essential Hooks

These hooks provide the **minimum viable integration** for reliable session management.
Implement these first.

### 🛡️ PreToolUse — Identity Guard (shipping)

**Event**: Fires before Edit / Write / MultiEdit / NotebookEdit / Bash /
Serena write-mutating tools, **only while the SP skill is active**.

**SP Behavior**: Blocks source-file mutations with exit code 2 unless the
path is in an allow-list (`.prompts/`, `.handoffs/`, `.scripts/`, `.backlog/`,
`CLAUDE.md`, `CHANGELOG.md`, `README.md`, `SKILL.md`, `.claude/`, `.gitignore`).
This is the structural enforcement behind the SP's "never edits source files"
identity rule.

**Delivery**: Inlined directly in SKILL.md frontmatter under
`hooks: PreToolUse:` as a `command: |` block. Standalone reference script at
`hooks/guard-impl.sh` is kept in sync for testing. Skill-scoped lifecycle is
correct here — the guard needs to fire only while the SP is active (that is
when it must block SP-initiated source edits); PreToolUse hooks fire during
tool calls made while the skill is invoked, which matches the desired scope.

---

### 🚀 SessionStart — investigated in v5.9.0, architecturally incompatible

**TL;DR**: A SessionStart hook in SKILL.md frontmatter **cannot fire at
Claude Code session start**. v5.9.0 investigated this approach, confirmed it
empirically, and removed it. The SP's contribution to context-handoff timing
on large-window sessions is now a pure **advisory note** delivered in
orientation — see `startup-checklist.md` Step 5 "Context advisory" bullet and
`context-handoff.md` § Environment Baseline.

**Why it can't work (lifecycle mismatch)**: Per Anthropic's hooks documentation
(https://code.claude.com/docs/en/hooks), hooks declared in a component's
frontmatter are **scoped to that component's lifecycle and only run while
that component is active**. SessionStart fires at Claude Code session start —
before any skill activates. A SessionStart hook declared in a skill's
frontmatter is therefore registered for an event that, by the harness's own
lifecycle rules, cannot fire for that skill. Evidence:

- An instrumented SessionStart hook inlined in `SKILL.md` frontmatter was
  tested on a fresh Claude Code session invoked via `/strategic-partner`. The
  hook's trace line (`/tmp/sp-hook-trace.log`) never appeared — the hook did
  not fire.
- Of all skills installed at `~/.claude/skills/` on the development machine,
  only the SP declared SessionStart in SKILL.md frontmatter. Other
  well-established skills (including ones previously cited as precedents)
  have no `hooks:` section at all or use only tool-lifecycle events.
- Issue anthropics/claude-code#17688 (OPEN, labeled `bug`, 22 comments)
  reports that even PreToolUse hooks in SKILL.md frontmatter fail within
  plugins on CC 2.1.5 — confirming the skill-frontmatter hook surface is
  unreliable even for architecturally-valid events.

**What IS real**: `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is a documented harness
env var (https://code.claude.com/docs/en/env-vars.md) honored at Claude Code
startup from the launching shell. Setting `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=5`
via `export` before launching `claude` works — empirical test confirmed
compaction fires almost immediately on the resulting session. This is a
**user-side shell concern**, not a skill-side automation. The SP does not
ship any mechanism to set it, recommend bash snippets for it, or install it
into user shells — changing it globally would cause surprise compaction in
long sessions users want to keep running. That is a footgun the SP
deliberately avoids.

**What the SP does instead**: On 1M-context sessions (Opus 4.7 or any model
run with `SP_CONTEXT_WINDOW=1M` exported), the SP surfaces an informational
note in orientation: retrieval reliability degrades above ~256K tokens
(known Anthropic autocompact issues #34332, #42375, #43989, #50204 make the
default ~95% threshold behave inconsistently above that point), so the user
may want to plan handoff timing accordingly. No settings are changed, no
commands are run. The note is situational awareness; the SP's session-end
detection and handoff protocol (SKILL.md § Continuity Stewardship) remain
the mechanism that translates awareness into action. See
`startup-checklist.md` Step 5 and `context-handoff.md` § Environment
Baseline for the exact copy and trigger conditions.

---

### 🚨 PreCompact (user-owned, optional)

**Event**: Fires when Claude Code reaches the autocompact threshold (by
default, approximately 95% of the session's context window, per Anthropic
documentation at https://code.claude.com/docs/en/env-vars.md). Threshold
configuration is entirely user-owned — SP does not set or recommend a value.
See the 🚀 SessionStart section above for why the SP cannot manage this
setting from within a skill.

**SP Behavior (if the user configures this hook in their own `settings.json`):**
```
┌─ PreCompact Emergency Sequence ─────────────────────┐
│  1. 🛑 Extract session state immediately            │
│  2. 📂 Write handoff to .handoffs/[topic-slug]      │
│  3. 💾 Save critical decisions + pending prompts     │
│  4. 🧠 Write session summary to Serena memory       │
│  5. 🏷️ Suggest user finalize name: /rename sp-[topic]│
│  6. 💬 Present continuation prompt (AskUserQuestion) │
│  7. ✅ System compacts regardless — SP's job is done │
└──────────────────────────────────────────────────────┘
```

**Configuration (user-owned, not shipped with the skill):**
```json
{
  "hooks": {
    "PreCompact": [
      {
        "type": "command",
        "command": "echo 'CONTEXT_THRESHOLD_REACHED' >> /tmp/sp-context-alerts.log",
        "description": "SP context threshold alert - triggers handoff preparation"
      }
    ]
  }
}
```

PreCompact is a Claude Code session lifecycle event — it is NOT skill-scoped,
so a PreCompact hook in SKILL.md frontmatter would have the same lifecycle
mismatch as SessionStart. If a user wants this behavior, they add it to their
own `~/.claude/settings.json` where it is genuinely session-scoped.

Independent of whether the user configures a PreCompact hook, the SP's
session-end detection and handoff protocol (SKILL.md § Continuity Stewardship)
remain the primary mechanism for preserving session state. The PreCompact
hook is a belt-and-suspenders backstop, not a required dependency.

---

### 🛑 Stop — RESTORED in v5.14.0 as response-end validator (Layer 2)

The Stop hook was removed in v5.0.0 because it was being used for session-end
detection — the wrong scope for a hook that fires on every turn. v5.14.0 restores
it for the **correct** scope: **response-end validation**. Every turn IS the right
scope for checking structural rules against the assistant's just-completed response.

**What Layer 2 validates (per synthesis Rev 3 scope split):**

| Check | Scope | What it detects |
|---|---|---|
| AUQ-must-be-AUQ | Always-on | Sentence-final `?` in prose without an `AskUserQuestion` tool call in the same turn |
| Tool-availability claims | Always-on | First-person tool-access claim ("I can run", "I have access to", "I cannot access", etc.) without a verified call |
| Fence-write coupling | Fence-conditional | `══ START 🟢 COPY ══` fence without a preceding `Write` to `.handoffs/last-prompts/[N].md` in the same turn |

**AUQ scan: line-by-line.** Both the inlined SKILL.md hook and the standalone
`hooks/lib/validators.sh::validate_auq_must_be_auq` iterate the assistant turn
line-by-line (preserving newlines from the JSONL transcript) and flag the first
prose line ending in `?`. An earlier draft of the inlined hook collapsed the turn
into a single line via `tr '\n' ' '`, which made the check inert for any prose
question that wasn't the literal last sentence of the response — fixed in the
follow-up patch to cecd1be so the inlined runtime parity matches the standalone.

**Tool-availability scope: first-person only.** The patterns are scoped to phrases
where the model is claiming its own tool access — `"I can run "`, `"I can call "`,
`"I have access to "`, `"I cannot access "`, `"I don't have access"`,
`"I'm able to run "`, `"I am able to run "`. Broad substring matches like
`"is available"`, `"is not available"`, `"is unavailable"`, `"not detected"`,
and `"detected"` were intentionally excluded — they false-positive on common
neutral SP phrases ("the harness is available at /tmp/foo", "Sonnet 4.6 is
available", "the test suite is unavailable") that are statements about the world,
not unverified tool-availability claims by Claude. Both the inlined SKILL.md
hook and `hooks/lib/validators.sh::validate_tool_availability` use the same
tightened pattern set (Layer 2 and Layer 3 stay in sync).

**Exit behavior:** Exit 2 on first violation. Stop hook exit-2 prevents Claude from
completing its turn and forces continuation — the stderr message becomes Claude's
revision context. Exit 0 on pass.

**Delivery:** Inlined in SKILL.md frontmatter under `hooks: Stop:` (same delivery
surface as the PreToolUse guard). Standalone reference script at
`hooks/stop-validator.sh` kept in sync for local testing. Validator logic extracted
to `hooks/lib/validators.sh` and shared with Layer 3 transcript lint.

**Empirical findings (from `.handoffs/v514-spike-findings-0429.md` Q3 — GREEN):**

The spike confirmed three Stop-hook stdin facts that are NOT documented in Anthropic's
official hooks documentation (as of 2026-04-29):

1. **`last_assistant_message` field** — included in Stop hook stdin JSON. Contains
   the trailing text block of the final response. Used for a fast-path check
   (is `══` or `?` present?) before falling back to full transcript parsing.
   This avoids the expensive JSONL parse on clean responses.

2. **`stop_hook_active` boolean** — included in Stop hook stdin JSON. The validator
   MUST exit 0 immediately when `stop_hook_active=true`. This is Anthropic's own
   loop-prevention signal: a Stop hook exit-2 causes a forced continuation, and if
   the validator re-fires at the end of THAT continuation and exits 2 again, the
   result is an infinite loop. The `stop_hook_active=true` check is the circuit
   breaker.

3. **Missing transcript (graceful degradation)** — if `transcript_path` does not
   exist on disk (e.g., session started with `--no-session-persistence`), the
   validator exits 0 rather than failing. Normal interactive sessions always
   persist the transcript; the graceful exit is for robustness in edge cases.

The full empirical Stop hook stdin schema (confirmed via subprocess `claude -p` run,
2026-04-29):
```json
{
  "session_id": "...",
  "transcript_path": "/Users/.../<encoded-cwd>/<session-uuid>.jsonl",
  "cwd": "...",
  "permission_mode": "...",
  "hook_event_name": "Stop",
  "stop_hook_active": false,
  "last_assistant_message": "..."
}
```

**Plugin-context caveat (anthropics/claude-code#17688):** Issue #17688 (OPEN, labeled
bug, 22 comments) reports that SKILL.md frontmatter hooks sometimes fail in plugin
contexts on CC 2.1.5+. If Layer 2 is not firing for a user, the root cause is likely
this issue. The documented fallback for those users is Layer 3 (the release-time
transcript lint at `tests/lint-transcripts.sh`), which catches violations at release
time regardless of runtime hook availability.

**Theme C coordination note:** Theme C's 6-state closure evidence ledger (SKIPPED /
RESOLVED / RESOLVED-AUTO / etc.) emits state markers in the final assistant turn. Layer
2 explicitly does NOT validate closure-ledger state markers — they are status output,
not user-directed questions or copy fences. Step 4's Theme C implementation must not
introduce patterns that would trigger the AUQ-must-be-AUQ or fence-write coupling
checks unintentionally.

**v5.0.0 distinction:** v5.0.0's removal was architecturally correct — Stop was wrong
for session-end detection. v5.14.0's restoration is architecturally correct — Stop is
right for response-end validation. Same event, different (and correct) use case.

---

## 🟡 Phase 2: Monitoring Hooks

These hooks add **visibility** into session activity for better advisory decisions.

### 🤖 SubagentStart / SubagentStop

**Event**: Fires when a sub-agent is spawned or completes.

**SP Behavior:**
- 📊 Track which agents are currently running (agent dashboard)
- 📝 Log agent purpose, model, and spawn time
- ✅ On SubagentStop: capture result summary, verify completion (fire-and-verify)
- ❌ Detect agent failures and surface them proactively

**Configuration:**
```json
{
  "hooks": {
    "SubagentStart": [
      {
        "type": "command",
        "command": "echo \"AGENT_START: $(date +%H:%M:%S)\" >> /tmp/sp-agent-tracking.log",
        "description": "Track sub-agent lifecycle for SP advisory"
      }
    ],
    "SubagentStop": [
      {
        "type": "command",
        "command": "echo \"AGENT_STOP: $(date +%H:%M:%S)\" >> /tmp/sp-agent-tracking.log",
        "description": "Track sub-agent completion for fire-and-verify pattern"
      }
    ]
  }
}
```

**💡 Value**: Enables the fire-and-verify pattern from `startup-checklist.md`.
Without these hooks, agent verification requires polling or inline checks.

---

### 📝 PostToolUse — write tracker (Layer 1, shipping in v5.14.0)

**Event**: Fires after Write / Edit / MultiEdit tool calls complete (filtered by
matcher). Skill-scoped via SKILL.md frontmatter — fires only while the SP is active.

**SP Behavior (v5.14.0):**
- Filters for Write/Edit/MultiEdit calls where `file_path` matches
  `.handoffs/last-prompts/[0-9]+.md`
- On match: appends `<session_id>\t<timestamp>\t<file_path>` to
  `.claude/sp-state/last-prompt-writes.txt`
- Exit 0 always — tracking only, never blocks
- Session-scoped cleanup: if the first entry in the state file belongs to a
  different `session_id`, the file is truncated before appending. Prevents
  stale cross-session state from polluting fence-write coupling checks.
- Uses `command -v jq` to detect jq; falls back to bash+grep for field extraction.

**State file:** `.claude/sp-state/last-prompt-writes.txt`
**Format per line:** `<session_id>\t<timestamp_iso8601>\t<file_path>`

**Why this exists:** The Stop hook (Layer 2) needs to answer "did a write to
`.handoffs/last-prompts/[N].md` precede the fence emission in this turn?" The JSONL
transcript records which tool calls were made, but the state file provides a fast,
session-scoped, pre-parsed answer. Layer 1 produces the evidence; Layer 2 consumes it.

**Standalone reference script:** `hooks/postuse-tracker.sh` — kept in sync with the
inlined SKILL.md frontmatter version for local testing and documentation.

**Delivery:** Inlined in SKILL.md frontmatter under `hooks: PostToolUse:` alongside
the existing PreToolUse guard. Matcher: `"Write|Edit|MultiEdit"`.

**Previous behavior (pre-v5.14.0):**
The PostToolUse section below described a /tmp/-based file-modification log for
handoff state reconstruction. That was an advisory pattern never shipped in
SKILL.md frontmatter. v5.14.0 ships the first actual PostToolUse hook.

**Configuration (reference — see SKILL.md for the inlined version):**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "... (see SKILL.md frontmatter PostToolUse block) ...",
        "description": "Track .handoffs/last-prompts/ writes for Layer 2 fence-write coupling check",
        "toolNames": ["Write", "Edit", "MultiEdit"]
      }
    ]
  }
}
```

---

### 💬 UserPromptSubmit

**Event**: Fires when the user sends a message.

**SP Behavior:**
- 🔢 Count exchange turns for context budget estimation
- 📊 Estimate context consumption per exchange
- ⏳ Trigger context monitoring checks (see `context-handoff.md` thresholds)

**Configuration:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "TURNS=$(cat /tmp/sp-turn-count.txt 2>/dev/null || echo 0); echo $((TURNS+1)) > /tmp/sp-turn-count.txt",
        "description": "SP exchange counter for context budget estimation"
      }
    ]
  }
}
```

---

## 🟠 Phase 3: Advanced Hooks

These hooks provide deeper integration for **power users** and diagnostics.

### 🔧 ConfigChange

**Event**: Fires when Claude Code settings change during a session.

**SP Behavior:**
- 🔍 Detect changes that affect advisory (e.g., effort level changed externally)
- ⚠️ Warn if SP identity settings are overridden (`/effort` lowered, `/color` changed)
- 🛡️ Track permission mode changes that might affect prompt execution

**Configuration:**
```json
{
  "hooks": {
    "ConfigChange": [
      {
        "type": "command",
        "command": "echo \"CONFIG_CHANGED: $(date +%H:%M:%S)\" >> /tmp/sp-config-tracking.log",
        "description": "Monitor settings changes affecting SP advisory"
      }
    ]
  }
}
```

---

### ❌ PostToolUseFailure

**Event**: Fires when a tool call fails.

**SP Behavior:**
- 📝 Log tool failures for diagnostic purposes
- 🔍 Detect patterns (e.g., repeated Serena failures → language server issue)
- 💡 Surface actionable failure patterns to user proactively
- 🔄 Trigger fallback strategies (see RULES.md, Serena Fallback Strategy)

**Configuration:**
```json
{
  "hooks": {
    "PostToolUseFailure": [
      {
        "type": "command",
        "command": "echo \"TOOL_FAILURE: $TOOL_NAME $(date +%H:%M:%S)\" >> /tmp/sp-error-tracking.log",
        "description": "SP tool failure diagnostics and pattern detection"
      }
    ]
  }
}
```

---

### 🔌 Custom Hooks (File-Based Signaling)

For SP-specific events that don't map to built-in hook events:

```
┌──────────────────┬──────────────────────────────┬──────────────────────────┐
│  Signal          │  File                        │  Purpose                 │
├──────────────────┼──────────────────────────────┼──────────────────────────┤
│  🚨 Context      │  /tmp/sp-context-alerts.log  │  Companion script alerts │
│  🤖 Agents       │  /tmp/sp-agent-tracking.log  │  Sub-agent lifecycle     │
│  📝 Files        │  /tmp/sp-file-tracking.log   │  Modified files list     │
│  🔢 Turns        │  /tmp/sp-turn-count.txt      │  Exchange counter        │
│  ❌ Errors       │  /tmp/sp-error-tracking.log  │  Tool failure patterns   │
└──────────────────┴──────────────────────────────┴──────────────────────────┘
```

---

## 💬 Hook Delivery Summary

As of v5.14.0, the SP ships **three frontmatter hooks** (all inlined in SKILL.md):

| Hook | Event | Matcher | Purpose | Ships via |
|---|---|---|---|---|
| Identity guard | PreToolUse | `Edit\|Write\|MultiEdit\|NotebookEdit\|Bash\|mcp__plugin_serena_serena__` | Block source-file mutations; allow SP workspace paths | SKILL.md frontmatter |
| Write tracker | PostToolUse | `Write\|Edit\|MultiEdit` | Record `.handoffs/last-prompts/[N].md` writes to state file for Layer 2 | SKILL.md frontmatter |
| Response-end validator | Stop | (no matcher — fires on all Stop events) | Validate AUQ-must-be-AUQ, tool-availability claims, fence-write coupling | SKILL.md frontmatter |

All three are lifecycle-correct for skill-frontmatter delivery:
- PreToolUse fires during tool calls while the skill is active — correct for blocking source edits.
- PostToolUse fires after tool calls while the skill is active — correct for tracking writes.
- Stop fires at end-of-turn while the skill is active — correct for response-end validation.

**Layer 3 (transcript lint):** `tests/lint-transcripts.sh` — runs the same three
checks as Layer 2 at release time. Exit 0 if clean; exit 1 with per-violation output
if any violations found. Added to CLAUDE.md release process Step 2a. This is the
backstop for users where Layer 2 is unavailable (e.g., plugin-context issue #17688).

All other hook types discussed in this file are either:

- **Architecturally incompatible with skill-frontmatter delivery**
  (SessionStart, investigated and removed in v5.9.0 — see Phase 1 above)
- **Optional user-owned configurations** (PreCompact and all Phase 2 / Phase 3
  hooks) — if a user wants PreCompact logging, SubagentStart tracking, or
  any other monitoring hook, they add it to their own
  `~/.claude/settings.json`. The SP does not auto-install hooks into user
  settings and does not modify them.

---

## 📎 Cross-Reference

| Reference | Relationship |
|---|---|
| `startup-checklist.md` | Step 5 context advisory + identity commands |
| `context-handoff.md` | Advisory framing for autocompact threshold (user-owned) |
| `companion-script-spec.md` | Historical spec — deprecated in v5.9.0, retained for reference |
| `orchestration-playbook.md` | Agent patterns that SubagentStart/Stop tracks |
