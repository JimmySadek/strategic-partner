# 📡 Companion Script Specification

---

> ⚠️ **DEPRECATED as of v5.9.0 (2026-04-21)**
>
> This specification is retained for reference but is **no longer active guidance**. Its foundational mechanisms are known to be architecturally broken:
>
> 1. **SessionStart hook from SKILL.md frontmatter** — Cannot fire at Claude Code session start. Per Anthropic's hooks documentation (https://code.claude.com/docs/en/hooks), skill-frontmatter hooks are scoped to the component's lifecycle and only run while the component is active. SessionStart fires before any skill activates, so a SessionStart hook registered in SKILL.md frontmatter cannot trigger at its event. Empirical testing confirmed this in v5.9.0; see CHANGELOG.md entry for v5.9.0.
>
> 2. **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` as an authoritative PreCompact signal** — The env var controls autocompact threshold, but its value is entirely user-owned and set at Claude Code startup from the launching shell. The SP does not manage it. The 70% hardcoded assumption no longer holds.
>
> The spec below describes an architecture that cannot be realized with Claude Code's current hook surface. Read for historical context only.

---

Reference file for the strategic-partner advisor. Architecture specification
for an optional external Python script that monitors context consumption.
This is the "advanced" recommendation from audit finding F1.

```
┌──────────────────────────────────────────────────────┐
│  💡  Status: SPECIFICATION ONLY — not implemented    │
│  👤 Audience: Power users wanting external monitoring │
│  📎 Prerequisite: hooks-integration.md               │
└──────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code Session                                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  🎯 Strategic Partner Skill                           │  │
│  │  • Reads .context-state file                          │  │
│  │  • Reacts to alert_level changes                      │  │
│  │  • Triggers handoff at thresholds                     │  │
│  └───────────────────────────────────────────────────────┘  │
│           ▲                                                  │
│           │ reads .context-state                             │
└───────────┼──────────────────────────────────────────────────┘
            │
            │ file write (atomic: tmp → rename)
┌───────────┴──────────────────────────────────────────────────┐
│  📡 sp-monitor.py (Companion Script)                         │
│                                                              │
│  Inputs:                                                     │
│  ├─ 📝 /tmp/sp-file-tracking.log    (PostToolUse hook)      │
│  ├─ 🔢 /tmp/sp-turn-count.txt       (UserPromptSubmit hook) │
│  ├─ 🤖 /tmp/sp-agent-tracking.log   (Subagent hooks)       │
│  └─ ❌ /tmp/sp-error-tracking.log   (PostToolUseFailure)    │
│                                                              │
│  Output:                                                     │
│  └─ 📊 .context-state (JSON status file)                    │
│                                                              │
│  Startup:                                                    │
│  ├─ 🚀 SessionStart hook (recommended), or                  │
│  └─ 🖥️  Manual: python sp-monitor.py                       │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔄 Monitor Loop

The script runs a continuous loop that aggregates hook data into a context
consumption estimate.

### Loop Steps

