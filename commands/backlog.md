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
- **Close** — for any non-closed item. Mark with one of four reasons (`completed`, `not-planned`, `duplicate`, `superseded`); move file to `.handoffs/backlog-archive/`. For `duplicate` and `superseded`, also capture `superseded_by:`.

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
- Offer the five triage actions (discard, promote to clarified, promote to active, set trigger and park, close)
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
