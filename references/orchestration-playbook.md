# Orchestration Playbook

Reference file for the strategic-partner advisor. Model selection, parallelization
rules, and agent orchestration patterns.

```
Model Selection → Parallelization Decision → Spawn Pattern (A/B/C/D) → Session Planning
```

---

## Model Selection

| Model | Use For | Avoid For |
|-------|---------|-----------|
| Opus 4.6 | Architecture, complex debugging, research, coordination, multi-expert analysis | Simple implementation, routine tasks |
| Sonnet 4.6 | Implementation, code review, testing, exploration, standard work, parallel agents | Critical architecture decisions, complex reasoning chains |

### Decision Rule

```
Is this task architectural, complex debugging, deep research, or coordination?
├─ Yes → Opus 4.6
└─ No  → Sonnet 4.6
```

When in doubt, default to Sonnet. Opus is for tasks where getting it wrong is expensive.

---

## Parallelization Decision Tree

```
3+ independent files to modify?
├─ Yes → Parallel Sonnet agents (one per file or logical group)
└─ No  → Single agent

Research + implementation in same task?
├─ Different concerns → Parallel (research agent + impl agent)
└─ Implementation depends on research findings → Sequential

Multiple questions to answer?
├─ Independent → Parallel research agents
└─ Each builds on prior answer → Sequential

Architecture → implementation → review?
└─ Always sequential chain (each depends on prior output)
```

---

## Agent Spawn Patterns

### Pattern 1: Parallel Implementation

When 3+ files need independent changes:

```
Spawn N agents in parallel:
  Agent 1 (Sonnet 4.6): [file A — task + expected output]
  Agent 2 (Sonnet 4.6): [file B — task + expected output]
  Agent 3 (Sonnet 4.6): [file C — task + expected output]
```

---

### Pattern 2: Research → Synthesis

When gathering information from multiple sources before deciding:

```
Phase 1 (parallel):
  Agent 1 (Sonnet 4.6): Research [topic A] — produce findings summary
  Agent 2 (Sonnet 4.6): Research [topic B] — produce findings summary

Phase 2 (sequential):
  Agent 3 (Opus 4.6): Synthesize Agent 1+2 outputs → produce recommendation
```

---

### Pattern 3: Explore → Design → Build → Review

Standard feature development chain. **Resolve each step from the routing matrix** —
the skill names below are placeholders, not defaults.

```
Step 1: Agent (Sonnet 4.6, subagent_type=Explore) → understand existing code
Step 2: Agent (Opus 4.6, subagent_type=[architect-agent]) → design approach
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
Agent (Opus 4.6, subagent_type=business-panel-experts): [analysis question]
  or
/[best spec-review skill from routing matrix] → multi-expert specification review
```

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

The SP delegates mechanical work to Explore agents to preserve its own context window
for strategic reasoning. These patterns are used by the SP itself during startup and
prompt crafting — not in implementation prompts.

### Pattern A: Initialization Scan (2 parallel agents)

Spawn after `check_onboarding_performed` completes:

**Agent 1 — Onboarding/Staleness Check:**
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

**Agent 2 — Architecture Scan:**
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

### Pattern B: Continuation Staleness Check (1 agent)

Spawn while reading the handoff file:

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

### Pattern C: Pre-Prompt File Reading (1 agent, foreground)

Spawn before crafting an implementation prompt that requires reading 3+ files:

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

### Pattern D: Fire-and-Forget Operations

These need no return value — spawn and move on immediately:

**Serena dashboard fix:**
```
Read ~/.serena/serena_config.yml. If web_dashboard_open_on_launch is true,
change it to false. No output needed.
```

**Gitignore auto-add:**
```
Read .gitignore in the project root. If any of these entries are missing,
add them: .handoffs/, .prompts/, .scripts/
If .gitignore doesn't exist, create it with those three entries.
No output needed.
```

### Delegation Decision Rules

```
Is this mechanical scanning/validation?
  YES → Delegate to Explore agent (Sonnet)
  NO  → Keep in main context

Does the SP need the raw content for reasoning?
  YES → Read directly (CLAUDE.md, handoffs, memories)
  NO  → Agent returns summary

Is this a fire-and-forget config fix?
  YES → Spawn agent, don't wait for result
  NO  → Wait for agent summary before proceeding

Are there 3+ files to read before crafting a prompt?
  YES → Pattern C (foreground agent, wait for summary)
  NO  → Read directly (1-2 files isn't worth the overhead)
```

---

## Anti-Patterns

- ❌ **Opus for implementation**: Spawning Opus agents for implementation tasks (waste of capability)
- ❌ **Unnecessary sequential**: Sequential agents when they could be parallel (waste of time)
- ❌ **Dependent parallels**: Parallel agents with dependencies (race conditions, inconsistency)
- ❌ **Skipping Explore**: Jumping to implementation before understanding existing code
- ❌ **Missing model spec**: Not specifying model in agent spawn instructions
- ❌ **Agent overkill**: Spawning agents for tasks that a single skill invocation handles
- ❌ **Agent vs skill**: Using Agent tool when a direct skill command exists (unnecessary overhead)
- ❌ **Delegating strategy reads**: Delegating CLAUDE.md or handoff file reading (SP must internalize)
- ❌ **Delegating memory reads**: Delegating memory content reading (SP reasons from full content)
- ❌ **Delegating matrix build**: Having an agent build the routing matrix (costs as much to review)
- ❌ **Waiting on fire-and-forget**: Waiting for dashboard fix or gitignore agents (spawn and move on)
