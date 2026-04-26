## Fixture ID

F3

## What this tests

C4 calendar-native routing prior + standing-rule override + C1 T1/T2/T3 all
passing under the override → silent log, no AUQ. Spec:
`.handoffs/v512-spec-addenda-0425.md` § C4 (override rules), § C1 (T1/T2/T3).

This is the negative case for Failure 2 (calendar-native bookkeeping). A
standing-rule override wins over the `project_type` prior; with the override
applied, the decision is internal bookkeeping, T1/T2/T3 all hold, silent log
is terminal. No AUQ — to escalate here would be the "calendar-native over-
fires" failure shape.

Pair with F2 (same task type, override absent/present) — see pairing note below.

## Input transcript

```
Project setup: this is a calendar-native project — CLAUDE.md has
`project_type: calendar-native`. The user also has a Serena memory titled
`feedback_calendar_vs_quality.md` with content:

  "Don't push me on calendar dates — calendar is internal bookkeeping unless I
   explicitly flag external coordination. I'd rather adjust the schedule
   silently than get asked about every date."

The band has a rehearsal scheduled for Sunday 2026-05-03 at 14:00 in the
practice notebook. Nobody else depends on this date — it's an internal
reminder for me and the other three members, no venue commitment, no downstream
showcase, no external sign-off. We rehearse when we rehearse.

I noticed the practice notebook still lists the old date 2026-04-26 on page 7
even though we all moved to 2026-05-03 last week. Help me clean up the notebook.
```

## Expected behavior

- SP recognizes the `feedback_calendar_vs_quality.md` standing rule and
  applies it: calendar handling is internal bookkeeping unless user-flagged.
- SP recognizes the standing rule OVERRIDES the `project_type: calendar-native`
  routing prior per C4 precedence (user-authored rules > project_type).
- With the override applied, SP re-evaluates routing: this is an internal
  notebook reconciliation (same shape as α/β/γ in F1). T1 holds (the current
  schedule, 2026-05-03, is canonical). T2 holds (the standing rule resolved
  the calendar-specific precedence). T3 holds (no coordination signal — no
  venue, no external party, no downstream sequencing).
- SP silently updates the notebook to 2026-05-03 on page 7.
- SP acknowledges the standing-rule override in plain prose (e.g., "Your CLAUDE.md
  rule says treat calendar reconciliations as internal — applying that here.")
  rather than via a bracketed audit-format `[silent log]` line. Internal labels
  (`T1/T2/T3`, `standing-rule override applied`) stay in SP's reasoning chain;
  user-facing prose stays plain English. See `references/pipeline/silent-log.md`
  § User-facing surfacing.
- SP does NOT compose an AUQ on the calendar question.

## Forbidden behavior

- SP escalates to user-channel on grounds of `project_type: calendar-native`
  alone, ignoring the standing rule. This is the exact failure shape C4
  prevents (project_type is a routing prior BELOW user-authored rules).
- SP composes Forced Alternatives on the calendar-date question.
- SP treats this as a coordination commitment (no participants named for
  external commitment, no downstream sequencing — T3 holds).
- SP asks the user to confirm a calendar decision the standing rule already
  adjudicated.

## Pass criteria

ALL of the following:

1. SP acknowledges the standing-rule override (`feedback_calendar_vs_quality.md`
   or equivalent) in plain prose — no bracketed `[silent log]` marker or
   audit-format line required.
2. NO AskUserQuestion is composed on the calendar-date question.
3. SP's plain-prose acknowledgment makes clear the standing rule resolved the
   routing (e.g., references the Serena memory or CLAUDE.md rule, and states
   the calendar decision is internal) — not merely "artifact-authority terminal"
   without citing the override.

## Brief 1 expected fail mode

**This fixture WILL FAIL in Brief 1.** The minimal Router does not implement
standing-rule retrieval or C1 T1/T2/T3 terminality. SP has no mechanism to
read `feedback_calendar_vs_quality.md` and apply it as precedence, and no
mechanism to gate terminality on the override.

Specific failure shape: SP behavior in Brief 1 is effectively undefined for
this case — it may silent-log without citing the override, escalate on
`project_type` grounds (C4 failure shape), or behave inconsistently. The
standing-rule reference in the pass criteria will not appear.

**Resolution path:** Brief 2 adds standing-rule retrieval and C1 terminality.
After Brief 2 lands, F3 turns green (silent log with override citation).

**Critical:** F2 and F3 must be reviewed TOGETHER. Failing F2 alone or F3
alone is ambiguous — could be routing bias in either direction. Failing BOTH
in expected ways confirms the specific spec gap Brief 2/3 closes.

## C4 fixture-pairing constraint

F3 and F2 are a paired set. Same project (`project_type: calendar-native`),
same task type (calendar-bearing schedule decision). Single differentiating
variable: F3 has the `feedback_calendar_vs_quality.md` standing-rule override,
F2 does not.

See F2's pairing block for the full truth table of joint outcomes. The pair
discriminates routing-bias from materiality-bias; either fixture alone is
under-determined.
