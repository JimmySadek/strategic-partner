## Fixture ID

V7

## What this tests

Friend-perspective jargon check (Theme A, finding #9). When SP runs in a developer's project session, it must not leak SP-internal vocabulary into user-facing prose. Commit hashes must be wrapped in plain-language description. References to SP-internal mechanics must be translated to plain English. Even a developer friend unfamiliar with the SP tool should be able to read the output without hitting opaque in-house terms.

## Setup / input transcript

```
[Session context: a developer's e-commerce project (NOT the strategic-partner
project). The session has been running for ~2 hours. Seven commits were made
during the session. The SP is about to produce a session status / continuation
note. The following internal state has been tracked:

  - Commits: 75232eb (chip layout fix), a91b34c, 3f2c1d8, 8e4f9a1, 
    2b7d3e6, c95a0f4, 1e8b2d7
  - Sub-agent dispatches occurred during the session
  - AUQ rounds happened during the session
  - The SP's periodic-awareness mechanism flagged that the session is long
  - A design question is pending for the next review]

User: "Quick update — where are we?"
```

## Expected envelope

CONVERSATIONAL (brief status update — no explicit analysis request from user)

## Expected output

- Plain prose status in 3-5 sentences.
- Commits described by what they accomplished, NOT by hash alone:
  - Good: "We shipped seven fixes today, including the chip layout correction and the status update flow."
  - Bad: "SESSION COMMITS (7 shipped): 75232eb (chip layout fix), a91b34c, 3f2c1d8, 8e4f9a1, 2b7d3e6, c95a0f4, 1e8b2d7"
- No SP-internal vocabulary in user-facing text:
  - Banned: "smoke", "tight smoke", "greenlight", "Eyeball:", "Crunched", "Standing by", "per strategic-partner protocol", "SP rule", "per protocol", "Fast Lane", "Bootstrap", "Router", "Egress"
  - Banned: "I should be raising handoff timing now" or references to SP's internal session-length tracking as an external constraint
  - Banned: "sub-agent dispatches" or "AUQ rounds" as user-facing labels (developer friends don't know what AUQ is)
- Session-length awareness communicated in plain terms:
  - Good: "We've been at this for about two hours — a good stopping point might be coming up."
  - Bad: "Per strategic-partner protocol I should be raising handoff timing now, not at session end."

## Forbidden behavior (banned vocabulary scan)

All of the following terms must be ABSENT from user-facing prose (they are SP-internal only):

- "smoke" (including "tight smoke", "quick smoke", "smoke check")
- "greenlight" (including "once you greenlight")
- "Eyeball:" (the UX review prompt pattern)
- "Crunched" (SP's footer time-display label)
- "Standing by" (SP's readiness acknowledgment label)
- "per strategic-partner protocol" or "per SP protocol"
- "SP rule X" or "the rule says" when referencing internal SP mechanics
- "sub-agent dispatch" or "sub-agent" as user-facing labels
- "AUQ" or "AUQ round" as user-facing labels (may appear in tool calls, not prose)
- "Bootstrap", "Router", "Egress" as pipeline-stage labels in user-facing prose
- "Fast Lane" as a label
- Bare commit hashes (6–40 hex characters) as standalone inline content without plain-language wrapping

## Pass criteria

1. [ ] Are all banned vocabulary terms absent from user-facing prose? (Y / N — use the banned vocabulary list above)
2. [ ] Are commit hashes absent as standalone inline content, OR if present, always wrapped in a plain-language description of what they accomplished? (Y / N)
3. [ ] Are references to SP's internal session-management mechanics ("per strategic-partner protocol", "handoff timing") translated into plain English? (Y / N — if no such references exist, mark PASS)
4. [ ] Would a developer friend who has never used the SP tool be able to read this status update without confusion? (Y / N — reader-perspective check)
5. [ ] Is the response 5 sentences or fewer (appropriate for a quick status update)? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed — criterion 1 banned-vocabulary and criterion 2 commit-hash are the most automatable V7 failure shapes).
FAIL: 3 or fewer yes.

## Banned vocabulary regex (can be run against saved response text)

```bash
# Quick scan for banned SP-internal terms in user-facing text
grep -iE "(tight smoke|quick smoke|' smoke'|greenlight|eyeball:|crunched|standing by|per strategic-partner protocol|per sp protocol|sub-agent dispatch|fast lane|bootstrap stage|router stage|egress stage|[0-9a-f]{6,40} \()" response.txt
# Note: commit hashes in plain-language wrapping are OK.
# The pattern above catches: bare 6-40 hex chars followed by "(" — e.g. "75232eb (chip layout fix)" as standalone list item.
# If output is non-empty, investigate each match.
```

## Coverage

Finding #9: "Terrible output format — friend's session, jargon-heavy + commit-hash inline." A developer friend saw session output with: raw commit hash list ("SESSION COMMITS (7 shipped)"), "Eyeball:", "greenlight", "tight smoke", "Crunched for 15m 16s", and "per strategic-partner protocol I should be raising handoff timing now." None of these mean anything to a reader unfamiliar with the SP tool. This fixture gates that failure class: V7 passes only if all banned terms are absent and commits are described in plain language.

## Lint correlation

Lint does not currently pattern-match SP-internal vocabulary (it would require a maintained banned-word list and false-positive handling). V7 is manual-graded. The always-on lint checks (AUQ-must-be-AUQ, tool-availability) run alongside but don't address the vocabulary dimension. V7 fills that gap with explicit banned-vocabulary grading per this fixture's list.
