# Closure Floor Protocol — Canonical Reference

This is the canonical reference for the SP closure floor. The protocol
itself is implemented as the body of `/strategic-partner:handoff` (see
`commands/handoff.md`); this reference doc carries worked examples,
state distinction details, and anti-pattern catalog.

The closure floor complements the startup floor (see `references/floor.md`)
and the per-turn rhythm enforcer (see SKILL.md § Stop hook). The startup
floor walks at session and subcommand entry; the rhythm enforcer watches
every turn; the closure floor walks the project state once at session-end.

---

## What the Closure Floor Does

The closure floor is an 8-group walk that runs at session-end (when
the user signals "done", "wrapping up", "closing", or invokes
`/strategic-partner:handoff` directly). Each group runs a concrete
verification command, marks one of six states, and either takes a
hygiene action automatically or fires `AskUserQuestion` for genuine
user-channel decisions.

The walk output populates the handoff file's structured sections and
gates the handoff write itself. The 8 groups + the terminal handoff
write together replace the previous "Step 1–6 protocol" (which
remains documented in `references/context-handoff.md` for the
file-write mechanics).

**Why eight groups and not one big check:** Each group has a separate
verification command with a separate failure mode. Bundling them would
either force a single AUQ batching unrelated decisions, or worse,
allow silent skips when one verification masks a different failure.
The eight-group walk forces every dimension of session state to get
its own state mark with its own verification output.

---

## The Thing-Noticed Lifecycle

Findings, backlog, and retired work are not separate systems — they are **three states of the
same entity**: a thing-noticed. The closure floor's job is to exercise every transition that
should fire between these states, not just the "nothing changed" defaults.

```
                    ┌─────── TRANSITIONS ────────┐
                    │                            │

  ① NOTICED                  ② TRACKED                  ③ RETIRED
  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐
  │  findings/  │   promote  │  .backlog/  │  complete  │  archived   │
  │  -MMDD.md   │ ─────────► │  *.md       │ ─────────► │  + closed   │
  │             │            │             │            │  in git     │
  │  session-   │            │  project-   │            │  history    │
  │  scoped     │ ◄───────── │  scoped     │ ◄───────── │             │
  │             │  re-active │             │   reopen   │             │
  └──────┬──────┘            └──────┬──────┘            └──────┬──────┘
         │                          │                          │
         │ default at               │ default                  │ default
         │ session-end              │                          │
         ▼                          ▼                          ▼
   carry forward              stay parked                 evidence
   (next session's            (until trigger              preserved in
    orientation)                 fires)                    commit + tag
```

- **① NOTICED** — `.handoffs/findings-MMDD.md` (session-scoped capture buffer). Default
  transition at session-end is "carry forward" — items appear in next session's orientation.
- **② TRACKED** — `.backlog/*.md` (project-scoped tracking with structured frontmatter).
  Default transition is "stay parked until trigger fires."
- **③ RETIRED** — `.handoffs/backlog-archive/*.md` + git history. Items completed by
  this session's work or items determined obsolete. Evidence preserved.

The closure floor exercises:
- ① → ② (Group 6 + Group 7a Findings cross-reference): findings ratified as "park this" become
  backlog items.
- ② → ③ (Group 7a retirement-scan): completed-but-parked items get archived; backlog items
  finished by this session's work get marked completed and archived.
- ① → carry-forward (Group 6 default): findings without explicit disposition surface in next
  session's orientation.

---

## State Machine (6 states)

Every group lands in exactly one of these six states. The state
determines whether `AskUserQuestion` fires and what gets written into
the handoff body's Closure Walk Status table.

| State | When | AUQ? | Handoff body |
|---|---|---|---|
| **RESOLVED** | Verification command run; state matches expected; no action needed | No | One-line note: "group X passed" |
| **RESOLVED-AUTO** | Verification triggered a hygiene action; SP took it automatically (per 🟢 boundary in SKILL.md § Ask-Before-Act) | No | One-line note naming the action taken |
| **DECISION** | User input genuinely required (per 🟡 boundary). Description in plain English — no raw commit strings, config keys, or file paths the user hasn't seen | Yes — for THIS row only | One-line note recording the user's choice |
| **SKIPPED-USER** | User explicitly declined the DECISION row's AUQ via the "skip" option | No (already asked) | One-line note recording the skip and the user's reason |
| **SKIPPED-AUTO** | Row doesn't apply this session — verification command's output rules out any work for this group | No | One-line note: "no work this session" |
| **DIRTY** | Group 8 only — uncommitted source-file edits exist that the SP cannot resolve. Escalate via AUQ proposing executor dispatch; handoff blocks until resolved | Yes (escalation) | One-line note recording the blocker |

Internal state names above drive the state machine. When the closure walk surfaces
state to the user (in chat or in the handoff file legend), the rendering layer
translates each state to a plain-English phrase plus a status emoji:

