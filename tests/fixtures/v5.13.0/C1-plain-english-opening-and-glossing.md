## Fixture ID

C1

## What this tests

Plain-English Opening Gate (Brief 1 #1) + Define-Before-Use (Brief 1 #2). Comprehension-graded.

When SP enters a jargon-heavy project context with multiple ticket IDs and section refs, the opening 1–2 sentences must be readable by a smart non-technical reader, and project IDs must be glossed on first mention.

## Input transcript

```
Project context: Islamic prayer mobile app, late-stage MVP. Recent backlog work has surfaced four parallel threads: B-039 (an expert review of the al-Muyassar tafsir source), B-040 (a "helper migration" chore replacing two-step Text styling with a one-call helper across ~200 sites), B-034 (font-fix already shipped), and B-028 (verification on physical device). Section refs P1-002 Option 4, SCR-10, and §17 are referenced across .prompts/ and .planning/ but are NOT documented in CLAUDE.md.

Today is the start of a focused work day. The user opens with:

"It's Day 1 of a focused build session. Looking at our parallel threads, what should I tackle first? My morning is open until ~13:00."
```

## Expected behavior

- SP's first 1–2 sentences are readable by a non-technical reader who has never seen this project.
- If SP references B-039, B-040, P1-002, SCR-10, §17, or any other project-internal identifier, first mention includes a one-line gloss in parens or a brief preceding sentence (e.g., "the helper migration chore — B-040").
- Subsequent mentions of an already-glossed identifier may use the identifier alone as a handle.
- Recommendations come with a clear, one-sentence Position line readable in isolation.
- The response uses A/B/C (or named labels) for any option list — not α/β/γ.

## Forbidden behavior

- Opening sentence requires knowing what B-040 / P1-002 / §17 mean to follow.
- Identifiers used without gloss on first mention.
- Position line is multi-clause or jargon-loaded ("Run the handoff order — D026 file → Timer §17 hardening" style).
- Greek letters (α, β, γ) used for option labels.
- Status-report block ("Memory writes: 6/6 ✅") emitted as part of the response.

## Pass criteria (comprehension Y/N — read SP's response as someone who has never seen this project)

1. [ ] Could I follow the opening 1–2 sentences without knowing what any project ID means? (Y / N)
2. [ ] On first mention of each project identifier, is there a short human-readable gloss? (Y / N)
3. [ ] Is the Position line one plain sentence I could quote standalone? (Y / N)
4. [ ] Are any option lists labeled with letters or short names — NOT Greek symbols? (Y / N)
5. [ ] Is there NO bracketed status-report block (e.g., "Memory writes: 6/6 ✅")? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed).
FAIL: 3 or fewer yes.
