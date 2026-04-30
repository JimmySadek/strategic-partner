# Floor-Signal Handling — Canonical Patterns

Implementation-level reference for the SKILL.md § Floor-Signal Handling
table. Each non-clean signal from the startup-floor sentinel
(`SP-FLOOR-COMPLETE` line) gets a worked example of the expected
remediation pattern: agent type, model, prompt skeleton, verification,
and post-dispatch state.

The summary table in SKILL.md tells the SP **what** to do for each signal.
This document tells the SP **how** — exact dispatch parameters, prompt
shapes, and verification commands the model should run.

Default model for any remediation dispatch is **Opus 4.7** with
`run_in_background: true`. These are load-bearing decisions that
propagate through every downstream session, so synthesis quality
matters more than dispatch speed.

---

## Pattern: routing=missing or routing=stale

**Trigger:** Floor sentinel emits `routing=missing` (no
`.serena/memories/skill_routing_matrix.md`) or `routing=stale`
(matrix exists but file mtime is older than 1 hour).

**Surface in orientation:** Note the matrix state in one line.
"Routing matrix is stale (last refreshed Nh ago) — dispatching a
background rebuild." or "No routing matrix found — dispatching a
background build."

**Dispatch parameters:**

- **Tool**: Agent (built-in)
- **Agent type**: `general-purpose`
- **Model**: `opus` (explicit — do not inherit the user-thread model)
- **`run_in_background`**: `true` (the SP continues advisory work
  without blocking)
- **Mode**: `acceptEdits` (the agent will write to the Serena memory
  file under `.serena/memories/`)

**Prompt skeleton:**

```
You are building the SP routing matrix for the project at [PROJECT_PATH].

Read the system-reminder skill list available in this conversation, plus
the contents of these reference files:

- references/skill-routing-matrix.md (canonical task categories)
- .claude/agents/ (project-level custom agents — directory may not exist)
- ~/.claude/agents/ (user-level custom agents — directory may not exist)

For each available skill, match it to a task category from the routing
matrix reference. Build a markdown table with columns:
| Task Category | Best Tool | Why | Tier |

Then write the table to .serena/memories/skill_routing_matrix.md (full
file replacement is fine — this is the canonical version). Include a
header comment with today's date and the count of skills mapped.

Return: one-line summary "Matrix built: N skills mapped, M custom agents
detected." Do not return prose explanations of individual mappings.
```

**Verification (the SP runs this in its own thread after the agent
returns):**

```
mcp__plugin_serena_serena__list_memories
# expect skill_routing_matrix in the list

mcp__plugin_serena_serena__read_memory(memory_file_name="skill_routing_matrix")
# expect a markdown table with task categories
```

**Post-dispatch hygiene:**

