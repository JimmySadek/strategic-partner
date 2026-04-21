# 🔗 Hooks Integration Guide

Reference file for the strategic-partner advisor. Comprehensive hooks strategy
for proactive session management. Phased rollout from essential to advanced.

```
┌─────────────────────────────────────────────────────────────────────┐
│  SP Hooks Rollout                                                    │
│                                                                      │
│  Phase 1 (Essential)     Phase 2 (Monitoring)    Phase 3 (Advanced) │
│  ┌──────────────────┐   ┌──────────────────┐    ┌────────────────┐  │
│  │ 🛡️ PreToolUse    │   │ 🤖 SubagentStart │    │ 🔧 ConfigChange│  │
│  │    (identity)    │   │ 🤖 SubagentStop  │    │ ❌ PostToolUse │  │
│  │ 🚨 PreCompact    │   │ 📝 PostToolUse   │    │    Failure     │  │
│  │    (user-owned)  │   │ 💬 UserPrompt    │    │ 🔌 Custom      │  │
│  │ 🛑 Stop (removed)│   │    Submit        │    └────────────────┘  │
│  │ 🚀 SessionStart  │   └──────────────────┘                        │
│  │  (incompatible)  │                                               │
│  └──────────────────┘                                               │
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

### 🛑 Stop — REMOVED in v5.0.0

The Stop hook was removed in v5.0.0. The implementation script (`hooks/check-handoff.sh`)
was deleted and the `hooks:` section was removed from SKILL.md frontmatter.

**Why it was removed:** Hooks fire on every turn, not specifically at session end.
The Stop hook could not reliably detect the difference between a mid-session pause
and an actual session termination, making it an unreliable backstop.

**What replaced it:** Session-end detection is now handled entirely by the SP's
behavioral protocol in SKILL.md — keyword detection for session-end signals
(e.g., "done", "wrapping up", "closing") combined with a periodic check every
5th exchange. There is no automated fallback; the SP must catch session-end
signals proactively through its behavioral rules.

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

### 📝 PostToolUse (on Edit)

**Event**: Fires after any tool use completes. Filter for Edit/Write tools.

**SP Behavior:**
- 📂 Track file modifications automatically for handoff state
- 📋 Maintain a running list of files changed this session
- ⚡ No need to manually reconstruct "Files Modified" at handoff time

**Configuration:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "echo \"FILE_MODIFIED: $TOOL_INPUT_PATH $(date +%H:%M:%S)\" >> /tmp/sp-file-tracking.log",
        "description": "Track file modifications for SP handoff state",
        "toolNames": ["Edit", "Write"]
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

The SP ships exactly one frontmatter hook: the **PreToolUse identity guard**
(SKILL.md frontmatter). It is lifecycle-correct — PreToolUse fires during
tool calls made while the SP is active, which is precisely when source-file
mutations need to be blocked.

All other hook types discussed in this file are either:

- **Removed** (Stop, v5.0.0 — hooks fire on every turn, not just session end)
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