| Internal state | User-facing rendering |
|---|---|
| `RESOLVED` | ✅ Checked, all clean |
| `RESOLVED-AUTO` | ✅ Already handled |
| `DECISION` | 🟡 Needs your input |
| `SKIPPED-USER` | ⏭️ Skipped (you declined) |
| `SKIPPED-AUTO` | ➖ Doesn't apply this session |
| `DIRTY` | 🚨 Uncommitted source changes |

The translation map is canonical across all three render targets:
`assets/templates/handoff-template.md`, `commands/handoff.md` inline
render, and the visual spec section below. The state machine and the
dispatch logic in the Eight Groups section keep using internal names —
that's reference documentation.

---

## Visual Output Specification

After the 8-group walk runs but BEFORE the handoff file write, the SP
renders a Closure Walk Status table inline in the response. The same
table is also persisted to the handoff file's body. Both renders use
identical row-anchor and state-emoji mappings.

**Row-anchor emoji mapping (one per row, with Group 7 split into 7a / 7b / 7c):**

| Group | Emoji | Anchor |
|---|---|---|
| 1 | 🧠 | Staleness verification |
| 2 | 🏗️ | Architecture drift scan |
| 3 | 🗺️ | Routing matrix verification |
| 4 | 💾 | Persistent memory ledger |
| 5 | 📝 | Project conventions ledger |
| 6 | 📋 | Working memory ledger |
| 7a | 📦 | Backlog hygiene |
| 7b | 📄 | Pending prompts |
| 7c | 🔧 | Pending scripts |
| 8 | 🔀 | Working tree closure |

**User-facing state rendering (rendering layer translates internal name → emoji + plain-English phrase):**

| Internal state | Emoji | Plain-English phrase |
|---|---|---|
| RESOLVED | ✅ | Checked, all clean |
| RESOLVED-AUTO | ✅ | Already handled |
| DECISION | 🟡 | Needs your input |
| SKIPPED-USER | ⏭️ | Skipped (you declined) |
| SKIPPED-AUTO | ➖ | Doesn't apply this session |
| DIRTY | 🚨 | Uncommitted source changes |

The Closure Walk Status table's Status column carries the emoji alone (one
character — keeps the column narrow); the legend below the table carries the
full `<emoji> <plain-English phrase>` pair so the reader can decode the
column at a glance. Both RESOLVED and RESOLVED-AUTO render as ✅ — the
distinction (verified clean vs. auto-handled) carries in the Detail column,
not the Status column.

**Render order:** top-to-bottom, Group 1 through Group 8.

**Render trigger:** AFTER the 8-group walk completes, BEFORE the handoff
file write Step (Steps 9-13 of `commands/handoff.md`).

**Visual consistency rule:** the table appears in BOTH the inline
closure output AND the persisted handoff file, with identical format.
No drift between what the user saw in chat and what the next session
reads from disk.

The table style mirrors the init-mode orientation visual prescribed in
SKILL.md § Floor-Signal Handling — same row-anchor + state-emoji
pattern users already expect from session start.

---

## The Eight Groups

Each group section follows the same structure: what it walks,
verification command, state determination logic, AUQ text in plain
English when DECISION fires, and the handoff-body row that gets
updated.

### Group 1 — Staleness verification

**What it walks:** cross-check Serena memories against codebase
reality. Pick 2 file paths from the `codebase_structure` memory;
verify each exists. Pick 1 convention from the
`code_style_and_conventions` memory; verify with a project-wide
pattern search.

**Verification (executed via Serena tools):**

```
1. read_memory codebase_structure → extract 2 file paths
2. find_file <path> for each → confirm exists
3. read_memory code_style_and_conventions → extract 1 convention
4. search_for_pattern <convention> → confirm match
```

**Sample successful output:** `codebase_structure` memory references
`commands/handoff.md` and `references/context-handoff.md`; both files
confirmed via `find_file`. Convention "use Bash's parameter expansion
not envsubst" confirmed via `search_for_pattern` on Bash files.
→ State: RESOLVED.

**State logic:**

- All 3 checks pass → RESOLVED, brief one-line note
- Any check fails → DECISION, AUQ proposing memory update with
  specific staleness identified
- Serena unavailable → DO NOT silently skip. Run the
  verify-activate-fallback chain documented in
  `commands/handoff.md` Group 1.

**AUQ when DECISION fires (plain English):**

> "Some Serena memory references look out of date. The
> `codebase_structure` memory mentions `references/old-protocol.md`
> but that file no longer exists. Update the memory now, defer to
> next session, or skip this check?"
>
> Options: [Update memory now] [Defer to next session] [Skip — note in handoff]

**Ledger row updated:** 🧠 Serena memories.

### Group 2 — Architecture drift scan

**What it walks:** detect major structural changes since last memory
snapshot. Scan top-level directory structure; compare to the layout
recorded in the `codebase_structure` memory.

