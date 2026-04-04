---
name: backlog
description: "View project backlog — parked ideas, deferred work, and future improvements"
category: advisory
complexity: standard
mcp-servers: []
---

# /strategic-partner:backlog — Backlog Review

> Surface parked ideas and deferred work. Check triggers against current project state,
> highlight actionable items, and recommend promotions. Run on-demand or when prompted
> after version releases and milestone completions.

## Output Style

Adopt the adaptive-visual output style (`~/.claude/output-styles/adaptive-visual.md`).
Use status symbols for scannable output. Default to concise mode; expand for items
with met triggers.

## Behavioral Flow

### Step 1 — Locate Backlog

Glob `.backlog/*.md` in the project directory.

- **No files found**: Report: "No backlog items found. I'll offer to add items when
  ideas surface during our sessions." End here.
- **No `.backlog/` directory**: Same message. No error.
- **Files found**: Proceed to Step 2.

### Step 2 — Read Frontmatter

For each `.backlog/*.md` file, extract YAML frontmatter fields:

| Field | Required | Values |
|---|---|---|
| `title` | Yes | Descriptive title |
| `status` | Yes | `parked` / `promoted` / `completed` / `stale` |
| `priority` | Yes | `high` / `medium` / `low` |
| `added` | No | `YYYY-MM-DD` |
| `origin` | No | Session name or context |
| `trigger` | Yes | Specific re-engagement condition |

**Malformed frontmatter**: Skip the item, note in output: "⚠️ [filename] — skipped
(malformed frontmatter)."

### Step 3 — Check Triggers

For each item with status `parked`, evaluate the `trigger` condition against current
project state. Evaluation methods:

| Trigger Type | How to Check |
|---|---|
| Version-based ("next release", "v6.0") | Compare against current version in SKILL.md |
| File-based ("when X exists") | Glob/Read for the file |
| Feature-based ("when codex-feedback changes") | `git log --oneline` for relevant commits |
| Time-based ("after 3 sessions") | Count is approximate — flag as "possibly due" |
| External ("traction data", "user feedback") | Cannot verify — note as "requires manual check" |

Mark items with met triggers as **actionable**.

### Step 4 — Present

Display as a status table:

```
## 📋 Backlog — [project name]

| # | Title | Status | Priority | Trigger |
|---|---|---|---|---|
| 1 | [title] | 🅿️ parked | 🔴 high | [trigger summary] |
| 2 | [title] | 🅿️ parked | 🟡 medium | [trigger summary] |
| 3 | [title] | ✅ completed | 🟢 low | — |

### 🔔 Actionable Items
> **[Title]** — trigger condition met: [explanation of why trigger is satisfied].
> [1-2 line summary of what the item proposes.]
```

Sort order: actionable items first, then by priority (high → medium → low),
then by date added (oldest first).

If Serena is available, also check `project_backlog_index` memory for any items
not yet migrated to files. Note any found: "ℹ️ N items in Serena memory not yet
in `.backlog/` files."

### Step 5 — Recommend

**If any triggers are met**, present via `AskUserQuestion`:

> "N backlog items have met their triggers. What would you like to do?"

Options:
- [Promote to active work] — SP will help frame the promoted item for implementation
- [Keep parked] — Acknowledge and leave as-is
- [Review all items] — Walk through each item for status check

**If no triggers are met**, end with count summary:

> "N backlog items parked, none actionable. Run `/strategic-partner:backlog`
> anytime, or I'll check triggers at session startup."

**If more than 10 items**, add prune recommendation:

> "💡 Backlog has N items — consider a prune pass to remove completed or stale entries."

## Failure Modes

| Scenario | Response |
|---|---|
| `.backlog/` directory doesn't exist | Silent — no error, friendly empty message |
| Frontmatter malformed | Skip item, note in output |
| Serena unavailable | Proceed with file-only scan |
| No items have triggers | Show table, end with count summary |

## Boundaries

**Will:**
- Scan `.backlog/` directory and read file frontmatter
- Present status table with visual formatting
- Check trigger conditions against project state
- Recommend promotions via `AskUserQuestion`

**Will Not:**
- Add items (conversational triggers handle this)
- Delete items (prune is a future mode)
- Modify item files without `AskUserQuestion` confirmation
- Block on Serena availability