```
┌─ Monitor Cycle (every 10s) ──────────────────────────────────┐
│                                                               │
│  1. 📖 Read hook data files                                  │
│     ├─ sp-file-tracking.log   → count edits, estimate sizes  │
│     ├─ sp-turn-count.txt      → read exchange count          │
│     ├─ sp-agent-tracking.log  → count active/completed       │
│     └─ sp-error-tracking.log  → count tool failures          │
│                                                               │
│  2. 🧮 Estimate context consumption                          │
│     ├─ Base: ~2KB per exchange (prompt + response)           │
│     ├─ Tool results: parse file tracking for sizes           │
│     ├─ Agent overhead: ~5KB per spawn                        │
│     ├─ Skill loading: ~6KB (one-time at startup)             │
│     └─ Accumulated: sum of all contributions                 │
│                                                               │
│  3. 📊 Calculate estimated percentage                        │
│     ├─ 200K context: estimated_kb / 200 * 100                │
│     └─ 1M context:   estimated_kb / 1000 * 100              │
│                                                               │
│  4. 🚦 Determine alert level                                │
│     ├─ 🟢 green:           < 55%                             │
│     ├─ 🟡 monitoring:      55-64%                            │
│     └─ 🔴 urgent_handoff:  ≥ 65%                            │
│                                                               │
│  5. 💾 Write .context-state file (atomic)                    │
│  6. 😴 Sleep 10 seconds                                     │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

### 📏 Estimation Heuristics

These are **rough estimates** (±20% variance) — the script cannot measure actual token consumption,
and file-size-to-token-count conversion is non-linear. The goal is directional accuracy, not precision.

| Source | Estimated Size | Notes |
|---|---|---|
| 💬 User message | ~0.5KB | Varies heavily |
| 🤖 Assistant response | ~1.5KB | Advisory responses tend to be longer |
| 📖 File read (tool) | Actual file size | Logged by PostToolUse hook |
| ✏️ File edit (tool) | ~0.5KB per edit | Old + new content |
| 🤖 Agent spawn | ~5KB | Instructions + system prompt + results |
| 📦 Skill loading | ~6KB | SP skill body, one-time |
| 🧠 Serena memory read | ~1KB per memory | Varies by memory size |

---

## 📊 `.context-state` File Format

Written to the project root (or a configured path).

```json
{
  "estimated_pct": 62,
  "estimated_kb": 124,
  "context_size_kb": 200,
  "tool_results_kb": 45,
  "messages_count": 34,
  "agents_spawned": 3,
  "agents_active": 1,
  "tool_failures": 0,
  "files_modified": 7,
  "alert_level": "monitoring",
  "last_updated": "2026-03-16T14:32:05Z",
  "thresholds": {
    "monitoring": 55,
    "urgent_handoff": 65
  }
}
```

### Field Descriptions

| Field | Type | Description |
|---|---|---|
| `estimated_pct` | `int` | 📊 Estimated context usage as percentage |
| `estimated_kb` | `int` | 📦 Estimated total context in KB |
| `context_size_kb` | `int` | 🔧 Configured context window size in KB |
| `tool_results_kb` | `int` | 🔧 Cumulative tool result sizes in KB |
| `messages_count` | `int` | 💬 Number of user-assistant exchanges |
| `agents_spawned` | `int` | 🤖 Total agents spawned this session |
| `agents_active` | `int` | 🤖 Currently running agents |
| `tool_failures` | `int` | ❌ Count of tool failures this session |
| `files_modified` | `int` | 📝 Count of unique files modified |
| `alert_level` | `string` | 🚦 Current threshold level |
| `last_updated` | `string` | 🕐 ISO 8601 timestamp of last update |
| `thresholds` | `object` | 🔧 Configured threshold percentages |

---

## 🚦 Threshold Markers

The script uses threshold markers to signal the SP when action is needed.
The `.context-state` file's `alert_level` field is the primary signal.

| Marker | Range | Script Action |
|---|---|---|
| 🟢 Normal | 0-55% | No marker |
| 🟡 Monitor | 55-65% | Write `.context-state` with "monitoring" status |
| 🔴 Handoff | 65%+ | Write `.context-state` with "urgent_handoff" status |

**📌 Note**: These thresholds are intentionally **~5% lower** than the SP's self-assessment
tiers in `context-handoff.md` (55/65 vs 60/70) to account for external monitoring variance.
The companion script's estimates have higher variance than in-session self-assessment,
so it errs toward early warnings. See `context-handoff.md` § Handoff Thresholds for
the SP's authoritative tiers.

---

## 🔗 Integration Points

### 📝 PostToolUse Hook → Log Result Sizes

The PostToolUse hook (Phase 2, see `hooks-integration.md`) writes file modification
data to `/tmp/sp-file-tracking.log`. The companion script reads this log to
estimate how much context tool results consume.

**Log format** (one line per event):
```
FILE_MODIFIED: path/to/file.ts 14:32:05
```

The script checks file sizes on disk to estimate how much of the file was
likely read into context during the tool operation.

### 💬 UserPromptSubmit → Count Turns

The UserPromptSubmit hook (Phase 2) increments a counter in `/tmp/sp-turn-count.txt`.
The script reads this to track exchange count and estimate base context consumption
from conversation alone.

### 🚨 PreCompact → Emergency Trigger

When the PreCompact hook fires (at `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70%`), it
writes to `/tmp/sp-context-alerts.log`. The companion script detects this as
an **authoritative signal** that overrides its own estimate:

```python
if precompact_fired:
    alert_level = "urgent_handoff"
    estimated_pct = max(estimated_pct, 70)
```

This ensures the `.context-state` file reflects reality even if the script's
estimate was optimistic.

---

## 🚀 Startup

### Via SessionStart Hook (Recommended)

The SessionStart hook can launch the companion script automatically:

**Note**: The script path uses `$SKILLS_SCRIPTS_DIR` with a fallback to
`~/.config/skills/scripts/`. Set the env var if your skills installation
is in a non-standard location.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "python3 ${SKILLS_SCRIPTS_DIR:-~/.config/skills/scripts}/sp-monitor.py --context-size 200 &",
        "description": "Launch SP companion context monitor"
      }
    ]
  }
}
```

### 🖥️ Manual Launch

```bash
python3 sp-monitor.py --context-size 200            # 200K context
python3 sp-monitor.py --context-size 1000           # 1M context window
```

### ⚙️ CLI Arguments

| Argument | Default | Description |
|---|---|---|
| `--context-size` | `200` | Context window size in KB |
| `--interval` | `10` | Polling interval in seconds |
| `--state-file` | `.context-state` | Path to output state file |
| `--log-dir` | `/tmp` | Directory for hook log files |
| `--quiet` | `false` | Suppress stdout output |

---

## 🧹 Cleanup

The companion script should clean up on exit:

```
┌─ Exit Cleanup ───────────────────────────────────────────────┐
│  1. 🗑️  Remove /tmp/sp-*.log and /tmp/sp-turn-count.txt     │
│  2. 📊 Write final .context-state: alert_level=session_ended │
│  3. 🛑 Stop hook (Phase 1) terminates script if still running│
└───────────────────────────────────────────────────────────────┘
```

🛡️ Add `.context-state` to `.gitignore` — it is session-ephemeral and should
never be committed.

---

## 💡 Limitations

| # | Limitation | Impact |
|---|---|---|
| 1 | **Estimates are rough** — cannot measure actual token consumption | Treat thresholds as directional guides, not precise measurements |
| 2 | **File size ≠ token count** — tokenization varies by content type | Code tokenizes differently than prose |
| 3 | **No streaming access** — cannot read Claude Code's internal context state | Infers from external signals only |
| 4 | **Hook dependency** — without Phase 2 hooks, limited data (turn count only) | Estimates degrade significantly without hooks |
| 5 | **Race conditions** — script and Claude Code both read/write `.context-state` | Use atomic writes (write to tmp, rename) to avoid partial reads |

---

## 📎 Cross-Reference

| Reference | Relationship |
|---|---|
| `hooks-integration.md` | Hooks that feed data to this script |
| `context-handoff.md` | Threshold strategy this script supports |
| `startup-checklist.md` | Step 3 env var that sets the PreCompact trigger |
