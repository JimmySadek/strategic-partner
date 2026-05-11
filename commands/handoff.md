---
name: handoff
description: "Trigger context handoff with split writes and continuation prompt"
category: session
complexity: standard
mcp-servers: [serena]
---

# /strategic-partner:handoff — Context Handoff

> Direct trigger for the context handoff procedure. Run when you want to save session
> state and generate a continuation prompt — either proactively or when context is getting full.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Use ASCII diagrams for any workflow or relationship that has >3 steps.
Default to concise mode; expand for problems or decisions.

## Context Inheritance

This subcommand inherits the active advisor context. It knows what happened in the current
session — it doesn't need its own startup sequence or mode detection.

If invoked outside an active advisor session, it still works but will have less context
to draw from (it will do its best with what's available in conversation history).

## Behavioral Flow

The handoff command body is an 8-group closure walk followed by the
handoff file write. Each of the 8 groups runs a concrete verification
command, marks one of six states (RESOLVED, RESOLVED-AUTO, DECISION,
SKIPPED-USER, SKIPPED-AUTO, DIRTY), and either takes a hygiene action
automatically or fires `AskUserQuestion` for a genuine decision.

Then the file write protocol from `references/context-handoff.md`
runs as Steps 9-13 (Reflect, Slug, Split writes, Continuation prompt,
Display) followed by Post-Handoff Verification (Step 14).

See `references/closure-floor.md` for worked examples of each group's
output, the AUQ text patterns, and the anti-pattern catalog.

### Pre-walk Setup — Directories and Gitignore Coverage

Before Group 1 runs, ensure the four session-work directories exist
and `.gitignore` covers them:

- `.handoffs/` directory exists
- `.prompts/` directory exists
- `.scripts/` directory exists
- `.backlog/` directory exists
- `.gitignore` contains entries for all four — add silently if missing

This is an enforced guardrail, not a discretionary edit (consistent
with SKILL.md fire-and-forget and context-handoff.md). Auto-add
`.gitignore` entries without asking.

### Group 1 — Staleness verification

Cross-check Serena memories against codebase reality. Pick 2 file
paths from the `codebase_structure` memory; verify each exists. Pick
1 convention from the `code_style_and_conventions` memory; verify with
a project-wide pattern search.

```
# Verification (executed via Serena tools):
# 1. mcp__plugin_serena_serena__read_memory codebase_structure
#    → extract 2 file paths
# 2. mcp__plugin_serena_serena__find_file <path> for each → confirm exists
# 3. mcp__plugin_serena_serena__read_memory code_style_and_conventions
#    → extract 1 convention
# 4. mcp__plugin_serena_serena__search_for_pattern <convention>
#    → confirm match
```

State logic:
- All 3 checks pass → RESOLVED, brief one-line note in handoff body
- Any check fails → DECISION, AUQ proposing memory update with the
  specific staleness identified
- Serena unavailable → DO NOT silently skip. Run the
  verify-activate-fallback chain:
  - **(a) Verify**: call `mcp__plugin_serena_serena__check_onboarding_performed`.
    If it returns a project list, Serena IS available — activate the
    project for current cwd and retry Group 1 from the top.
  - **(a.1) MCP error / timeout / crash handling**: if
    `check_onboarding_performed` itself returns an error, times out,
    or the MCP server crashes — retry ONCE with a 5-second cooldown
    (`sleep 5`). If the retry ALSO fails, surface DECISION via AUQ:
    - [Investigate MCP failure] — pause closure to diagnose; provide
      user with the error output and stack trace for triage
    - [Defer to next session with explicit acknowledgment] — note
      BOTH the closure gap AND the MCP failure in handoff body's
      Deferred Floor Signals section
    - DO NOT auto-mark SKIPPED-AUTO on MCP failure; use SKIPPED-USER
      only after explicit user choice on the AUQ above. Silent skip
      on MCP error reproduces the same failure pattern this group's
      chain exists to prevent.
  - **(b) Retry after activation**: if step (a) found a matching
    project, call `mcp__plugin_serena_serena__activate_project` with
    the cwd-matching project name, then re-run Group 1's three
    checks. Mark state per the normal logic above.
  - **(c) Fallback dispatch**: if step (a) finds NO project for current
    cwd (or onboarding has not been done), surface DECISION via AUQ:
    - [Run Serena onboarding now] — dispatch background Opus 4.7
      agent to onboard this project
    - [Defer to next session with explicit acknowledgment] — note
      the gap in handoff body's Deferred Floor Signals section
    - [Investigate the unavailability further] — pause closure to
      diagnose
  - **(d) Mark SKIPPED-USER ONLY after (a.1) or (c)** is explicitly
    resolved by user, with the user's reason in the handoff body.

The chain forces SP to verify before declaring Serena unavailable,
then asks the user before skipping anything. Silent skip on apparent
unavailability reproduces the failure pattern findings-0428 issue 4
captured.

Ledger row updated: 🧠 Serena memories.

Anti-pattern: marking RESOLVED without running the verification
commands. Anti-pattern: marking SKIPPED-AUTO on Serena unavailability
without first running the verify-activate chain.

### Group 2 — Architecture drift scan

Detect major structural changes since the last memory snapshot. Scan
top-level directory structure; compare to the layout recorded in the
`codebase_structure` memory.

```bash
ls -d */ | sort
# Compare against the structure documented in codebase_structure memory
```

State logic:
- No drift detected → RESOLVED, brief note
- Minor drift (1-2 new directories) → RESOLVED-AUTO, note in handoff
  body with proposed memory update
- Major drift (>2 new directories OR removed directories) → DECISION,
  AUQ proposing re-onboarding

Ledger row updated: 🧠 Serena memories (`codebase_structure`
specifically).

Anti-pattern: skipping this group entirely because Serena is
"probably fine" — past failures show drift accumulates silently
across sessions.

### Group 3 — Routing matrix verification (full rediscovery + diff)

Re-enumerate the current environment (skills, custom agents, MCP
servers) and diff against the cached `skill_routing_matrix` Serena
memory. Per the locked v5.15.0 design, closure must REDISCOVER, not
just check freshness.

```
# Verification (executed by SP — runs the rediscovery in a focused
# background dispatch: Opus 4.7, run_in_background=true):
# 1. mcp__plugin_serena_serena__read_memory skill_routing_matrix
#    → cached state (skill count, agent count, MCP server count, build_timestamp)
# 2. Read system-reminder skill list → current skill inventory
# 3. ls ~/.claude/agents/*.md AND .claude/agents/*.md (project-level)
#    → current custom agents
# 4. Identify active MCP servers from current context
# 5. Diff (4) against (1): added skills, removed skills, agent changes,
#    MCP changes
```

State logic:
- Cached matrix exists AND no diff vs current environment → RESOLVED,
  one-line note in handoff body ("routing matrix current: N skills,
  M agents, K MCPs")
- Cached matrix exists BUT diff detected → RESOLVED-AUTO; dispatch
  background Opus 4.7 rebuild (matrix construction is hygiene per
  the `feedback_opus_max_for_substantive_work` Serena memory feedback);
  summarize diff in handoff body ("routing matrix updated: +X skills,
  -Y skills, agent changes")
- Cached matrix MISSING → DECISION, AUQ proposing immediate background
  build dispatch (same pattern as 2026-05-01's matrix-build dispatch)

Ledger row updated: 🧠 Serena memories (`skill_routing_matrix`
specifically). NOTE: this is a NEW ledger row to add — the existing
8-row ledger in SKILL.md doesn't include `skill_routing_matrix` as
its own row. Add it.

Anti-pattern: marking RESOLVED based on existence + mtime alone
without actually rediscovering and diffing the environment. Stale
matrices that "look fresh" by mtime but reference removed skills
are the failure mode this group prevents.

### Group 4 — Persistent memory ledger

Catalog Serena memory writes from this session. Cross-check the
session's substantive decisions against `decision_log` updates.

```
# Verification:
# 1. mcp__plugin_serena_serena__list_memories → current state
# 2. Diff against the same call's output captured at session start
#    (if available)
# 3. Cross-reference: every "key decision" from session conversation
#    should have a corresponding decision_log entry
```

State logic:
- All session decisions captured in decision_log → RESOLVED-AUTO,
  file silently as hygiene
- Decisions made but not captured (gap detected) → RESOLVED-AUTO if
  SP can append the decision_log entry directly (decision_log is
  established type per Ask-Before-Act)
- New memory of unestablished type needed → DECISION, AUQ proposing
  the new memory with content preview
- No new memory writes needed → SKIPPED-AUTO

Ledger row updated: 🧠 Serena memories (decision_log + any new memories).

Anti-pattern: appending session decisions silently without the user
seeing what's being recorded.

### Group 5 — Project conventions ledger

Scan session for "let's add a rule" or "remember this for future
sessions" signals; check for CLAUDE.md updates needed.

```bash
git diff CLAUDE.md  # any uncommitted changes?
# AND scan session conversation for emerged-rule signals
```

State logic:
- No new conventions emerged → RESOLVED, brief note
- Convention emerged AND text already drafted in conversation →
  DECISION, AUQ presenting the proposed CLAUDE.md edit text
- Convention emerged but no text drafted → DECISION, AUQ asking
  whether to draft + commit during closure or defer

Ledger row updated: 📝 CLAUDE.md.

Anti-pattern: noting "convention emerged" in the handoff body
without actually proposing the edit. Either commit it or explicitly
defer.

### Group 6 — Working memory ledger

Findings file actions from this session. Identify items that should
be promoted to backlog, items that should be marked resolved, items
that carry forward.

```bash
ls .handoffs/findings-*.md | tail -1  # today's findings file
# Read it; cross-reference issues against session resolution status
# Scan for items already ratified during conversation as "park this"
```

State logic:
- No findings this session → SKIPPED-AUTO. Detail string collapses
  to "no findings this session."
- Findings exist (N>0) → DECISION or RESOLVED-AUTO depending on
  disposition clarity. The Group 6 row's detail string MUST follow
  this format:

  ```
  N findings: M resolved in-session, K promoted to .backlog/, L carrying forward
  ```

  Where N = total findings in today's findings file, and M + K + L = N.
  Every finding gets explicit disposition. Counts that don't sum to
  N indicate the disposition is incomplete and the row CANNOT be
  RESOLVED-AUTO.
- Findings ratified for promotion during conversation → RESOLVED-AUTO,
  promotion to `.backlog/` filed automatically; counted in K.
- Findings with unclear promotion intent → DECISION, batched AUQ
  with options [Park as backlog item] [Keep as session finding] [Drop].
  After user resolves, recompute the disposition string before
  marking RESOLVED-AUTO.

Ledger row updated: 📋 Session findings.

Anti-pattern: leaving findings in limbo (neither resolved nor
promoted nor explicitly carried forward).

Anti-pattern: marking RESOLVED on "any new findings?" alone — the
row's detail must enumerate disposition for ALL findings in the
file, not just new captures from this session. RESOLVED-AUTO requires
the full "N findings: M resolved in-session, K promoted to .backlog/,
L carrying forward" disposition string.

### Group 7 — Workspace ledger (with backlog hygiene as first-class)

This is the biggest group — splits into 4 sub-walks.

#### 7a — Backlog hygiene pass

```bash
# List all backlog items:
ls .backlog/*.md

# For each item, check trigger against current state:
# - Read frontmatter (title, status, priority, trigger, added date)
# - Determine if trigger has fired (e.g., "after v5.15.0 release"
#   when v5.15.0 just shipped)
# - Determine if item is stale (>30 days no status change AND no
#   trigger movement)
```

State logic (grouped summary first, per-item only on opt-in — matches
existing `commands/backlog.md` pattern):

1. **Compute aggregate counts**: total items (N), items with met
   triggers (X), items stale (>30 days no movement) (Y), items
   recently added — last 7 days (Z), and items with `status:
   completed` still in `.backlog/` (W).

2. **Emit aggregate-format summary in handoff body**. The Group 7a
   row's detail string MUST follow this format:

   ```
   Backlog: N total. Met: X. Stale: Y. Recent: Z. Completed-parked: W.
   ```

   Where N = total `.backlog/*.md` files, X = items whose `trigger:`
   fired against current state, Y = items >30 days no movement,
   Z = items added in last 7 days, W = items with `status: completed`
   still in the `.backlog/` directory.

3. **AUQ ONLY ONCE for the entire backlog** (not per-item):
   - If X + Y + W == 0 → no AUQ, mark RESOLVED with the summary line
   - If X > 0 OR W > 0 OR Y > 10 → AUQ with grouped options:
     - [Review met-trigger items now] — opens per-item walk for the X items
     - [Review stale items now] — opens per-item walk for the Y items
     - [Archive completed-parked items now] — opens 7a-retirement-scan
       below for the W items
     - [Defer all to next session] — items carry forward in next orientation
     - [Drop accumulated stale items in bulk] — bulk action, single confirmation
   - If 0 < Y ≤ 10 AND X == 0 AND W == 0 → no AUQ (informational only);
     items surface in next session's orientation per existing protocol

4. **Per-item walk fires ONLY if user opts in via step 3**. Then
   per item:
   - Met trigger → AUQ [Activate now] [Re-park with new trigger] [Drop]
   - Stale → AUQ [Keep parked] [Re-park with new trigger] [Drop as obsolete]

##### 7a-retirement-scan

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

After backlog pass, handle newly-promoted findings (from Group 6):
- Items already ratified during conversation as "park this" →
  RESOLVED-AUTO, file automatically (no AUQ)
- Promotion scope unclear → DECISION, single AUQ batching ALL unclear
  findings (not per-item) with options [Promote all] [Skip all]
  [Review per item]

Per-item AUQs at closure cause fatigue and break the
hygiene/decision split's intent. The existing `commands/backlog.md`
already has the right pattern — group summary + recommend prune only
when stale exceeds threshold. Match that pattern at closure.

#### 7b — `.prompts/` scan

List `.prompts/[milestone]/` for unsaved drafts the user explicitly
approved during the session.

State logic:
- No unsaved drafts → SKIPPED-AUTO
- Drafts approved during conversation → RESOLVED-AUTO, save
  automatically
- Drafts with ambiguous scope/naming → DECISION, AUQ proposing
  filename + milestone

#### 7c — `.scripts/` scan

List `.scripts/` for any scripts discussed during session.

State logic:
- No scripts → SKIPPED-AUTO
- Scripts already saved → RESOLVED, brief note
- Scripts discussed but not saved → DECISION, AUQ to save with
  proposed filename

#### 7d — Workspace ledger summary

Emit a single-line summary of `.handoffs/`, `.prompts/`, `.scripts/`,
`.backlog/` counts and any actions taken.

Ledger rows updated: 📦 Backlog, 📄 `.prompts/`, 🔧 `.scripts/`.

Anti-pattern: silent appends to `.backlog/` without surfacing what was
filed. Anti-pattern: bulk-promoting findings without per-item AUQ
when scope is unclear.

### Group 8 — Working tree closure

Git state — branch, dirty/clean, ahead/behind, last commit sanity.

```bash
# Verification (separate parallel calls per CLAUDE.md):
git status
git log --oneline -3
git branch --show-current
```

State logic:
- Clean tree, on expected branch → RESOLVED, brief one-line summary
- Hygiene commit made automatically (non-source content staged) →
  RESOLVED-AUTO, name the commit
- Source-shaped or ambiguous diff exists → DECISION, AUQ proposing
  commit message and scope confirmation
- Source-file edits exist that the SP cannot commit (outside
  allow-list) → DIRTY, escalate explicitly via AUQ proposing executor
  dispatch (handoff blocks until resolved or user explicitly defers)

Ledger row updated: 🔀 Git.

Anti-pattern: continuing to write the handoff file with dirty source
state — every dirty case must be explicitly RESOLVED-AUTO, DECISION,
or DIRTY; no silent ignores.

### After Group 8 — Render Closure Walk Status table inline

Before the handoff file write Steps 9-13 begin, render the Closure
Walk Status table inline in the response so the user sees the walk
outcome before persistence:

```
## Closure Walk Status

| Group | Status | Detail |
|---|---|---|
| 🧠 1. Staleness verification     | [STATUS_EMOJI] | [one-line outcome] |
| 🏗️ 2. Architecture drift scan   | [STATUS_EMOJI] | [one-line outcome] |
| 🗺️ 3. Routing matrix verification | [STATUS_EMOJI] | [one-line outcome] |
| 💾 4. Persistent memory ledger    | [STATUS_EMOJI] | [one-line outcome] |
| 📝 5. Project conventions ledger  | [STATUS_EMOJI] | [one-line outcome] |
| 📋 6. Working memory ledger       | [STATUS_EMOJI] | [findings disposition format] |
| 📦 7a. Backlog hygiene            | [STATUS_EMOJI] | [N total. Met: X. Stale: Y. Recent: Z. Completed-parked: W.] |
| 📄 7b. Pending prompts            | [STATUS_EMOJI] | [one-line outcome] |
| 🔧 7c. Pending scripts            | [STATUS_EMOJI] | [one-line outcome] |
| 🔀 8. Working tree closure        | [STATUS_EMOJI] | [one-line outcome] |
```

Use the canonical user-facing state rendering (✅ Checked, all clean for
RESOLVED; ✅ Already handled for RESOLVED-AUTO; 🟡 Needs your input for
DECISION; ⏭️ Skipped (you declined) for SKIPPED-USER; ➖ Doesn't apply
this session for SKIPPED-AUTO; 🚨 Uncommitted source changes for DIRTY)
and the canonical row-anchor emoji mapping (🧠 / 🏗️ / 🗺️ / 💾 / 📝 / 📋
/ 📦 / 📄 / 🔧 / 🔀, with 📦 / 📄 / 🔧 anchoring sub-rows 7a / 7b / 7c
respectively). The Status column carries the emoji alone; the legend
below the table carries the full `<emoji> <phrase>` pair. The internal
state names (RESOLVED, RESOLVED-AUTO, etc.) stay in the dispatch logic
above — only the rendering translates. The same table is also persisted
to the handoff file body in Step 11. See `references/closure-floor.md`
§ Visual Output Specification for the canonical mapping; the mapping is
identical across all three render targets (this inline render, the
handoff template, and the closure-floor reference).

### After Group 8 — Proceed to handoff file write (Steps 9-13)

After all 8 groups have been walked and their states determined, the
handoff file write runs as Steps 9-13. The walk's per-group state
output populates the handoff file's structured sections:

- **Files Modified** ← Group 8
- **Serena Memory Updates** ← Group 4
- **Open Questions / Blockers** ← Groups 5-7 DECISION rows
- **Pending Implementation Prompts** ← Group 7b
- **Pending Scripts** ← Group 7c
- **Deferred Floor Signals** ← Group 1 fallback chain (when SKIPPED-USER)

Follow `references/context-handoff.md` § Handoff Protocol Steps 1-6,
which run as Steps 9-13 of this command body.

### Step 9 — Reflect

Synthesize state from the 8-group walk plus session context. Run
`/insights` first; extract relevant items into the handoff file's
`/insights Analysis` section. Then extract per the template:

- **Primary goal**: what the user was trying to achieve
- **Current state**: done / half-done / broken or blocked
- **Key decisions made**: choices and the reasoning behind them
- **Files modified**: every file created, edited, or deleted
- **Open issues**: unresolved questions, blockers, follow-ups
- **Pending prompts**: any implementation prompts not yet run
- **Serena memory changes**: memories created, updated, or deleted
- **Next immediate action**: single most important thing to do next

### Step 10 — Derive topic slug

From session goal and files touched, derive a 2-4 word hyphenated
slug: `auth-refactor`, `dashboard-stats`, `subcommand-setup`,
`closure-floor`.

### Step 11 — Split writes

Write up to three artifacts in parallel:

| Artifact | Destination | Template |
|---|---|---|
| Session state | `.handoffs/[topic-slug]-[MMDD-HHMM].md` | `assets/templates/handoff-template.md` |
| Pending prompts | `.prompts/[milestone]/[descriptor].md` | `assets/templates/prompt-template.md` |
| Pending scripts | `.scripts/[descriptor].sh` | — |

Prompt-save threshold: save if >250 lines OR >5 deliverables OR >1
prompt pending. The handoff file references prompts by path in its
"Pending Implementation Prompts" section and scripts by path in its
"Pending Scripts" section.

### Step 12 — Write the Continuation Prompt

Append after the final `---` in the handoff file.

**🔴 Critical**: The continuation prompt's **FIRST LINE** must be:

```
/strategic-partner .handoffs/[topic-slug]-[MMDD-HHMM].md
```

This restores the advisor persona via the argument path (startup
uses `$ARGUMENTS` to load the specific handoff file). Omitting it
means the next session starts in initialization mode and loses all
session state.

The prompt must be self-contained — a fresh session with zero context
must understand what to do. Write it as if briefing a new expert
collaborator. See `references/context-handoff.md` Step 4 for the
recommended structure.

### Step 13 — Display Results

Present in this exact format:

```
✅ Handoff written to `.handoffs/[filename]`
🧾 Closure floor: [N]/8 checked, [M] handled automatically, [K] not applicable, [J] needs your input
📁 Implementation prompts saved to `.prompts/[milestone]/` (if applicable)
```

Then a separator, followed by a clearly labeled block:

```
📋 COPY THIS INTO A NEW SESSION:

══════════════════ START 🟢 COPY ══════════════════
[The full continuation prompt — complete and usable as-is]
══════════════════= END 🛑 COPY ═══════════════════

Open a new Claude Code session and paste the above prompt to continue.
```

**STOP** — no commentary, praise, or editorial after the fence.

### Step 14 — Post-Handoff Verification

After writing the handoff file and displaying the continuation prompt,
run a verification pass before ending the session:

```bash
# 1. Continuation prompt is present and intact
grep -c "FRESH THREAD STARTING PROMPT" .handoffs/[topic-slug]-[MMDD-HHMM].md
# Expected: 1

# 2. Continuation prompt invokes the SP
grep -c "/strategic-partner" .handoffs/[topic-slug]-[MMDD-HHMM].md
# Expected: ≥1

# 3. Today's findings file exists or "no findings this session" was acknowledged
ls -la .handoffs/findings-*.md 2>/dev/null
# Expected: at least today's findings-MMDD.md, OR explicit acknowledgment
# in the closure walk's Group 6 output that no findings were captured

# 4. .gitignore covers all four session-work directories
grep -E "^\.handoffs/|^\.prompts/|^\.scripts/|^\.backlog/" .gitignore | wc -l
# Expected: ≥4
```

If any check fails, surface the gap via `AskUserQuestion` before
confirming the handoff complete. Do NOT silently retry; the user
must see what failed and approve the fix.

The verification confirms the handoff actually delivered on the
closure contract — no silent gaps. See `references/closure-floor.md`
§ Anti-Pattern Catalog for the failure modes this verification
catches.

## Thresholds Reference (Tiered Escalation)

For awareness (the advisor monitors these during normal operation):

| Context Level | Tier | Action |
|---|---|---|
| **>60%** | Monitoring | Check context on every 2nd exchange |
| **67%** | Gentle nudge | Visible inline note, begin extracting session state |
| **72%** | Strong push | AskUserQuestion proposing handoff NOW |
| **77%** | Urgent | Execute handoff immediately (confirm slug only) |

## Backlog Stewardship

Closure includes a backlog scan. As part of the closure flow (per
SKILL.md § Closure Evidence Ledger, the Backlog row), the SP surfaces
items in `.backlog/*.md` whose `trigger` field has fired against current
project state, and offers to promote unresolved findings from this
session if the user wants to park them as backlog items rather than let
them carry forward in the next session's findings file.

Two layers, distinct purposes:

- **Findings** — lightweight, automatic, session-scoped. Captured as
  the SP encounters issues during the session and written to
  `.handoffs/findings-MMDD.md`. Carry forward to the next session's
  orientation by default.
- **Backlog** — curated, selective, project-scoped. Items live in
  `.backlog/*.md` with structured frontmatter (`title`, `status`,
  `priority`, `trigger`). Reviewed via `/strategic-partner:backlog` or
  surfaced at startup when triggers fire.

Handoff bridges them: at session-end, the SP looks at unresolved
findings and asks (via `AskUserQuestion`, only when the promotion scope
is unclear) whether any should become backlog items. Items with clear
"park this" / "for later" intent already ratified during the session
are filed automatically (RESOLVED-AUTO on the Backlog ledger row); the
AUQ only fires when the SP has no signal whether a finding belongs in
backlog or should stay as a session note.

See SKILL.md § Backlog Stewardship for the canonical spec, including
proactive trigger signals during normal advisory flow.

## Boundaries

**Will:**
- Read session context and synthesize state
- Write handoff file to `.handoffs/`
- Write implementation prompts to `.prompts/` (if applicable)
- Update `.gitignore` (with confirmation)
- Display the continuation prompt for copy-paste

**Will Not:**
- Push to git or create commits (that's a separate ask-before-act decision)
- Delete or overwrite existing handoff files
- Implement any source code changes

## See Also

- `/strategic-partner:status` — mid-session check on where things stand. Use before triggering handoff if you want a sanity check on what state will be captured.
- `/strategic-partner:backlog` — review parked items and defer unresolved findings before closing. Use during the closure flow when the SP asks about backlog promotion.
- `/strategic-partner:copy-prompt` — pull the continuation prompt this command emitted into the OS clipboard. Use immediately after handoff when you're about to open a new session.
