# Orchestration Playbook

Reference file for the strategic-partner advisor. Model selection, parallelization
rules, and agent orchestration patterns.

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

### Pattern 2: Research → Synthesis

When gathering information from multiple sources before deciding:

```
Phase 1 (parallel):
  Agent 1 (Sonnet 4.6): Research [topic A] — produce findings summary
  Agent 2 (Sonnet 4.6): Research [topic B] — produce findings summary

Phase 2 (sequential):
  Agent 3 (Opus 4.6): Synthesize Agent 1+2 outputs → produce recommendation
```

### Pattern 3: Explore → Design → Build → Review

Standard feature development chain:

```
Step 1: Agent (Sonnet 4.6, subagent_type=Explore) → understand existing code
Step 2: Agent (Opus 4.6, subagent_type=feature-dev:code-architect) → design approach
Step 3: /feature-dev:feature-dev or /gsd:quick → implement
Step 4: /code-review:code-review → validate
```

### Pattern 4: Multi-Expert Panel

For strategic analysis requiring diverse perspectives:

```
Agent (Opus 4.6, subagent_type=business-panel-experts): [analysis question]
  or
/sc:spec-panel → multi-expert specification review
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

## Anti-Patterns

- Spawning Opus agents for implementation tasks (waste of capability)
- Sequential agents when they could be parallel (waste of time)
- Parallel agents with dependencies (race conditions, inconsistency)
- Skipping the Explore step before complex implementation
- Not specifying model in agent spawn instructions
- Spawning agents for tasks that a single skill invocation handles
- Using Agent tool when a direct skill command exists (unnecessary overhead)
