---
name: backlog
description: "View project backlog — items grouped by lifecycle state, with triage menu"
category: advisory
complexity: standard
mcp-servers: []
---

# /strategic-partner:backlog — Backlog Review and Triage

> Show every tracked item grouped by lifecycle state. Check triggers against
> current project state, surface actionable items, and offer triage actions
> (discard, promote, set trigger, close). Run on-demand any time, or wait for
> the automatic release-boundary triage.

## Output Style

Adopt the adaptive-visual output style (`~/.claude/output-styles/adaptive-visual.md`).
Use the lifecycle's functional emoji anchors (📥 inbox, 🔍 clarified, ⏳ parked,
🔄 active, ✅ closed) for scannable output. Closed items are not surfaced by
default — they live in `.handoffs/backlog-archive/`.

## Lifecycle context

Items move through five states. See `references/backlog-cycle.md` for the full
spec; this command surfaces the four non-closed states.

| State | Storage |
|---|---|
| 📥 inbox | `.handoffs/findings-MMDD.md` **or** `.backlog/*.md` with `state: inbox` |
| 🔍 clarified | `.backlog/*.md` with `state: clarified` |
| ⏳ parked | `.backlog/*.md` with `state: parked` |
| 🔄 active | `.backlog/*.md` with `state: active` |

**Triage cadence.** Two events fire triage: automatically before every minor
or major release, and on-demand whenever this command runs.

## Behavioral Flow

### Step 1 — Locate the inbox (both shapes)

Walk **both** storage locations — findings and `.backlog/` — as one logical
inbox.

- Glob `.handoffs/findings-*.md` for lightweight captures (each line under
  `## Issues` is one inbox item).
- Glob `.backlog/*.md` for substantive items in any non-closed state.

If neither exists: report "No backlog items found. I'll offer to add items
when ideas surface during our sessions." End here.

### Step 2 — Read frontmatter

For each `.backlog/*.md` file, extract YAML frontmatter:

| Field | Required | Values |
|---|---|---|
| `title` | Yes | Verb-led title matching the file's verb prefix |
| `state` | Yes | `inbox` / `clarified` / `parked` / `active` |
| `labels` | Yes | Flat list — type + `priority:*` + `severity:*` (bugs) + `area:*` |
| `opened` | Yes | `YYYY-MM-DD` |
| `status_updated` | No | `YYYY-MM-DD` — last meaningful frontmatter change |
| `origin` | No | Single sentence — where the item came from |
| `progress` | No | One-line summary of partial progress (state=parked only) |
| `triggers_logic` | No | `any` (default) or `all` |
| `triggers` | If state=parked | Structured list — type/when/check |

**Malformed frontmatter:** skip the item, note in output: "⚠️ [filename] — skipped (malformed frontmatter)."

**Old-schema item detected** (any of `status:`, `trigger:` prose, top-level
`type:` / `priority:` / `severity:` / `added:`): list in a separate "Old
schema — needs migration" section; suggest the user run the migration
script (see SKILL.md § Backlog Auto-Migration for the install-location-resolved
invocation).

### Step 3 — Check triggers (parked items only)

For each `state: parked` item, evaluate every entry in `triggers:` against
current project state. The `triggers_logic:` flag (default `any`) controls
composition:

- `any` — any one trigger firing surfaces the item
- `all` — all triggers must fire simultaneously

| Trigger type | How SP checks it |
|---|---|
| **mechanical** | Run the `check:` shell expression via `bash -c`. Exit 0 = met. |
| **event** | Scan findings, recent handoffs, current session for the signal. |
| **temporal** | Compare against current version, time, or session count. |

Mark items with met composite triggers as **actionable**.

### Step 3.5 — Scan for shipped work

Backlog items go "ghost" when work ships but the note is never closed, so
the backlog inflates and orientation slows. This step catches that: it
scans recent git history for evidence that a non-closed item's scope
already shipped, and surfaces close-candidates for confirmation. **It never
auto-closes** — every close is the user's call.

This is the single shipped-work scan. The release process (project
`CLAUDE.md`, Release Process) invokes the *same* logic against the
release's commit range — there is no separate release-only detector.

**Candidates.** Every non-closed `.backlog/*.md` item (`inbox`,
`clarified`, `parked`, `active`). Closed items are out — they already live
in `.handoffs/backlog-archive/`.

