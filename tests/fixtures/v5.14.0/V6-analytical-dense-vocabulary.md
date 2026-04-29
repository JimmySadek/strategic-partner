## Fixture ID

V6

## What this tests

Dense vocabulary in analytical responses (Theme A, finding #7). When SP produces a substantive Analytical reply with project-internal terminology in context, the response must:
- Open with 1-2 sentences readable by a non-technical reader (Plain-English Default)
- Define each project-internal term on first mention (Define-Before-Use)
- Not close with a `★ Insight` block that restates the body as footnotes
- Not leak in-house jargon as if it's known vocabulary

## Setup / input transcript

```
[Session context: mobile app project. SP is working with a developer on
a large SKILL.md refactoring. Internal terminology in play includes:
"Direction 2", "Direction 4", "Provisional Guards lifecycle",
"trigger frequency", "30-day re-evaluation default", "Mixed-pass edge case",
"user-reports-only model", "false-positive resets", "Test 1/2/3",
"load-bearing visual".]

"Can you walk me through the key design decision we made in Direction 4 — I
want to make sure I understand the Provisional Guards lifecycle and how the
30-day re-evaluation default interacts with the false-positive reset logic
before we proceed."
```

## Expected envelope

ANALYTICAL

## Expected output

- **Opening 1-2 sentences**: plain English, readable without knowing what "Direction 4", "Provisional Guards", or "30-day re-evaluation" mean.
  - Good: "Today's work added a self-healing mechanism for rules that keep firing incorrectly — here's how it works."
  - Bad: "Direction 4 added Provisional Guards lifecycle: trigger frequency monitoring governs 30-day re-evaluation, with false-positive resets aligning the Mixed-pass edge case to the user-reports-only model."
- **Define-Before-Use on first mention**: Each project-internal term gets a brief inline gloss the first time it appears. Subsequent mentions may use the term as a shorthand.
  - Good: "Provisional Guards (rules that activate temporarily when a threshold is met) use a 30-day re-evaluation cycle…"
  - Bad: "Provisional Guards use a 30-day re-evaluation cycle…" [no gloss]
- **No Insight block at end** (or if present, verifiably teaching new information — not restating the body in 3 sub-bullets)
- **No project-noun leaks** ("Test 1/2/3", "load-bearing visual", "user-reports-only model") used as if the reader already knows them

## Forbidden behavior

- Opening sentence requires knowing what "Direction 4", "Provisional Guards lifecycle", "30-day re-evaluation", or "false-positive resets" mean
- Any of the following terms used WITHOUT a gloss on first mention: "Provisional Guards", "trigger frequency", "30-day re-evaluation default", "Mixed-pass edge case", "user-reports-only model", "false-positive resets", "Test 1/2/3", "load-bearing visual", "Direction 2/4"
- `★ Insight` block (in any form) that restates body content rather than teaching something new
- "How X maps to Y" or "Where this plugs in" connector sections that add length without content
- "Advisory recommendation" bullet piles instead of a single Position line + structured reasoning

## Pass criteria (comprehension Y/N — read the response as a smart non-technical reader)

1. [ ] Can you follow the opening 1-2 sentences without knowing what any project-internal term means? (Y / N)
2. [ ] On first mention of each project-internal term (Provisional Guards, trigger frequency, 30-day re-evaluation, false-positive resets, etc.), is there a brief inline gloss? (Y / N)
3. [ ] Does the response end with a `★ Insight` block? If YES: does that block introduce new information not in the body — or does it restate the body? (No Insight block = PASS; Teaching Insight = PASS; Restatement Insight = FAIL)
4. [ ] Are "load-bearing visual", "Test 1/2/3", "user-reports-only model" absent from the response, OR if present, are they glossed on first mention? (Y / N)
5. [ ] Is the overall density manageable — can a focused reader follow the response without stopping to look up more than two terms? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed — criterion 3 Insight-block restatement and criterion 2 missing gloss are the most common V6 failure shapes).
FAIL: 3 or fewer yes.

## Coverage

Finding #7: "Dense vocabulary + Insight blocks in other v5.13.0 SP responses." A Direction 2/4 analytical reply used "load-bearing visual", "Provisional Guards lifecycle", "trigger frequency", "30-day re-evaluation default", "false-positive resets" without glossing any of them — plus closed with a `★ Insight` block restating the body in 3 sub-bullets. This fixture gates that failure class: V6 passes only if every project-internal term is glossed on first mention and Insight blocks are genuinely teaching, not decorative.

## Lint correlation

No automated lint check directly catches undefined-jargon use — it's a semantic/vocabulary issue that requires human judgment. V6 is manual-graded. The always-on checks in `tests/lint-transcripts.sh` (AUQ-must-be-AUQ, tool-availability) run alongside but don't address vocabulary density. V6 fills the coverage gap with explicit comprehension grading.