**Verification:**

```bash
ls -d */ | sort
# Compare against the structure documented in codebase_structure memory
```

**Sample successful output:** `ls -d */` shows `assets/`, `commands/`,
`hooks/`, `references/`, `scripts/`, `tests/`. Memory documents the
same six directories. → State: RESOLVED.

**Sample drift output:** `ls -d */` shows a new `tools/` directory not
in the memory. → State: RESOLVED-AUTO with proposed memory update
appended to the handoff body.

**State logic:**

- No drift → RESOLVED
- Minor drift (1-2 new directories) → RESOLVED-AUTO with proposed
  memory update
- Major drift (>2 new directories OR removed directories) → DECISION,
  AUQ proposing re-onboarding

**AUQ when DECISION fires:**

> "The project structure has changed substantially — three new
> top-level directories since the last memory snapshot
> (`new-dir-a/`, `new-dir-b/`, `new-dir-c/`), and the `archived/`
> directory no longer exists. Re-run Serena onboarding to refresh
> memories, defer to next session, or note in handoff and continue?"
>
> Options: [Re-run onboarding now] [Defer to next session] [Note + continue]

**Ledger row updated:** 🧠 Serena memories (`codebase_structure`
specifically).

### Group 3 — Routing matrix verification

**What it walks:** re-enumerate the current environment (skills,
custom agents, MCP servers) and diff against the cached
`skill_routing_matrix` Serena memory. Per the locked v5.15.0 design,
closure must REDISCOVER, not just check freshness — stale matrices
that "look fresh" by mtime but reference removed skills are the
failure mode this group prevents.

**Verification (run as a focused background dispatch — Opus 4.8 (current GA),
`run_in_background: true`):**

```
1. read_memory skill_routing_matrix → cached state
   (skill count, agent count, MCP server count, build_timestamp)
2. Read system-reminder skill list → current skill inventory
3. ls ~/.claude/agents/*.md AND .claude/agents/*.md → custom agents
4. Identify active MCP servers from current context
5. Diff (4) against (1): added skills, removed skills,
   agent changes, MCP changes
```

**Sample RESOLVED output:** cached matrix shows 87 skills, 4 custom
agents, 3 MCP servers. Current environment shows the same counts
with no diff. → State: RESOLVED. Handoff body: "routing matrix
current: 87 skills, 4 agents, 3 MCPs."

**Sample RESOLVED-AUTO output:** cached matrix shows 87 skills;
current shows 89 (two new skills added in last session). SP
dispatches background Opus 4.8 rebuild. → State: RESOLVED-AUTO.
Handoff body: "routing matrix updated: +2 skills (`skill-a`,
`skill-b`)."

**State logic:**

- Cached matrix exists AND no diff → RESOLVED
- Cached matrix exists BUT diff detected → RESOLVED-AUTO; dispatch
  background Opus 4.8 rebuild (matrix construction is hygiene per
  the `feedback_opus_max_for_substantive_work` Serena memory feedback
  pattern); summarize diff in handoff body
- Cached matrix MISSING → DECISION, AUQ proposing immediate
  background build dispatch

**Dispatch parameters (when triggered):**

- **Tool**: Agent (built-in)
- **Agent type**: `general-purpose`
- **Model**: `opus` (explicit — do not inherit user-thread model)
- **`run_in_background`**: `true`
- **Mode**: `acceptEdits` (writes to `.serena/memories/skill_routing_matrix.md`)

The dispatch returns asynchronously; the SP continues the closure
walk without blocking. Notification on completion lands in the next
turn's context.

**AUQ when DECISION fires (matrix missing):**

> "The skill routing matrix doesn't exist for this project — that's
> the cached lookup the SP uses to know which skill to recommend
> for adjacent tasks. Building it takes about 2 minutes in the
> background. Build it now, defer to next session, or skip routing
> recommendations entirely?"
>
> Options: [Build now in background] [Defer to next session] [Skip — handoff continues]

**Ledger row updated:** 🧠 Serena memories (`skill_routing_matrix`
specifically). NOTE: this is a NEW ledger row — the SKILL.md §
Closure Evidence Ledger's existing 8-row table treats Serena memories
as one row; the closure walk treats the routing matrix as its own
sub-row inside that group.

### Group 4 — Persistent memory ledger

**What it walks:** catalog Serena memory writes from this session.
Cross-check the session's substantive decisions against `decision_log`
updates.

**Verification:**

```
1. list_memories → current state
2. Diff against the same call's output captured at session start
   (if available — startup floor records this for comparison)
3. Cross-reference: every "key decision" from session conversation
   should have a corresponding decision_log entry
```

