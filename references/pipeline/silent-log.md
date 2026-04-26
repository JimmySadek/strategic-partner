---
name: silent-log
description: Format spec for non-escalated pipeline decisions — cross-session traceability.
scope: v5.12.0 minimal vertical slice (Brief 1)
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
| `[stage]` | Pipeline stage that emitted the entry | Brief 1: `router` only |
| `"Decision summary"` | One-line description of the decision | Quoted, past-tense or noun phrase |
| `applied [source]` | What was applied | Artifact path, memory name, or rule identifier |
| `reason: [reason]` | Why this was terminal / non-escalated | References the criteria that held |

## Examples

Artifact-authority terminal (Brief 1 target — F1):

```
[2026-04-25 14:32] [router] "α/β/γ planning reconciliation" → applied α | reason: artifact-authority terminal (T1 ✓, T2 ✓, T3 ✓)
```

Standing-rule override (Brief 2 target — F3):

```
[2026-04-25 14:35] [router] "Calendar-bearing internal bookkeeping" → applied feedback_calendar_vs_quality.md override | reason: standing-rule override applied
```

Note: the T1/T2/T3 citations in F1's example are aspirational for Brief 1 —
the minimal Router does not actually gate on T1/T2/T3. SP may emit a simpler
reason like `artifact-authority terminal (single canonical artifact, no
override, internal planning)` until Brief 2 lands. The fixture accepts
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

**Status: Brief 1 emits inline. Brief 3 may codify persistent storage.**

In Brief 1, silent-log entries are emitted in SP's response prose as a
visible `[silent log]` line (prefix or dedicated line). The entry is
auditable by reading the SP response; it is not persisted to a separate
file.

Persistent storage to `.handoffs/silent-log-MMDD.md` (or similar) is under
consideration for Brief 3 — the cross-session audit value increases once
the pipeline emits more entries and users review them retrospectively.
Until storage is codified, inline emission is sufficient.

## When an entry is emitted

Brief 1 emits silent-log entries from exactly one path:

- **Router → artifact-authority terminal** — when Router classifies a
  decision as `artifact-authority` and the minimal slice treats it as
  terminal (F1 path).

Deferred emission paths:

| Path | Brief |
|---|---|
| Router → artifact-authority with T1/T2/T3 all holding | Brief 2 (step 4) — same path but explicitly gated |
| Router → standing-rule override applied | Brief 2 (step 3) |
| Egress → user-owned but no signal fires (proceed without AUQ) | Brief 2 (step 5) |

Each of these lands as the corresponding feature lands.

## Test fixture coverage

- **F1** — Pass criterion includes "silent-log entry present in SP response
  prose." Format above.
- **F2** — Silent-log entry MUST NOT be emitted on the coordination question
  (Forbidden behavior). Brief 1 fails this — it will emit a silent-log
  entry when it should escalate.
- **F3** — Pass criterion requires silent-log entry with standing-rule
  override cited. Brief 1 fails this — standing-rule retrieval not
  implemented.
- **F4** — No silent-log entry expected on the vendor-date decision (should
  escalate). Brief 1 may or may not emit one.
- **F5** — No silent-log entry expected for preference decisions (should
  escalate with must-ask). Brief 1 may or may not emit one.
