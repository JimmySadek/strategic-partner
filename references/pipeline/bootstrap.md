---
name: bootstrap
description: Stage 1 of the v5.12.0 pipeline — session prereq evaluation before Router runs.
scope: v5.12.0 (complete)
---

> **Internal vocabulary — do not surface.** The labels in this file
> (`Bootstrap`, `B1`, `B2`, `bootstrap_blocking`, `genuine_ambiguity` flag,
> `must-ask`, etc.) are SP-internal reasoning checkpoints. They MUST NOT
> appear in user-facing prose. See
> `references/pipeline/user-output-style.md` for the user-facing
> translation layer.

# Bootstrap — Stage 1

## Purpose

Bootstrap is the first stage of the v5.12.0 pipeline (Bootstrap → Router →
Egress → Asking Pattern). It evaluates session prerequisite questions BEFORE downstream Router
classification runs. If a prereq is unresolved, Bootstrap blocks the pipeline
until resolved via direct AUQ.

The stage exists to prevent two failure modes:

- SP proceeds without knowing what the user is trying to achieve (B1 failure).
- SP silently applies an SP-default for a user-owned preference the user has
  not yet bound (B2 failure — deferred to Brief 2).

## Scope (Brief 2)

**Both B1 and B2 are implemented in Brief 2.** Bootstrap performs the full
prereq evaluation specified in `.handoffs/v512-spec-addenda-0425.md` § C5.

Remaining deferral: the depth-modulation MECHANICS for the `must-ask`
attention hint (how the hint affects Asking Pattern depth and Forced
Alternatives composition) land in Brief 3 step 7. Brief 2 emits the
`must-ask` label on the `genuine_ambiguity` flag, but downstream depth
behavior is still inherited from general advisory habits.

Fixture F5 tests B2 and is expected to PASS after Brief 2.

## B1 — Fresh-session Q1/Q4 resolution

This behavior existed in v3 and is preserved in the v5.12.0 pipeline unchanged.

On every fresh session, Bootstrap evaluates two questions:

- **Q1 — What is the user trying to achieve?** (goal, not task)
- **Q4 — What does "done" look like?** (concrete deliverables)

If either is unresolved, Bootstrap emits the `bootstrap_blocking` flag and
halts downstream Router/Egress. SP issues a direct AUQ to resolve the
outstanding question. Only after both are resolved does the pipeline proceed.

Continuation sessions (handoff file provides answers) skip the AUQ if the
handoff clearly states Q1/Q4. Fast-Lane dispatches still re-confirm Q1 —
handoff provides context, not consent.

B1's interaction with the rest of the pipeline: if `bootstrap_blocking` is
set, Router does not run at all for the current turn. The AUQ IS the
response.

## B2 — Unknown user-owned preference detection

When Bootstrap completes B1 cleanly, it then evaluates B2.

### Detection trigger

B2 detects when the current task contains a user-owned scoping or
optimization preference that is unknown — meaning no current instruction,
handoff state, active standing rule, or user-message context binds the
preference. The shape: a decision SP would otherwise pick a default for,
where alternatives are not all equivalent for the user, and where no
material signal fires (per `.handoffs/v512-spec-addenda-0425.md` § C5
Detection shape).

If a material signal fires (money, legal, coordination, etc.), Egress's
composite rule already escalates and B2 does not need to. B2 catches the
class of decisions that material signals miss: the user owns the decision
because they live with the result, but no signal flags it.

### Six preference categories (non-exhaustive)

Detection is by SHAPE, not enumeration. The six categories below are the
canonical examples documented in C5; the trigger is the shape, not
membership in this list.

| # | Category | Example trigger |
|---|---|---|
| 1 | PR decomposition | One bundled PR vs incremental PRs vs sequencing across PRs |
| 2 | Depth / variant | Minimal viable / recommended / comprehensive; standard / strict |
| 3 | Trade-off prioritization | Speed vs quality, simplicity vs flexibility, breadth vs depth |
| 4 | Refactor approach | Incremental change vs structural rewrite |
| 5 | Test strategy (task-scoped) | Unit / integration / none / post-merge for this specific task |
| 6 | Documentation depth (task-scoped) | Terse comment / brief docstring / full doc page |

### What makes a preference "known" (binding)

A preference is KNOWN if any one of the four sources below provides an
explicit answer:

1. **Current direct user instruction** in this session
2. **Handoff state** — continuation file carries the preference forward
3. **Active standing rule** — CLAUDE.md convention, Serena memory (e.g.,
   `feedback_*.md`), `.claude/rules/` path-scoped rule
4. **User-message context** — the task description itself specifies

A preference is UNKNOWN otherwise. **SP's own defaults / heuristics do NOT
make a preference known** — they are SP priors, not user bindings. Treating
priors as bindings is exactly the failure mode B2 closes.

### Explicit delegation exception

If the user has explicitly delegated SP authority for the preference type
("you decide", "use your judgment", "do whatever is cleanest"), apply the
SP default and silent-log. Explicit delegation is a user-channel decision
that authorizes future SP-channel decisions of the same type within
session scope.

Delegation expires:

- At session end
- On context shift (new feature / new task class)
- On user override ("actually, ask me from now on")

### Output flag

When B2 detects an unknown user-owned preference, Bootstrap emits:

```
{flag: "genuine_ambiguity", reason: "<category-name>"}
```

The `reason` field carries WHICH preference category triggered detection
(e.g., `"PR decomposition"`, `"refactor approach"`, `"test strategy"`).
Per Codex note (b), the ambiguity reason MUST be preserved through the
pipeline — it is not a logging detail, it is the basis of AUQ framing
downstream.

### Interaction with downstream stages

| Stage | Behavior on `genuine_ambiguity` |
|---|---|
| Router | Routes to `user`-channel with `must-ask` attention hint |
| Egress | Composite rule satisfied via the `genuine_ambiguity` clause; AUQ_PROCEED |
| AUQ composition | Reads `reason` to frame the question — e.g., "There's an unknown {reason} preference here — pick one:" |

C5 is self-satisfying: Egress does not need any of the 7 materiality
signals to fire when `genuine_ambiguity` is set. B2 is the dedicated path
for preference-class decisions that materiality signals do not catch.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C5.

## Output flags

| Flag | Set by | Consumed by | Status |
|---|---|---|---|
| `bootstrap_blocking` | B1 (Q1/Q4 unresolved) | Router (halts pipeline) | Implemented |
| `genuine_ambiguity` | B2 (C5 detection) — carries `reason` field naming the triggering preference category | Router (must-ask hint) + Egress (composite clause) + AUQ composition (framing via `reason`) | Implemented (Brief 2) |

Both flags are emitted in Brief 2 per the contracts above.

## Test fixture coverage

- **F1-F4** — Bootstrap B1 passes (goal/done resolvable from input).
  Bootstrap exits cleanly, Router runs.
- **F5** — Tests B2. After Brief 2, B2 detects the unknown user-owned
  preference, emits `genuine_ambiguity` with `reason` field naming the
  triggering category, and F5 passes.

## Downstream stage

When Bootstrap exits without emitting `bootstrap_blocking`, control passes to
Router. See `references/pipeline/router.md`.
