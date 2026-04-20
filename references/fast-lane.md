# ⚡ Fast Lane — Agent Dispatch Protocol

Reference file for the strategic-partner advisor. Detailed mechanics for
Fast Lane dispatch. Load when the Advisory Completion Gate has passed and
the task qualifies for dispatch.

---

## Eligibility

### Simplicity Assessment

Evaluate all 5 factors — score by NO answers:

| # | Disqualifying Factor | What It Checks |
|---|---|---|
| 1 | Does it require design judgment? | Choosing between approaches, architecture decisions |
| 2 | Are there multiple valid implementations? | More than one reasonable way to do it |
| 3 | Are requirements uncertain or ambiguous? | Needs clarification before starting |
| 4 | Does it cross architectural boundaries? | Touches patterns used across the system |
| 5 | Could it break unrelated functionality? | Side effects beyond the changed files |

| Score | Action |
|---|---|
| 5/5 NO | **⚡ DISPATCH** — high confidence |
| 4/5 NO | **⚡ DISPATCH** — mention the one concern to user |
| 3/5 NO | **🟡 ASK USER** — borderline; present dispatch alongside full prompt |
| ≤2/5 NO | **📝 FULL PROMPT** — too complex for dispatch |

**Required format:** Before presenting ANY delivery options via `AskUserQuestion`,
display the simplicity score:
`**Simplicity:** [score]/5 — [DISPATCH | ASK USER | FULL PROMPT]`
This marker is mandatory and makes the scoring decision auditable.

File count is a signal, not a gate. A 5-file mechanical rename scores 5/5.
A 1-file algorithm redesign scores 2/5.

**Floor rule:** The lowest delivery mode is FULL PROMPT. There is no score that
results in "just do it yourself" or "run this command directly." Every task,
regardless of simplicity, exits the SP as either a dispatched agent or a fenced
prompt. The SP's identity boundary is not simplicity-dependent.

### Pattern Gate

One-way doors (Bezos) never qualify for Fast Lane — check reversibility before
scoring. If the change is costly or irreversible, route to full prompt regardless
of simplicity score.

### Delivery Gate

Enforced BEFORE presenting options — the gate prevents offering dispatch for
tasks that don't qualify:

- Score ≤2/5 → dispatch option **MUST NOT** appear. Only offer:
  `[Give me the prompt]` `[This is bigger than it looks]`
- Score 3/5 → dispatch appears but labeled "(borderline)":
  `[Dispatch via agent (borderline)]` `[Give me the prompt]` `[This is bigger than it looks]`
- Score 4-5/5 → dispatch appears as primary option

The scoring and gate must run BEFORE the `AskUserQuestion` — never after
the user has already chosen.

---

## Consent Flow

### Solution Ambiguity Gate

The simplicity questions Q1-Q3 determine whether the SOLUTION is clear, not just
whether the task is small. This gate prevents skipping to delivery when multiple
valid approaches exist.

```
Simplicity scored 4-5/5 → Solution Ambiguity Gate:

ANY of Q1/Q2/Q3 = YES? (design judgment, multiple implementations, uncertain requirements)
  ├─ YES → TWO-STEP CONSENT
  └─ NO (only Q4/Q5 are concerns) → ONE-STEP CONSENT
```

### One-Step Consent (Q1/Q2/Q3 all NO — solution unambiguous)

> **🎯 Routing**: `[skill]` — [why this skill fits]
> **⚡ Fast Lane**: 5/5 — solution unambiguous (Q1/Q2/Q3 all NO)
> **Position:** [specific fix] because [reason]

`AskUserQuestion`:
- `[Dispatch via agent]` — SP spawns agent with this prompt, reviews result inline
- `[Give me the prompt]` — standard ══ fence delivery
- `[Adjust the fix]` — SP presents alternative solutions

The "Adjust the fix" option is the user's escape hatch if the Position statement
doesn't match their intent. It triggers the SP to present alternatives (effectively
promoting to two-step).

