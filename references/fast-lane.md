# ⚡ Fast Lane — Agent Dispatch Protocol

Reference file for the strategic-partner advisor. Detailed mechanics for
Fast Lane dispatch. Load when the Advisory Readiness Gate has passed and the
Delivery Choice Checkpoint (SKILL.md § 📦 Delivery Modes) reaches its load step —
implementation-shaped work that is not categorically disqualified.

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
  `[Dispatch now — <subagent_type> (borderline)]` `[Hold — let me review the brief first]` `[Wrong agent — let me pick]`
- Score 4-5/5 → dispatch appears as the primary exact-confirmation option:
  `[Dispatch now — <subagent_type>]` `[Hold — let me review the brief first]` `[Wrong agent — let me pick]`

The scoring and gate must run BEFORE the `AskUserQuestion` — never after
the user has already chosen.

---

## Consent Flow

### 🎯 Mandatory routing line (all dispatch paths)

Before presenting any dispatch `AskUserQuestion` — one-step, two-step, or the
borderline score-3 label — SP states the chosen specialist on its own line:

> **Routing:** <task shape> → `<subagent_type>` per <matrix row in `references/skill-routing-matrix.md`, or explicit rationale>

The `<subagent_type>` is the specific specialist for the task — for example,
`frontend-architect` for a React/Tailwind UI change — and that same name goes in the
exact dispatch-confirmation option label (`[Dispatch now — <subagent_type>]`) so the
user can catch a wrong pick before confirming. SP never defaults to `general-purpose`
unless no specialist fits; when that is the case, the routing line states why no
specialist matched. This mirrors SP's Pre-Dispatch Routing Verification rule (output
style), which already requires the `subagent_type` in the dispatch option label.

A delivery-choice answer, readiness approval, or "run it now" answer is not dispatch
confirmation unless the AUQ shows the exact `Dispatch now — <subagent_type>` option
plus `[Hold — let me review the brief first]` and `[Wrong agent — let me pick]`.

This dispatch routing line supplements — it does not replace — the per-template
`**🎯 Routing**` skill line in the One-Step and Two-Step Consent blocks below. The
`[skill]` named there and the `<subagent_type>` named here are the same specialist for
the task, written in each block's existing style.

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
- `[Dispatch now — <subagent_type>]` — SP spawns this exact agent with this prompt and reviews the result inline
- `[Hold — let me review the brief first]` — SP shows the prompt/fence path before any agent runs
- `[Wrong agent — let me pick]` — SP reopens agent selection before dispatch

The "Wrong agent" option is the user's escape hatch if the route does not match their
intent. If the fix itself is wrong, SP reopens alternatives before returning to
dispatch confirmation.

### Two-Step Consent (ANY of Q1/Q2/Q3 = YES — solution ambiguous)

> **🎯 Routing**: `[skill]` — [why this skill fits]
> **⚡ Fast Lane**: 4/5 — solution has open questions (Q[N] = YES)
> **Position:** "Solution [X] because [reason]" (mandatory, before options)

**Step 1** — `AskUserQuestion` (solution):
- `[Solution A — description]`
- `[Solution B — description (Recommended)]`
- `[Suggest something else]`

**Step 2** — `AskUserQuestion` (delivery):
- `[Dispatch now — <subagent_type>]` — SP spawns this exact agent with this prompt and reviews the result inline
- `[Hold — let me review the brief first]` — SP shows the prompt/fence path before any agent runs
- `[Wrong agent — let me pick]` — SP reopens agent selection before dispatch

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

**Capture the agent's ID when Agent Teams is enabled:** If
`agent_teams_available` is true (the experimental Agent Teams switch was
detected at startup — see `references/startup-checklist.md` § Agent Teams
Flag Detection), SP stores the `agentId` returned in the `Agent()` dispatch
response for the rest of this session. That stored ID is what lets SP send a
one-line correction to the same warm agent later instead of re-dispatching
the whole brief (see § SendMessage Correction Path). The ID is session-scoped
only — SP never reuses it across sessions. When `agent_teams_available` is
false, SP captures nothing here and Fast Lane behaves exactly as it does
today.

If user chooses hold: show the standard `══` fence delivery before any agent runs.
If user says the work is bigger than it looks: escalate to full prompt with design phase.

**What doesn't change:**
- The SP still crafts the prompt before dispatching — no shortcuts
- Exact `AskUserQuestion` before every dispatch — never auto-spawn
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
summary is not a substitute for reading the diff. Verify directly via Bash,
every time — a summary is not evidence.

**If the agent failed or produced incorrect results:**
- Do NOT retry automatically
- Present the issue via `AskUserQuestion`:
  `[Retry with adjusted prompt]` `[Give me the prompt to run manually]` `[Investigate first]`
- An agent failure does NOT mean "try the same thing in the user's session" —
  investigate why it failed before deciding the delivery mechanism

**If the agent succeeded but the result has a small, correctable gap —
only when `agent_teams_available` is true:**

The agent did the work and committed, but review found a minor miss: wrong
commit convention, a skipped constraint, formatting drift. The original
agent still holds warm context. When the experimental Agent Teams switch
was detected at startup (see `references/startup-checklist.md` § Agent
Teams Flag Detection), present:

