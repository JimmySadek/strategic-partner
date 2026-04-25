---
name: egress
description: Stage 3 of the v5.12.0 pipeline — composite materiality gate deciding AUQ_PROCEED.
scope: v5.12.0 minimal vertical slice (Brief 1)
---

# Egress — Stage 3

## Purpose

Egress is the third and final stage of the v5.12.0 pipeline. For each
decision that Router routes to a non-terminal channel (primarily `user`),
Egress evaluates the composite materiality rule and decides whether to
compose an AskUserQuestion (`AUQ_PROCEED`) or proceed without asking.

The stage exists to prevent two opposite failure modes:

- SP asks about everything, including trivial decisions (over-firing; the
  failure shape `project_type: calendar-native` can trigger without C4).
- SP asks about nothing the user would want to own (under-firing; the
  α/β/γ / calendar-bookkeeping / preference failures).

## Scope (Brief 1 minimal)

The composite rule STRUCTURE is described and applied, but signal evaluation
is a placeholder pass-through. Specifically:

- `owner` evaluates correctly — channel-derived from Router output.
- Material signals (`material`, `irreversible`, `high-cost`,
  `genuine_ambiguity`, `explicit_override`) all evaluate as placeholder
  pass-through — each returns `false` in the minimal slice (no detection
  logic is implemented).

In the minimal slice, `AUQ_PROCEED` fires only when SP's general advisory
heuristics (not the Egress composite rule) would compose an AUQ — the
composite rule itself does not yet gate anything.

This is intentional. Signal evaluation lands in Brief 2 step 5 (7 materiality
signals) and Brief 2 (`genuine_ambiguity` from Bootstrap B2). Until those
land, Egress is a structural placeholder that documents the target form
without computing it.

## Composite rule (target form)

```
AUQ_PROCEED iff owner == user AND (
  material OR irreversible OR high-cost OR genuine_ambiguity OR explicit_override
)
```

Readings of each clause:

| Clause | Meaning | Source |
|---|---|---|
| `owner == user` | Router classified channel as `user` | Router output |
| `material` | Any of the 7 materiality signals fires | Brief 2 step 5 |
| `irreversible` | Decision is a one-way door (Bezos) | Brief 2 / pattern gate |
| `high-cost` | Reversing is costly even if technically possible | Brief 2 |
| `genuine_ambiguity` | Bootstrap B2 emitted the flag (C5) | Brief 2 (B2) |
| `explicit_override` | User explicitly asked to be consulted | Session context |

The `owner == user` requirement guards against asking on decisions the user
does not own. The OR-cluster inside the parentheses requires at least one
substantive reason to ask. Both halves must hold — a user-owned decision
without any signal does not proceed to AUQ (e.g., a trivial preference the
user delegated).

## Signal evaluation (DEFERRED)

**Status: placeholder pass-through. Brief 2 step 5 implements.**

The 7 materiality signals (per C3's coordination sharpening and v3 spec):

| # | Signal | Fires when |
|---|---|---|
| 1 | `external_commitment` | Decision creates or modifies an external obligation |
| 2 | `quality_bar` | Decision affects a stated quality threshold |
| 3 | `governance_gate` | Decision crosses a sign-off / approval boundary |
| 4 | `coordination` | Named participants / external comms / sequencing / calendar-bearing deliverable (C3) |
| 5 | `money` | Spend, revenue, or financial commitment |
| 6 | `legal` | Compliance, contract, or regulatory exposure |
| 7 | `critical_path_dependency` | Current execution depends on this decision |

In Brief 1, none of these are detected. Egress treats `material` as `false`
for all decisions. `genuine_ambiguity` is also `false` (Bootstrap B2 is
deferred).

`irreversible` and `high-cost` are detectable via pattern-gate heuristics
(Bezos one-way doors, Blast Radius Instinct) — these continue to fire from
general advisory habits in Brief 1, but are not yet wired into the Egress
composite rule.

**Full spec:** v3 materiality definitions + `.handoffs/v512-spec-addenda-
0425.md` § C3 (coordination sharpening).

## Behavior in Brief 1

Because the composite rule's OR-cluster evaluates as placeholder-false,
Egress in Brief 1 does NOT actively gate AUQ_PROCEED — instead, AUQs fire
via SP's general advisory habits (Forced Alternatives pattern, Ask Don't
Drift, Advisory Completion Gate). This means:

- Decisions Router classifies as `artifact-authority` silent-log and never
  reach Egress (F1 works).
- Decisions Router classifies as `user` reach Egress, the composite rule
  is a no-op, and SP falls back to advisory habits — which may or may not
  produce the right AUQ depending on the fixture.
- Fixtures F2, F3, F4, F5 all depend on signals or flags that Brief 1 does
  not compute. Their expected Brief 1 failure modes reflect this.

This is the correct minimal-slice behavior — Brief 1 authors the structure
without the signal detection that makes the structure effective.

## Test fixture coverage

- **F1** — Egress never runs (Router terminates at artifact-authority). F1
  passes by Router alone.
- **F2-F4** — Egress runs but signal detection is deferred; composite rule
  does not fire correctly; fixtures fail as documented.
- **F5** — Egress's `genuine_ambiguity` clause is the target satisfier, but
  the flag is not emitted in Brief 1 (B2 deferred). F5 fails as documented.

## Silent log integration

Egress itself does NOT emit silent-log entries in Brief 1. Silent logs are
produced by Router's `artifact-authority` terminal path. When Brief 2 adds
signal detection and C1 terminality, additional silent-log entries will fire
from Egress "proceed without AUQ" outcomes (user-owned but no signal fires).
See `references/pipeline/silent-log.md`.
