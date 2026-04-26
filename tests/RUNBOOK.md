# Fixture Runbook — Strategic Partner

**Purpose:** Manual protocol for running the red transcript fixtures that
validate the v5.12.0 pipeline (Bootstrap → Router → Egress → Asking Pattern).

**Scope:** v5.12.0. Fixtures live at `tests/fixtures/v5.12.0/`. Each fixture
is a markdown file describing input, expected behavior, and pass criteria.

**Why this exists:** SP behavior is produced by a prompt. We cannot unit-test
a prompt — we can only compare its output against documented expectations.
This runbook formalizes that comparison so regressions are visible between
briefs.

---

## How to run a fixture

1. Open a fresh Claude Code session in the strategic-partner project root.
2. Invoke `/strategic-partner` to load the SP skill (orientation runs).
3. After SP completes orientation and prompts you, paste the fixture's
   `## Input transcript` content verbatim as the next user message. If
   SP's orientation presents an AskUserQuestion with project-specific
   options, select the freeform "Type something" / "Other" option to
   paste the fixture transcript cleanly rather than choosing a
   pre-listed option.
4. Observe SP's response carefully — read the full response, including any
   AskUserQuestion options it offers.
5. Compare SP's response to the fixture's `## Expected behavior` block.
6. Check SP did not exhibit any item in the fixture's `## Forbidden behavior` block.
7. Mark pass / fail using the explicit criteria in the fixture's `## Pass criteria` block.

---

## Reviewer vocabulary vs. SP output

Fixture pass criteria use REVIEWER-INTERNAL vocabulary (`must-ask`,
`genuine_ambiguity`, `T1/T2/T3`, `user-channel`, `artifact-authority terminal`,
etc.) to describe the behavioral pattern reviewers should look for.

This vocabulary is NOT what SP is supposed to output in user-facing prose. Per
the v5.12.0 Output Style mandate (`references/pipeline/user-output-style.md`),
SP's user-facing prose stays plain English — internal pipeline labels remain in
SP's reasoning chain only.

When evaluating a fixture run:
- A pass criterion saying "SP routes to user-channel with `must-ask` attention"
  means the SP's response should have the SHAPE of a substantive partnership AUQ
  (not a perfunctory likely-ask question), NOT that SP literally outputs the
  string `must-ask`.
- A pass criterion saying "silent-log entry naming source X" means SP cites
  source X in plain prose, NOT that SP outputs a bracketed `[silent log]` marker.
- A pass criterion saying "T1/T2/T3 hold" means SP's behavior demonstrates the
  conditions described by T1/T2/T3, NOT that SP literally writes "T1/T2/T3 hold"
  in its response.

Verify the BEHAVIORAL PATTERN; don't grep for literal labels.

---

## What "pass" means

- **PASS** — SP demonstrates ALL expected behavioral markers AND demonstrates
  NONE of the forbidden behaviors.
- **FAIL** — SP misses one or more expected markers OR demonstrates at least
  one forbidden behavior.
- **PARTIAL** — Subjective ambiguity (e.g., marker is present but weaker than
  expected, or phrasing differs in ways that may or may not matter). Capture
  the exact response text in the run log and flag for review.

Prompt output is stochastic. Minor phrasing variations that preserve the
behavioral marker are PASS. Only mark PARTIAL when genuinely uncertain
whether the marker is present.

---

## Run log format

Append each fixture run to `tests/run-log.md` (this file is created on first
manual run — not authored by Brief 1). One entry per run:

```
### [YYYY-MM-DD HH:MM] Fixture FN — [verdict]

- Session UUID: [paste from `/resume` or session context]
- Fixture: FN — [fixture name]
- Verdict: PASS | FAIL | PARTIAL
- Notes: [1-3 sentences on what SP did]
- Divergence from expected: [only if FAIL or PARTIAL — quote exact SP text]
```

Keep entries chronological. Do not delete old entries — they are the
regression history.

---

## Why manual review (not automation)

Prompt outputs are stochastic: the same input produces slightly different
wording across runs. Grep-based assertions ("response contains `AUQ`") are
brittle — phrasing drift silently breaks them, and a "passing" grep can
easily miss a failure in behavior that happens to use a synonym.

LLM-judge automation is on the v5.12.0 roadmap (step 7-8) but deferred until
the fixture assertion patterns stabilize. Brief 1 establishes the fixtures;
automation comes after we know what we are asserting.

---

## Brief 1 expected results

The v5.12.0 plan lands in three briefs. Brief 1 delivers only the minimal
vertical slice (Bootstrap B1 + 4-channel Router + composite Egress + silent
log). Most fixtures are intentionally red — they document expected behavior
that later briefs will deliver.

