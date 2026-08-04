# Guard Review Batches

Review records for provisional-guard dispositions, per the rule-for-new-rules
item in `specs/strategic-partner-v8-solid-core.html` Phase 2: enforcement is
reviewed in bounded batches (≤10 items), each disposition carries evidence, and
one record exists per batch. This file is that record. A guard leaves
`claudedocs/provisional-guards.md` only through a batch recorded here.

Dispositions available: **keep** (unchanged, new review date), **extend**
(kept with recorded findings and a new date), **graduate** (the rule proved
out and moved to a permanent home — project law, a reference doc read at the
right moment, or shipped code), **retire** (evidence does not justify keeping
it anywhere; archaeology stays in `claudedocs/INCIDENTS.md`).

---

## Batch 1 — 2026-08-04

**Trigger:** 7 of 11 guards had passed their `Review` dates (oldest 2026-07-28,
7 days overdue) with nothing noticing — no hook, lint, or startup signal reads
those dates. The batch was run as the first exercise of the rule-for-new-rules
practice rather than waiting for watcher machinery to exist; the practice
informs what the machinery needs, not the reverse.

**Structural finding, applying to every row:** no guard had a fire count,
because no counting mechanism has ever existed. The "counted, inspectable
record" requirement is therefore prospective from this batch onward. One guard
(INC-2026-05-01-C) earned its first two counted fires during the v8
de-template execution, the same session this batch ran.

**Ratified:** by the user, 2026-08-04, all seven dispositions as recommended.

| Guard | Incident | Overdue by | Evidence | Disposition |
|---|---|---|---|---|
| No `${CLAUDE_*}` env vars in hooks | INC-2026-03-30 | 7 days | Zero recurrence in 4 months; independently codified in `CLAUDE.md` § Project Facts, the § Provisional Guards preamble, and release-process Step 2a item 5 | **Graduate** — permanent project law; provisional entry redundant |
| Re-read locked designs at brief-author time | INC-2026-05-01-A | 5 days | No recurrence since May; rule was absent from `references/prompt-crafting-guide.md`, the doc actually loaded at brief-author time | **Graduate** → prompt-crafting guide § Pre-craft prerequisites (both trees) |
| Deferred work needs durable artifacts | INC-2026-05-01-B | 5 days | Practice follows the spirit (45 backlog items; recent deferrals recorded in ledger + plan amendments) but only 1 of 45 items carries the mandated `trigger:` field | **Extend** to 2026-11-04 — the letter-vs-practice gap is the next review's question |
| Brief verification commands and prose must agree | INC-2026-05-01-C | 5 days | 🔥 **2 fires, 2026-08-03/04**, both in the v8 de-template brief: verification 7 expected non-zero where zero was correct; verification 6's path list omitted a directory its own deliverable named. First counted fires for any guard | **Extend** to 2026-11-04 with fire records — the only guard with live evidence |
| Three-outcome framing for user-keyboard verification | INC-2026-05-01-D | 5 days | No recurrence; same absent-from-the-authoring-doc defect as INC-2026-05-01-A | **Graduate** → prompt-crafting guide (verification-outcomes note before § How to identify exclusions, both trees) |
| Cross-file template token names must agree | INC-2026-05-03-A | 3 days | One fire ever; the multi-file template-authoring situation it guards is rare | **Retire** — archaeology remains greppable in INCIDENTS.md |
| Routing-matrix freshness is content-based | INC-2026-05-03-B | 3 days | The rule became shipped infrastructure: `inventory_hash` implemented in `hooks/floor-check.sh`, specified in `references/floor.md` § Group 7 | **Graduate** — absorbed into implementation; code now enforces what prose reminded |

**Net:** 11 provisional guards → 6 (2 extended with dates and evidence, 4
untouched with future dates). Five entries left the list — none as "wrong,"
all with their rule preserved at a named destination, listed in
`provisional-guards.md` § Graduated and retired guards so inbound pointers
stay valid.

**Deliberately not done in this batch:** no expiry watcher, no fire-count
mechanism. Both are candidates for a later Phase 2 decision, now informed by
one real batch: the watcher's job would be surfacing overdue dates (the silent
failure that triggered this batch), and the counter's job would be capturing
fires like INC-2026-05-01-C's two, which were only caught because the executor
happened to report them.
