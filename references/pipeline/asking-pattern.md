---
name: asking-pattern
description: Asking Patterns — stage 4 of the v5.12.0 pipeline. Depth modulation for AUQ composition based on attention hint set by Router.
scope: v5.12.0 (Brief 3)
---

# Asking Pattern — Stage 4

## Purpose

Asking Pattern is the fourth stage of the v5.12.0 pipeline. When Egress
emits `AUQ_PROCEED=true`, Asking Pattern determines HOW the AUQ is
composed — depth, structure, brevity. The stage exists to prevent two
opposite failure modes:

- **Over-asking** — heavy AUQ for a minor decision wastes user time.
- **Under-asking** — terse AUQ for a major decision suppresses needed
  deliberation.

Egress decides WHETHER to ask; Asking Pattern decides HOW to ask. The
split keeps each gate single-purpose: materiality lives in Egress,
composition discipline lives here.

## Stage placement

```
Bootstrap → Router → Egress → Asking Pattern → AUQ or log
```

Asking Pattern runs ONLY when Egress emits `AUQ_PROCEED=true`. When
Egress emits silent log (composite rule unsatisfied, or
artifact-authority terminal), Asking Pattern is skipped — there is no
AUQ to compose.

## Inputs

| Input | Source | Meaning |
|---|---|---|
| `attention_hint` | Router output | `must-ask` / `likely-ask` / `could-skip` — set by C1 T-failure escalations, by C4 routing prior, or by Bootstrap B2 emission |
| Decision context | Pipeline state | Channel, owner, materiality signals fired |
| `genuine_ambiguity` reason | Bootstrap B2 (when emitted) | Triggering preference category — used to frame the alternatives |

## Three depth modes

Verbatim from cycle 5 spec:

| Hint | Depth | Forced Alternatives | Position First | Reasoning detail |
|---|---|---|---|---|
| `must-ask` | Full | A/B/C with full trade-offs (3+ sentences each) | Full Position with rationale | Cite all signals fired and constraints |
| `likely-ask` | Brief | Named alternatives + 1-line trade-off each | Brief Position (1-2 sentences) | Cite primary signal only |
| `could-skip` | Minimal | Skip or single named alternative | Skip Position; recommend directly | Brief reason if relevant |

Depth scales monotonically — `must-ask` is a strict superset of what
`likely-ask` produces, and `likely-ask` a strict superset of
`could-skip`. The hint never reduces what an AUQ contains below what
the next-lower hint would produce.

## Composition mechanics

**Full depth (`must-ask`):**
Multi-paragraph AUQ with explicit headings (Position / Alternatives /
Trade-offs / Risks). Used for decisions touching multiple signals or
one-way doors. Examples: F4 (vendor-rule override path with the rule
cited), F5 (Bootstrap B2 `genuine_ambiguity` with named preference
category).

**Brief depth (`likely-ask`):**
Single-paragraph AUQ with named alternatives inline and a 1–2 sentence
Position. Used for decisions where the user owns the choice but the
structure is well-bounded. Example: F2 (calendar-native rehearsal
coordination — coordination signal fires per C1 T3 failure, C4
routing prior contributes the `likely-ask` hint).

**Minimal (`could-skip`):**
One-line confirmation or silent log. Used when Egress passes but the
gate is barely cleared (e.g., the `explicit_override` clause is the
only thing keeping AUQ_PROCEED true and no other signal fires).

## Interaction with Bootstrap B2 `genuine_ambiguity`

When Router routes via Bootstrap B2 emission, `attention_hint` is
always `must-ask`. AUQ composition reads the `reason` field that B2
populated and frames the alternatives around the triggered preference
category — not around a generic "what should we do?" prompt.

Example: `reason: PR_decomposition` → AUQ alternatives are "one
bundled PR" / "incremental PRs" / "sequenced across PRs," each with
trade-offs.

The `reason` field preserves the specific category Bootstrap detected,
so Asking Pattern's framing matches the user-owned preference rather
than reverting to generic Forced Alternatives.

## Interaction with the AUQ whitelist

The 3 protocol-mandated AUQ whitelist entries (codified in SKILL.md)
bypass both Router and Egress gates — they ALWAYS emit an AUQ
regardless of channel classification or materiality outcome. Asking
Pattern still applies to whitelist entries; they default to `must-ask`
depth.

The split: **whitelist defines WHEN to ask; Asking Pattern defines HOW
to ask.** Bypassing the gates does not bypass composition discipline.

## Test fixture coverage

| Fixture | Asking Pattern behavior |
|---|---|
| F1 | `AUQ_PROCEED=false` (artifact-authority terminal under T1/T2/T3). Asking Pattern is skipped; silent log only. |
| F2 | `likely-ask` depth → brief AUQ with named alternatives + 1-line trade-off + brief Position. C1 T3 fires on the coordination signal; C4 prior contributes the hint. |
| F3 | `AUQ_PROCEED=false` (standing-rule override redirects routing back to artifact-authority; T1/T2/T3 hold under override). Asking Pattern is skipped. |
| F4 | `must-ask` depth (T2 fail with override path). Full AUQ with the user-authored rule cited and full Position. |
| F5 | `must-ask` depth via Bootstrap B2 `genuine_ambiguity`. Full AUQ with reason-framed alternatives (e.g., PR decomposition / refactor depth). |

## Output

Asking Pattern emits the composed AUQ via `AskUserQuestion` per the
SP's primary-output contract (see SKILL.md § "Ask, Don't Drift"). The
composed AUQ inherits the depth determined here — no further
modulation downstream.

## Downstream

After the user responds to the AUQ, control returns to the SP's main
advisory loop. The Asking Pattern stage has no persistent state — each
turn re-evaluates inputs and re-composes from scratch.