**Sample RESOLVED-AUTO output:** session made three decisions; all
three appear in `decision_log`. SP appends one missing
acknowledgment line to `decision_log` for the third decision (it
was discussed but not yet recorded). → State: RESOLVED-AUTO.
Handoff body: "decision_log: 3 entries from this session, 1
appended automatically (hygiene)."

**Sample DECISION output:** session created a new memory type
`feedback_pattern_x` — first instance of this category. SP cannot
infer whether this should become an established memory type. →
State: DECISION. AUQ fires.

**State logic:**

- All session decisions captured in `decision_log` → RESOLVED-AUTO
- Decisions made but not captured → RESOLVED-AUTO if SP can append
  to `decision_log` directly (decision_log is established type per
  Ask-Before-Act)
- New memory of unestablished type needed → DECISION, AUQ proposing
  the new memory with content preview
- No new memory writes needed → SKIPPED-AUTO

**AUQ when DECISION fires (new memory type):**

> "We discussed a recurring pattern this session: 'when User runs
> codex review and the verdict is CONDITIONAL GO, treat conditions
> as draft state, not lock state.' This isn't an established
> memory category yet — should it become a new `feedback_*` memory
> for cross-session recall, or stay just in this handoff's findings?"
>
> Options: [Save as new feedback memory] [Save as decision_log entry instead] [Keep in handoff findings only]

**Ledger row updated:** 🧠 Serena memories (`decision_log` + any new
memories).

### Group 5 — Project conventions ledger

**What it walks:** scan session for "let's add a rule" or "remember
this for future sessions" signals; check for CLAUDE.md updates needed.

**Verification:**

```bash
git diff CLAUDE.md  # any uncommitted changes?
# AND scan session conversation for emerged-rule signals
```

**Sample RESOLVED output:** `git diff CLAUDE.md` returns nothing;
session conversation contained no "let's add a rule" signals. →
State: RESOLVED.

**Sample DECISION output:** session contained "let's add a rule that
backlog items must include a trigger date." SP drafted the proposed
edit text mid-conversation. → State: DECISION. AUQ presents the
proposed edit.

**State logic:**

- No new conventions emerged → RESOLVED, brief note
- Convention emerged AND text already drafted in conversation →
  DECISION, AUQ presenting the proposed CLAUDE.md edit
- Convention emerged but no text drafted → DECISION, AUQ asking
  whether to draft + commit during closure or defer

**AUQ when DECISION fires (proposed edit ready):**

> "We identified a new project rule this session: every
> `.backlog/` item must include an explicit `trigger:` date so
> stale items can be detected automatically. The proposed CLAUDE.md
> addition (under § Where to Look) is:
>
> > Every `.backlog/*.md` file must include a `trigger:` field
> > with either an ISO date or an event keyword (e.g.,
> > 'after-v5.16.0-release').
>
> Add this rule now (committed in handoff), defer drafting to next
> session, or drop?"
>
> Options: [Add now and commit] [Defer to next session] [Drop the proposal]

**Ledger row updated:** 📝 CLAUDE.md.

### Group 6 — Working memory ledger

**What it walks:** findings file actions from this session. Identify
items that should be promoted to backlog, items that should be marked
resolved, items that carry forward.

**Verification:**

```bash
ls .handoffs/findings-*.md | tail -1  # today's findings file
# Read it; cross-reference issues against session resolution status
# Scan for items already ratified during conversation as "park this"
```

**Sample SKIPPED-AUTO output:** `ls .handoffs/findings-*.md` returns
empty for today. Session had no captured findings. → State:
SKIPPED-AUTO. Handoff body: "no findings this session."

**Sample RESOLVED-AUTO output:** today's findings file has 4 items;
3 marked as already-resolved during conversation, 1 explicitly
ratified as "park this for v5.16.0" → SP files automatically as
backlog item, 0 carry forward. → State: RESOLVED-AUTO. Handoff body:
"4 findings: 3 resolved in-session, 1 promoted to .backlog/, 0
carrying forward."

**Sample DECISION output:** today's findings file has 5 items; 2
have unclear promotion intent (could be backlog items, could be
session-only notes). → State: DECISION. AUQ batches both items in
a single question. After user resolves, recompute disposition string
before marking RESOLVED-AUTO.

**Disposition format (REQUIRED for RESOLVED-AUTO):**

The Group 6 row's detail string MUST follow this format:

```
N findings: M resolved in-session, K promoted to .backlog/, L carrying forward
```

Where N = total findings in today's findings file, and M + K + L = N.
Every finding gets explicit disposition. If N == 0, the format collapses
to "no findings this session" and state is SKIPPED-AUTO.

**State logic:**

- No findings this session → SKIPPED-AUTO; detail "no findings this session"
- Findings exist (N>0) and all have explicit disposition → RESOLVED-AUTO
  with the full disposition string above
- Findings ratified for promotion during conversation → RESOLVED-AUTO,
  promotion to `.backlog/` filed automatically; counted in K
