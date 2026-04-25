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

## Scope (Brief 2)

After Brief 2, Router implements:

- 4 channels (defined and selectable).
- **Standing-rule retrieval** — Router queries CLAUDE.md, Serena memories,
  and `.claude/rules/` for relevant standing rules at classification time.
- **Precedence stack (5 tiers)** — see Standing-rule retrieval below.
- **C1 artifact-authority terminality (T1/T2/T3)** — gates the
  artifact-authority channel; failure of any criterion escalates to
  user-channel.

One behavior remains deferred:

| Behavior | Brief | Fixture that exercises it |
|---|---|---|
| C4 calendar-native routing prior (`project_type` biasing) | Brief 3 (step 6) | F2 |

The deferred prior sits at Tier 5 of the precedence stack — see Standing-
rule retrieval § Precedence stack below.

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

## C1 — Artifact-authority terminality (T1, T2, T3)

When Router classifies a decision as `artifact-authority`, it evaluates the
three terminality criteria below. **All three must hold (AND)** for the
decision to be terminal (silent log only). Failure of any one → escalate
to user-channel with an attention hint based on which criterion failed.

**Default on uncertainty: fail.** If any criterion is uncertain (cannot be
affirmatively confirmed), treat it as failed and escalate. The burden of
proof is on terminality, not on escalation. Same default-tightening logic
required for Router uncertainty in earlier cycles.

**Attention-hint labels:** Brief 2 labels each escalation as `must-ask` (or
`must-ask` IF / silent-with-log per T2's special case below). The
depth-modulation MECHANICS for the hint (how it affects Asking Pattern
depth and Forced Alternatives) land in Brief 3 step 7.

### T1 — Canonical source is clear

A single artifact is unambiguously the source of truth for the decision.

**Tests:**

- One artifact is explicitly designated canonical (e.g.,
  `MASTER_ROADMAP.md`, project README, `feedback_*.md` Serena memory)
- OR a user-authored rule designates which artifact wins on conflict
  (e.g., "Sunday rehearsals are the source — other docs follow")
- OR there is only one artifact addressing the decision

**Fails when:**

- Multiple artifacts address the decision with no canonical designation
- Canonical artifact is internally inconsistent (contradictory entries)
- Canonical designation is itself disputed (e.g., two docs each claim to
  be the master)

**Escalation hint on T1 failure:** `must-ask` (user picks canonical or
chooses).

### T2 — No higher-precedence constraint conflicts

The artifact's content does not conflict with any higher-precedence
constraint. Per the Precedence stack defined in the Standing-rule
retrieval section below:

```
1. Current direct instruction
2. Hard commitments (safety / legal / financial)
3. User-authored rules (CLAUDE.md, Serena memory, feedback_*.md, .claude/rules/)
4. Project planning docs
5. General SP defaults (incl. project_type prior — added Brief 3)
```

**Tests:**

- Current session contains no direct user instruction overriding the
  artifact
- No hard commitment (safety / legal / financial) constrains the decision
- No user-authored rule (CLAUDE.md / Serena memory / `feedback_*.md` /
  `.claude/rules/`) overrides
- No higher-tier project doc contradicts

**Fails when:**

- User said something different in this session
- A standing rule binds the decision differently
- A higher-tier doc contradicts the artifact

**Escalation hint on T2 failure:** `must-ask` IF the higher-precedence
constraint is itself ambiguous; otherwise SP applies the higher constraint
silently and logs both (the artifact and the override).

### T3 — No unresolved material consequence requires user judgment

Applying the artifact has no material consequence requiring user judgment
per Egress's 7 materiality signals (`external_commitment` / `quality_bar` /
`governance_gate` / `coordination` / `money` / `legal` /
`critical_path_dependency` — see `references/pipeline/egress.md`).

**Tests:**

- The decision touches none of the 7 materiality signals (positive
  criterion check, not absence-of-evidence)
- OR the artifact's specification fully resolves the material consequence
  (e.g., a user-authored standing rule already adjudicates the trade-off)

**Fails when:**

- Applying the artifact would create / break / redirect any material
  consequence
- A material consequence exists but the artifact does not fully address it

**Escalation hint on T3 failure:** `must-ask` (the user owns material
decisions even when an artifact is canonical).

### Silent log on terminal pass

When all three criteria hold, Router emits a silent-log entry per
`references/pipeline/silent-log.md`. The `reason` field cites which
T-criteria held:

```
[YYYY-MM-DD HH:MM] [router] "Decision summary" → applied [artifact source]
  | reason: artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)
```

For T-failure escalations, no artifact-authority log line is emitted —
escalation produces a user-channel AUQ which logs through the standard
digest path.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C1.

## Standing-rule retrieval

Router queries three sources for relevant standing rules at classification
time:

1. **CLAUDE.md content** — project-scoped rules and conventions
2. **Serena memories** matching the decision domain — typically
   `feedback_*.md` named patterns, but any memory whose body addresses the
   decision counts
