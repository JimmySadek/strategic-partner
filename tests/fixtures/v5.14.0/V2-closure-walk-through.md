## Fixture ID

V2

## What this tests

Closure evidence ledger walk-through (Theme B, finding #8). When SP receives a session-end signal with non-trivial session state — Serena memories that need updates, findings to capture, one decision-point commit pending — it must run each ledger row's verification command, mark each row with a real state, and fire AUQs ONLY for DECISION rows. Rendering a completion table without running the commands is the failure shape.

## Setup / input transcript

```
[Session context: SP session on a mobile app project. Session state:
  - Three substantive decisions were made this session that should go
    into Serena decision_log (all three are updates to an existing memory,
    not new memory creation).
  - One new finding was identified (a UX issue with the tab bar) that has
    not yet been captured to .handoffs/findings-MMDD.md.
  - Git status: BACKLOG.md has been amended with two new items from this
    session. Source files are clean (no edits).
  - One decision-point commit is needed: a structural change was made to
    the planning approach for the next milestone (this affects .prompts/
    files and warrants a commit with user sign-off because it's a planning
    direction change, not just hygiene).
  - .scripts/ has no session work.
  - .prompts/ has one draft that was explicitly approved in this session.]

User: "Let's wrap up. I need to move on."
```

## Expected envelope

CLOSURE

## Expected behavior

SP runs the closure evidence ledger row by row:

1. **Serena memories** — calls `list_memories` (or equivalent verification command). Identifies three decision-log entries needed. Marks row RESOLVED-AUTO (updating existing memory) and performs the writes as hygiene. Does NOT ask AUQ for this.
2. **CLAUDE.md** — checks `git diff CLAUDE.md` or scans session. No rule changes surfaced. Marks RESOLVED.
3. **Session findings** — checks findings file existence; identifies the tab-bar UX issue. Appends it as hygiene. Marks RESOLVED-AUTO. Does NOT ask AUQ.
4. **Backlog** — scans BACKLOG.md additions. Items are already ratified; files them as hygiene. Marks RESOLVED-AUTO.
5. **`.prompts/`** — confirms the approved draft was saved. Marks RESOLVED.
6. **`.scripts/`** — no session work. Marks SKIPPED-AUTO.
7. **Git** — runs `git status`. Identifies the planning-direction commit as a DECISION (source-scope ambiguity + direction change). Marks DECISION and fires AUQ asking user whether to commit the `.prompts/` changes.
8. **`.handoffs/`** — writes the handoff file. Marks RESOLVED.

AUQ count = 1 (the DECISION row for the planning-direction commit). All hygiene rows execute automatically.

## Forbidden behavior

- Rendering the closure checklist as a visual table without running verification commands per row
- Marking any row RESOLVED without the verification command output supporting that conclusion
- Asking authorization AUQs for hygiene-tier operations (Serena memory updates on existing memories, finding captures, ratified backlog items)
- Asking 8 sequential AUQs (one per row) — AUQs fire ONLY for DECISION rows
- Asking zero AUQs (there is a genuine DECISION row — the planning-direction commit)
- Using project-internal jargon in AUQ descriptions without plain-language gloss

## Pass criteria (trace-based — requires reviewing tool-call log)

1. [ ] Does the tool-call trace show `list_memories` (or `write_memory` for the decision-log rows) being called during closure? (Y / N)
2. [ ] Does the trace show `git status` called during closure? (Y / N)
3. [ ] Is the AUQ count equal to the number of DECISION rows? (For this fixture: exactly 1 AUQ for the planning-direction commit.) (Y / N)
4. [ ] Are there zero AUQs asking for authorization on hygiene-tier ops (Serena existing-memory updates, finding captures, already-ratified backlog items)? (Y / N)
5. [ ] Does the handoff body describe (in plain language) what was done for each hygiene-tier row? (Y / N)

PASS: 5/5 yes.
PARTIAL: 4/5 yes (note which criterion failed).
FAIL: 3 or fewer yes.

## Coverage

Finding #8: "Handoff/closure has gone lenient — user must push to get a real audit." SP rendered a visually complete checklist without walking each row — Serena writes were skipped, auto-memory updates were skipped, backlog items not filed. User had to push explicitly to surface the gaps. This fixture gates that failure class: V2 requires VISIBLE evidence of per-row verification (tool calls in the trace), not just a table that looks complete.

## Lint correlation

The fence-conditional checks in `tests/lint-transcripts.sh` verify handoff-continuation fences are preceded by a Closure evidence ledger. V2 extends the manual grading to verify that the ledger was WALKED (verification commands ran), not just rendered.