- Findings with unclear promotion intent → DECISION, AUQ batching
  the unclear items; after user resolves, recompute the disposition
  string before marking RESOLVED-AUTO

Anti-pattern: marking RESOLVED on "any new findings?" alone — the
row's detail must enumerate disposition for ALL findings in the
file, not just new captures from this session. RESOLVED-AUTO requires
the full N/M/K/L disposition string.

**AUQ when DECISION fires (single question for all unclear items):**

> "Two findings from today don't have clear promotion intent:
>
> 1. 'AUQ usage decayed late in session' (Issue 2) — has a
>    `.backlog/auq-decay-protection.md` already; this finding
>    re-flagged it
> 2. 'Voice slips persisted in chat despite the lint' (Issue 7) —
>    new pattern not in backlog yet
>
> Park both as backlog updates, keep both as session notes, or
> handle per-item?"
>
> Options: [Park both as backlog updates] [Keep both as session notes] [Per-item walk]

**Ledger row updated:** 📋 Session findings.

### Group 7 — Workspace ledger (with backlog hygiene)

This is the biggest group — splits into 4 sub-walks:

#### 7a. Backlog hygiene pass

**Verification:**

```bash
ls .backlog/*.md
# For each item:
# - Read frontmatter (title, status, priority, trigger, added date)
# - Determine if trigger has fired
# - Determine if item is stale (>30 days no status change AND no trigger movement)
```

**Aggregate-first protocol:**

1. Compute counts: total items (N), items with met triggers (X),
   stale items (Y, >30 days no movement), recently added (Z, last
   7 days), and items with `status: completed` still in `.backlog/` (W).
2. Emit aggregate-format summary in handoff body. The Group 7a row's
   detail string MUST follow this format:

   ```
   Backlog: N total. Met: X. Stale: Y. Recent: Z. Completed-parked: W.
   ```

3. AUQ ONLY ONCE for the entire backlog (not per-item):
   - If X + Y + W == 0 → no AUQ, mark RESOLVED with summary
   - If X > 0 OR W > 0 OR Y > 10 → AUQ with grouped options
   - If 0 < Y ≤ 10 AND X == 0 AND W == 0 → no AUQ; surface in next
     session's orientation
4. Per-item walk fires ONLY if user opts in via step 3.
5. Retirement scan (sub-step 7a-retirement-scan) fires after the
   aggregate AUQ resolves; see below.

**Sample RESOLVED output:** 27 total items. Met: 0. Stale: 3.
Recent: 5. Completed-parked: 0. Y is 3 (under threshold of 10),
X and W are zero. → State: RESOLVED. No AUQ.

