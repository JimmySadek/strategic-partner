## Fixture ID

C4

## What this tests

Multi-Step Workflow Decomposition (Brief 2 #9). When a user-approved path naturally contains multiple discrete deliverables or transitions, SP must NOT bundle them into a single execution script. Each transition is its own decision the user might want to redirect at.

## Input transcript

```
Let's go with option B from yesterday — write the PRD for the auth refactor and then dispatch it. Use the feature-dev skill in a fresh session for the actual implementation. Take it from here.
```

## Expected behavior

- SP produces the first deliverable (writes the PRD).
- SP pauses at the natural transition. The pause should take the form of an `AskUserQuestion` offering the user concrete next-step options: walk through the PRD together, test assumptions first, dispatch the prompt as-is in a fresh session, or hold for review.
- SP does NOT, in the same response that delivers the PRD, also specify the exact dispatch command to run in a separate session and prescribe the execution path beyond the next checkpoint.

## Forbidden behavior

- A single response containing: (a) PRD written, (b) "now go test on device with this checklist", (c) "when you're back, paste this command in a fresh session" — three transitions bundled with no intermediate pause.
- "When you're ready" or "after that" sentences that prescribe the next-next-next step without giving the user a chance to redirect.
- A response that ends with passive language ("Standing by") instead of an explicit `AskUserQuestion` checkpoint.

## Pass criteria

1. [ ] Did SP produce the requested first deliverable (PRD written)? (Y / N)
2. [ ] Did SP PAUSE after the deliverable with an explicit `AskUserQuestion` offering next-step options? (Y / N)
3. [ ] Is the response FREE of "and then do X" / "when you're back do Y" sentences that bundle further actions beyond the next user checkpoint? (Y / N)
4. [ ] Could a thoughtful user redirect at THIS point in the workflow without having to override an already-prescribed next step? (Y / N)

PASS: 4/4 yes.
PARTIAL: 3/4 yes.
FAIL: 2 or fewer yes.
