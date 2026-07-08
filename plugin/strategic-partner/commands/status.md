---
name: status
description: "Recenter briefing — where we stand, what's done, what's next"
category: advisory
complexity: standard
mcp-servers: [serena]
---

# /strategic-partner-plugin:status — Recenter Briefing

> Active re-read and synthesis of all advisory state. Answers: "Where do we stand?
> What's done? What's next?" Run mid-session to recenter, or at session start for orientation.

## Output Style

Adopt the adaptive-visual output style (`~/.claude/output-styles/adaptive-visual.md`).
Use status symbols (✅ ❌ ⚠️ 🔄 ⏳) and action symbols (🔍 🎯 📁 🔧 🚀) for scannable output.
Use ASCII diagrams for multi-step workflows or phase progress. Default to concise mode;
expand for problems or decisions.

## Behavioral Flow

### Step 1 — Gather State (parallel reads where possible)

Collect information from all available sources:

| Source | What to Extract |
|---|---|
| `.handoffs/` directory | Latest handoff file → goal, state, decisions, open questions |
| `.prompts/` directory | Pending implementation prompts by milestone, status (ready/draft) |
| Serena `list_memories` | 2-3 most relevant memories → architectural context, decisions |
| `CLAUDE.md` | Current conventions, active rules, project overview |
| `git status` | Current branch, uncommitted changes, clean/dirty state |
| `git log --oneline -5` | Recent commits for activity context |
| `VERSION` or `package.json` | Current version (if applicable) |

**Parallel execution**: git commands, directory listings, and Serena reads are independent —
run them concurrently.

**Graceful degradation**: If a source doesn't exist (no `.handoffs/`, no Serena memories),
skip it and note its absence. Never fail because one source is missing.

### Step 2 — Synthesize Briefing

Combine gathered state into a structured briefing using adaptive-visual format:

```
## 📊 Advisory Status — [project name]

🎯 **Goal**: [from latest handoff or Serena memory — or "No active advisory goal detected"]
🏗️ **Phase**: [from roadmap/planning state if available — or omit]
📦 **Version**: [current version — or omit if not versioned]
🔗 **Branch**: [git branch] [✅ clean | ⚠️ dirty — N uncommitted changes]

### Progress
✅ [completed item 1]
✅ [completed item 2]
🔄 [in-progress item]
⏳ [pending item]
[... or "No tracked progress found — this may be a fresh advisory session"]

### 📁 Pending Prompts
- `.prompts/v1.4/phase1-auth.md` — [description] 🚀 ready
- `.prompts/v1.4/bugfix-round2.md` — [description] ⏳ draft
[... or "None pending"]

### ⚠️ Open Questions / Blockers
- [blocker or unresolved question from handoff or memories]
[... or "None identified"]

### 🎯 What's Next
[Single concrete next action — file, function, or command to act on]
```

**When state is multi-phase**, add an ASCII progress flow:
```
Phase 1 (infra) ──✅──→ Phase 2 (auth) ──🔄──→ Phase 3 (UI) ──⏳
                                 ↑
                           ← you are here
```

### Step 3 — Show The Briefing, Then Ask

Do not put the whole briefing only inside `AskUserQuestion`. The user must see
a useful recenter first.

1. Show a visible briefing in normal chat. Keep it viewport-safe: 3-5 useful
   lines, or one compact table/ASCII flow when the state has several tracks.
   Include the current situation, 2-4 concrete facts, any open risk, the
   implication, and one recommended next move.
2. Then call `AskUserQuestion`. Repeat only a compact context echo inside the
   question/options: branch or goal, live risk, and recommended path. This keeps
   the choice understandable if the terminal scrolls.
3. Draw option labels from the live briefing, not a generic menu.

**Question**: "[compact context echo]\n\nWhat should we focus on next?"

**Options**:
- [Continue with <recommended next move>] — Proceed with the identified next action
- [Correct the status] — User will clarify what's different
- [Switch to <other live track>] — Shift focus to a different goal or phase

## Key Differences from Startup

| Aspect | Startup Step 2a | This Command |
|---|---|---|
| **Trigger** | Automatic at session start | Manual, mid-session |
| **Mode detection** | Yes (continuation vs init) | No — pure state read |
| **Skill catalog** | Yes (built at startup) | No — routing is built at startup only |
| **Purpose** | Orient a fresh session | Recenter an active session |

## Boundaries

**Will:**
- Read from `.handoffs/`, `.prompts/`, Serena memory, CLAUDE.md, git
- Synthesize a structured briefing with visual formatting
- Show a visible briefing, then present a compact `AskUserQuestion` echo for confirmation

**Will Not:**
- Modify any files or state
- Trigger mode detection or upgrade detection
- Run the full startup sequence
- Make implementation decisions

## See Also

- `/strategic-partner-plugin:backlog` — review parked items and check whether any triggers have fired since the last orientation. Use when the status briefing surfaces unresolved findings that may belong in backlog.
- `/strategic-partner-plugin:handoff` — close the session at a clean point. Use when status confirms a good stopping place and you want to write a continuation prompt before context fills up.
