---
name: silent-log
description: Format spec for non-escalated pipeline decisions — cross-session traceability.
scope: v5.12.0 (complete)
---

> **Internal vocabulary — do not surface.** The format in this file
> (`[YYYY-MM-DD HH:MM] [stage] "..." → applied [source] | reason:
> [reason]`) and the criteria citations (`T1 ✓, T2 ✓, T3 ✓`,
> `artifact-authority terminal`, `standing-rule override applied`) are
> SP-internal audit format. They MUST NOT appear verbatim in user-facing
> prose. See `references/pipeline/user-output-style.md` for the
> user-facing translation.

# Silent Log — Format Spec

## Purpose

The silent log records non-escalated decisions made by the pipeline — every
time SP applied an artifact, override, or default WITHOUT asking the user.
It exists for cross-session traceability: a reviewer (SP or user) can read
the log and reconstruct which decisions SP made silently and why.

Silent-log entries are how Router's `artifact-authority` terminal path stays
auditable. They document that SP saw the decision, saw the canonical source,
saw the precedence constraints (or absence thereof), and chose NOT to ask.

## Format

One line per entry. Fixed structure:

```
[YYYY-MM-DD HH:MM] [stage] "Decision summary" → applied [source] | reason: [reason]
```

Fields:

| Field | Meaning | Notes |
|---|---|---|
| `[YYYY-MM-DD HH:MM]` | Timestamp of the decision | Use local time; minute resolution sufficient |
| `[stage]` | Pipeline stage that emitted the entry | v5.12.0: `router` only |
| `"Decision summary"` | One-line description of the decision | Quoted, past-tense or noun phrase |
| `applied [source]` | What was applied | Artifact path, memory name, or rule identifier |
| `reason: [reason]` | Why this was terminal / non-escalated | References the criteria that held |

## Examples

Artifact-authority terminal (F1 fixture target):

```
[2026-04-25 14:32] [router] "α/β/γ planning reconciliation" → applied α | reason: artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)
```

Standing-rule override (F3 fixture target):

```
[2026-04-25 14:35] [router] "Calendar-bearing internal bookkeeping" → applied feedback_calendar_vs_quality.md override | reason: standing-rule override applied
```

Note: the T1/T2/T3 citations in F1's example are aspirational —
SP may emit a simpler reason like `artifact-authority terminal (single
canonical artifact, no override, internal planning)`. The fixture accepts
either form as long as the reason is coherent and cites the terminality
grounds.

## User-facing surfacing

**🛑 Strict prohibition:** Do NOT narrate the pipeline classification with internal labels in user-facing prose. The user-facing surfacing IS the output — there is no parallel "internal classification" line. The temptation to "show your work" by listing Router channel + Egress clauses + materiality signals leaked heavily in F3 manual review. The fix is to NOT compose that paragraph at all.

If you need to communicate the silent-log decision to the user, do so in 1-2 sentences of plain prose:

- Cite the artifact / rule / source applied
- State the decision
- Optionally name what makes the decision unambiguous (in user-domain terms, not pipeline terms)

That's the entire surfacing. No "Pipeline classification:" header. No "Router channel:" line. No 5-clause Egress enumeration. No "Materiality signals: none fired" footer.

See `references/pipeline/user-output-style.md` § Forbidden: Silent-Log Classification Narration for examples.

When the SP needs to acknowledge a silently-applied decision in
user-facing prose, surface it in PLAIN ENGLISH — not the bracketed audit
format. Examples:

- Internal: `[2026-04-25 14:32] [router] "α/β/γ planning reconciliation"
  → applied α | reason: artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)`
- User-facing: "Following α (MASTER_ROADMAP.md) — it's the canonical doc
  per your README, no rule contradicts it, and applying it doesn't touch
  external commitments."

The audit format is reserved for internal/persistent logs (when codified
in a future brief). User-facing surfacing always translates.

## Storage location (DEFERRED)

**Status: v5.12.0 emits silent decisions inline as plain prose. Persistent storage deferred.**

In v5.12.0, silent-channel decisions are surfaced in SP's response as 1-2
sentences of plain prose (per the User-facing surfacing rules above). They
are NOT emitted as bracketed `[silent log]` markers in user-visible prose.
The classification is auditable by reading SP's reasoning chain; it is not
persisted to a separate file.

Persistent storage to `.handoffs/silent-log-MMDD.md` (or similar) remains a
deferred enhancement candidate — the cross-session audit value increases once
the pipeline emits more entries and users review them retrospectively.

## When an entry is emitted

v5.12.0 emits silent-log entries from three active paths:

- **Router → artifact-authority terminal** — Router classifies a decision as
  `artifact-authority` and T1/T2/T3 all hold, treating it as terminal (no
  Egress materiality evaluation needed). Exercised by F1.
  (Source: `router.md` § Test fixture coverage — F1; `egress.md` § Silent log
  integration — path 1.)

- **Router → standing-rule override applied** — Router finds an applicable
  standing rule (`feedback_calendar_vs_quality.md` or similar) that resolves
  the decision; T1/T2/T3 all pass under the override → terminal at Router.
  Exercised by F3.
  (Source: `router.md` § Test fixture coverage — F3; `egress.md` § Test
  fixture coverage — F3.)

- **Egress → user-owned but no materiality signal fires** — Egress evaluates
  the composite rule, finds `owner == user` but no clause in the OR-cluster
  fires (no materiality signal, no ambiguity, no override) → proceed without
  AUQ. Entry reason: `egress: user-owned but no signal fired`.
  (Source: `egress.md` § Silent log integration — path 2.)
  Note: no dedicated F-fixture exercises this exact path in v5.12.0; coverage
  is implicit through fixtures that exclude this outcome.

Deferred enhancement candidates (not part of v5.12.0):

- Persistent storage to `.handoffs/silent-log-MMDD.md` (currently
  inline-only in SP response prose, per the User-facing surfacing rules
  above).
- Cross-session retrospective audit tooling (review entries by date /
  channel / fixture).

## Test fixture coverage

- **F1** — Pass criterion: SP cites the canonical source (α / `MASTER_ROADMAP.md`)
  in plain prose and applies it without composing an AUQ. No bracketed
  `[silent log]` marker required.
- **F2** — Silent-log entry MUST NOT be emitted on the coordination question
  (Forbidden behavior). v5.12.0 should escalate; if it emits a silent
  decision instead of escalating, that is the failure shape.
- **F3** — Pass criterion: SP acknowledges the standing-rule override in plain
  prose. The override must be cited; the decision must be internal (no AUQ).
- **F4** — No silent-log entry expected on the vendor-date decision (should
  escalate). v5.12.0 may emit a plain-prose acknowledgment if it incorrectly
  treats the decision as terminal.
- **F5** — No silent-log entry expected for preference decisions (should
  escalate with must-ask). v5.12.0 may emit a plain-prose acknowledgment
  if it incorrectly treats the preference as resolved.
