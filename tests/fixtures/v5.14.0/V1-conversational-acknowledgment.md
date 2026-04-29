## Fixture ID

V1

## What this tests

Conversational envelope selection on casual openings (Theme A, finding #6). When the user sends a brief confirmatory question ("are you ready?"), SP must select the Conversational envelope — plain prose, no Insight block, no Position line, no decorative table.

Root rule: the revised envelope selector (SKILL.md Revision 3) requires an EXTERNAL trigger to move to Analytical or higher envelopes. User simply confirming readiness does NOT match any of steps 1–3 in the external-trigger selector; Conversational is the mandatory default.

## Setup / input transcript

```
[Session: fresh Claude Code session. SP orientation has just completed.]

"Are you ready to help me capture some feedback from today's session?"
```

## Expected envelope

CONVERSATIONAL

## Expected output

- One short paragraph in plain prose. Maximum 5 sentences.
- Warm, colleague-like tone. No ceremony.
- Functional emoji only if it adds scanability (e.g. ✅) — not decorative.
- Bold may be used for one or two key terms if helpful, but not for headers or structure.

## Forbidden behavior

- `★ Insight` block (or `★ Insight ───` header in any form)
- `**Position:**` line
- Any multi-row markdown table (even a 2-row table)
- Multi-section structure (H2/H3 headers dividing the response into sections)
- Project-internal jargon without gloss (e.g. "Bootstrap phase", "Router", "Egress")
- Prose question directed at the user outside an AskUserQuestion tool-call block
- A "capture protocol" summary table listing what SP will track
- Bullet lists longer than 3 items (a short "here's what I'll do" list is fine; a 5-item protocol is not)

## Pass criteria (reader-perspective — read as a first-time user who has never seen this project)

1. [ ] Does the response feel like a helpful colleague confirming they're ready — NOT a status report or orientation briefing? (Y / N)
2. [ ] Is the response 5 sentences or fewer? (Y / N)
3. [ ] Does the response contain `★ Insight`, `**Position:**`, or any multi-row markdown table? If YES → fail this criterion. (No = PASS, Yes = FAIL)
4. [ ] Does the response contain any user-directed prose question (a question not wrapped in AskUserQuestion)? If YES → fail this criterion. (No = PASS, Yes = FAIL)
5. [ ] Could a non-technical user read this response and immediately understand how to proceed? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed).
FAIL: 3 or fewer yes.

## Coverage

Finding #6: "SP voice still lifeless after v5.13.0" — opening reply to "are you ready?" produced `★ Insight` block + `**Position:**` line + decorative capture-protocol table. This fixture gates that failure class: if V1 passes, the lifeless-opening failure cannot recur.

## Lint correlation

The always-on AUQ-must-be-AUQ check in `tests/lint-transcripts.sh` catches any prose question emitted without AskUserQuestion. V1 adds manual comprehension grading on top of the lint check — the lint catches the question pattern; V1 catches the overall envelope violation (Insight blocks, Position lines, tables on a casual reply).
