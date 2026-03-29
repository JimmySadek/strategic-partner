# 🔗 Hooks Integration Guide

Reference file for the strategic-partner advisor. Comprehensive hooks strategy
for proactive session management. Phased rollout from essential to advanced.

```
┌─────────────────────────────────────────────────────────────────────┐
│  SP Hooks Rollout                                                    │
│                                                                      │
│  Phase 1 (Essential)     Phase 2 (Monitoring)    Phase 3 (Advanced) │
│  ┌──────────────────┐   ┌──────────────────┐    ┌────────────────┐  │
│  │ 🚀 SessionStart  │   │ 🤖 SubagentStart │    │ 🔧 ConfigChange│  │
│  │ 🚨 PreCompact    │   │ 🤖 SubagentStop  │    │ ❌ PostToolUse │  │
│  │ 🛑 Stop (removed)│   │ 📝 PostToolUse   │    │    Failure     │  │
│  │                  │   │ 💬 UserPrompt    │    │ 🔌 Custom      │  │
│  └──────────────────┘   │    Submit        │    └────────────────┘  │
│                         └──────────────────┘                        │
│  ◄── implement first    ◄── visibility      ◄── power users        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Hook Delivery

Hooks are delivered via **SKILL.md frontmatter** (session-scoped). Claude Code reads
the `hooks:` section at skill load time and registers them for the session. This
follows the same pattern used by gstack and other well-established skills.

### Why Frontmatter (not settings.json)

| Approach | Ships with skill? | Scope | Maintenance |
|---|---|---|---|
| SKILL.md frontmatter ✅ | Yes — travels with the skill file | Session (active while skill is loaded) | Zero — automatic on skill load |
| `.claude/settings.json` ❌ | No — gitignored, per-machine | Persistent (all sessions) | Manual install + update |

Frontmatter hooks are the correct mechanism for skill-owned behavior. Settings.json
hooks are appropriate for user-owned customizations that should persist independently
of any skill.

### The `${CLAUDE_SKILL_DIR}` Variable

SKILL.md frontmatter hooks can reference `${CLAUDE_SKILL_DIR}`, which resolves to the
directory containing SKILL.md at load time. This enables portable script paths:

```yaml
hooks:
  PreCompact:
    - matcher: ""
      hooks:
        - type: command
          command: "bash ${CLAUDE_SKILL_DIR}/hooks/some-script.sh"
          statusMessage: "Running hook..."
```

The variable works regardless of where the skill is installed.

> **Note:** The SP previously used this mechanism for a Stop hook
> (`hooks/check-handoff.sh`), but that hook was removed in v5.0.0.
> The example above illustrates the general pattern.

---

## 🔴 Phase 1: Essential Hooks

These hooks provide the **minimum viable integration** for reliable session management.
Implement these first.

### 🚀 SessionStart

**Event**: Fires when a new Claude Code session begins.

**SP Behavior:**
```
┌─ SessionStart Actions ──────────────────────────────┐
│  1. 🔧 Set CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70       │
│     (via CLAUDE_ENV_FILE — the only programmatic     │
│      session setting hooks can control)              │
│  2. 🚀 Begin full startup sequence                   │
│     (see startup-checklist.md)                       │
│                                                      │
│  ⚠️ /effort, /color, /rename are user-only commands │
│     — hooks cannot invoke slash commands. The SP     │
│     recommends these to the user in orientation.     │
└──────────────────────────────────────────────────────┘
```

**Delivery**: SessionStart is handled by the skill's startup sequence
(`startup-checklist.md`), not by a hook. Claude Code loads the skill, which
triggers the full startup protocol. No separate SessionStart hook is needed
in the frontmatter — the skill invocation IS the session start signal.

---

### 🚨 PreCompact

**Event**: Fires when context reaches the auto-compaction threshold (70% with
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70`).

**SP Behavior:**
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

**Configuration:**
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

**Why 70%**: The default ~95% threshold is too late for structured handoff.
At 95%, the SP barely has room to extract state, write files, and present a
continuation prompt. At 70%, there is ample space for a clean handoff while
still allowing aggressive context usage.

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
- 🔗 Feed turn count to companion script if running (see `companion-script-spec.md`)

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
- ⚠️ Surface actionable failure patterns to user proactively
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

The SP's essential hooks (SessionStart, PreCompact) are handled via the skill's
startup sequence and environment configuration — no manual installation step
is needed. The Stop hook was removed in v5.0.0 (see Phase 1 section above).

Phase 2 and 3 hooks (monitoring and advanced) are **optional user-level
configurations**. If a user wants to add PreCompact logging, SubagentStart
tracking, or other monitoring hooks, they would add those to their
`~/.claude/settings.json` manually. The SP does not auto-install hooks
into user settings.

---

## 📎 Cross-Reference

| Reference | Relationship |
|---|---|
| `startup-checklist.md` | Step 1 identity commands that SessionStart automates |
| `context-handoff.md` | Threshold strategy that PreCompact integrates with |
| `companion-script-spec.md` | External monitoring that hooks feed data to |
| `orchestration-playbook.md` | Agent patterns that SubagentStart/Stop tracks |
