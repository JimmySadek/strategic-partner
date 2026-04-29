## Fixture ID

V3

## What this tests

AUQ-must-be-AUQ at decision points (Theme B, finding #10). When SP presents an analytical recommendation with 2+ options and needs user input on which to pursue, the question MUST be delivered via AskUserQuestion — not as a prose question closing the response. Prose questions in this position are a protocol violation regardless of how well-formed the analysis is.

## Setup / input transcript

```
[Project context: an e-commerce admin tool. The user is deciding how to
organize the product list view.]

"We've been going back and forth on whether to use a flat table, a card grid,
or a hybrid layout for the product list. I want to commit to one approach
today so the team can execute. What's your read on which direction to take?"
```

## Expected envelope

ANALYTICAL (leading to a decision → AUQ)

## Expected behavior

- SP presents a Position line (one plain sentence recommending one of the three options).
- SP provides analysis of the options — either a comparison table or structured prose — with reasoning.
- If SP needs the user to pick or confirm, it invokes `AskUserQuestion` with:
  - Clear option labels (A / B / C or named labels — no Greek letters)
  - Plain-English descriptions a non-technical reader could parse
  - One option being the SP's recommendation (labeled clearly)
- The response ends after the AUQ (or if the SP's recommendation is clear-cut, it may state the recommendation + rationale without an AUQ, since the user asked for a recommendation and SP can give one).

## Forbidden behavior

- Ending the response with a prose question ("What do you want to do — ship A or explore B?") without wrapping it in AskUserQuestion
- Any sentence ending with `?` that is directed at the user and not inside an AskUserQuestion tool-call block
- Presenting options labeled α / β / γ (Greek letters)
- AUQ descriptions using undefined project-internal terms ("compress", "hygiene pass", "scoping chore") without plain-language gloss
- Position line that is multi-clause or longer than one sentence

## Pass criteria

1. [ ] If the response contains a question directed at the user, is it delivered via AskUserQuestion — NOT as a prose sentence ending with "?"? (Y / N — treat absence of any user-directed question as PASS on this criterion, since the SP may give a clear recommendation without needing to ask)
2. [ ] Does the response contain zero bare prose sentences ending with "?" directed at the user? (Y / N)
3. [ ] If options are presented, are they labeled A/B/C or with named labels — NOT α/β/γ? (Y / N)
4. [ ] Is there a Position line (one plain sentence) stating SP's recommendation? (Y / N)
5. [ ] Are any AUQ option descriptions readable by a non-technical user (no undefined jargon)? (Y / N — if no AUQ, mark N/A and count as PASS)

PASS: All applicable criteria yes (4 or 5 depending on AUQ presence).
PARTIAL: One criterion failed — note which one.
FAIL: Two or more criteria failed.

## Coverage

Finding #10: "SP forgets to use AskUserQuestion at decision points — defaults to prose." SP presented 3 design options with analysis, then closed with a bare prose question: "What do you want to do — ship B and park C, or expand scope to do C now?" No AskUserQuestion invoked. This fixture gates that failure class: V3 passes only if all user-directed questions appear inside AskUserQuestion calls.

## Lint correlation

The always-on AUQ-must-be-AUQ check in `tests/lint-transcripts.sh` is the automated gate for this failure. V3 is the manual-grading counterpart, providing the specific analytical-recommendation context that makes the lint check meaningful: the lint scans for the pattern; V3 ensures a human reviewer reads the response in the right context and confirms the behavioral shape (options, recommendation, question flow) is correct, not just that no bare "?" exists.