**Scan window** (which commits count as evidence):

| Context | Window |
|---|---|
| On-demand (`/strategic-partner:backlog`) | Commits since each item's `opened:` date, bounded to the last ~200 commits |
| Release boundary (per `CLAUDE.md`) | `<previous-tag>..HEAD` |
| Release boundary, docs-only push | `<last-push>..HEAD` |

**Item text** (what each candidate is matched *from*): title + filename
slug + `labels` + `origin` + `progress` + body section headings +
definition-of-done.

**Evidence text** (what each item is matched *against*, per in-window
commit): commit subject + commit body + changed file paths + diff hunk
content + any release `CHANGELOG` entry inside the window.

**Matcher — deterministic; no sub-agent in the default path.** Scoring is a
deterministic token/overlap computation over the full item-text × evidence-
text feature set above:

- **Normalize** both sides: lowercase; split on non-alphanumerics and on
  `-`/`_`/`/`/`.`; drop a small stopword set; keep short tokens that carry
  signal (version stamps, counts like `16`/`17`).
- **Weight tokens by rarity** across the backlog corpus — a token shared by
  many items counts little; a distinctive token (e.g. `emission`,
  `actor-ambiguity`) counts a lot. This rarity weighting is the
  de-noising core.
- **Phrase / bigram bonus.** The item's slug as a phrase (verb prefix
  stripped, `-` → space), or any distinctive two-to-three-word sequence
  from the title, appearing contiguously in evidence is a strong signal
  (e.g. `script emission protocol`, `name the actor explicitly`,
  `routing decision`).
- **Area corroboration.** If the item's `area:*` label matches the commit's
  conventional-commit scope (`feat(voice)`, `fix(routing)`) or the changed
  paths' area, add a small bonus.
- **Aggregate** per item as the strongest single-commit score plus a capped
  sum across in-window commits (an item shipped over several commits still
  accumulates). A candidate clears when the aggregate ≥ the tuned
  threshold.

**Completed vs. partial.** If the matched commit(s) cover the item's stated
scope (slug phrase or a definition-of-done anchor present, and a
release/feature commit references it) → propose **close (completed)**. If
only part of the named scope appears → propose **update progress (partial
ship)**, never a completed-close.

**Revert safety.** If an in-window commit is a revert (`revert` subject
prefix, or body `This reverts commit <sha>`) and the reverted commit was a
candidate's only evidence, drop that candidate.

**Per-candidate actions** — surfaced via `AskUserQuestion`, NEVER
auto-applied:

- **close (completed)** — feeds the Step 5 Close action (writes the closed
  schema; see Step 5)
- **update progress (partial ship)** — appends a `progress:` line; the item
  stays open
- **dismiss this match** — records the pair so it never resurfaces (see
  Noise control)
- **leave open** — no change this scan

**Noise control (all required):**

1. Cap surfaced candidates at **5**, ranked by match strength.
2. Collapse the rest to a single line: `+N possible matches (lower confidence)`.
3. For each surfaced candidate, show the matched terms / the evidence line
   inline — confirming is then a 2-second read, not a guess.
4. **Persist dismissals.** Append `<commit-short-sha>:<item-slug>` to
   `.handoffs/.backlog-scan-dismissed` (the same idiom as the startup
   scan's `.handoffs/.scan-acks-<session>` acknowledgement file — one
   record per line, append-only). Any pair already in that file is filtered
   out of future scans in the same window, so a dismissed false positive
   never reappears.

**Semantic escape hatch (optional — NOT the default).** Dispatch a single
read-only sub-agent to adjudicate matches ONLY when either: (a) the
deterministic candidate count exceeds the cap of 5, or (b) a release-context
scan finds zero candidates despite high-risk evidence (e.g. many files
changed since the last close). In every other case the path is
deterministic scoring plus user confirmation — human confirmation *is* the
semantic stage in the common case.

**Output.** Surface the close-candidates immediately before the Step 4
grouped view, under a `✅ Possibly shipped — confirm close` heading; fold
confirmed closes into the Step 5 triage menu.

### Step 4 — Present grouped by state

