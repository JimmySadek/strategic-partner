---
name: bootstrap
description: Stage 1 of the v5.12.0 pipeline — session prereq evaluation before Router runs.
scope: v5.12.0 minimal vertical slice (Brief 1)
---

# Bootstrap — Stage 1

## Purpose

Bootstrap is the first stage of the v5.12.0 pipeline (Bootstrap → Router →
Egress). It evaluates session prerequisite questions BEFORE downstream Router
classification runs. If a prereq is unresolved, Bootstrap blocks the pipeline
until resolved via direct AUQ.

The stage exists to prevent two failure modes:

- SP proceeds without knowing what the user is trying to achieve (B1 failure).
- SP silently applies an SP-default for a user-owned preference the user has
  not yet bound (B2 failure — deferred to Brief 2).

## Scope (Brief 1 minimal)

**Only B1 is implemented in Brief 1.** B2 (C5 unknown-preference detection)
is deferred to Brief 2.

The minimal Bootstrap treats B2 as a no-op. Fixture F5 tests B2 and is
expected to fail in Brief 1 as documented in its `## Brief 1 expected fail
mode` block.

## B1 — Fresh-session Q1/Q4 resolution

This behavior existed in v3; Brief 1 inherits it unchanged.

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

## B2 — Unknown user-owned preference detection (DEFERRED)

**Status: stub. Brief 2 implements detection logic.**

B2 will detect when the task contains a user-owned scoping or optimization
preference that is unknown per C5 — meaning no current instruction, handoff,
standing rule, or user-message context binds the preference, AND no SP prior
makes the preference "known" (priors are not bindings).

Preference categories per C5: PR decomposition, depth/variant, trade-off
prioritization, refactor approach, test strategy (task-scoped), documentation
depth (task-scoped).

When B2 detects an unknown preference, it will emit `genuine_ambiguity` with
the triggering category named in the flag's reason field. The Router will
then route to user-channel with `must-ask` attention hint; Egress will
satisfy composite rule via the `genuine_ambiguity` clause.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C5.

Brief 1 does NOT implement B2. Fixture F5 documents the target behavior and
is expected to fail until Brief 2 lands.

## Output flags (Brief 1)

| Flag | Set by | Consumed by | Brief 1 status |
|---|---|---|---|
| `bootstrap_blocking` | B1 (Q1/Q4 unresolved) | Router (halts pipeline) | Implemented |
| `genuine_ambiguity` | B2 (C5 detection) | Router (must-ask hint) + Egress (composite clause) | **Deferred to Brief 2** |

`genuine_ambiguity` is NOT emitted in Brief 1 — the flag is listed here for
spec completeness but produces no runtime effect in the minimal slice.

## Test fixture coverage

- **F1-F4** — Bootstrap B1 passes (goal/done resolvable from input). Bootstrap
  exits cleanly, Router runs.
- **F5** — Tests B2. Expected to fail in Brief 1 (B2 not implemented); turns
  green after Brief 2 adds C5 detection.

## Downstream stage

When Bootstrap exits without emitting `bootstrap_blocking`, control passes to
Router. See `references/pipeline/router.md`.