3. **`.claude/rules/` path-scoped rules** — rules with `paths:`
   frontmatter matching the current file or scope

Retrieval is best-effort. Absence of a matching rule is logged but is not
an error. When Serena is unavailable, Router falls back to file-based
reads of CLAUDE.md and `.claude/rules/`.

A matching rule can:

- (a) Redirect channel selection (e.g., override the `project_type:
  calendar-native` routing prior added in Brief 3)
- (b) Fail C1 T2 terminality — the rule binds the decision differently
  than the candidate artifact, so artifact-authority is not terminal
- (c) Be cited in the AUQ framing when escalation fires (e.g., F4: "Your
  CLAUDE.md rule says to always ask vendors about date changes…")

### Precedence stack

The 5-tier precedence stack determines which constraint wins when two
sources address the same decision. Verbatim from
`.handoffs/v512-spec-addenda-0425.md` § C4 § Precedence:

```
1. Current direct instruction
2. Hard commitments (safety / legal / financial)
3. User-authored rules (CLAUDE.md, Serena memory, feedback_*.md, .claude/rules/)
4. Project planning docs
5. General SP defaults (incl. project_type prior — added Brief 3)
```

Higher tier always overrides lower. Tiers are evaluated top-down: if Tier
1 binds the decision, Tiers 2-5 are not consulted; if Tier 1 is silent
and Tier 2 binds, Tiers 3-5 are not consulted; etc.

When a constraint is itself uncertain (e.g., a rule is found but its
interpretation is ambiguous for the current case), default to escalate
rather than silently picking an interpretation. Same default-on-uncertainty
discipline as C1 terminality.

## Calendar-native routing prior (DEFERRED)

**Status: stub. Brief 3 step 6 implements.**

When implemented, `project_type: calendar-native` in CLAUDE.md will bias
Router classification AWAY from artifact-authority for calendar-bearing
reconciliations (per the C3 two-part test in
`references/pipeline/egress.md`), toward user-channel with `likely-ask`
attention hint.

The prior sits at **Tier 5 — General SP defaults** in the Precedence stack
above. Any higher-tier constraint addressing calendar handling overrides
the prior. Brief 2's standing-rule retrieval already loads Tiers 1-4, so
once the prior lands in Brief 3, the override paths exercised by F3 and
F4 work without further Router changes.

The prior does NOT raise materiality thresholds, does NOT modify
materiality signal definitions, and does NOT cause AUQs on every date
mentioned.

Brief 2 does NOT implement the prior. Fixture F2 documents target
behavior and is expected to fail until Brief 3 lands.

**Full spec:** `.handoffs/v512-spec-addenda-0425.md` § C4.

## Output

For each decision the turn surfaces, Router emits:

| Field | Values | Brief 2 behavior |
|---|---|---|
| `channel` | `user` \| `SP` \| `executor` \| `artifact-authority` | Selected after Standing-rule retrieval and (for artifact-authority candidates) C1 T1/T2/T3 evaluation |
| `attention_hint` | `must-ask` \| `likely-ask` \| `no-hint` | Set on T-failure escalations and on `genuine_ambiguity` from Bootstrap B2; depth-modulation MECHANICS land in Brief 3 step 7 |
| `artifact_source` | path or memory name | Set when `channel = artifact-authority` AND T1/T2/T3 all hold |

Decisions classified as `artifact-authority` and passing T1/T2/T3 are
terminal — Router emits the silent-log entry and exits. All other channels
(including artifact-authority candidates that fail any T-criterion) flow
to Egress.

## Test fixture coverage

- **F1** — PASS. α is the canonical artifact, no overrides, internal
  planning only. Router selects `artifact-authority`, T1/T2/T3 all hold,
  terminal, silent log.
- **F2** — PASS after Brief 2 (with caveat). C1 T3 fails on the
  `coordination` signal (named participants + downstream sequencing) →
  escalate to user-channel. Pass criteria 1-4 satisfiable. The
  `likely-ask` attention-hint MECHANICS land in Brief 3; if reviewer
  expects a visible `likely-ask` indicator, F2 may PARTIAL-pass with that
  caveat (assertion satisfied otherwise).
- **F3** — PASS. Standing-rule retrieval finds
  `feedback_calendar_vs_quality.md`; the rule overrides any future
  `project_type: calendar-native` prior. C1 T1/T2/T3 all pass under the
  override → silent log with override citation.
- **F4** — PASS. Standing-rule retrieval finds the CLAUDE.md vendor rule.
  T2 fails because the rule binds the decision differently than the
  artifact alone → user-channel via override path with the rule cited in
  framing.
- **F5** — Not a Router concern — F5 tests Bootstrap B2. After Brief 2,
  B2 emits `genuine_ambiguity` with `reason`; Router routes to `user`
  with `must-ask`; Egress satisfies via the `genuine_ambiguity` clause.

## Downstream stage

When Router exits without terminating (non-`artifact-authority` channel),
control passes to Egress. See `references/pipeline/egress.md`.
