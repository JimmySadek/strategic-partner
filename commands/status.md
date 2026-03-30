---
name: status
description: "Recenter briefing — where we stand, what's done, what's next"
category: advisory
complexity: standard
mcp-servers: [serena]
---

# /strategic-partner:status — Recenter Briefing

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

### Step 3 — Present via AskUserQuestion

Show the full briefing in the question description.

**Question**: "Does this match where we are? What should we focus on?"

**Options**:
- [Yes, let's continue from here] — Proceed with the identified next action
- [I need to correct something] — User will clarify what's different
- [Let's reprioritize] — Shift focus to a different goal or phase

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
- Present findings via AskUserQuestion for confirmation

**Will Not:**
- Modify any files or state
- Trigger mode detection or upgrade detection
- Run the full startup sequence
- Make implementation decisions
