# Startup Checklist (Internal)

Reference file for the strategic-partner advisor. Supplementary detail for
the inline startup checklist in SKILL.md. Do not display to user.

---

## Serena Memory Monitoring

### When to Propose Memory Writes
- New convention or process agreed in conversation
- Architectural decision made with rationale
- Significant gotcha or lesson learned discovered
- Threshold values calibrated and confirmed

### When to Propose Re-Onboarding
- Memory references files/directories that no longer exist
- Memory describes module structure contradicting actual codebase
- Major architectural reorganization since last onboarding
- Memory content is internally inconsistent
- User explicitly says "memories are wrong" or "re-onboard"

### Re-Onboarding Protocol
1. Never re-onboard autonomously — it overwrites existing memories
2. AskUserQuestion: describe inconsistency + propose re-onboarding with rationale
3. Options: [Yes, re-onboard now] [Let me fix specific memories instead] [Keep going]
4. If confirmed: `onboarding` call refreshes codebase analysis and memories

---

## Staleness Validation (Delegated to Agent)

Staleness checks are delegated to an Explore agent during startup. The SP does NOT
perform these checks directly — it reviews the agent's summary (~150 tokens).

**What the agent does** (see orchestration-playbook.md § Pattern A/B):
1. Pick 2 file paths from `codebase_structure` memory → verify with `find_file`
2. Pick 1 convention from `code_style_and_conventions` memory → verify with `search_for_pattern`
3. Return: PASS/FAIL + list of any failures

**What the SP does with the result:**
- PASS → proceed normally, no mention to user
- FAIL → flag immediately in orientation, propose targeted memory update via AskUserQuestion

---

## Serena Dashboard Enforcement (Fire-and-Forget)

The Serena web dashboard auto-opens a browser tab on every session start, which is
distracting. This is a **hard preference** — auto-fix without asking.

**Delegated**: This is a fire-and-forget operation. Spawn an agent during startup and
do not wait for the result. See orchestration-playbook.md § Pattern D.

### What the agent does

1. Read `~/.serena/serena_config.yml`
2. If `web_dashboard_open_on_launch` is `true` → change to `false`
3. No return needed

### Why fire-and-forget

This is an enforced config guardrail, not a discretionary decision. The user has
explicitly stated this should always be off. No summary is needed — if it was true,
it's now false. If it was already false, nothing happened. Either way, the SP doesn't
need to know.

---

## Partner Profile

- Does Serena memory `partner_profile` exist?
- If yes → read and adapt communication depth
- If no → observe during session, write after 3+ exchanges

---

## CLAUDE.md Monitoring Triggers

Propose an update when:
- A new convention or process is agreed upon in conversation
- A "lessons learned" emerges from an implementation report
- An architectural decision is made that should constrain future sessions
- A rule is being violated repeatedly (suggests missing guardrail)
- Version bump process is established or changed

---

## Memory Placement Guide

```
Serena memories     → architectural decisions, codebase structure, code conventions,
                      threshold values, known gotchas, design rationale
CLAUDE.md           → process rules, enforcement conventions, project-wide guardrails
.claude/rules/      → path-specific rules (e.g., "all files in src/api/ must...")
Auto-memory         → session learnings, user preferences (auto-managed)
.handoffs/          → current session state, continuation prompts
.prompts/           → implementation prompts organized by milestone
.scripts/           → runnable operational scripts
```

---

## Ask-Before-Act Examples

**Serena memory write:**
> "I want to record our decision to use cosine distance thresholds (T_ACCEPT=0.25,
> T_REJECT=0.55) in Serena as 'identity_threshold_decisions'. Rationale: this was a
> corrected value from Round 1's wrong calibration and should survive session resets.
> Shall I write this memory?"

**CLAUDE.md update:**
> "I want to add a Dev Visibility Rule to CLAUDE.md requiring a CHANGELOG.json entry
> with every pipeline change. Rationale: we keep forgetting this across sessions.
> Proposed text: [exact text]. Shall I add it?"

**Git commit:**
> "Good checkpoint for a commit — the roadmap review is complete. Proposed message:
> `docs: player identity roadmap reviewed, regression gate baseline corrected`.
> Shall I commit?"

**Context handoff:**
> "We're approaching context limits and I want to preserve what we've built today
> before quality degrades. I'll write a handoff to `.handoffs/` — the continuation
> prompt will restore the advisor persona in the fresh session. Shall I do it?"
