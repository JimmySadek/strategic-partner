# Orchestration Playbook

Reference file for the strategic-partner advisor. Model selection, parallelization
rules, and agent orchestration patterns.

```
Model Selection → Parallelization Decision → Spawn Pattern (A/B/C/D/E) → Session Planning
```

---

## Model Selection

| Model | Use For | Avoid For |
|-------|---------|-----------|
| Opus 4.7 | Architecture, complex debugging, research, coordination, multi-expert analysis, synthesis of parallel results | Simple implementation, routine tasks, parallel worker agents |
| Sonnet 4.6 | Implementation, code review, testing, exploration, standard work, parallel worker agents | Critical architecture decisions, complex reasoning chains |

### Decision Rule

```
Is this task architectural, complex debugging, deep research, or coordination?
├─ Yes → Opus 4.7
└─ No  → Sonnet 4.6

Is this a parallel worker agent (one of N doing independent work)?
├─ Yes → Sonnet 4.6 (always — Opus is wasted on constrained subtasks)
└─ No  → Apply the rule above

Is this a synthesis step (combining outputs from parallel agents)?
├─ Yes → Opus 4.7 (needs to reason across multiple inputs)
└─ No  → Apply the rule above
```

**Cost-effectiveness principle**: Parallel worker agents should almost always be
Sonnet. The task has already been decomposed and scoped — the hard reasoning
happened during decomposition (which the SP or an Opus coordinator did). Workers
execute a well-defined subtask where Sonnet excels.

Reserve Opus for:
- The coordinator/synthesizer that combines parallel outputs
- Single-agent tasks requiring deep reasoning (root cause analysis, architecture)
- Multi-expert panels where perspective diversity matters
- Research agents where missing a subtle detail is costly

---

## ⚡ Parallelization Heuristics

These heuristics align with the **🔴 mandatory parallelization check** in
`prompt-crafting-guide.md`. When that check triggers YES on questions 1-3,
use these patterns to design the `<orchestration>` section.

### Decision Tree

```
1. Can this task be split into 2+ independent file changes?
   ├─ YES → Parallel Sonnet agents (one per file or logical group)
   └─ NO  → Single agent

2. Does this task have a research phase and a build phase?
   ├─ YES, different concerns → Parallel (research agent + impl agent)
   └─ YES, build depends on research → Sequential phases, parallel WITHIN each

3. Are there 3+ deliverables that don't depend on each other?
   ├─ YES → Parallel agent per deliverable group
   └─ NO  → Single agent or sequential chain

4. Is this a single-file, single-concern change?
   └─ YES → No orchestration needed
```

### ✅ Concrete Examples: WHEN to Parallelize

**Example A: 3 independent file changes**
Task: "Add logging to auth, payments, and notifications modules"
```
<orchestration>
  Spawn 3 agents in parallel:
    Agent 1 (Sonnet 4.6): Add structured logging to auth/middleware.py
    Agent 2 (Sonnet 4.6): Add structured logging to payments/processor.py
    Agent 3 (Sonnet 4.6): Add structured logging to notifications/sender.py
</orchestration>
```
Why: Each module is independent. No shared state. Changes don't conflict.

**Example B: Research + build with independent research targets**
Task: "Evaluate 3 auth libraries and implement the best one"
```
<orchestration>
  Phase 1 (parallel research):
    Agent 1 (Sonnet 4.6): Evaluate passport.js — API, maintenance, bundle size
    Agent 2 (Sonnet 4.6): Evaluate lucia-auth — API, maintenance, bundle size
    Agent 3 (Sonnet 4.6): Evaluate next-auth — API, maintenance, bundle size
  Phase 2 (sequential):
    Agent 4 (Opus 4.7): Compare findings, select library, implement
</orchestration>
```
Why: Research targets are independent. Synthesis requires all research complete.

**Example C: Multiple independent deliverables**
Task: "Add CLI wizard, MCP tool, and API endpoint for team listing"
```
<orchestration>
  Spawn 3 agents in parallel:
    Agent 1 (Sonnet 4.6): CLI wizard (cli/teams.py + cli/__init__.py)
    Agent 2 (Sonnet 4.6): MCP tool (mcp/cmrad_mcp.py)
    Agent 3 (Sonnet 4.6): API endpoint (api/routes/teams.py + api/routes/__init__.py)
</orchestration>
```
Why: Three distinct interfaces to the same data. No code-level dependencies between them.