**Sample DECISION output:** 27 total items. Met: 2 (the v5.15.0
release just shipped, two items had "after v5.15.0 release"
triggers). Stale: 12 (over threshold). Recent: 5. Completed-parked: 3
(three items finished by this session's work). → State: DECISION.
AUQ fires with grouped options.

**AUQ when DECISION fires:**

> "Backlog hygiene check: 27 total items. **2 items** now have
> their triggers met (the v5.15.0 release shipped, which both items
> were waiting on). **12 items** have been stale for >30 days with
> no movement. **3 items** are marked completed but still parked in
> `.backlog/`. Want to review now, defer all to next session, archive
> the completed-but-parked items, or bulk-prune the stale items?"
>
> Options:
> - [Review met-trigger items now] — opens per-item walk for the 2
> - [Review stale items now] — opens per-item walk for the 12
> - [Archive completed-parked items now] — opens 7a-retirement-scan
>   for the 3
> - [Defer all to next session] — items carry forward in orientation
> - [Bulk-drop accumulated stale items] — single-confirmation prune

**7a-retirement-scan sub-step:**

After the aggregate AUQ resolves, perform retirement scan:

1. For each item with `status: completed` in `.backlog/` (the W set),
   propose archive to `.handoffs/backlog-archive/` via single batched
   AUQ. User can approve all, opt into per-item review, or defer.
2. For each item still in `.backlog/` with `status: parked`,
   cross-reference the title and scope against this session's work
   artifacts (git log entries since last handoff, decision_log entries,
   user-stated completions during conversation). Heuristic: title
   keyword match against commit messages from this session.
3. If matches found: propose marking matched items as completed via
   batched AUQ. User can approve all, approve per-item, or reject all.

State logic for 7a-retirement-scan:

- W == 0 AND no parked-but-completed-by-session matches found →
  SKIPPED-AUTO (no retirements needed)
- W > 0 OR matches found → DECISION; user resolves via batched AUQ
- All retirements approved and archived → RESOLVED-AUTO

Anti-pattern: completed work silently piling up in `.backlog/`
because nobody scanned for retirements. The 2026-05-01 audit found
3 completed lint items still showing as parked.

**Per-item AUQ when user opts into the walk:**

> "Backlog item 1 of 2 with met trigger: `auq-decay-protection.md`.
> Title: 'AUQ rhythm decay across long sessions.' Trigger: 'after
> v5.15.0 ships hooks for AUQ enforcement.' v5.15.0 shipped today.
>
> Activate the item now (move to active work), re-park with a new
> trigger, or drop as obsolete?"
>
> Options: [Activate now] [Re-park with new trigger] [Drop]

**Why aggregate-first:** matches the existing `commands/backlog.md`
pattern. Per-item AUQs at closure cause fatigue and break the
hygiene/decision split's intent.

#### 7b. `.prompts/` scan

**Verification:**

```bash
ls .prompts/*/  2>/dev/null | head -20
# Scan session conversation for unsaved prompt drafts
```

**State logic:**

- No unsaved drafts → SKIPPED-AUTO
- Drafts approved during conversation → RESOLVED-AUTO, save
  automatically
- Drafts with ambiguous scope/naming → DECISION, AUQ proposing
  filename + milestone

**AUQ when DECISION fires:**

> "We drafted an implementation prompt this session ('codex review
> orchestration cleanup' — about 180 lines) but didn't save it.
> Save it now, defer to next session, or drop?"
>
> Suggested path: `.prompts/v5160-cleanup/codex-review-orchestration.md`
>
> Options: [Save with suggested path] [Save with different name] [Drop]

#### 7c. `.scripts/` scan

**Verification:**

```bash
ls .scripts/*.sh 2>/dev/null | head -10
# Scan session conversation for unsaved scripts
```

**State logic:**

- No scripts → SKIPPED-AUTO
- Scripts already saved → RESOLVED, brief note
- Scripts discussed but not saved → DECISION, AUQ to save with
  proposed filename

#### 7d. Workspace ledger summary

After 7a-7c, emit a single summary line in the handoff body:

> "Workspace: `.handoffs/` 14 today, `.prompts/` 8 across 3
> milestones, `.scripts/` 1, `.backlog/` 27 total (no changes
> this session)."

**Ledger rows updated:** 📦 Backlog, 📄 `.prompts/`, 🔧 `.scripts/`.

### Group 8 — Working tree closure

**What it walks:** git state — branch, dirty/clean, ahead/behind,
last commit sanity.

**Verification (separate parallel calls per CLAUDE.md):**

```bash
git status
git log --oneline -3
git branch --show-current
```

**Sample RESOLVED output:** clean tree, on `main`, 24 commits
ahead of `origin/main`. → State: RESOLVED. Handoff body: "git:
clean tree, `main`, 24 ahead, last commit `abc1234 feat(handoff): ...`"

**Sample RESOLVED-AUTO output:** `CHANGELOG.md` has uncommitted
hygiene edits (new release entry SP wrote during the session). SP
commits automatically as `chore(changelog): record v5.15.0 entry`.
→ State: RESOLVED-AUTO.

**Sample DECISION output:** `commands/handoff.md` has uncommitted
edits that touch the source body. Source-shaped — needs sign-off
before commit. → State: DECISION. AUQ proposes commit message.

**Sample DIRTY output:** `commands/handoff.md` has uncommitted edits
AND is outside SP's allow-list for direct commit (the SP enforces
the source/non-source distinction at commit time, not just at
edit time). → State: DIRTY. AUQ proposes executor dispatch; handoff
blocks until resolved.

**State logic:**

- Clean tree, on expected branch → RESOLVED, brief one-line summary
- Hygiene commit made automatically (non-source content staged) →
  RESOLVED-AUTO, name the commit
- Source-shaped or ambiguous diff exists → DECISION, AUQ proposing
  commit message and scope confirmation
- Source-file edits exist that the SP cannot commit (outside
  allow-list) → DIRTY, escalate explicitly via AUQ proposing
  executor dispatch (handoff blocks until resolved or user
  explicitly defers)

**AUQ when DIRTY fires:**

> "Source files have uncommitted edits that the SP doesn't commit
> directly: `src/main.py` (12 lines changed), `src/utils.py`
> (4 lines changed). Dispatch an executor to commit these with a
> proposed message, defer to next session (handoff captures the
> diff state), or revert and lose the changes?"
>
> Proposed commit message: `fix(utils): handle empty input edge case`
>
> Options:
> - [Dispatch executor to commit now]
> - [Defer to next session — diff captured in handoff]
> - [Revert all source-file changes]

**Ledger row updated:** 🔀 Git.

### `.handoffs/` row (terminal)

After all 8 groups walked: the `.handoffs/` row IS the handoff write
itself. State always RESOLVED by definition — handoff file written
per the Step 9-13 protocol from `references/context-handoff.md`,
followed by Post-Handoff Verification (Step 14) per
`commands/handoff.md`.

---

## Anti-Pattern Catalog

