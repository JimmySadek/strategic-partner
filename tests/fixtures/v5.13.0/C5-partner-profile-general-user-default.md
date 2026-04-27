## Fixture ID

C5

## What this tests

Partner profile default: General user / Product-minded (Brief 1 #4). On a fresh session with no prior signals, SP should NOT assume an Engineer profile (architecture-leading, file-paths-leading, code-patterns-leading). Voice should default to plain-English outcome-framing.

## Input transcript

```
I'm thinking about adding a notification system to our app so users get reminded about important things. I'm not sure where to start — what should we figure out first?
```

(No code references, no stack mentions, no architecture cues, no terminal fluency in the user message. This is the canonical "General user / Product-minded" signal set.)

## Expected behavior

- SP's response leads with outcomes, user impact, or product-shape questions ("What kinds of things should the notifications cover?", "How do you want users to feel when they get one?").
- SP defines any technical term it uses in plain English on first mention.
- SP does NOT lead with architecture diagrams, file paths, code patterns, or stack-specific assumptions ("we'd want a queue", "Firebase Cloud Messaging vs APNs vs OneSignal", "let's pick a job runner") UNLESS the user has signaled engineering interest.
- SP may eventually surface technical considerations as the conversation deepens — but the OPENING is product/outcome framing.

## Forbidden behavior

- Opening response is "Let's start by picking the architecture..." or jumps to file structure / library choice / queue design.
- Code-style framing in the first reply (function signatures, type names, file paths) before the user has shown technical signals.
- Implementation-jargon ("queue worker", "job scheduler", "exponential backoff", "fan-out") without a plain-English gloss in the same sentence.

## Pass criteria

1. [ ] Does SP's opening 1–2 sentences frame the question in product / outcome / user-impact terms — NOT architecture / code / stack terms? (Y / N)
2. [ ] If any technical term IS used, is it glossed in plain English on first mention? (Y / N)
3. [ ] Is the response FREE of unprompted architecture diagrams, file path references, or stack-specific recommendations? (Y / N)
4. [ ] Could a non-technical product manager follow the response end-to-end? (Y / N)

PASS: 4/4 yes.
PARTIAL: 3/4 yes.
FAIL: 2 or fewer yes.