### ❌ Concrete Examples: When NOT to Parallelize

**Anti-example A: Tight dependencies (shared types)**
Task: "Define TypeScript interfaces, then implement components using them"
Why NOT: Components import the interfaces. If Agent 2 starts before Agent 1 defines
the types, it will either guess wrong or fail.
Correct: Sequential — define types first, then parallel implementation.

**Anti-example B: Shared state / same file**
Task: "Add 3 new methods to the UserService class"
Why NOT: All three agents would edit the same file. Merge conflicts are guaranteed.
Correct: Single agent handles all three methods in sequence.

**Anti-example C: Cascading data flow**
Task: "Parse input → validate → transform → persist"
Why NOT: Each step consumes the output of the prior step. No independence.
Correct: Single agent, sequential implementation.

**Anti-example D: Schema migration + code that uses the schema**
Task: "Add new database columns and update the ORM models that use them"
Why NOT: The ORM changes depend on the migration being correct first.
Correct: Sequential — migration first, then ORM updates.

---

## Agent Permission Modes

Background agents (`run_in_background: true`) **cannot prompt the user for permissions**.
If a background agent attempts a tool call that requires approval and no `mode` is set,
it fails silently. Always specify `mode` on every agent spawn.

### Mode Reference

| Mode | Behavior | Use Case |
|------|----------|----------|
| `"auto"` | Automatically approves safe operations (reads, searches, web fetches) | Research, exploration, scanning, file reading |
| `"acceptEdits"` | Auto-approves reads AND file edits (Edit, Write, NotebookEdit) | Implementation, code changes, file creation |
| `"bypassPermissions"` | All tools approved without prompting | Full autonomy — **security risk**, use sparingly |
| `"default"` | Prompts user for each tool call | Foreground-only — **never use with background agents** |
| `"plan"` | Requires plan approval before execution | Supervised implementation in foreground |
| `"dontAsk"` | Skips tool calls that would require permission | Graceful degradation — skips instead of failing |

### ⚠️ Background Agent Warning

```
Background agent (run_in_background: true) + no mode specified
  → Agent hits a permission prompt → SILENT FAILURE
  → No error returned, no work done, no indication of why
```

This is the #1 cause of "agent did nothing" bugs. Always specify mode.

### Mode Selection Decision Tree

```
Is this agent doing read-only work (research, exploration, file reading)?
├─ YES → mode: "auto"
└─ NO → Does it write config files (gitignore, settings, symlinks)?
    ├─ YES → mode: "acceptEdits"
    └─ NO → Does it write/edit source or implementation files?
        ├─ YES → mode: "acceptEdits"
        └─ NO → Does it need unrestricted tool access?
            ├─ YES → mode: "bypassPermissions" (❌ security risk — document why)
            └─ NO → mode: "default" (foreground agents only)
```

### Belt-and-Suspenders: Pre-Approve Common Tools

Even with `mode: "auto"`, recommend users pre-approve `WebFetch(*)` and `WebSearch(*)`
in `~/.claude/settings.json` to avoid edge cases where research agents stall:

```json
{
  "permissions": {
    "allow": ["WebFetch(*)", "WebSearch(*)"]
  }
}
```

This ensures research agents never block on web access regardless of mode.

---

## Agent Spawn Patterns

### Pattern 1: Parallel Implementation

When 3+ files need independent changes:

```
Spawn N agents in parallel:
  Agent 1 (Sonnet 4.6, mode: "acceptEdits"): [file A — task + expected output]
  Agent 2 (Sonnet 4.6, mode: "acceptEdits"): [file B — task + expected output]
  Agent 3 (Sonnet 4.6, mode: "acceptEdits"): [file C — task + expected output]
```

---

### Pattern 2: Research → Synthesis

When gathering information from multiple sources before deciding:

```
Phase 1 (parallel):
  Agent 1 (Sonnet 4.6, mode: "auto"): Research [topic A] — produce findings summary
  Agent 2 (Sonnet 4.6, mode: "auto"): Research [topic B] — produce findings summary

Phase 2 (sequential):
  Agent 3 (Opus 4.7, mode: "acceptEdits"): Synthesize Agent 1+2 outputs → produce recommendation
```

---

### Pattern 3: Explore → Design → Build → Review

Standard feature development chain. **Resolve each step from the routing matrix** (see `references/skill-routing-matrix.md`) —
the skill names below are placeholders, not defaults.

```
Step 1: Agent (Sonnet 4.6, mode: "auto", subagent_type=Explore) → understand existing code
Step 2: Agent (Opus 4.7, mode: "acceptEdits", subagent_type=[architect-agent]) → design approach
Step 3: /[best implementation skill from routing matrix] → implement
Step 4: /[best review skill from routing matrix] → validate
```

Before writing this chain into a prompt, look up the routing matrix for:
- The best **implementation** skill (match task scope: focused vs multi-phase)
- The best **review** skill (match task type: PR review vs quality check)

---

### Pattern 4: Multi-Expert Panel

For strategic analysis requiring diverse perspectives:

```
Agent (Opus 4.7, mode: "auto", subagent_type=business-panel-experts): [analysis question]
  or
/[best spec-review skill from routing matrix] → multi-expert specification review
```

---

## Agent Failure & Timeout Handling

Delegation is an optimization, not a dependency. If an agent fails, the SP falls
back to doing the advisory work directly (reading, analysis, re-crafting the prompt).
Implementation work gets a new prompt or agent dispatch, not direct execution.
Never block on agent failures.

| Scenario | Detection | Response |
|----------|-----------|----------|
| **Agent times out** | No response within expected window | Other parallel agents continue. Mark timed-out agent's results as incomplete. Do the advisory work directly (reading, analysis, re-crafting the prompt). Implementation work gets a new prompt or agent dispatch, not direct execution. |
| **Agent returns error** | Error message in result | Assess: retry once if transient (permission denied, network). If structural (wrong tool, bad prompt), fix the prompt and re-delegate. |
| **Agent returns garbled/partial output** | Result doesn't match expected format | Extract what's usable. Fill gaps from main context. Note limitation in orientation. |
| **Agent permission denied** | Tool call denied by user | Do the advisory work directly (reading, analysis, re-crafting the prompt). Implementation work gets a new prompt or agent dispatch, not direct execution. **Prevention**: specify `mode` parameter on every agent spawn (see Agent Permission Modes above). |

### Applying This to Spawn Patterns

- **Parallel Implementation (Pattern 1)**: If one of N agents fails, the others'
  results remain valid. Do the advisory work directly (reading, analysis, re-crafting the prompt).
  Implementation work gets a new prompt or agent dispatch, not direct execution.
- **Research → Synthesis (Pattern 2)**: If a research agent fails, synthesis proceeds
  with reduced inputs. Note the gap in the synthesis prompt.
- **Explore → Design → Build → Review (Pattern 3)**: If the Explore agent fails,
  fall back to Grep/Glob-based exploration. The chain continues.
- **Self-Delegation (Patterns A–E)**: Fire-and-verify agents (D) are non-blocking
  by design. Scanning agents (A, B) fall back to direct reads if they time out.
  Diagnostic audit agents (E) report findings for SP verification.

---

## Session Planning

### Single-Task Session
- **When**: focused bug fix, single file change, one deliverable
- **Strategy**: one prompt, one skill invocation, no agents needed
- **Context budget**: minimal — leave room for iteration

### Multi-Task Session
- **When**: feature implementation, multiple related changes
- **Strategy**: skill chain with explicit ordering, agent spawning for parallel tracks
- **Context budget**: tiered handoff at 67/72/77% — multi-task sessions consume context fast

### Discovery Session
- **When**: new codebase, architecture analysis, understanding before building
- **Strategy**: Explore agent first, then Serena onboarding, then synthesis
- **Context budget**: generous — discovery is read-heavy, not write-heavy

---

## Advisor Self-Delegation

> **Internal patterns only.** The patterns below describe how the SP itself delegates
> during startup and prompt crafting. They are NOT used in crafted implementation
> prompts. For implementation prompt orchestration, see Patterns 1–4 above.

