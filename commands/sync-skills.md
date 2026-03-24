---
name: sync-skills
description: "Scan live skills vs routing matrix, flag gaps, optionally update"
category: utility
complexity: standard
mcp-servers: [serena]
---

# /strategic-partner:sync-skills — Skill Inventory Sync

> On-demand skill inventory refresh. Run mid-session to rescan available skills
> without restarting the advisor.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Use ASCII diagrams for any workflow or relationship that has >3 steps.
Default to concise mode; expand for problems or decisions.

## Scope Split

```
Global (references/skill-routing-matrix.md):
  → Universal skills: sc:*, gsd:*, feature-dev:*, code-review:*
  → Updated by sync-skills only when universal skills change

Per-project (Serena memory `skill_inventory`):
  → Project-local skills: jimmy:*, any custom commands/skills
  → Written by sync-skills, read at advisor startup
  → Project-scoped automatically (Serena = per-project)
```

## Behavioral Flow

### Step 1 — Discover Live Skills

Read the system context for the currently available skills list (from the skill registry
in the conversation environment). This gives you every skill that Claude Code can invoke
right now.

### Step 2 — Classify Each Skill

For each discovered skill, classify:
- **Project-local**: lives in `<project>/.claude/commands/` or `<project>/.claude/skills/`
  (e.g., `jimmy:alfred-buildx`, project-specific commands)
- **Global**: everything else — installed plugins, `~/.claude/commands/`, `~/.claude/skills/`
  (e.g., `sc:*`, `gsd:*`, `feature-dev:*`, `code-review:*`)

### Step 3 — Compare Against Routing Matrix

Read `{skill-dir}/references/skill-routing-matrix.md` (where `{skill-dir}` is the
directory containing SKILL.md — resolve from the skill invocation context).

Compare **global skills only** (project-local skills live in Serena, not the matrix):

| Category | Meaning |
|---|---|
| ✅ **Catalogued** | In environment AND in matrix — healthy |
| ⚠️ **Uncatalogued** | In environment but NOT in matrix — needs routing entry |
| ❌ **Unavailable** | In matrix but NOT in environment — stale reference |

### Step 4 — Collect Project-Local Skills

Gather project-local skills separately. These are NOT compared against the global matrix —
they go into Serena memory for project-scoped routing.

For each project-local skill, note:
- Skill name (e.g., `jimmy:alfred-buildx`)
- Description (from skill metadata)
- What it does / when to route to it

### Step 5 — Present Findings

Use `AskUserQuestion` to present the scan results:

**Description format:**
```
## 🔍 Skill Inventory Scan

### Global Skills
✅ [N] catalogued (in matrix + environment)
⚠️ [N] uncatalogued (in environment, missing from matrix):
  - `/skill-name` — [description]
  - ...
❌ [N] unavailable (in matrix, missing from environment):
  - `/skill-name` — [was used for...]
  - ...

### Project-Local Skills
📁 [N] project skills detected:
  - `/skill-name` — [description]
  - ...
```

**Question**: "How should I update the skill references?"

**Options**:
- [Update global matrix + write project skills to Serena] (Recommended) — Add uncatalogued
  globals to `skill-routing-matrix.md` and write project-local skills to Serena memory
  `skill_inventory`
- [Write project skills to Serena only] — Only update Serena memory with project-local
  skills; leave the global matrix unchanged
- [Just show me, don't change anything] — Display-only, no modifications

### Step 6 — Apply Updates (if confirmed)

**If Serena update confirmed:**
- Write or update Serena memory `skill_inventory` with project-local skills
- Include: skill name, description, what it does, when to route to it
- Format as a concise reference table

**If matrix update confirmed:**
- Edit `{skill-dir}/references/skill-routing-matrix.md`
- Add uncatalogued global skills to the Task → Skill Mapping table
- Mark unavailable skills (in matrix but not in environment) with a note

### Step 7 — Confirm Results

Display a concise summary of what was updated:
```
✅ Updated skill-routing-matrix.md — added [N] skills
✅ Updated Serena memory `skill_inventory` — [N] project skills
```

## Implementation Firewall Exception

This subcommand is an **operational maintenance task**, not source code implementation.
It edits only:
- `references/skill-routing-matrix.md` (advisor reference file)
- Serena memory `skill_inventory` (cross-session knowledge)

The implementation firewall does NOT apply here.

## Boundaries

**Will:**
- Scan the live skill environment
- Compare against the routing matrix
- Update routing matrix and Serena memory (with confirmation)

**Will Not:**
- Install, uninstall, or modify skills themselves
- Edit SKILL.md or any source code
- Make changes without explicit user confirmation
