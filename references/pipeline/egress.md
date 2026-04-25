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

## Scope (Brief 2)

After Brief 2, the composite rule STRUCTURE is fully active:

- `owner` evaluates from Router channel selection.
- `material` evaluates against the **7 materiality signals** detailed
  below (with C3 sharpening of the `coordination` signal).
- `genuine_ambiguity` evaluates from Bootstrap B2's flag (with `reason`
  field carrying the triggering preference category).
- `irreversible`, `high-cost`, `explicit_override` evaluate via existing
  pattern gates (Bezos one-way doors, Blast Radius Instinct, session
  context) and the composite rule reads them.

The v5.12.0 minimum for Brief 2 requires `material OR genuine_ambiguity`
to gate AUQ_PROCEED on user-channel decisions. Full Egress wiring of
`irreversible` / `high-cost` / `explicit_override` (vs being inherited
from pattern gates) is not strictly required for Brief 2; pattern gates
continue to fire those clauses as they do today.

## Composite rule (active)

```
AUQ_PROCEED iff owner == user AND (
  material OR irreversible OR high-cost OR genuine_ambiguity OR explicit_override
)
```

Readings of each clause:

| Clause | Meaning | Source |
|---|---|---|
| `owner == user` | Router classified channel as `user` | Router output |
| `material` | Any of the 7 materiality signals fires | The 7 materiality signals section below |
| `irreversible` | Decision is a one-way door (Bezos) | Pattern gate (Bezos one-way doors / Blast Radius Instinct) |
| `high-cost` | Reversing is costly even if technically possible | Pattern gate (cost-of-reversal heuristic) |
| `genuine_ambiguity` | Bootstrap B2 emitted the flag (C5) — `reason` field carries the triggering preference category | Bootstrap output (`references/pipeline/bootstrap.md` § B2) |
| `explicit_override` | User explicitly asked to be consulted on this decision class | Session context |

The `owner == user` requirement guards against asking on decisions the user
does not own. The OR-cluster inside the parentheses requires at least one
substantive reason to ask. Both halves must hold — a user-owned decision
without any signal does not proceed to AUQ (e.g., a trivial preference the
user delegated).

## The 7 materiality signals

The `material` clause fires when ANY of the 7 signals below fires for the
decision under evaluation. The signal set is locked at exactly 7 — neither
more nor fewer. Order: `external_commitment`, `quality_bar`,
`governance_gate`, `coordination`, `money`, `legal`,
`critical_path_dependency`.

### 1. external_commitment

**Definition:** Decision creates, modifies, or affects an obligation to a
party outside the SP+user dyad — a customer, vendor, partner, reviewer,
candidate, or anyone who has set expectations based on it.

**Fires when:**

- A communication has been or will be sent to a third party committing to
  a date, deliverable, or quality
- A contract, SLA, or public statement is on the line
- A counterparty is sequencing their work on the assumption SP+user will
  deliver
- The decision changes what was previously communicated externally

**Examples:**

- Vendor delivery date in a roadmap that was shared with the vendor
- Public launch date on a marketing page
- Customer-facing API change that breaks integration contracts

### 2. quality_bar

**Definition:** Decision affects a stated quality threshold — a level of
correctness, polish, performance, or completeness the user has previously
declared as the bar for "good enough."

**Fires when:**

- The decision lowers a standard the user has explicitly named (e.g.,
  test coverage threshold, p99 latency, "no shipping with known TODOs")
- The decision raises a standard in a way that affects scope or schedule
- A trade-off between speed and quality is on the table and the user has
  expressed strong preferences in either direction
- The output crosses an "acceptance bar" the user owns

**Examples:**

- Skipping integration tests on a refactor when the user has a "always
  green main" rule
- Shipping a feature with known accessibility gaps
- Choosing a cheaper algorithm that misses the user's stated p95 target

### 3. governance_gate

**Definition:** Decision crosses a sign-off or approval boundary — review,
audit, change-management, or any process gate that a defined role owns.

**Fires when:**

- The decision needs a code review, security review, design review, or
  legal review before merging or shipping
- A change-management gate (CAB, release manager, on-call lead) must
  approve
- The user is not the approver and the decision pre-empts the approver's
  role
- The decision sets policy that other contributors will be expected to
  follow

**Examples:**

- Merging a migration without DBA review when the project requires one
- Promoting a release candidate to production without the user's "ship"
  call
- Adding a new dependency without security review

### 4. coordination

**Definition:** Decision touches the date, time, or sequencing of a
calendar-bearing deliverable — meaning an artifact whose schedule is
load-bearing for parties who consume it as coordination truth (per the
C3 two-part test below).

**Fires when** the decision's date / time / sequencing affects ANY of:

- Participants (named individuals or roles)
- External comms (sent, scheduled, or planned)
- Deadline compliance (a stated deadline)
- Sequencing (current execution depends on date ordering)
- Venue, vendor, customer, reviewer, candidate, legal, grant, or
  public-launch commitments
- A **calendar-bearing deliverable** (per C3 two-part test below)

#### C3 — Calendar-bearing deliverable two-part test (AND)

A "calendar-bearing deliverable" is an artifact for which BOTH hold —
verbatim from `.handoffs/v512-spec-addenda-0425.md` § C3:

- **P1 — Substance test:** The date / schedule / sequencing is a
  load-bearing element of the deliverable's coordination function (not
  metadata about the deliverable). Removing the date changes the
  deliverable's coordination meaning. The deliverable's primary purpose
  is communicating schedule, date, or sequencing — or the date is named
  / cited as a binding element.