The SP delegates mechanical work to Explore agents to preserve its own context window
for strategic reasoning. These patterns are used by the SP itself during startup and
prompt crafting — not in implementation prompts.

### Pattern A: Initialization Scan (2 parallel agents)

Spawn after `check_onboarding_performed` completes. Both agents are read-only —
use `mode: "auto"` for background compatibility.

**Agent 1 — Onboarding/Staleness Check (Sonnet 4.6, mode: "auto"):**
```
You are checking codebase freshness for an advisor session.

IF the project has NOT been onboarded to Serena:
  - Run `onboarding` to analyze the project and create memories
  - Return: list of memory names created, 1-line summary of each

IF the project HAS been onboarded:
  - Read the `codebase_structure` Serena memory
  - Pick 2 file paths mentioned → verify each exists with `find_file`
  - Read the `code_style_and_conventions` memory
  - Pick 1 convention → verify with `search_for_pattern`
  - Return ONLY:
    STALENESS: PASS or FAIL
    Failed checks: [list any failures, or "none"]
    Summary: [1 sentence on codebase health]
```

**Agent 2 — Architecture Scan (Sonnet 4.6, mode: "auto"):**
```
You are scanning project documentation for an advisor session.

1. Check for these paths (use find_file or list_dir):
   - docs/, doc/, documentation/
   - README.md, ARCHITECTURE.md, DESIGN.md
   - roadmap files, TODO.md, CHANGELOG.md
   - .planning/, .gsd/ (project management)

2. For each file found, read it and extract:
   - Tech stack and frameworks
   - Architecture pattern (monolith, microservices, etc.)
   - Current milestone or version
   - Key conventions or constraints

3. Return ONLY a structured summary (5 bullets max, ~300 tokens):
   - Tech stack: [...]
   - Architecture: [...]
   - Current state: [...]
   - Key constraints: [...]
   - Active milestone: [...]
```

### Pattern B: Continuation Staleness Check (1 agent, mode: "auto")

Spawn while reading the handoff file (read-only background agent):

```
You are validating session continuity for an advisor.

1. Read Serena memories: `codebase_structure`, `code_style_and_conventions`
2. Verify 2 file paths from codebase_structure exist (find_file)
3. Verify 1 convention from code_style_and_conventions (search_for_pattern)
4. Run: git log --oneline -15
5. Return ONLY:
   STALENESS: PASS or FAIL
   Failed checks: [list any failures, or "none"]
   Recent commits (last 15):
   [paste git log output]
```

### Pattern C: Pre-Prompt File Reading (1 agent, foreground, mode: "auto")

Spawn before crafting an implementation prompt that requires reading 3+ files (read-only):

```
You are reading target files to help an advisor craft an implementation prompt.

Read these files and return a structured summary for each:
[SP inserts file list here]

For each file, report:
- File path
- Exports / public API (function signatures, class names)
- Key patterns (state management, error handling, naming conventions)
- Current state (working, broken, partial, TODO markers)
- Dependencies (imports from other project files)
- Flags: any conflicts, recent changes, broken imports

Keep total response under 500 tokens. Focus on what an implementer needs to know.
```

### Pattern D: Fire-and-Verify Operations (mode: "auto")

These spawn without blocking startup. Background agents require explicit mode:
`"auto"` for read-only agents. Results are **verified** before the SP presents
its orientation. See `startup-checklist.md` for verification logic.

> **Note**: Command registration and hook delivery previously handled by Agent C
> at runtime are now handled by the `setup` script (install/update time) and
> SKILL.md frontmatter hooks (session-scoped). No runtime config agent is needed.

### Pattern E: Diagnostic Audit (3–4 parallel agents, mode: "auto")

Spawn when the SP needs to audit project files for correctness, consistency, or
staleness. The SP splits project files into 3–4 logical groups and dispatches
parallel Explore agents, each analyzing its group against audit categories.
Findings are severity-classified; the SP verifies all Important+ findings before
presenting to the user.

**Agent dispatch:**
- Split files into logical groups (core files, reference groups, templates/docs)
- Each agent gets a specific file list and audit categories
- All agents: Sonnet 4.6, `mode: "auto"`, `run_in_background: true`

