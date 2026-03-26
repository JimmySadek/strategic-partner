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
│  │ 🛑 Stop          │   │ 📝 PostToolUse   │    │    Failure     │  │
│  │                  │   │ 💬 UserPrompt    │    │ 🔌 Custom      │  │
│  └──────────────────┘   │    Submit        │    └────────────────┘  │
│                         └──────────────────┘                        │
│  ◄── implement first    ◄── visibility      ◄── power users        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 Hook Configuration

Hooks are configured in Claude Code's settings files. Discover the location:
- **User-global**: typically `~/.claude/settings.json` (check `$CLAUDE_CONFIG_DIR/settings.json` as fallback)
- **Project-level**: `.claude/settings.json` in the project root The SP should document a recommended configuration and
offer to auto-install it during startup — but **always ask-before-act**
for hook installation, since hooks affect the user's global or project settings.

### Configuration Location

| Scope | File | Precedence |
|---|---|---|
| 🌐 User-global | `~/.claude/settings.json` (or `$CLAUDE_CONFIG_DIR/settings.json`) | Lower |
| 📁 Project-level | `.claude/settings.json` (hooks key) | Higher |

**💡 Recommendation**: Install SP hooks at the **user-global** level so they apply
to all SP sessions regardless of project. Project-level hooks should be
reserved for project-specific behavior.

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

**Configuration** — minimal signal stub (detection only, not a functional hook):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "echo 'SP session initialized'",
        "description": "Strategic Partner session startup signal"
      }
    ]
  }
}
```

> **📌 This is intentionally a stub.** The SP startup logic lives in the skill's
> startup sequence (`startup-checklist.md`), not in this hook. This hook signals
> that a session started — the skill handles the rest. Do not make this hook
> "functional"; the stub-as-signal design is correct.

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

### 🛑 Stop

**Event**: Fires when the session is ending (user exits or session terminates).

**SP Behavior:**
```
┌─ Stop Sequence ───────────────────────────────────────────────────┐
│  1. 🔄 Trigger full handoff protocol if not already done          │
│     • Write handoff file + continuation prompt (══ fences)       │
│     • This is the PRIMARY action — session state preservation    │
│     • Skip only if handoff was already written this session      │
│  2. 🧠 Write session summary to Serena memory                    │
│     • Key decisions made                                         │
│     • Files modified                                             │
│     • Open issues and next steps                                 │
│  3. ⚠️ Warn if pending prompts exist                            │
│  4. 🧹 Clean up temporary session files                          │
└───────────────────────────────────────────────────────────────────┘
```

The handoff protocol (Step 1) follows the same Steps 1-6 from `context-handoff.md`.
This is the **backstop** — if the SP detected the user's session-end signal earlier
and already wrote the handoff, Step 1 is a no-op. If the SP missed the signal,
the Stop hook ensures state is preserved before the session closes.

**Configuration** — minimal signal stub (detection only, not a functional hook):
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "echo 'SP session ending - saving state'",
        "description": "Strategic Partner session cleanup and state preservation"
      }
    ]
  }
}
```

> **📌 This is intentionally a stub.** Session cleanup logic (Serena memory writes,
> file tracking, pending prompt warnings) lives in the SP skill's stop sequence,
> not in this hook. The hook signals session end — the skill handles cleanup.

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

## 💬 Auto-Installation Protocol

The SP may offer to install hooks during startup. This is **ask-before-act**:

```
════════════════════ HOOK INSTALLATION PROMPT ════════════════════
"I'd like to set up Claude Code hooks for this session to enable:
  • Automatic context monitoring at 70% (PreCompact)
  • Session state preservation on exit (Stop)
  • File modification tracking for handoffs (PostToolUse)

This would modify ~/.claude/hooks.json. Shall I install these hooks?

Options: [Yes, install all]
         [Essential only (PreCompact + Stop)]
         [No, skip hooks]"
══════════════════════════════════════════════════════════════════
```

🚨 **Never install hooks silently.** Hooks modify the user's shell environment
and persist across sessions. The user must consent.

### ✅ Verifying Hook Installation

After installation, verify hooks are active:
1. Check that the hooks file exists and is valid JSON
2. Confirm the hook events are registered
3. Test one hook (e.g., write to the turn counter) to verify execution

---

## 📎 Cross-Reference

| Reference | Relationship |
|---|---|
| `startup-checklist.md` | Step 1 identity commands that SessionStart automates |
| `context-handoff.md` | Threshold strategy that PreCompact integrates with |
| `companion-script-spec.md` | External monitoring that hooks feed data to |
| `orchestration-playbook.md` | Agent patterns that SubagentStart/Stop tracks |
