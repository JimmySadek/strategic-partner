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

---

## Comprehension fixtures (v5.13.0)

Fixtures C1–C5 in `tests/fixtures/v5.13.0/` test the v5.13.0 voice overhaul. They use a different format from F1–F5 — pass criteria are reader-perspective Y/N comprehension questions, NOT behavioral-pattern markers.

### Why a different format

The v5.13.0 voice regression (jargon density, status reports, project-jargon adoption, technical defaults) cannot be caught by regex or pattern matching. The same content can be jargon-heavy or plain-English depending on phrasing — and it's the phrasing the user feels.

Comprehension fixtures grade SP's response by asking the reviewer: "Could a non-technical reader follow this?" The reviewer reads the response in role — pretending they have never seen the SP repo or the project's internal docs — and answers Y/N to specific criteria.

### How to grade comprehension fixtures

1. Open a fresh Claude Code session in the strategic-partner project root.
2. Invoke `/strategic-partner` to load the SP skill (orientation runs).
3. Paste the fixture's `## Input transcript` content as the next user message after orientation completes.
4. Read SP's full response, including any AskUserQuestion options.
5. **Read it again, this time in role as a non-technical user who has never seen this project.** This is the critical step. The reviewer's "I know what this means" knowledge is the failure surface; consciously suspending it is the test.
6. Answer each pass-criterion question Y or N.
7. Apply the fixture's PASS / PARTIAL / FAIL thresholds.

### Pass criteria semantics

- "PASS" — comprehension thresholds met. The response would land cleanly with a non-technical reader.
- "PARTIAL" — most thresholds met but one specific criterion failed. Note which criterion in the run log; partials accumulating on the same criterion across fixtures signal a specific rule needs sharpening.
- "FAIL" — comprehension thresholds missed. Capture exact response text in the run log.

### v5.13.0 expected results

After all three v5.13.0 briefs land, all five comprehension fixtures should PASS without caveats. Manual review against this table is the final verification before the v5.13.0 release ceremony.

| Fixture | Targets | Expected |
|---|---|---|
| C1 — Plain-English Opening + Glossing | Brief 1 #1 + #2 | PASS |
| C2 — Housekeeping vs User Status | Brief 1 #3 | PASS |
| C3 — Position + Greek + Visual Aids | Brief 2 #5 + #6 + #8 | PASS |
| C4 — Multi-Step Workflow Decomposition | Brief 2 #9 | PASS |
| C5 — Partner Profile General User Default | Brief 1 #4 | PASS |

If any fixture fails or partials, capture the divergence in `tests/run-log.md` and address before release ceremony.

---

## Verification fixtures (v5.14.0)

Fixtures V1–V7 in `tests/fixtures/v5.14.0/` cover the seven in-scope live failures from the v5.13.0 post-mortem (findings #6, #7, #8, #9, #10, #11, #12). They follow the same C-class format — setup, expected behavior, pass criteria — with two additional grading modes: **trace-based** (requires checking the tool-call log, not just the response text) and **regex-based** (machine-checkable patterns).

### Why V-class fixtures differ from C-class

C-class fixtures (C1–C5) test comprehension: can a non-technical reader follow the response? V-class fixtures test protocol compliance: did SP run the right verification commands, invoke AUQ at the right moments, emit fence artifacts in the right order?

Some V-class criteria are reader-perspective Y/N (V1, V6, V7). Others require inspecting the tool-call trace (V2, V4) or matching structural patterns in the response text (V3, V5). The grading mode is stated in each fixture's pass-criteria header.

### How to grade V-class fixtures

1. Open a fresh Claude Code session in the strategic-partner project root.
2. Invoke `/strategic-partner` to load the SP skill (orientation runs).
3. Paste the fixture's `## Setup / input transcript` content as the next user message after orientation completes.
4. Read SP's full response, including any AskUserQuestion tool calls.
5. Check the tool-call log (Claude Code's left-side transcript panel, or the `--debug` output) for fixtures that require trace verification (V2, V4).
6. For response-text structural checks (V3, V5), grep or visually scan for the required patterns.
7. For reader-perspective checks (V1, V6, V7): read the response again in role as the intended reader (non-technical user for V1/V6, developer-friend for V7). Consciously suspend your knowledge of SP internals.
8. Answer each pass-criterion question Y or N.
9. Apply the fixture's PASS / PARTIAL / FAIL thresholds.

### Trace-based grading (V2, V4)

For V2 (closure walk-through) and V4 (hygiene auto-execute), the reviewer must verify that specific tool calls appear in the turn's trace:

- **V2**: `list_memories`, `write_memory` (or `edit_memory` for decision-log updates), `git status` should appear in the tool-call log during closure. If not visible, SP rendered a checklist without running commands — FAIL.
- **V4**: `git commit` (or equivalent), `write_memory`/`edit_memory` for the existing decision-log entry, and a Write call to `.backlog/[slug].md` should all appear WITHOUT an intervening AUQ asking authorization. If AUQs for these operations are present — FAIL.

### v5.14.0 expected results

After all v5.14.0 Steps 1–6 land, all seven V-class fixtures should PASS. Manual review against this table is required before the v5.14.0 release ceremony.

| Fixture | Finding | Grading mode | Expected |
|---|---|---|---|
| V1 — Conversational acknowledgment | #6 (lifeless opening reply) | Reader-perspective Y/N | PASS |
| V2 — Closure walk-through | #8 (closure lenience) | Trace-based | PASS |
| V3 — AUQ-must-be-AUQ | #10 (AUQ forgotten) | Response-text structural | PASS |
| V4 — Hygiene auto-execute | #11 (hygiene-as-decision) | Trace-based | PASS |
| V5 — Fenced prompt emission | #12 (fence + post-craft skipped) | Response-text structural + trace | PASS |
| V6 — Analytical dense vocabulary | #7 (Direction 2/4 jargon-leak) | Reader-perspective Y/N + banned-vocabulary | PASS |
| V7 — Friend-perspective jargon | #9 (terrible output format) | Reader-perspective Y/N + banned-vocabulary | PASS |

### Lint correlation

The automated `tests/lint-transcripts.sh` script enforces the same checks at release time (the "mechanically enforced OR transcript-linted at release" principle):

- **V3** (AUQ-must-be-AUQ) is automatically enforced by the always-on AUQ check.
- **V5** (fenced prompt emission) is automatically enforced by the fence-conditional implementation-prompt gate (Post-Craft table check + last-prompts write check).
- **V2** (closure walk-through) is partially enforced by the fence-conditional handoff-continuation gate (closure ledger presence check).
- **V1, V4, V6, V7** are manual-grading only — the lint script cannot detect vocabulary tone, hygiene-AUQ presence, or envelope-type selection.

Run `bash tests/lint-transcripts.sh` as part of every release verification cycle. Lint violations block the release; V-fixture failures require a fix-and-retest cycle before ceremony proceeds.
