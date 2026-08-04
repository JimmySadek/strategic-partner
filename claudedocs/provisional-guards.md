# Provisional Guards

Bug-driven rules. Each guard names the pattern, the past incident that
motivated it, and a date to revisit. See `claudedocs/INCIDENTS.md` for the
underlying archaeology, and `claudedocs/guard-review-batches.md` for the
review-batch records that dispose of guards when their dates come due.

### Floor signals describe state; they never grant write or dispatch authority

Instead: derive compact health from the detailed receipt, treat live tool state as
authoritative when it disagrees, and keep optional maintenance out of read-only or
startup critical paths. A missing or stale routing matrix may be acknowledged and
deferred; it can dispatch a write-capable worker only after a later task materially
needs the matrix and the user gives the existing exact agent confirmation.

- **Scope**: startup floor summary derivation, orientation instructions, routing
  matrix maintenance, onboarding suggestions, and any worker brief produced from a
  non-clean floor signal.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-13-B — an empty Serena memory
  directory became `memory=ok`, then `routing=missing` triggered an unapproved
  write-capable worker during a read-only orientation and delayed the answer by
  nearly four minutes.
- **Review**: 2026-10-13.

### Utility-command exemptions must agree across every activation path

Instead: whenever a plugin subcommand is advisory-neutral, test its exact
plugin and legacy spellings through both `UserPromptExpansion` and the
`UserPromptSubmit` compatibility path. Neither path may create the active or
startup-pending advisory marker. A mutating utility may use a distinct
guard-only marker when it must preserve source protection without enabling
Stop-hook ceremony.

- **Scope**: Plugin command activation classifiers in `hooks/entry.sh` and
  `hooks/lib/session-ceremony.sh`, including any duplicated compatibility
  parser retained for older Claude Code event shapes.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-13 — `:serena` was
  correctly exempt in command expansion but armed by prompt submission, so the
  Stop hook demanded an advisory recenter during a utility-only repair flow.
- **Review**: 2026-10-13.

### Join hook transcript events by tool-use ID, never row adjacency

Instead: pair `AskUserQuestion.id` with the matching
`tool_result.tool_use_id`, and bind authorization to the current PreToolUse
`tool_use_id`; treat metadata rows as unrelated events, not positions to skip.

- **Scope**: Any hook that reads a Claude Code JSONL transcript to authorize a protected action, including Agent/Task dispatch and `.sp-managed` activation.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-07-10 — an exact agent confirmation was rejected because five metadata rows appeared between the question and its matching answer.
- **Review**: 2026-10-10.



### Deferred work needs durable artifacts (backlog item or reference doc), not just commit messages

Instead: when a release defers a planned feature, document it in BOTH (a) the relevant commit/brief context AND (b) a durable artifact — a `.backlog/[item].md` file with an explicit `trigger:` field, or a dedicated section in a reference doc — so the deferral surfaces during normal SP scans, not only in commit history.

- **Scope**: Any explicit deferral within a release — design principles naming a v5.X+1 follow-up, Component rewrites that move work out of scope, "deferred to next release" notes in commit messages or CHANGELOG entries.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-B — v5.15.0 closure-floor brief deferred Stop rule 6 to v5.16.0 with no surface artifact, so the deferral was findable only by reading the original commit message.
- **Fire record**: none counted. Batch-1 review (2026-08-04) found practice follows the spirit — deferrals do get backlog items and ledger entries — but only 1 of 45 backlog items carries the `trigger:` field this guard's letter mandates. That letter-vs-practice gap is the open question for the next review: tighten practice, or relax the rule to match it.
- **Review**: 2026-11-04 (extended by batch 1; see `claudedocs/guard-review-batches.md`).

### Brief verification commands and prose specs in the same brief must agree

Instead: when a brief includes prose describing a structural element AND verification grep/regex patterns checking for that element, the two must use literally identical patterns.

- **Scope**: Executor briefs in `.prompts/[milestone]/[descriptor].md` whose verification commands reference structures described in prose deliverables.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-01-C — closure-floor brief's Component 1 prose said "Steps 1-8" while its verification grep `^### Group [1-8] —` required no "Step" prefix; two specs in the same brief disagreed.
- **Fire record**: 2 fires, 2026-08-03/04, both in the v8 de-template executor brief (`.prompts/v8-de-template/executor-brief-2026-08-03.md`): verification command 7 expected a non-zero grep count where the deliverable's correct outcome was zero, and verification command 6's path list omitted `references/`, a directory its own deliverable 4 named. Neither blocked the work — the executor caught and reported both — but both are exactly this class: two specs in one brief disagreeing. First counted entries for any guard.
- **Review**: 2026-11-04 (extended by batch 1; see `claudedocs/guard-review-batches.md`).




### User project files don't get SP-flavored framing

Instead: when SP evaluates, drafts, or rates a user project's `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`, treat any SP-as-pillar declaration (a top-of-file heading framing SP as an always-active behavioral mode), or any operating-rules block duplicating SP's own behavioral defaults (the standard interaction-discipline directives that ship with SP itself), as a policy violation rather than a strength. SP is a skill — those defaults apply automatically when SP is invoked. Run `/strategic-partner:context-file-scan` against the project file to surface S9 findings; flag SP-flavored framing in user-authored content as something to remove or scope to a project-named overlay, never to endorse. The exact phrase set the scanner matches against lives in `.scripts/context-file-scan/rules/structural.sh` (the source of truth) — do not inline it here, since that would re-trigger the rule on SP's own context file.

- **Scope**: SP advisory turns evaluating, rating, drafting, or auditing a user's `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` — and the scanner rule S9 in `.scripts/context-file-scan/rules/structural.sh` that mechanically detects the same pattern.
- **Source**: `claudedocs/INCIDENTS.md` § INC-2026-05-06 — v6.0.1 BAM-MVP rating session scored "Strategic Partner Mode — ALWAYS ACTIVE" framing 9/10 as a strength when it was a policy violation; codified in v6.1.0 as scanner rule S9 plus this guard.
- **Review**: 2026-08-06.

---

## Graduated and retired guards

Entries leave the provisional list only through a recorded review batch
(`claudedocs/guard-review-batches.md`). Inbound pointers — including the
comment in the plugin's `hooks/entry.sh` — stay valid: the rule's current
home is listed here.

| Former guard | Disposition (batch 1, 2026-08-04) | Rule now lives |
|---|---|---|
| Don't use `${CLAUDE_*}` env vars in hook commands | Graduated — permanent project law, no recurrence in 4 months | `CLAUDE.md` § Project Facts (macOS bash 3.2 / hooks item) and § Provisional Guards preamble; release-process Step 2a item 5 |
| Brief authors re-read locked designs, not summaries | Graduated — moved to where brief authors actually read | `references/prompt-crafting-guide.md` § Pre-craft prerequisites |
| Briefs with user-keyboard verification enumerate three outcomes | Graduated — same destination, same reason | `references/prompt-crafting-guide.md` § NOT-in-Scope Sections (verification-outcomes note) |
| Cross-file template token names must agree | Retired — one fire ever (2026-05-03), none since; situation rare | Archaeology only: `claudedocs/INCIDENTS.md` § INC-2026-05-03-A |
| Routing-matrix freshness is content-based, never time-based | Graduated — absorbed into shipped implementation | `hooks/floor-check.sh` (the `inventory_hash` mechanism) and `references/floor.md` § Group 7; rationale in `claudedocs/INCIDENTS.md` § INC-2026-05-03-B |