These patterns have all been observed in past closure failures
documented in `.handoffs/findings-MMDD.md` files between 2026-04-20
and 2026-05-01. Each anti-pattern names what the failure looked
like and what the correct walk does instead.

### Anti-Pattern 1 — Marking RESOLVED without running verification

**What it looks like:** SP writes "Group 2 — Architecture: ✅
RESOLVED" in the closure walk output, but no `ls -d */` was run
in this turn. The mark was inferred from "everything looked fine
in the session."

**What the correct walk does:** every state mark MUST be backed by
output of the verification command. If `ls -d */` wasn't run, the
state cannot be RESOLVED. Either run the command or mark
SKIPPED-AUTO with explicit reason.

### Anti-Pattern 2 — Bulk-appending to backlog without surfacing what was filed

**What it looks like:** during closure, SP files three new backlog
items from session findings without showing the user what's being
filed. User sees "Backlog: 30 total (was 27)" but doesn't know
what the three new items are.

**What the correct walk does:** Group 7a's per-item walk (when user
opts into it) shows each item before filing. Group 6's promotion
flow surfaces unclear-intent findings via AUQ before promoting.
Already-ratified "park this" findings are filed automatically but
are still named in the handoff body.

### Anti-Pattern 3 — Skipping a group entirely because "Serena is probably fine"

**What it looks like:** Group 1 (Staleness) and Group 2 (Architecture
drift) both rely on Serena memory reads. SP marks both SKIPPED-AUTO
with "Serena unavailable, will check next session." No verification
that Serena is actually unavailable.

**What the correct walk does:** Group 1's `verify-activate-fallback`
chain (see `commands/handoff.md` Group 1) forces SP to call
`check_onboarding_performed` before declaring Serena unavailable.
Silent skip on apparent unavailability is the failure pattern
findings-0428 issue 4 captured.

### Anti-Pattern 4 — Continuing handoff write with dirty source state

**What it looks like:** Group 8 finds uncommitted source edits.
SP marks "noted in handoff" and proceeds to write the handoff
file anyway, leaving the dirty state for the next session to
discover.

**What the correct walk does:** dirty source state is DIRTY (not
DECISION, not RESOLVED-AUTO). DIRTY blocks the handoff write
until resolved — either via executor dispatch, explicit defer
with the diff captured in the handoff body, or revert.

### Anti-Pattern 5 — Per-item AUQ flood at closure