```
You are auditing a file group for a project diagnostic.

Files to audit:
[SP inserts file list for this agent's group]

For each file, check against these categories:
  C — Correctness: factual errors, wrong values, broken references
  I — Inconsistency: contradictions between files, mismatched conventions
  R — Robustness: missing edge cases, fragile assumptions, gaps
  N — Nice-to-have: style improvements, clarity, optional enhancements

For any finding you'd classify as Important or higher, you MUST complete the
intent-check gate below BEFORE assigning final severity.

┌─────────────────────────────────────────────────────────┐
│                 INTENT-CHECK GATE (5 steps)             │
├─────────────────────────────────────────────────────────┤
│ 1. Pattern Check                                       │
│    Is this notation/approach used elsewhere in the      │
│    file or project? YES → likely intentional            │
│                                                         │
│ 2. Context Check                                       │
│    What kind of document is this?                       │
│    Historical doc → "stale" may be intentional record   │
│    Template → placeholders are by design                │
│    Living spec → stale data is a real concern           │
│                                                         │
│ 3. Git Archaeology                                     │
│    What commit introduced this? Does the commit         │
│    message explain the design choice?                   │
│                                                         │
│ 4. Environment Assumption Check                        │
│    Hardcoded values → potential bug                     │
│    Placeholders/generics → correct by design for a     │
│    multi-environment skill                              │
│                                                         │
│ 5. Reclassification Gate                               │
│    After steps 1–4, does the severity still hold?       │
│    If reduced → note original + reason for downgrade    │
│    If maintained → include intent-check evidence        │
└─────────────────────────────────────────────────────────┘

Return findings in this format:

[CATEGORY]-[N]: [one-line summary]
  - File: [filename]:[line range]
  - Detail: [2-3 sentences]
  - Intent check: [what investigation showed — REQUIRED for Important+]
  - Severity: [Critical/Important/Minor] [→ downgraded from X if applicable]

Keep total response under 800 tokens. Omit Nice-to-have items unless Critical
or Important findings are fewer than 3.
```

**SP verification pass (after all agents report):**
1. Spot-check all Important+ findings with Grep/Read
2. Apply intent-check gate to any finding the agent didn't fully investigate
3. Filter false positives — document rejected findings with reason (transparency)
4. Present only verified findings to user

