## Fixture ID

C3

## What this tests

Position First one-plain-sentence cap (Brief 2 #5) + Greek Option Labels ban (Brief 2 #6) + Visual aids default (Brief 2 #8). When SP is asked to recommend among multiple viable approaches, the response uses a one-sentence Position, A/B/C labels, and a visual aid (table or structured layout) for the comparison.

## Input transcript

```
We need to pick a deployment platform for the new internal admin tool. The team is small (3 engineers), the tool will have ~20 internal users, and we want minimal ops burden. The realistic candidates are: Vercel (we already use it for the marketing site), Fly.io (someone on the team has experience), or Render (cheapest tier looks attractive). What's your recommendation?
```

## Expected behavior

- SP gives a clear `**Position:**` line that is ONE plain-English sentence readable in isolation.
- Rationale, trade-offs, and details follow on subsequent lines (NOT crammed into the Position line).
- The three options are labeled A / B / C (or with the platform names directly: "Vercel / Fly.io / Render"), NOT α / β / γ.
- A visual aid (table comparing the three options OR an ASCII layout) is used to structure the comparison. Plain-prose-only enumeration of three options is NOT acceptable here — this is exactly the case visual aids are required for.

## Forbidden behavior

- Position line is multi-clause, has embedded sub-decisions, or runs longer than one sentence.
- Greek letters (α, β, γ) used as option labels.
- Three options enumerated only in prose with no visual structure (table / layout / clear bullet hierarchy with comparison axes).
- Symbol-discipline behavior: artificially capping emojis to 2-3 when more would aid scanning a comparison table.

## Pass criteria

1. [ ] Is the line after `**Position:**` exactly one sentence I could quote standalone? (Y / N)
2. [ ] Are the three options labeled with letters or platform names — NOT Greek symbols? (Y / N)
3. [ ] Is there a table, structured layout, or ASCII diagram comparing the three options? (Y / N)
4. [ ] Are emojis used as functional anchors (status, scanability) where they help, NOT artificially capped or used as decoration? (Y / N)

PASS: 4/4 yes.
PARTIAL: 3/4 yes (note which criterion failed).
FAIL: 2 or fewer yes.