```
## 📋 Backlog — [project name]

📥 Inbox (lightweight + substantive)
- 2 findings in .handoffs/findings-MMDD.md
- 1 item in .backlog/ with state: inbox

🔍 Clarified — 0 items

⏳ Parked — N items   (M actionable this triage)
| # | Title | Labels | Triggers | Opened |
|---|---|---|---|---|
| 1 | [title] | bug, area:hooks, priority:medium | event: "Next hook-touching release" | 2026-05-08 |
...

🔄 Active — 0 items
```

Items with met triggers float to the top of their state group and are
flagged with a 🔔 marker.

If Serena is available, also check `project_backlog_index` memory for any
items not yet migrated to files. Note any found: "ℹ️ N items in Serena memory
not yet in `.backlog/` files."

### Step 5 — Triage menu

Present the triage actions via `AskUserQuestion`:

> "Triage: what would you like to do?"

Options (per-item or batched):

- **Discard** — for 📥 inbox findings. Remove the line from the findings file; add a "Promoted/discarded" note.
- **Promote to 🔍 clarified** — for 📥 inbox items. Move from findings to `.backlog/[verb-prefix]-[slug].md` with `state: clarified`; SP proposes the verb prefix and slug.
- **Promote to 🔄 active** — for any non-closed item. Move to `state: active`; SP frames it for implementation.
- **Set trigger and park** — for 🔍 clarified items. Move to `state: parked`; user supplies the trigger(s); SP structures them.
- **Close** — for any non-closed item, including a Step 3.5 shipped-work confirmation. Closing is **not a bare `mv`**: first rewrite the frontmatter to the closed schema — `state: closed`, `close_reason:` (one of `completed`, `not-planned`, `duplicate`, `superseded`), `closed: <YYYY-MM-DD>` — then move the file to `.handoffs/backlog-archive/`. For `duplicate` and `superseded`, also capture `superseded_by:`. Writing the closed schema (not just moving the file) is what keeps archived items queryable — it is the exact metadata-update gap the 2026-05-18 ghost items exposed.

### Step 6 — Cadence summary

End with a short summary noting the next automatic triage event and the
on-demand path:

> "Next automatic triage: before the next minor/major release. On-demand
> triage available any time via `/strategic-partner:backlog`."

**If more than 10 items**, add a prune recommendation:

> "💡 Backlog has N items — consider closing items that have aged out (close reason: `not-planned`) to keep the list scannable."

## Failure Modes

| Scenario | Response |
|---|---|
| `.backlog/` directory doesn't exist AND no findings file | Silent — friendly empty message |
| Frontmatter malformed | Skip item; note in output |
| Old-schema items detected | List under separate "Old schema — needs migration" section; suggest the migration script per SKILL.md § Backlog Auto-Migration |
| Trigger `check:` expression fails (non-zero non-exit-1) | Treat as "not met" + warn once |
| Serena unavailable | Proceed with file-only scan |

## Boundaries

**Will:**
- Walk both `.handoffs/findings-*.md` and `.backlog/*.md` as one logical inbox
- Group items by lifecycle state with functional emoji anchors
- Evaluate `triggers:` (mechanical/event/temporal) and surface actionable items
- Scan recent git history (Step 3.5) for shipped work and surface close-candidates for confirmation — deterministic matcher, never auto-close
- Offer the five triage actions (discard, promote to clarified, promote to active, set trigger and park, close)
- On close, write the closed schema (`state: closed`, `close_reason:`, `closed:`) before moving the file to `.handoffs/backlog-archive/` — never a bare `mv`
- Block close-with-`superseded`-or-`duplicate` until `superseded_by:` is captured

**Will Not:**
- Surface closed items by default (they live in `.handoffs/backlog-archive/`)
- Modify item files without `AskUserQuestion` confirmation
- Auto-migrate old-schema items (the user picks via the startup migration prompt)
- Block on Serena availability

## See Also

- `references/backlog-cycle.md` — full lifecycle reference (states, transitions, triggers, naming, labels, file format)
- `/strategic-partner:status` — current session state, in-progress work, and what's next. Use when you want a recenter briefing on the active session rather than a backlog review.
- `/strategic-partner:handoff` — close the session and write a continuation prompt. Use when you're wrapping up; the closure flow surfaces backlog automatically as part of the evidence ledger.