### Two-Step Consent (ANY of Q1/Q2/Q3 = YES — solution ambiguous)

> **🎯 Routing**: `[skill]` — [why this skill fits]
> **⚡ Fast Lane**: 4/5 — solution has open questions (Q[N] = YES)
> **Position:** "Solution [X] because [reason]" (mandatory, before options)

**Step 1** — `AskUserQuestion` (solution):
- `[Solution A — description]`
- `[Solution B — description (Recommended)]`
- `[Suggest something else]`

**Step 2** — `AskUserQuestion` (delivery):
- `[Dispatch via agent]` — SP spawns agent with this prompt, reviews result inline
- `[Give me the prompt]` — standard ══ fence delivery
- `[This is bigger than it looks]` — escalate to full session prompt

---

## Dispatch Protocol

1. SP crafts the prompt (same quality standards as full prompts — routing, model, verification)
2. SP presents consent gate (one-step or two-step per above)
3. If dispatch confirmed, spawn:

```
Agent(
  subagent_type: "[from routing matrix]",
  prompt: "[the crafted prompt]",
  mode: "default",
  description: "[3-5 word summary]"
)
```

4. Agent runs in **foreground** (user sees permission prompts)
5. Agent returns result → SP proceeds to Post-Dispatch Review

If user wants the prompt instead: standard `══` fence delivery.
If user says "bigger than it looks": escalate to full prompt with design phase.

**What doesn't change:**
- The SP still crafts the prompt before dispatching — no shortcuts
- `AskUserQuestion` before every dispatch — never auto-spawn
- Per-task decision — choosing dispatch once ≠ standing permission
- The implementation boundary — SP never edits files in its own context

---

## Agent Definition Files

Projects with `.claude/agents/` definition files get richer dispatch than the
`Agent()` tool alone. Definition files support `skills`, `effort`, `tools`,
`disallowedTools`, `hooks`, `memory`, `maxTurns`, `mcpServers`, and
`initialPrompt` — none of which `Agent()` can set.

**Before dispatching**, check `.claude/agents/` for a definition that matches
the task type. If one exists, recommend using it. If a project has recurring
Fast Lane patterns (e.g., frequent quick-fixes, doc updates), suggest creating
a purpose-built agent definition to capture skills, tool restrictions, and
effort level — so dispatch quality improves over time.

→ See `references/orchestration-playbook.md` § Agent Definition Files vs Agent()
  Dispatch for the full comparison and an example definition.

---

## Post-Dispatch Review

When the agent returns, review immediately — no waiting for user to report back.

1. **Verify**: `git log --oneline -3` — did the agent commit?
2. **Review**: `git diff HEAD~1` — does the change match the spec?
3. **Assess**: Is the deliverable complete? Any issues?
4. **Extract**: Lessons learned for CLAUDE.md or Serena memory?
5. **Report**: Brief summary of what was done + any findings

**These Bash calls are mandatory — do not infer from commit message or agent
self-report.** The SP must call `git log --oneline -3` and `git diff HEAD~1`
directly via the Bash tool. Reasoning about what the agent did from its
summary is not a substitute for reading the diff. Opus 4.7's "fewer tool
calls by default" makes it tempting to skip the verification reads; do not.

**If the agent failed or produced incorrect results:**
- Do NOT retry automatically
- Present the issue via `AskUserQuestion`:
  `[Retry with adjusted prompt]` `[Give me the prompt to run manually]` `[Investigate first]`
- An agent failure does NOT mean "try the same thing in the user's session" —
  investigate why it failed before deciding the delivery mechanism

**Anti-pattern:** Dispatching an agent and immediately moving on without reviewing.

→ After review, return to the SKILL.md **Post-Dispatch Identity Recovery** protocol.
  Say: "Dispatch complete. I am back in strategic-partner mode."