- Note completion in the next user-facing turn ("Routing matrix
  refreshed in the background — N skills mapped.").
- No `.handoffs/` write needed for this remediation; the matrix file
  is the artifact.

---

## Pattern: memory=missing

**Trigger:** Floor sentinel emits `memory=missing` (no
`.serena/memories/` directory exists in the project).

**Critical**: This is held to a higher bar than `routing=missing`.
Serena onboarding writes 5+ memories with project analysis, which is a
heavier intervention than building a routing matrix. **Always ask the
user before dispatching.**

**Surface in orientation:** Mention the missing memory state and
recommend onboarding. Frame as a one-time investment.

> "No Serena memories found for this project. Onboarding is recommended
> — it analyzes the codebase and writes 5+ memories (project overview,
> codebase structure, conventions) that the SP uses for cross-session
> context. Want to run it now?"

Wrap the question in `AskUserQuestion`. Options:

- [Yes, run onboarding now]
- [Skip — I'll run it later via `mcp__plugin_serena_serena__onboarding`]
- [What does onboarding write?]

**Dispatch parameters (only after user confirms):**

- **Tool**: Agent (built-in)
- **Agent type**: `general-purpose`
- **Model**: `opus` (explicit)
- **`run_in_background`**: `true`
- **Mode**: `acceptEdits`

**Prompt skeleton:**

```
You are running Serena onboarding for the project at [PROJECT_PATH].

Use these tools in order:
1. mcp__plugin_serena_serena__check_onboarding_performed — confirm not yet onboarded
2. mcp__plugin_serena_serena__onboarding — run the full onboarding workflow

The onboarding workflow will analyze the codebase and write the standard
memory set (project_overview, codebase_structure, code_style_and_conventions,
suggested_commands, task_completion_checklist). Do not modify the workflow
prompts; let onboarding handle the writes.

Return: one-line summary "Onboarding complete: N memories written" or, if
onboarding fails partway, the specific error and which memories were
written before the failure.
```

**Verification:**

```
mcp__plugin_serena_serena__list_memories
# expect at least project_overview, codebase_structure, code_style_and_conventions
```

**Post-dispatch hygiene:**

- Surface the memory list briefly to the user ("Onboarding complete:
  5 memories written, including project_overview and codebase_structure.").
- The next session's floor sentinel will pick up `memory=ok` automatically.

---

## Pattern: git=dirty

**Trigger:** Floor sentinel emits `git=dirty changed=N` (uncommitted
changes in the working tree).

**Acknowledgment-only pattern.** The SP does not auto-commit or
auto-stash. Surface the state, confirm the user is aware, and continue.

**Surface in orientation:** Single-line note.

> "Working tree has N uncommitted change(s). Carrying that into the
> session — let me know if you want me to surface them before any new
> work begins."

No `AskUserQuestion` required for this signal alone — it is informational
unless the user wants to act on it.

**If the user signals a session-end** with `git=dirty` still active, the
Closure Evidence Ledger's Git row escalates to DIRTY state, and an AUQ
fires there per the closure protocol. See SKILL.md § Closure Evidence
Ledger.

**No dispatch.** The SP never auto-commits source-file changes; that
falls outside the source-edit allow-list.

---

## Pattern: version=behind

**Trigger:** Floor sentinel emits `version=behind` (local SKILL.md
`version:` field is older than the latest GitHub release).

**Update-notice pattern.** Surface the available version and recommend
the user run `/strategic-partner:update` when convenient.

**Surface in orientation:** One-line update notice.

> "Update available: vLOCAL → vREMOTE. Run `/strategic-partner:update`
> when convenient — the update brings [one-line summary if known from
> the release notes]."

If the SP can fetch the release notes summary cheaply (single curl,
already cached from the floor sentinel's Group 6 work), include the
one-line summary; otherwise omit and let the user decide.

**No automatic update.** The SP never invokes `/strategic-partner:update`
on the user's behalf. The update flow has its own confirmation step.

**No dispatch.** The user runs the update subcommand directly.

---

## Pattern: conventions=missing

**Trigger:** Floor sentinel emits `conventions=missing` (no `CLAUDE.md`
in the project root).

**Acknowledgment-only pattern.** Note the absence; suggest creation if
the project warrants it.

**Surface in orientation:** Single-line note.

> "No project rules file (`CLAUDE.md`) in this directory. The SP will
> rely on global rules for now. If this project has its own conventions
> worth pinning, I can propose a starter `CLAUDE.md` when you want."

No `AskUserQuestion` required at startup — it surfaces the gap and lets
the user decide whether to invest in a rules file.

**If the user later asks** about adding project rules, the SP proposes
content via `AskUserQuestion` and writes after confirmation (CLAUDE.md
is in the source-edit allow-list).

**No dispatch.** The SP creates the file directly when the user
confirms.

---

## Pattern: findings=N (informational)

**Trigger:** Floor sentinel emits `findings=N` where N≥0 (the count of
`.handoffs/findings-*.md` files in the project).

**Standard surface pattern.** The count is always present; only act on
it when N>0.

**Surface in orientation:** When N>0, scan the most recent findings
file and surface unresolved issues.

> "N unresolved findings from [date]. Promote any to backlog, or
> continue — they carry forward."

When N=0, skip silently.

**No dispatch.** Findings are session-scoped notes; the SP reads and
references them but does not auto-promote without user confirmation.

---

## Pattern: backlog=N (informational)

**Trigger:** Floor sentinel emits `backlog=N` where N≥0 (the count of
`.backlog/*.md` files).

**Standard trigger-check pattern.** When N>0, evaluate each backlog
item's `trigger` field against current state and surface actionable
items per `commands/backlog.md` Step 3.

**Surface in orientation:** When triggers are met, list actionable
items by name.

> "Backlog item [Title] — trigger met: [reason]."

If no items are actionable: single-line count.

> "N backlog items parked, none actionable."

When N=0, skip silently.

**No dispatch.** The user runs `/strategic-partner:backlog` for the
full table; orientation only flags actionable items.

---

## When to Add a New Pattern

Add a new pattern entry when:

1. A new floor field is added to the `SP-FLOOR-COMPLETE` line in
   SKILL.md (the hook frontmatter's UserPromptSubmit handler).
2. The new field has a non-clean state that requires a remediation
   action (dispatch, AUQ, or surface-and-defer).
3. The remediation differs from the patterns above in any of: agent
   type, model, prompt structure, or verification step.

If a new field is purely informational (like `findings` or `backlog`),
the standard surface-and-reference pattern is sufficient — no new
section needed unless the surface logic differs meaningfully.

When adding a pattern, mirror the structure used above:

- **Trigger** — exact field=value condition
- **Surface in orientation** — what the user sees
- **Dispatch parameters** (if applicable) — agent, model, mode, background
- **Prompt skeleton** with `[PLACEHOLDER]` markers
- **Verification** — commands the SP runs to confirm completion
- **Post-dispatch hygiene** — what the SP does after the agent returns

Update the SKILL.md § Floor-Signal Handling summary table in the
same release as the new pattern.

---

## Cross-Reference

| Reference | Relationship |
|---|---|
| `SKILL.md` § Floor-Signal Handling | Summary table — what to do per signal |
| `references/floor.md` | Floor sentinel protocol — how `SP-FLOOR-COMPLETE` is emitted |
| `references/startup-checklist.md` | Broader startup orientation (post-floor) |
| `references/orchestration-playbook.md` | Agent dispatch patterns (Pattern A/B for fire-and-verify) |