`AskUserQuestion`:
- `[Send correction to same agent]` — one-line fix to the warm agent; no context re-upload
- `[Dispatch fresh]` — a new agent with an updated brief
- `[Accept as-is]` — the gap is not worth correcting

Before offering this, use the small-delta-vs-fresh routing table in
§ SendMessage Correction Path to decide whether the gap actually counts as
"small". Large delta or broken state → do not offer same-agent; route to
fresh dispatch.

**When `agent_teams_available` is false, this branch does not exist.**
Post-dispatch review stays binary — accept the result or dispatch fresh,
exactly as it works today — and nothing about SendMessage is mentioned to
the user.

**Anti-pattern:** Dispatching an agent and immediately moving on without reviewing.

→ After review, return to the SKILL.md **Post-Dispatch Identity Recovery** protocol.
  Say: "Dispatch complete. I am back in strategic-partner mode."

---

### No PushNotification on Fast Lane Dispatches

Fast Lane dispatches run in the foreground (`run_in_background` unset or
`false`). The user is still engaged at the terminal — adding a notification
would be noise, not signal. The SP rule "Notify on Backgrounded Completion"
(SKILL.md) applies only to `run_in_background: true` dispatches, which Fast
Lane explicitly does not use.

If a Fast Lane dispatch grows past ~60s or surfaces unexpected latency,
that's signal to either (a) re-scope the task toward a background dispatch,
or (b) add a timer-based notification on that specific flow — but not as
a blanket Fast Lane rule.

---

## SendMessage Correction Path

Everything in this section is conditional on `agent_teams_available` being
true — the experimental Agent Teams switch
(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`) was detected at startup (see
`references/startup-checklist.md` § Agent Teams Flag Detection). When the
switch is absent, none of this exists.

When a Fast Lane dispatch returns an almost-right result, SP can send a
one-line correction to the same warm agent instead of re-dispatching the
whole brief to a fresh agent. The original agent still holds the task
context, so the fix lands without re-uploading everything.

### When "same agent" vs "fresh dispatch"

The decision table below is **reproduced verbatim** from its canonical
source, `.handoffs/backlog-archive/add-sendmessage-fast-lane-correction-MERGED-0516.md`.
That archived file is the single source of truth — do not redesign or
re-author the table here. It is mirrored inline only so SP has it at hand
during post-dispatch review.

**When "same agent" vs "fresh dispatch"**

| Situation | Route |
|---|---|
| Commit message convention mismatch | Same agent |
| Formatting off by whitespace or emoji | Same agent |
| Missed a small constraint (e.g., "don't touch file X") | Same agent |
| Produced the wrong deliverable entirely | Fresh dispatch |
| Agent reported an error | Fresh dispatch (likely environment issue) |
| Correction requires significant new context | Fresh dispatch |

The rule: small delta → same agent; large delta or broken state → fresh.

### Wiring the correction

On `[Send correction to same agent]`:

1. SP calls `SendMessage(to: storedAgentId, message: "Correction: <specific
   fix>")` — `storedAgentId` is the `agentId` captured at dispatch (see
   § Dispatch Protocol).
2. SP re-runs the post-dispatch review loop on the corrected result —
   `git log --oneline -3`, `git diff HEAD~1`, check against the brief. The
   same mandatory Bash verification as the first review; never an inference
   from the agent's reply.
3. SP reports the re-reviewed result and proceeds to the Acceptance Gate.

The correction is one line scoped to the specific fix — not a fresh brief,
not a multi-turn conversation. One correction, then re-review.

**Robustness — never block or retry against a dead teammate.** If a SendMessage
to a stored `agentId` fails, or the session was resumed or rewound (in-process
teammates are NOT restored after `/resume` or `/rewind`, so the stored ID
points at nothing), SP falls back to the standard fresh-brief path — a new
`Agent()` dispatch with a complete brief. SP does not retry the dead teammate
and does not stall waiting on it. The correction path is an optimization; its
failure mode is "dispatch fresh," exactly as if the Agent Teams switch were
off.

**Team-brief caveat — teammates are not worktree-isolated.** Agent Teams
teammates share the working tree; they are **not** worktree-isolated the way a
worktree spawn is. So any SP-crafted team brief must **partition the files** so
each teammate owns a different set — this reinforces SP's existing
"don't parallelize on shared files" anti-pattern. If two teammates would touch
the same file, that work is sequential or single-agent, not a team.

### Graceful degradation — flag absent is the default, not an error

`agent_teams_available = false` is the normal, expected state, exactly like
`codex_available = false` or Serena being unavailable. When the switch is
off:

- The correction branch never appears in post-dispatch review.
- No `agentId` is captured at dispatch.
- SendMessage is never mentioned to the user.
- Post-dispatch review is byte-for-byte today's behavior — accept the
  result, or dispatch a fresh agent.

Silent fallback, not a degraded mode and not an error. SP says nothing
about the missing switch — the same posture SP uses for the Codex CLI and
Serena: present when detected, invisible when not.
