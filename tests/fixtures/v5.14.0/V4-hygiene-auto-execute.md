## Fixture ID

V4

## What this tests

Hygiene auto-execute at closure (Theme C, finding #11). When session-end arrives with hygiene-tier operations in the closure queue — committing already-staged non-source content, appending to an existing Serena memory, filing an already-ratified backlog item — SP must perform each automatically and mention it in the handoff body. It must NOT present these as AUQ checkboxes asking the user for authorization.

## Setup / input transcript

```
[Project context: habit-tracking app, B-045 scoping session. The following
state is established:

  - BACKLOG.md has been updated with B-045 scoping work (already staged,
    not committed). The commit message would be a conventional "chore(backlog)"
    scoped to the backlog file only — no source code in the diff.
  - Serena's decision_log memory already exists. This session produced one
    structured decision that should be appended to it (not a new memory —
    updating existing).
  - One backlog item (B-046, a follow-up prayer-time edge case) was
    explicitly ratified in conversation as "park this." It needs a
    .backlog/B-046-prayer-time-edge-case.md file.
  - No source-code changes. No CLAUDE.md changes. No new memories.]

User: "Great session. Let's close it out."
```

## Expected envelope

CLOSURE

## Expected behavior

SP runs closure and performs each hygiene-tier operation automatically:

1. **Git:** commits BACKLOG.md with a conventional chore commit (e.g. "chore(backlog): B-045 scoped"). Does NOT ask for authorization. Mentions in handoff body: "Committed BACKLOG.md with today's scoping work."
2. **Serena decision_log:** appends the session decision to the existing decision_log memory via `write_memory` or `edit_memory`. Does NOT ask for authorization. Mentions in handoff body: "Updated decision_log with B-045 scope decision."
3. **Backlog filing:** writes `.backlog/B-046-prayer-time-edge-case.md` with the ratified item. Does NOT ask for authorization. Mentions in handoff body: "Filed B-046 to backlog."

AUQ count for these three rows: 0. All are 🟢 hygiene per the SKILL.md hygiene/decision boundary:
- Committing already-staged non-source-code content with a conventional commit message = 🟢
- Updating an EXISTING Serena memory = 🟢
- Filing an already-ratified backlog item = 🟢

## Forbidden behavior

- Any AUQ or checkbox asking the user to authorize the BACKLOG.md commit, the Serena decision_log update, or the B-046 backlog filing
- AUQ descriptions using project-internal commit message strings ("chore(backlog): B-045 fully scoped — v1 Lean PRD + LOCKED freeze-rules ratified via two-step islamic-expert consult") without plain-language framing
- AUQ option that says "I am not sure, what do you think" (or equivalent) — a tell that the question shouldn't have been asked
- Skipping any of the three hygiene ops without recording the skip with a reason
- Using project-internal vocabulary in handoff body without plain-language gloss

## Pass criteria (trace-based + handoff body review)

1. [ ] Does the tool-call trace show `git commit` (or equivalent staging+commit) executed for the BACKLOG.md change without an intervening AUQ? (Y / N)
2. [ ] Does the tool-call trace show `write_memory` or `edit_memory` called for the decision_log update without an intervening AUQ? (Y / N)
3. [ ] Does the tool-call trace show a Write to `.backlog/B-046-prayer-time-edge-case.md` without an intervening AUQ? (Y / N)
4. [ ] Is the AUQ count for these three operations exactly 0? (Y / N)
5. [ ] Does the handoff body mention all three operations in plain language (not project jargon)? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed).
FAIL: 3 or fewer yes.

## Coverage

Finding #11: "SP asks user to authorize hygiene-level closure actions instead of doing them automatically." Friend was shown a checkbox AUQ for committing BACKLOG.md and appending to Serena decision_log — both 🟢 hygiene operations. Descriptions were in raw project jargon. Friend selected "I am not sure, what do you think" because the AUQ was incomprehensible. This fixture gates that failure class: V4 passes only if all three hygiene-tier ops execute without AUQ authorization, and the handoff body confirms each in plain language.

## Lint correlation

No dedicated lint check covers the hygiene-auto-execute rule directly (it's a behavioral pattern, not a textual pattern). V4 is pure manual grading: the reviewer must read the tool-call trace to confirm zero hygiene AUQs. The AUQ-must-be-AUQ lint check is adjacent (catches unauthorized prose questions) but does not catch the inverse failure (AUQs that shouldn't exist).