**Why this pattern exists:** Agents that check "does this match expectations?"
without asking "was this deliberate?" produce ~30% false positives on
documentation-heavy projects (Chesterton's Fence principle). The intent-check
gate forces investigation of design intent before escalating severity.

### Delegation Decision Rules

```
Is this mechanical scanning/validation?
  YES → Delegate to Explore agent (Sonnet)
  NO  → Keep in main context

Does the SP need the raw content for reasoning?
  YES → Read directly (CLAUDE.md, handoffs, memories)
  NO  → Agent returns summary

Is this a fire-and-verify scan?
  YES → Spawn agent without blocking, verify result before orientation
  NO  → Wait for agent summary before proceeding

Are there 3+ files to read before crafting a prompt?
  YES → Pattern C (foreground agent, wait for summary)
  NO  → Read directly (1-2 files isn't worth the overhead)
```

---

## 🛡️ Worktree Isolation for Risky Implementations

When crafting prompts for large or risky changes, recommend `isolation: worktree`
in the agent spawn instructions. This creates a git worktree — an isolated copy
of the repo where the agent works without affecting the main working directory.

### When to Recommend Worktree Isolation

```
Is this change risky or large-scale?
├─ Touches 5+ files across multiple directories → recommend worktree
├─ Involves database migrations or schema changes → recommend worktree
├─ Refactors core infrastructure (auth, routing, state management) → recommend worktree
├─ Experimental approach (might be discarded) → recommend worktree
└─ Well-scoped, low-risk change → standard execution (no worktree)
```

### How to Embed in Prompts

Add to the `<orchestration>` section or as a top-level directive:

```
<orchestration>
  isolation: worktree

  Phase 1 (parallel, each in isolated worktree):
    Agent 1 (Sonnet 4.6): Refactor auth middleware
    Agent 2 (Sonnet 4.6): Refactor session management
  Phase 2:
    Review worktree diffs before merging to main working directory
</orchestration>
```

### Benefits

| Benefit | Why It Matters |
|---------|---------------|
| 🔄 **Safe rollback** | Implementation goes wrong → discard the worktree |
| ⚡ **Parallel safety** | Multiple agents can work on overlapping files without conflicts |
| 🔍 **Review gate** | Changes reviewed before merging to the main tree |
| 🧹 **No cleanup** | Worktrees are disposable by design |

---

## Agent Definition Files vs Agent() Dispatch

The `Agent()` tool accepts: `model`, `mode`, `subagent_type`, `prompt`,
`description`, `name`, `isolation`, `run_in_background`. This covers most
dispatch needs. But **agent definition files** (`.claude/agents/name.md`)
unlock additional configuration:

| Capability | Agent() | Definition file |
|---|---|---|
| model, mode, prompt | ✅ | ✅ |
| skills, effort | ❌ | ✅ |
| tools, disallowedTools | ❌ | ✅ |
| hooks, memory, maxTurns | ❌ | ✅ |
| mcpServers, initialPrompt | ❌ | ✅ |

### When to Recommend Creating a Definition

- **Recurring task patterns**: The same Fast Lane shape appears 3+ times (quick-fixes,
  doc updates, test additions) — encode the skills, effort, and tool restrictions once
- **Skill injection**: The agent needs specific skills loaded that `Agent()` can't set
- **Tool restrictions**: The agent should NOT have access to certain tools (e.g., no
  `WebFetch` for a code-only fixer)
- **Effort tuning**: Low-effort tasks shouldn't consume full reasoning depth

### Example Definition (`.claude/agents/quick-fix.md`)

```markdown
---
model: sonnet
effort: low
skills: ["code-simplifier"]
disallowedTools: ["WebFetch", "WebSearch"]
maxTurns: 15
---

You are a quick-fix agent. Execute the task described in your prompt.
Follow project conventions from CLAUDE.md. Commit when done.
```

When dispatching via Fast Lane, check `.claude/agents/` first. If a matching
definition exists, recommend it to the user alongside the standard `Agent()` option.

---

## Anti-Patterns

- ❌ **Opus for implementation**: Spawning Opus agents for implementation tasks (waste of capability)
- ❌ **Unnecessary sequential**: Sequential agents when they could be parallel (waste of time)
- ❌ **Dependent parallels**: Parallel agents with dependencies (race conditions, inconsistency)
- ❌ **Skipping Explore**: Jumping to implementation before understanding existing code
- ❌ **Missing model spec**: Not specifying model in agent spawn instructions
- ❌ **Missing mode spec**: Not specifying `mode` in agent spawn instructions — background agents fail silently without it
- ❌ **Wrong mode for writing agents**: Using `mode: "auto"` for agents that write files — auto only covers reads. Use `"acceptEdits"` for any agent that writes files
- ❌ **Agent overkill**: Spawning agents for tasks that a single skill invocation handles
- ❌ **Agent vs skill**: Using Agent tool when a direct skill command exists (unnecessary overhead)
- ❌ **Delegating strategy reads**: Delegating CLAUDE.md or handoff file reading (SP must internalize)
- ❌ **Delegating memory reads**: Delegating memory content reading (SP reasons from full content)
- ❌ **Delegating matrix build**: Having an agent build the routing matrix (costs as much to review)
- ❌ **Waiting on fire-and-forget**: Waiting for non-blocking scan agents (spawn and move on)
- ❌ **Opus for parallel workers**: Using Opus for constrained subtasks in parallel spawns (Sonnet handles scoped work)
- ❌ **Sonnet for synthesis**: Using Sonnet to combine outputs from multiple parallel agents (Opus reasons across inputs)
- ❌ **Parallel on shared files**: Spawning parallel agents that edit the same file (guaranteed merge conflicts)
- ❌ **Parallel on dependent steps**: Spawning parallel agents where one consumes the other's output (race condition)
- ❌ **No worktree for risky changes**: Sending large refactors to execute in the main working directory without isolation
- ❌ **Skipped intent-check**: Classifying audit findings as Important+ without investigating design intent — ~30% false positive rate on docs-heavy projects. Apply the 5-step intent-check gate (Pattern E) before escalating severity