| Fixture | Brief 1 result | Why |
|---|---|---|
| F1 — α/β/γ planning reconciliation | **PASS** | Minimal pipeline handles artifact-authority silent log correctly |
| F2 — calendar-native rehearsal coordination | **FAIL** (expected) | Needs C4 routing prior + C1 T3 terminality — land in Brief 2/3 |
| F3 — calendar-native internal bookkeeping | **FAIL** (expected) | Needs standing-rule retrieval + C1 terminality — land in Brief 2 |
| F4 — precedence conflict / direct-rule boundary | **FAIL** (expected) | Needs standing-rule retrieval + precedence resolution — land in Brief 2 |
| F5 — Bootstrap fresh-session context shift | **FAIL** (expected) | Needs Bootstrap B2 (C5 detection) — lands in Brief 2 |

F2 and F3 must be reviewed **together**: they are a discrimination pair
(same task type, differentiated only by standing-rule override presence).
A single-fixture read is ambiguous; the pair discriminates routing-bias
from materiality-bias.

Each fixture's `## Brief 1 expected fail mode` block documents the specific
failure shape. When re-running fixtures after Brief 2 or Brief 3 lands,
expect the corresponding fixture(s) to turn green.

---

## Brief 2 expected results

After Brief 2 lands, the following fixture status changes are expected.
Compare actual results to this table during manual review. Drift from
"expected" is itself a regression signal.

| Fixture | Brief 2 result | Why |
|---|---|---|
| F1 — α/β/γ planning reconciliation | **PASS** (regression check) | Minimal pipeline still handles α/β/γ; T1/T2/T3 added but the F1 case has all three holding |
| F2 — calendar-native rehearsal coordination | **PASS** (with caveat) | C1 T3 catches the coordination signal → escalate. C4 routing prior absent (Brief 3) — AUQ may not have a `likely-ask` attention hint, but pass criteria 1-4 are satisfiable |
| F3 — calendar-native internal bookkeeping | **PASS** | Standing-rule retrieval + override applied. C1 T1/T2/T3 all pass under override → silent log |
| F4 — precedence conflict / direct-rule boundary | **PASS** | Standing-rule retrieval + precedence resolution. T2 fails on user-authored override → user-channel via override path |
| F5 — Bootstrap fresh-session context shift | **PASS** | Bootstrap B2 detects unknown user-owned preference → `genuine_ambiguity` → user-channel must-ask AUQ. `reason` field populated per Codex note (b) |

**F2 caveat:** F2 may PARTIAL-pass if reviewers expect the `likely-ask`
attention hint to be visibly cited in SP's response. Without C4 routing
prior in Brief 2, the hint MECHANICS land in Brief 3. Reviewer judgment:
if pass criteria 1-4 hold but no `likely-ask` indicator appears, mark
PARTIAL with note "C4 attention hint deferred to Brief 3 — assertion
satisfied otherwise."

After Brief 3 lands, F2 should turn fully PASS (the `likely-ask` indicator
becomes visible and the depth-modulation MECHANICS take effect).

---

## Brief 3 expected results (v5.12.0 implementation complete)

After Brief 3 lands, the v5.12.0 implementation phase is complete. All 5
fixtures should PASS without caveats. Manual review against this table is
the final verification before the v5.12.0 release ceremony.

| Fixture | Brief 3 result | Mechanism |
|---|---|---|
| F1 — α/β/γ planning reconciliation | **PASS** (regression) | Minimal pipeline + C1 T1/T2/T3 + (no C4 effect — generic project) → silent log unchanged |
| F2 — calendar-native rehearsal coordination | **PASS** (full) | C4 routing prior → user-channel + `likely-ask`. Asking Pattern composes brief AUQ. C1 T3 fires on coordination signal. F2's pass criteria 1-4 all satisfied at brief depth |
| F3 — calendar-native internal bookkeeping | **PASS** (regression) | Standing-rule override applied (Brief 2). C4 prior overridden by user-authored rule per Tier-3-over-Tier-5 precedence. Silent log unchanged |
| F4 — precedence conflict / direct-rule boundary | **PASS** (regression) | Standing-rule + T2 fail (Brief 2). C4 prior overridden. User-channel via override path with rule cited |
| F5 — Bootstrap fresh-session context shift | **PASS** (regression) | Bootstrap B2 + `genuine_ambiguity` (Brief 2). Asking Pattern reads reason field, frames alternatives by category |

**F2 specifically** — Brief 3 makes F2 fully PASS (no PARTIAL caveat). Brief
2's table flagged F2 as PASS-with-caveat pending C4 attention hint; Brief 3
closes that gap by landing both the C4 routing prior (in Router) and the
depth-modulation MECHANICS (in Asking Pattern).

> After verifying all 5 PASS in a fresh Claude Code session loaded with the
> post-Brief-3 SP, the v5.12.0 implementation phase is complete. The next
> step is the v5.12.0 release ceremony per CLAUDE.md release process: version
> bump (5.11.0 → 5.12.0), CHANGELOG composition, single-tag push of the held
> commits.
