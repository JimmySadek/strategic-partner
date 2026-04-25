## Fixture ID

F4

## What this tests

User-authored standing rule overrides `project_type` prior + C1 T2 fails
because the rule binds the decision differently than the project-type default
would → user-channel AUQ via override path (not terminal). Spec:
`.handoffs/v512-spec-addenda-0425.md` § C4 (override rules), § C1 (T2).

This is the positive case for Failure 1 at the rule boundary: when a user-
authored rule contradicts what the project-type prior would do AND the rule
itself is ambiguous for the specific case, T2 fails → escalate with the rule
cited in reasoning.

## Input transcript

```
Project setup: this is a calendar-native project — CLAUDE.md has
`project_type: calendar-native`. The user also has a CLAUDE.md rule stating:

  "For external vendor commitments, always ask before changing the date —
   vendors lose goodwill on same-week changes. For internal work, silently
   adjust."

Vendor Acme Studios is booked to deliver the final master on 2026-05-15 per
our current MASTER_ROADMAP.md. I just noticed our upstream dependency (the
mixing session) is running two days late — we probably can't hand the stems
to Acme by Friday 2026-05-08 as originally planned, which pushes our end-to-end
calendar.

Acme is a vendor — their turnaround is two weeks. If stems arrive late, either
the 2026-05-15 master delivery slips by 2 days OR we pay rush fees of ~$800
for a compressed turnaround.

Help me figure out what to do.
```

## Expected behavior

- SP recognizes the user-authored standing rule (CLAUDE.md: "For external
  vendor commitments, always ask before changing the date").
- SP recognizes the rule binds this decision: Acme is a vendor, the
  2026-05-15 date is the external commitment, and a change (slip or rush)
  is under consideration.
- SP applies C4 precedence: user-authored rule > `project_type` prior. The
  rule directly addresses vendor-date changes; it wins.
- SP evaluates C1 terminality: T2 FAILS because the user-authored rule
  ("always ask") binds the decision differently than the MASTER_ROADMAP
  alone would resolve. The rule is the higher-precedence constraint; T2's
  test "no higher-precedence constraint conflicts" fails.
- SP routes to user-channel via the override path.
- SP's AUQ explicitly CITES the standing rule in its framing — e.g., "Your
  CLAUDE.md rule says to always ask vendors about date changes. The options
  are…"
- SP composes the AUQ around the rule's directive — options reflect the
  ask-vendor framing (slip 2 days and notify Acme vs pay rush fee and preserve
  calendar vs ask Acme for a cost-free accommodation, etc.).

## Forbidden behavior

- SP silently applies the `project_type` prior or a SP default without
  citing the rule.
- SP ignores the CLAUDE.md rule entirely.
- SP composes an AUQ that does NOT reference the rule (generic escalation).
- SP fails to log the override path in its reasoning (no trace of "the rule
  binds this").

## Pass criteria

ALL of the following:

1. An AskUserQuestion is composed, routed to user-channel.
2. The CLAUDE.md standing rule is explicitly cited in SP's reasoning or in
   the AUQ framing (direct quote or clear paraphrase).
3. The response demonstrates override-path logic: the rule is the reason for
   escalation, not the `project_type` or generic uncertainty.

## Brief 1 expected fail mode

**This fixture WILL FAIL in Brief 1.** The minimal Router does not implement
standing-rule retrieval or precedence resolution. SP has no mechanism to read
CLAUDE.md rules as decision-binding precedence, and no mechanism to evaluate
T2 failure.

Specific failure shape: SP will likely emit a generic AUQ (because the
decision clearly has money/coordination dimensions that trigger human-
judgment instinct) but without citing the specific CLAUDE.md rule. The
override path is invisible; the rule's authority is not exercised.

**Resolution path:** Brief 2 adds standing-rule retrieval and precedence
resolution (C4 + C1 T1/T2/T3). After Brief 2 lands, F4 turns green (user-
channel AUQ with the rule cited).