- **P2 — Consumption test:** Other parties or processes consume the date
  as coordination truth — they make commitments, allocate resources,
  sequence work, or set expectations based on it.

**Single-question discriminator (operational shortcut):**

> "Would removing this date from the artifact change downstream
> commitments, sequencing, or resource allocation?"

- **YES** → calendar-bearing deliverable (P1 ✓ AND P2 ✓) → `coordination`
  signal fires
- **NO** → not calendar-bearing → the `coordination` signal does not fire
  on this artifact alone

**Examples (calendar-bearing → fires):**

- Calendar invite (date IS the deliverable; invitees commit time)
- Project roadmap with milestone dates (team / stakeholders sequence on
  it)
- Launch plan with launch date (marketing / eng / legal sequence on it)
- Slack message confirming rehearsal time (attendees commit time)

**Examples (not calendar-bearing → does NOT fire):**

- Bug report with `reported_on: 2026-04-25` (date is metadata, not
  consumed for scheduling)
- README "last updated" timestamp (not a coordination basis)
- Code review checklist mentioning a date incidentally

### 5. money

**Definition:** Decision involves spend, revenue, or a financial
commitment — direct cost, opportunity cost beyond a threshold, or a
budgeted line item.

**Fires when:**

- The decision triggers spend (vendor fees, infrastructure cost, paid
  service) above an unwritten "small enough to absorb" threshold
- The decision affects revenue (pricing change, promo, churn risk)
- The decision allocates a budget the user owns
- A rush fee, late fee, or penalty is on the table

**Examples:**

- $800 rush fee for compressed mastering turnaround (F4)
- Switching to a paid tier of a SaaS dependency
- A refund / credit decision for a customer

### 6. legal

**Definition:** Decision creates compliance, contract, or regulatory
exposure — anything where the wrong move incurs legal risk.

**Fires when:**

- The decision affects data handling under a regulation (GDPR, HIPAA,
  CCPA, PCI, etc.)
- The decision modifies or interprets a contract clause
- The decision touches IP, licensing, attribution, or terms of service
- A statutory deadline or notification requirement applies

**Examples:**

- Changing data retention to ship a feature faster
- Using a library under a license incompatible with the project
- Sharing user data with a new third-party processor

### 7. critical_path_dependency

**Definition:** Current execution depends on this decision — work
downstream is blocked, or sequencing of upstream work is locked by it.

**Fires when:**

- A blocking dependency is waiting on the outcome
- The decision sets a precedent that downstream work is built around
- Reversing the decision later would invalidate work already in flight
- The decision is the gate before a parallel team / process can proceed

**Examples:**

- Schema choice that all downstream services will consume
- API contract that mobile and web clients are about to ship against
- Branching strategy decision before a major refactor lands

---

The 7 signals collectively cover the materiality space documented in v3
plus the C3 sharpening. New signals are not added; the set is locked.
When evaluating a decision, Egress checks each signal in order; the first
fire is sufficient (`material` is the OR of the 7).

**Full spec:** v3 materiality definitions + `.handoffs/v512-spec-addenda-
0425.md` § C3 (coordination sharpening).

## Behavior in Brief 2

Egress now actively gates AUQ_PROCEED via the composite rule. The
OR-cluster substantively evaluates each clause; SP's general advisory
habits (Forced Alternatives, Ask Don't Drift, Advisory Completion Gate)
compose the AUQ that the gate authorizes — they do not bypass it.

- Decisions Router classifies as `artifact-authority` and passing
  T1/T2/T3 silent-log at Router and never reach Egress (F1 works as in
  Brief 1).
- Decisions Router classifies as `user` (including artifact-authority
  candidates that fail any T-criterion) reach Egress. The composite rule
  evaluates `owner == user` AND (`material` OR `irreversible` OR
  `high-cost` OR `genuine_ambiguity` OR `explicit_override`).
- Fixtures F2, F3, F4 turn green via the materiality / override paths.
  F5 turns green via the `genuine_ambiguity` path from Bootstrap B2.
- Brief 3 layers C4 routing prior on top of Brief 2's gates. F2's
  `likely-ask` attention-hint depth-modulation lands in Brief 3 step 7.

## Test fixture coverage

- **F1** — Egress never runs (Router terminates at `artifact-authority`
  with T1/T2/T3 holding). F1 passes by Router alone.
- **F2** — Egress evaluates the `coordination` signal (named participants
  + downstream sequencing) → fires → composite rule satisfied →
  AUQ_PROCEED. F2 passes (modulo the Brief 3 attention-hint depth caveat).
- **F3** — Standing-rule override applied at Router; T1/T2/T3 all pass
  under the override → terminal at Router; Egress does not run. F3
  passes.
- **F4** — Standing-rule override applied at Router; T2 fails → escalate
  to Egress. Egress evaluates: `owner == user` ∧ (`coordination` ∨
  `money`) → AUQ_PROCEED. F4 passes with the rule cited in framing.
- **F5** — Bootstrap B2 emits `genuine_ambiguity` with `reason`; Router
  routes to `user` with `must-ask`; Egress satisfies the composite rule
  via the `genuine_ambiguity` clause → AUQ_PROCEED. F5 passes.

## Silent log integration

Silent logs fire from two paths after Brief 2:

1. **Router** — `artifact-authority` terminal pass (T1/T2/T3 all hold) →
   silent log with reason `artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)`.
2. **Egress** — user-channel decision with `owner == user` but no clause
   in the OR-cluster fires (no materiality, no ambiguity, no override) →
   silent log with reason `egress: user-owned but no signal fired`.

Both paths use `references/pipeline/silent-log.md` for entry format.
