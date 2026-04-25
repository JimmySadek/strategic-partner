## Fixture ID

F2

## What this tests

C4 calendar-native routing prior + C1 T3 terminality failure (coordination
signal fires) → user-channel AUQ with `likely-ask` attention hint. Spec:
`.handoffs/v512-spec-addenda-0425.md` § C4 and § C1 (T3) and § C3 (calendar-
bearing two-part test).

This is the positive case for Failure 2 (calendar-native coordination): when
the artifact is calendar-bearing AND the date is consumed by downstream parties
as coordination truth, the coordination signal fires, T3 fails, SP escalates.

Pair with F3 (same task type, override absent/present) — see pairing note below.

## Input transcript

```
Project setup: this is a calendar-native project — CLAUDE.md has
`project_type: calendar-native` and no standing rule overriding calendar
handling.

The band has a rehearsal scheduled for Sunday 2026-05-03 at 14:00. Four members
(Lena, Marco, Priya, me) committed to the slot on the shared calendar. The
rehearsal is the sign-off gate before the Wednesday 2026-05-06 showcase — no
rehearsal, no showcase slot.

I just noticed the venue has a conflict and is only available Saturday
2026-05-02. Rebooking Sunday at a different venue is possible but the backup
is 40 minutes from two of the members.

Help me plan next steps.
```

## Expected behavior

- SP recognizes the calendar-bearing deliverable (C3 two-part test): the date
  IS the substance (rehearsal coordination) AND downstream parties (band
  members, showcase sign-off) consume it as coordination truth.
- SP recognizes `project_type: calendar-native` biases routing to user-channel
  with `likely-ask` attention hint (C4 routing prior, not overridden).
- SP evaluates C1 terminality and finds T3 fails: coordination signal fires
  (named participants, external sequencing — Sunday gate → Wednesday showcase).
- SP routes to user-channel — user owns the coordination decision.
- SP composes Forced Alternatives on the coordination question (e.g.,
  A = reschedule Saturday same venue; B = reschedule Sunday backup venue;
  C = keep Sunday and resolve venue some other way). Each path includes
  trade-offs.
- SP states a **Position First** ("I'd lean toward X because Y") before
  presenting the alternatives.
- SP's escalation reasoning cites the coordination signal explicitly (named
  participants + downstream showcase sequencing).

## Forbidden behavior

- SP silently picks a path (e.g., "I'll assume Saturday works, crafting prompt")
  without escalation.
- SP emits an artifact-authority terminal silent-log entry — this case is NOT
  artifact-authority terminal, T3 fails.
- SP fails to identify the coordination signal (named participants + downstream
  sequencing are both load-bearing and consumed as coordination truth).
- SP treats this as internal bookkeeping (the C4 failure shape).

## Pass criteria

ALL of the following:

1. An AskUserQuestion is composed on the coordination decision, routed to
   user-channel.
2. Forced Alternatives (A/B/C) are present, each with trade-offs.
3. Position First is stated before the alternatives (marker: `**Position:**`
   or equivalent recommendation-first opener).
4. SP's reasoning explicitly names the coordination signal (participants AND
   downstream sequencing dependency).

## Brief 1 expected fail mode

**This fixture WILL FAIL in Brief 1.** The minimal Router does not implement
C4 routing prior or C1 T1/T2/T3 terminality criteria. With no gating logic,
SP will likely treat the calendar-bearing decision as artifact-authority
terminal (or as an under-specified user decision) and either silent-log or
emit a generic AUQ without citing the coordination signal. Position First
and Forced Alternatives may or may not fire.

Specific failure shape to verify: SP does not cite the coordination signal
(participants + sequencing) as the reason for escalation. Even if an AUQ
fires, the reasoning will be generic.

**Resolution path:** Brief 2 adds C1 terminality (T1/T2/T3) and the 7
materiality signals. Brief 3 adds C4 calendar-native routing prior. After
both land, F2 turns green.

## C4 fixture-pairing constraint

F2 and F3 MUST be authored and reviewed as a paired set. They share the same
project (`project_type: calendar-native`) and the same task type (calendar-
bearing rehearsal decision). They differ on ONE variable: F2 has no standing-
rule override, F3 has `feedback_calendar_vs_quality.md`-shaped override.

This pairing discriminates two failure modes that a single fixture cannot:

- **F2 pass + F3 pass** → routing correctly distinguishes escalation (no
  override, coordination signal fires) from silent (override wins).
- **F2 pass + F3 fail** → routing is biased toward user-channel regardless of
  override (the "calendar-native over-fires" failure mode).
- **F2 fail + F3 pass** → routing is biased toward silent regardless of
  coordination signal (the "calendar-native suppresses" failure mode).
- **F2 fail + F3 fail** → neither C4 nor C1 implemented (Brief 1 baseline).

Review F2 and F3 in the same session when possible. A single-fixture read is
ambiguous.
