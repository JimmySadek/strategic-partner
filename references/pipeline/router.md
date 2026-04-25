---
name: router
description: Stage 2 of the v5.12.0 pipeline — classifies each decision into one of 4 channels.
scope: v5.12.0 minimal vertical slice (Brief 1)
---

# Router — Stage 2

## Purpose

Router is the second stage of the v5.12.0 pipeline. For each decision surfaced
in the current turn, Router classifies it into exactly one of four channels.
Channel selection determines WHO owns the decision — and therefore whether
the decision flows to Egress for AUQ consideration or terminates silently.

## Scope (Brief 1 minimal)

The minimal Router is deliberately thin:

- 4 channels are defined and selectable.
- Channel selection is DESCRIPTIVE — the minimal Router does NOT gate on
  C1 T1/T2/T3 terminality criteria.
- No standing-rule retrieval. Rules in CLAUDE.md / Serena memory are NOT
  loaded as precedence constraints.
- No C4 calendar-native routing prior. `project_type` in CLAUDE.md has no
  effect on Router classification.

Three behaviors land in later briefs:

| Behavior | Brief | Fixture that exercises it |
|---|---|---|
| C1 artifact-authority terminality (T1/T2/T3) | Brief 2 (step 4) | F1 passes without; F2 needs T3 gating |
| Standing-rule retrieval + precedence | Brief 2 (step 3) | F3, F4 |
| C4 calendar-native routing prior | Brief 3 (step 6) | F2, F3 |

## Channels (4)

| Channel | Owner | Meaning | Terminal in Brief 1? |
|---|---|---|---|
| `user` | The user | Decisions the user owns — composes AUQ via Egress | No (flows to Egress) |
| `SP` | The SP | Decisions in the SP's authority (advisory tactics, framing choices) | Yes (in-role, not user-facing) |
| `executor` | Implementation session | Decisions for a downstream implementation session (scaffolded into the prompt) | No (deferred to executor) |
| `artifact-authority` | A canonical artifact | Decisions resolvable by applying the canonical artifact's content | **Yes (terminal; silent log)** |

Channel descriptions:

- **user** — The user owns the decision because they live with the result,
  the decision is irreversible, or material signals fire. Flows to Egress
  for the composite AUQ_PROCEED evaluation.
- **SP** — Advisory-layer choices: which reference to cite, which framing
  to lead with, whether to ask one question or two. SP does not surface
  these to the user; they are internal to how the SP composes the response.
- **executor** — Decisions that belong to the implementation session that
  will run the prompt SP is crafting. SP embeds these as deliverables or
  constraints inside the prompt itself — it does not resolve them in
  advisory.
- **artifact-authority** — A single artifact (MASTER_ROADMAP.md, project
  README, `feedback_*.md` memory, etc.) unambiguously resolves the decision.
  In the minimal slice, this channel is terminal: Router applies the
  artifact silently and emits a silent-log entry per
  `references/pipeline/silent-log.md`.

## Terminality (Brief 1 behavior)

The minimal Router treats `artifact-authority` as terminal whenever a single
artifact resolves the decision. There is no gating on canonical clarity
(T1), no precedence check (T2), and no materiality gate (T3).

**This is intentionally permissive.** It allows F1 to pass (α is clearly
canonical, no overrides, planning-only). It will cause F2 to misroute
(calendar-bearing decision with coordination signal should escalate, but
minimal Router will silent-log it).

Full C1 terminality lands in Brief 2 step 4 — adding T1/T2/T3 criteria, each
of which can fail and escalate to user-channel. Until then, artifact-authority
is a permissive terminal that passes F1 only.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C1.

## Standing-rule retrieval (DEFERRED)

**Status: stub. Brief 2 step 3 implements.**

When implemented, Router will load user-authored standing rules (CLAUDE.md
conventions, Serena memories matching `feedback_*.md` shape) at classification
time. Rules are evaluated as precedence constraints per C4's hierarchy:

```
current direct instruction > hard commitments > user-authored rules >
project planning docs > general SP defaults (incl. project_type)
```

A matching rule can (a) redirect channel selection (e.g., override
`project_type: calendar-native`'s bias), (b) fail C1 T2 terminality (rule
binds decision differently than artifact), or (c) be cited in the AUQ
framing when escalation fires.

Brief 1 does NOT retrieve standing rules. Fixtures F3 and F4 document the
target behavior and are expected to fail until Brief 2 lands.

## Calendar-native routing prior (DEFERRED)

**Status: stub. Brief 3 step 6 implements.**

When implemented, `project_type: calendar-native` in CLAUDE.md will bias
Router classification AWAY from artifact-authority for calendar-bearing
reconciliations (per C3 two-part test), toward user-channel with `likely-
ask` attention hint.

The prior sits at the `general SP defaults` precedence tier — below
current instruction, hard commitments, user-authored rules, and project
planning docs. Any higher-tier constraint addressing calendar handling
overrides the prior.

The prior does NOT raise materiality thresholds, does NOT modify materiality
signal definitions, and does NOT cause AUQs on every date mentioned.

Brief 1 does NOT implement the prior. Fixture F2 documents target behavior
and is expected to fail until Brief 3 lands.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C4.

## Output (Brief 1)

For each decision the turn surfaces, Router emits:

| Field | Values | Brief 1 behavior |
|---|---|---|
| `channel` | `user` \| `SP` \| `executor` \| `artifact-authority` | Descriptive selection |
| `attention_hint` | `must-ask` \| `likely-ask` \| `no-hint` | Defaults to `no-hint` (hint wiring is Brief 3 step 7) |
| `artifact_source` | path or memory name | Set when `channel = artifact-authority` |

Decisions classified as `artifact-authority` are terminal — Router emits the
silent-log entry and exits. All other channels flow to Egress.

## Test fixture coverage

- **F1** — PASS. α is clearly the canonical artifact, no overrides, internal
  planning only. Minimal Router selects `artifact-authority`, terminal,
  silent log. Fixture passes.
- **F2** — FAIL (expected). Needs C4 routing prior (Brief 3) + C1 T3
  terminality (Brief 2) to route correctly to `user` with `likely-ask`.
- **F3** — FAIL (expected). Needs standing-rule retrieval (Brief 2) to apply
  `feedback_calendar_vs_quality.md` override.
- **F4** — FAIL (expected). Needs standing-rule retrieval (Brief 2) + C1 T2
  terminality (Brief 2) to cite the rule and route via override path.
- **F5** — Not a Router concern — F5 tests Bootstrap B2. Router runs normally
  if B2 fires; in Brief 1, B2 is deferred so Router misroutes on preferences.

## Downstream stage

When Router exits without terminating (non-`artifact-authority` channel),
control passes to Egress. See `references/pipeline/egress.md`.
