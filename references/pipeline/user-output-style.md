---
name: user-output-style
description: User-facing output language for v5.12.0 — translation table from internal pipeline labels to plain English.
scope: v5.12.0
---

# User-Facing Output Style — v5.12.0 Pipeline

## Purpose

The v5.12.0 pipeline introduced internal vocabulary so SP can self-discipline
its decisions: `Bootstrap`, `Router`, `Egress`, `Asking Pattern`, channel
labels, criteria like `C1`/`C4`, terminality tests `T1`/`T2`/`T3`, the 7
materiality signals, the `genuine_ambiguity` flag, attention hints,
precedence tiers, and so on. These labels are reasoning checkpoints — they
let SP and reviewers audit how a decision was made.

This file defines the boundary between SP's internal reasoning vocabulary
and the language users actually see. The pipeline runs in internal
vocabulary; the output translates to plain English. Real users have no
model for "user-channel gate fires" or "C1 T3 failure on coordination
signal" — surfacing those labels reads like compliance-robot output and
breaks the partner-feel that is the SP's brand promise.

## The Mandate

**Internal pipeline labels MUST NOT appear in user-facing prose.**

User-facing prose includes EVERY visible response surface:

- Every visible reply (advisory paragraphs, recommendations, summaries)
- Every `AskUserQuestion` question text
- Every `AskUserQuestion` option label and option description
- Every `**Position:**` line
- Every reasoning paragraph
- Every silent-log entry surfaced inline (when SP acknowledges a silent
  decision in prose)

User-facing prose EXCLUDES:

- SP's own private reasoning chain that the user does not see
- Troubleshooting conversations with developers (e.g., "the C4 prior fired
  here") — when an engineer is debugging the pipeline and asks about
  internal mechanics, surfacing labels is the answer
- This file, the pipeline reference files, SKILL.md, and other internal
  documentation

When in doubt, ask "would a first-time user reading this response know
what this means without reading the pipeline references?" If no, translate.

## Translation Table

Each row pairs an internal label (left) with its user-facing equivalent
(right). Sections are alphabetized within for reviewability.

### Stage names

| Internal | User-facing |
|---|---|
| `Asking Pattern` | (omit — depth shows in AUQ structure, not in a label) |
| `B1` | (omit — describe what's being checked: "I need to confirm the goal first") |
| `B2` | (omit — describe what's being checked: "I noticed an unstated preference here") |
| `Bootstrap` | (omit — describe what's happening: "before I plan this, I need to confirm…") |
| `Egress` | (omit — describe what's happening in plain prose) |
| `Router` | (omit — describe what's happening in plain prose) |
| `Stage 2` | (omit) |
| `Stage 3` | (omit) |
| `Stage 4` | (omit) |

### Channel labels

| Internal | User-facing |
|---|---|
| `artifact-authority` | "the canonical X resolves this" / "your README / MASTER_ROADMAP / etc. answers this" |
| `executor channel` | "this is for the implementation session, not advisory" / "the executor will handle this" |
| `owner == user` | "this is your call" / "you should make this call" |
| `SP-channel` | (omit — these are internal advisory choices the user does not need to see) |
| `user-channel` | "this is your call" / "you should make this call" / (escalate without naming the channel) |

### Criteria, priors, and precedence

| Internal | User-facing |
|---|---|
| `artifact-authority terminality` | "the canonical doc resolves this without your input needed" |
| `C1` | (omit — name the test in plain English: "is there a single canonical doc, no override, no material consequence?") |
| `C3` | (omit — name the test: "is the date load-bearing AND consumed for scheduling?") |
| `C4` | (omit — describe the bias: "this is a calendar-native project, so I lean toward asking on calendar-bearing decisions") |
| `C5` | (omit — describe what was detected: "you have an unstated preference about X here") |
| `precedence stack` | "your direct instructions beat hard commitments beat standing rules beat planning docs beat my defaults" / "what wins when sources conflict" |
| `project_type: calendar-native` | "this project is calendar-native (you set that in CLAUDE.md)" |
| `routing prior` | (omit — describe the bias in plain prose) |
| `T1` | "is there a single canonical doc?" |
| `T2` | "does any rule or instruction override that doc?" |
| `T3` | "does applying it touch external commitments, money, legal, etc.?" |
| `Tier 1` | "your direct instructions" |
| `Tier 2` | "hard commitments (safety / legal / financial)" |
| `Tier 3` | "your standing rules (CLAUDE.md, memory, feedback files)" |
| `Tier 4` | "project planning docs" |
| `Tier 5` | "my defaults" |

### Materiality signals

| Internal | User-facing |
|---|---|
| `7 materiality signals` | (omit the count — name the relevant signal in prose) |
| `coordination` | "this affects [named participants] and [downstream sequencing]" |
| `critical_path_dependency` | "downstream work is blocked on this" / "this gates other work" |
| `external_commitment` | "[customer / vendor / partner] is expecting this" / "we've already told [party] X" |
| `governance_gate` | "this needs [review type] before it ships" / "[role] has to sign off" |
| `legal` | "this has compliance / contract / regulatory exposure" |
| `material` (clause) | (omit — name the specific signal that fired) |
| `money` | "this involves spend / revenue / [specific $ amount]" |
| `quality_bar` | "this trades against the [specific bar] you set" |

### Composite rule clauses

| Internal | User-facing |
|---|---|
| `AUQ_PROCEED` | (omit — composing the AUQ IS the user-facing surface) |
| `explicit_override` | "you asked me to consult you on this class of decision" |
| `genuine_ambiguity` | "you have a preference about [category] I haven't been told" |
| `high-cost` | "reversing this later would be costly" |
| `irreversible` | "this is a one-way door" / "this is hard to undo once shipped" |

### Attention hints

| Internal | User-facing |
|---|---|
| `attention_hint` | (omit the label — depth shows in AUQ structure) |
| `could-skip` | (omit the label — minimal AUQ shape conveys it) |
| `likely-ask` | (omit the label — brief AUQ shape conveys it) |
| `must-ask` | (omit the label — full AUQ shape conveys it) |

### Bootstrap flags

| Internal | User-facing |
|---|---|
| `bootstrap_blocking` | "I need to confirm [the goal / what done looks like] before I can plan further" |
| `genuine_ambiguity` flag schema | (omit the schema — name the preference category in prose: "you haven't told me your preference about [category]") |

### Miscellaneous internal labels

| Internal | User-facing |
|---|---|
| `composite rule` | (omit — describe what made the call user-facing in plain prose) |
| `discriminator` | "the test I'd use is: [plain question]" |
| `halting at Bootstrap` | "I need to confirm something before I plan further" |
| `P1` (substance test) | "the date is load-bearing for this artifact" |
| `P2` (consumption test) | "[parties] consume this date for scheduling" |
| `Persistence layer` | (omit — describe what's being persisted: "saving this to the handoff") |
| `Premise gate` | "I want to verify the assumption before I proceed" |
| `silent log` | (omit verbatim format — when surfacing inline, write plain prose; see § User-facing surfacing in `silent-log.md`) |
| `Trigger #N` | "what triggered this is [plain reason]" |
| `two-part test` | "two things have to be true: [P1 in prose] AND [P2 in prose]" |

### Public Cognitive Pattern names — OK to surface

These are part of public SP vocabulary and stay user-facing:

| Internal | User-facing |
|---|---|
| `Forced Alternatives` | OK to surface — public SP vocabulary |
| `Inversion check` | OK to surface — public SP vocabulary |
| `Position First` (`**Position:**`) | OK to surface — public SP vocabulary |
| `Premise Challenge` | OK to surface — public SP vocabulary |

## Before / After Examples

Each example shows a realistic SP response in current jargon-heavy form
(Before) and the plain-English equivalent (After) with identical content.
Examples are paired with the v5.12.0 fixture domains so reviewers can
mentally connect.

### Example 1 — F1 shape (artifact-authority terminal, silent log inline)

**Scenario:** User asks SP to reconcile planning docs α / β / γ. α is the
canonical roadmap, no overrides apply, and this is internal planning only
(no external party consumes it).

**Before (jargon-heavy):**

> Classifying as `artifact-authority` channel. C1 evaluation: T1 ✓ (α is
> canonical per the README), T2 ✓ (no precedence-stack override found),
> T3 ✓ (no materiality signal fires — internal planning, no external
> commitment). Terminal — emitting silent log.
>
> `[2026-04-26 11:02] [router] "α/β/γ planning reconciliation" → applied α | reason: artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)`
>
> Following α going forward.

**After (plain English):**

> Following α (your MASTER_ROADMAP.md). It's the canonical doc per your
> README, nothing in your standing rules contradicts it, and this is
> internal planning — no external commitments or downstream parties
> depend on which doc you reconcile to. So I'll apply α and move on.

### Example 2 — F2 shape (coordination escalation with Position + AUQ)

**Scenario:** Band rehearsal on Sunday is the sign-off gate before the
Wednesday showcase. Lena, Marco, and Priya committed to the slot. A venue
conflict forces a change.

**Before (jargon-heavy):**

> Routing prior C4 fires (`project_type: calendar-native` set in
> CLAUDE.md). C1 T3 fails: `coordination` signal fires (named
> participants: Lena, Marco, Priya; downstream sequencing: Sunday
> rehearsal → Wednesday showcase). Escalating to user-channel with
> `likely-ask` attention hint. Egress composite rule satisfied via the
> `material` clause.
>
> **Position:** Saturday, original venue. Triggering Forced Alternatives.
>
> A: Reschedule Saturday same venue. B: Reschedule Sunday backup venue.
> C: Keep Sunday, resolve venue separately.

**After (plain English):**

> The Sunday slot isn't just a date on a doc — Lena, Marco, and Priya
> committed to it, and Sunday is the sign-off gate before Wednesday's
> showcase. So this is your call.
>
> **Position:** I'd lean toward A (Saturday at the original venue),
> because keeping the venue limits the coordination cost — only the date
> moves, and the Wednesday showcase isn't disturbed.
>
> A. Reschedule Saturday at the original venue — preserves the venue, but
> Marco mentioned Saturday conflicts before; worth checking with him.
> B. Reschedule Sunday at the backup venue — preserves the day everyone
> blocked, but the backup is 40 minutes from two members.
> C. Keep Sunday and find a third option — most flexible, most
> coordination overhead.
>
> Which path do you want me to plan around?

### Example 3 — F4 shape (standing-rule override path with rule cited)

**Scenario:** Mastering vendor offers an $800 rush fee to compress
turnaround. User has a CLAUDE.md rule: "always ask the vendor about date
changes before committing."

**Before (jargon-heavy):**

> Standing-rule retrieval found CLAUDE.md vendor rule. C1 T2 fails — the
> rule binds the decision differently than the artifact alone. Routing
> via override path. Egress composite rule satisfied: `owner == user` ∧
> (`coordination` ∨ `money`) → `AUQ_PROCEED=true`. Attention hint:
> `must-ask`.
>
> **Position:** Decline the rush fee.
>
> A: Pay $800 rush fee. B: Decline, stick to standard turnaround. C: Ask
> vendor for cheaper alternatives.

**After (plain English):**

> Your CLAUDE.md rule says to always check with the vendor before
> committing on date changes — and this is an $800 spend on top of that.
> Both the money and your standing rule put this on you to decide.
>
> **Position:** I'd lean toward B (decline the rush fee). Your rule
> exists for a reason, and absorbing $800 to compress a date the vendor
> hasn't yet agreed to feels like the wrong order of operations.
>
> A. Pay the $800 rush fee — fastest, but commits the spend before the
> conversation your rule asks for.
> B. Decline and keep the standard turnaround — respects the rule, no
> extra spend, but you lose the compressed date.
> C. Ask the vendor for cheaper compression options before deciding —
> aligns with the rule, may unlock middle-ground options.
>
> Which path?

### Example 4 — F5 shape (`genuine_ambiguity` with named preference category)

**Scenario:** User asks SP to plan a refactor of the auth middleware.
Bootstrap detects an unstated preference about PR decomposition.

**Before (jargon-heavy):**

> Bootstrap B2 detection fires — `genuine_ambiguity` flag emitted, reason:
> `PR decomposition`. Router routes to user-channel with `must-ask`
> attention hint. Egress satisfies composite rule via the
> `genuine_ambiguity` clause → `AUQ_PROCEED=true`. Asking Pattern
> composes at full depth.
>
> **Position:** Incremental PRs.
>
> A: One bundled PR. B: Incremental PRs. C: Sequenced across PRs.

**After (plain English):**

> Before I plan the refactor itself, I need a call from you on how you
> want it broken up — that's a preference I haven't been told, and the
> three options aren't equivalent for review or rollback.
>
> **Position:** I'd lean toward B (incremental PRs). The auth surface is
> risky to land in one drop, and small PRs make rollback cheap.
>
> A. One bundled PR — fastest to merge, hardest to review and roll back.
> B. Incremental PRs (3-4) — slower to merge, much easier review and
> rollback. My recommendation.
> C. Sequenced across PRs (each depends on the prior) — clean history,
> but blocks parallel review.
>
> Which decomposition shape do you want?

## Acceptance Criteria

A response satisfies this style guide when ALL of the following hold:

1. **No leakage.** No cell from the left column of any Translation Table
   section appears in user-facing prose. If `Bootstrap`, `Router`, `C1`,
   `T3`, `coordination` (as a label, not as plain prose use of the word),
   `must-ask`, `AUQ_PROCEED`, or any other internal label appears
   verbatim in prose the user sees → the response fails this guide.
2. **Public patterns OK.** Public Cognitive Pattern markers
   (`**Position:**`, "Forced Alternatives", "Inversion check", "Premise
   Challenge") MAY appear and are encouraged where they apply.
3. **Plain-English reasoning.** Reasoning paragraphs name what's actually
   being weighed in plain English (e.g., "named participants and
   downstream sequencing" instead of "coordination signal fires").
4. **Translated silent logs.** Silent-log entries surfaced in prose use
   the User-facing surfacing format from
   `references/pipeline/silent-log.md` § User-facing surfacing, not the
   bracketed audit format.
5. **Depth via shape, not labels.** AUQ depth (`must-ask` / `likely-ask`
   / `could-skip`) is conveyed by the shape of the AUQ — full vs brief
   vs minimal — not by labeling the depth.

A reviewer can apply this checklist by reading any user-visible response
end-to-end and grepping for the terms in the left column. Each match is
a violation.