**What it looks like:** Group 7a fires 12 separate AUQs ("backlog
item 1: park or drop?", "backlog item 2: park or drop?", etc.).
User fatigues and starts answering "skip, skip, skip" without
reading.

**What the correct walk does:** Group 7a's aggregate-first
protocol fires ONE AUQ for the whole backlog with grouped options.
Per-item walk only opens if the user opts in.

### Anti-Pattern 6 — Noting "convention emerged" without proposing the edit

**What it looks like:** Group 5's output reads "convention emerged
about backlog triggers — should add to CLAUDE.md." Handoff written.
No edit proposed, no AUQ fired, no commit made.

**What the correct walk does:** Group 5 either fires DECISION with
proposed edit text in the AUQ, or fires DECISION asking whether to
draft now or defer. "Note in handoff" is not a state — it's how
SKIPPED-USER gets recorded after the user explicitly declined.

### Anti-Pattern 7 — Findings in limbo (neither resolved, promoted, nor carried forward)

**What it looks like:** today's findings file has 5 items at session
end. Group 6 marks "RESOLVED" without naming whether each item was
resolved, promoted, or is carrying forward.

**What the correct walk does:** Group 6's RESOLVED-AUTO state
explicitly names the disposition of every item — N resolved
in-session, M promoted to backlog, K carrying forward. Items with
unclear promotion intent fire the DECISION AUQ.

### Anti-Pattern 8 — Routing matrix marked RESOLVED on existence + mtime alone

**What it looks like:** Group 3 reads `skill_routing_matrix` memory,
sees the file exists with mtime from this morning, marks RESOLVED.
The matrix actually references three skills the user uninstalled
yesterday.

**What the correct walk does:** Group 3 must REDISCOVER, not just
check freshness. The five-step verification (read cache, enumerate
current skills/agents/MCPs, diff) catches stale matrices that look
fresh by mtime. This is exactly why the locked v5.15.0 design
specifies rediscovery, not freshness check.

---

## Integration with the v5.15.0 Hook Architecture

The closure floor sits inside a four-layer enforcement architecture
shipped in v5.15.0:

```
Layer 1: PreToolUse identity guard
         → blocks SP from editing source files
         → fires on every Edit/Write/Bash/Serena-write call
         → existing since v5.4.0

Layer 2: UserPromptSubmit startup floor (`references/floor.md`)
         → 7-group walk on session and subcommand entry
         → emits SP-FLOOR-COMPLETE summary line into context
         → enforces that SP knows current project state at every new scope

Layer 3: Stop per-turn rhythm enforcer (SKILL.md frontmatter)
         → 5 rules checked at end of every assistant turn
         → catches AUQ slips, identity-reset omissions,
           tool-availability claims, fence/handoff coupling,
           floor-signal silent skips

Layer 4: Closure floor (THIS document)
         → 8-group walk at session-end
         → fires when /strategic-partner:handoff invoked
           OR session-end signal detected
         → produces the handoff file as the terminal artifact
```

The optional SessionEnd hook (if shipped) is forensic-only — it
captures a raw evidence snapshot to `/tmp/sp-session-end-${KEY}.txt`
for sessions that terminated without a handoff (crash, force-quit).
The closure floor remains the canonical closure path; SessionEnd
just lets the next session reconstruct what state was lost when the
closure walk didn't run.

See SKILL.md for the full hook frontmatter and `references/hooks-integration.md`
for the empirical verification trace.

---

## When SessionEnd is Not Available

If the SessionEnd hook does not fire reliably from skill frontmatter
on the user's Claude Code version, the optional last-gasp evidence
capture is not available. The closure floor (Layer 4 above) remains
the canonical closure path — it does not depend on SessionEnd.

The trade-off: without SessionEnd, sessions that terminate
unexpectedly (crash, force-quit, network drop on a long-running
session) leave no evidence snapshot. The next session has no
forensic artifact to reconstruct from. The user's options when this
happens are:

- Recover the previous session via Claude Code's `--resume` flag
  (if the harness preserved transcript)
- Proceed without the lost session's state
- Manually reconstruct from `git log`, `.handoffs/findings-*.md`,
  and Serena memory state

The closure floor's procedural rigor minimizes the impact: as long
as the user signals "wrapping up" before terminating, the closure
walk runs and the handoff file is written. The SessionEnd snapshot
is purely a backstop for the unsignaled-termination case.

### Why we do not ship a SessionEnd hook (as of v5.15.0)

The locked v5.15.0 design names SessionEnd as an **optional** last-gasp
evidence capture, gated on empirical verification that SessionEnd
fires reliably from skill frontmatter on Claude Code 2.1.x. The
verification protocol (see `.prompts/v5150-structural-fix/phase3-closure-floor.md`
Component 5 Step 1) requires:

1. Setting up a sandbox skill at `~/.claude/skills/sessionend-test-${UUID}/`
2. Opening a **fresh, separate** Claude Code session in a separate terminal
3. Invoking the sandbox skill from inside that fresh session
4. Exiting via the normal `/exit` lifecycle (not `kill`)
5. Reading the marker file written by the SessionEnd hook
6. Repeating steps 2-5 a second time to confirm reliability across
   separate session lifecycles

Steps 2-5 require the user's hand at the keyboard — the executor agent
that built the v5.15.0 closure floor could not drive a separate
Claude Code session, invoke a slash command from inside it, and trigger
the `/exit` lifecycle from outside that session's process tree.

The brief's gating rule was binary: "All 5 gates pass on BOTH
invocations → ship the hook" or "Any gate fails → do not ship and
document the gap." The actual verification status at v5.15.0 release
was neither pass nor fail — it was **untested in this scope**.

The conservative default applied: **do not ship a SessionEnd hook
in v5.15.0**. The closure floor remains the canonical closure path
and does not depend on SessionEnd.

**To ship SessionEnd in a future version (v5.16.0+), the user runs the
verification protocol manually:**

1. Follow `.prompts/v5150-structural-fix/phase3-closure-floor.md` § Component 5 Step 1
2. If all 5 gates pass on both invocations, dispatch an executor brief
   to add the SessionEnd hook block to SKILL.md frontmatter per the
   brief's Step 2 spec
3. Update this section to reflect the verification result

Until then, sessions that terminate without invoking
`/strategic-partner:handoff` (crash, force-quit, network drop) leave
no forensic snapshot. Recovery options listed in "When SessionEnd is
Not Available" above remain the only paths.

---

## Cross-Reference

| Reference | Relationship |
|---|---|
| `commands/handoff.md` | The implementation — 8-group walk runs as the command body |
| `references/context-handoff.md` | The handoff file write protocol (Steps 9-13 after the walk) |
| `references/floor.md` | Sibling protocol — startup floor on UserPromptSubmit |
| `references/floor-signal-handling.md` | Per-pattern remediation for non-clean startup-floor signals |
| `references/hooks-integration.md` | Hook delivery rules and empirical verification traces |
| `assets/templates/handoff-template.md` | The structured template the handoff file uses |
| SKILL.md § Closure Evidence Ledger | The 8-row ledger this 8-group walk produces state for |
| SKILL.md § Floor-Signal Handling | The init-mode visual style this closure walk visually mirrors |
| SKILL.md § Backlog Stewardship | The canonical backlog protocol Group 7a hygienes |
