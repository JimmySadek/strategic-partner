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

### Step 0 — Signal Line (before any tool call)

Emit one visible line of text before the first tool call — the project and what
the recenter is about to do. This is the same Rule 1 the opening path follows
(SKILL.md § Opening Order); a thinking block does not satisfy it.

```
📋 Recentering on `bam-ui` — pulling current state now.
```

### Step 1 — Gather State (one parallel batch)

Most of the state is already computed. The startup-floor sentinel — the hook
documented in `references/floor.md` — writes its full per-group results to a
file whose path is printed at the end of the `SP-FLOOR-COMPLETE` line. Read
that file rather than re-running its checks.

| Source | What to Extract | Cost |
|---|---|---|
| Floor results file (`/tmp/sp-floor-<KEY>.txt`) | Branch, clean/dirty state, last commit, project-rules size band, memory presence, routing freshness, version diff, output style, backlog items, findings count | 1 read |
| `.handoffs/` listing | Latest handoff note → goal, state, decisions, open questions; findings filenames | 1 listing, then 1 read of the newest note |
| `.prompts/` listing | Pending implementation prompts by milestone, status (ready/draft) | 1 listing, only when the session is about pending prompts |
| Serena `list_memories` and memory contents | Architectural context, recent decisions | Deferred — see Step 2a |

**One batch**: the floor read and the directory listings are independent —
issue them together in a single response, not as a sequence of single probes.

**Never re-derive the floor**: no `git status`, no `git log`, no `CLAUDE.md`
read, no version request during a recenter. Those answers are in the results
file. If the floor line is absent (a carved-out subcommand, or a hook that did
not fire), say so in the briefing and gather what is needed directly — but say
it, never render a checked-looking row for a check that did not happen.

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

### Step 2a — Deeper Reads, After the Briefing

Serena memory contents and the body of a findings file are deeper reads. They
run **after** the briefing has rendered, and only when they can change the
user's next move. Until then those rows render ⏳ checking… or ❓ not verified —
never ✅ beside an admission that the read did not happen.

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

| Aspect | Startup opening path | This Command |
|---|---|---|
| **Trigger** | Automatic at session start | Manual, mid-session |
| **Mode detection** | Yes (continuation vs init) | No — pure state read |
| **Skill catalog** | Yes (built at startup) | No — routing is built at startup only |
| **Purpose** | Orient a fresh session | Recenter an active session |
| **Opening order** | Signal → batch → render → verify → ask | Identical (Steps 0-3 above) |

## Boundaries

**Will:**
- Read the floor sentinel's results file, plus `.handoffs/` and `.prompts/`
  listings; read Serena memory contents only after the briefing has rendered
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
