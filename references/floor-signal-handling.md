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

**Trigger:** Floor sentinel emits one of:

- `routing=missing` — neither
  `.serena/memories/skill_routing_matrix.md` nor
  `.claude/skill-routing-matrix.md` exists. Initial build needed.
- `routing=stale hash_diff=<current>:<stored>` — matrix exists, but the
  stored `inventory_hash` differs from a freshly-recomputed hash of the
  current agent inventory (`~/.claude/agents/*.md` filenames). The
  inventory has actually changed (additions, removals, renames) —
  rebuild is meaningful work, not waste.
- `routing=stale hash_diff=<current>:none` — matrix file exists but has
  no `inventory_hash:` field. Older matrix from a pre-v5.16.0 release,
  or the field was stripped. Treat as stale; rebuild populates the
  field.
- `routing=stale hash_compute_failed` — sha256 backend missing or hash
  compute errored. Defensive fail-stale; rare, indicates a hook
  environment issue (e.g., neither `sha256sum` nor `shasum` on PATH).
- `routing=stale hash_compute_failed inventory_unavailable` —
  `~/.claude/agents/` is missing or empty so the hash cannot be
  computed. Fail stale rather than emit a placeholder hash that would
  never match Agent D's. Rebuild dispatches and reseeds the inventory.

`routing=fresh hash=<short>` is the no-action case: the cached matrix is
current, and no rebuild dispatches.

**Surface in orientation:** Note the matrix state in one line.
"Routing matrix is stale (inventory changed since last build) —
dispatching a background rebuild." or "No routing matrix found —
dispatching a background build."

**Dispatch parameters:**

- **Tool**: Agent (built-in)
- **Agent type**: `general-purpose`
- **Model**: `opus` (explicit — do not inherit the user-thread model)
- **`run_in_background`**: `true` (the SP continues advisory work
  without blocking)
- **Mode**: `acceptEdits` (the agent will write to Serena memory or to
  `.claude/skill-routing-matrix.md` depending on Serena availability)

**Prompt skeleton:**

```
You are building the SP routing matrix for the project at [PROJECT_PATH].

Read the system-reminder skill list available in this conversation, plus
the contents of these reference files:

- references/skill-routing-matrix.md (canonical task categories +
  inventory_hash protocol — Initialization Step 6 has the exact hash
  inputs and shell shape)
- references/startup-checklist.md § Step 5 detail (canonical persistence
  rules: Serena memory if active, .claude/skill-routing-matrix.md if not)
- .claude/agents/ (project-level custom agents — directory may not exist)
- ~/.claude/agents/ (user-level custom agents — directory may not exist)

For each available skill, match it to a task category from the routing
matrix reference. Build a markdown table with columns:
| Task Category | Best Tool | Why | Tier |

Compute the inventory_hash per references/skill-routing-matrix.md
Initialization Step 6 — the input (sorted basenames of
~/.claude/agents/*.md plus agent_count) and shell shape MUST match the
floor sentinel's Group 7 hook in SKILL.md so the next session sees
`routing=fresh`.

Persistence — write to ONE source of truth based on Serena availability:

- If Serena memory tools (mcp__plugin_serena_serena__*) are available
  in this conversation → write the matrix to Serena memory
  `skill_routing_matrix` via write_memory. The memory body includes the
  table + footer with inventory_hash + other metadata.
- If Serena memory tools are NOT available → write to
  .claude/skill-routing-matrix.md (full file replacement). The footer
  includes inventory_hash on a line of the form:
    inventory_hash: "sha256:<short>"

Do NOT write to both. Do NOT create .claude/sp-routing-matrix.md
(deprecated as of v5.16.0).

Include a header comment with today's date and the count of skills
mapped.

Return: one-line summary "Matrix built: N skills mapped, M custom agents
detected. Persistence: <serena|.claude>. inventory_hash: sha256:<short>."
Do not return prose explanations of individual mappings.
```

**Verification (the SP runs this in its own thread after the agent
returns):**

```
# When Serena was the persistence target:
mcp__plugin_serena_serena__list_memories
# expect skill_routing_matrix in the list

mcp__plugin_serena_serena__read_memory(memory_file_name="skill_routing_matrix")
# expect a markdown table with task categories AND a footer line:
# inventory_hash: "sha256:<short>"

# When .claude/skill-routing-matrix.md was the persistence target:
# Read the file directly and grep for the inventory_hash line:
grep '^inventory_hash:' .claude/skill-routing-matrix.md
# expect: inventory_hash: "sha256:<short>"
```

If the inventory_hash line is missing from the artifact, the next floor
sentinel run will still report `routing=stale hash_diff=...:none` and
re-dispatch. Surface this as a verification failure to the user.

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

## Pattern: output_style=<name> (always-visible status row)

**Trigger:** Floor sentinel always emits `g8.output_style=<value>` — one of:

- `strategic-partner-voice` — SP's recommended Output Style is active. Status row shows ✅.
- Any other style name (e.g., `explanatory`, `adaptive-visual`) — a different Output Style is active.
- `none` — no `outputStyle` field is set in any settings file.

The hook resolves the value from the settings files in precedence order
(`.claude/settings.local.json` → `.claude/settings.json` →
`~/.claude/settings.json`), using `jq` if available with a `grep`/`sed`
fallback. The hook does not read the runtime `# Output Style:` header
(that lives in the model's system prompt and is not visible to shell
hooks); the model side handles runtime-vs-settings disagreement —
see "Runtime authority" below.

**Always-visible status row pattern.** This is the only floor signal
that surfaces a permanent row in orientation regardless of state.
Other signals (conventions, memory, etc.) surface only when non-clean.
Output Style is always rendered so users can see at a glance whether
the recommended style is active and act if not.

**Surface in orientation:**

| `g8.output_style` value      | Row format                                                            | Hint? |
|------------------------------|-----------------------------------------------------------------------|-------|
| `strategic-partner-voice`    | `📌 Output Style: ✅ active`                                          | No    |
| `<other-name>` (e.g. `adaptive-visual`) | `📌 Output Style: ⚠️ not active (current: <other-name>)` | Yes   |
| `none`                       | `📌 Output Style: ⚠️ not active`                                      | Yes   |

When the row is `⚠️ not active`, render the activation hint immediately
beneath the row (two lines, plain English):

```
Activate: /config → Output Style → Strategic Partner Voice
Or: set outputStyle: strategic-partner-voice in ~/.claude/settings.json
```

**Runtime authority — model-side conflict detection.**

The hook reports the settings-resolved value. The model — which has
direct visibility of its own system prompt's `# Output Style:` header
— compares that header to `g8.output_style` from the floor signal.

- If they agree → render the row per the table above; no extra line.
- If they disagree → render the row using the runtime header value
  (the runtime header is what the harness actually applies for the
  session), then add a brief disagreement note beneath the row:
  `⚠️ settings/runtime mismatch — likely needs a session restart to
  reconcile (settings: <settings-name>, runtime: <runtime-name>)`.

**Anti-pattern: do not infer the runtime header from system-reminders or
`additionalContext` blocks.** Plugin SessionStart hooks (e.g.,
`explanatory-output-style@claude-plugins-official`) inject text like
*"You are in 'explanatory' output style mode"* into the conversation
regardless of the actual `outputStyle` setting. That injected text is
not authoritative. The runtime ground truth is the `# Output Style:`
header at the top of the system prompt — read that, not the
plugin-injected reminder.

**Backwards-compat fallback (transitional).**

If the floor signal does not carry `g8.output_style` (a session running
an older floor sentinel during the transition), the orientation
rendering falls back to a direct settings-file read using the same
precedence order as the hook. After 1-2 release cycles past v6.3, the
fallback can be removed — the field is universally present.

**No AUQ pressure.** The status row is informational. When inactive,
the activation hint is rendered but no `AskUserQuestion` fires.
Respects users who have made an explicit non-`strategic-partner-voice`
choice. Users who want to switch see the hint and act when they want.

**No dispatch.** Activation requires user action (settings change or
`/config`); the SP cannot programmatically change the active Output
Style.

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

## Pattern: oldschema=N (migration offer)

**Trigger:** Floor sentinel emits `oldschema=N` (N≥0) — the count of
`.backlog/*.md` items still written under the pre-v6.4 backlog schema
(see `references/floor.md` § Group 4 for the detection; the predicate is
the canonical one from `.scripts/migrate-backlog.sh`, referenced not
restated).

This replaces the old soft startup-prose trigger. Previously the
migration offer was model-behavior prose chained to the orientation
flow; continuation-heavy sessions abbreviated past it, so it had zero
field adoption. The offer is now driven off this deterministic floor
field, which the model acts on reliably.

**Surface in orientation:**

| Condition | What SP does |
|---|---|
| `oldschema=0` | Silent. Steady state — say nothing. |
| `oldschema=N>0` AND `.handoffs/migration-deferred-v6.4.flag` absent | Surface the existing one-time migration prompt via `AskUserQuestion` — options **Migrate now** / **Preview** / **Skip**, unchanged from § Backlog Auto-Migration in SKILL.md. |
| `oldschema=N>0` AND the defer flag present | Quiet one-line banner only (the existing banner), NOT the full prompt: `N items in old schema; run the migration script to upgrade`. |

The prompt, the defer-flag mechanism, the banner copy, and
`.scripts/migrate-backlog.sh` are reused exactly as-is — only the
trigger moved from startup prose to this floor field.

**Scope and disclosure:**

- The offer is surfaced only when SP runs in the project (SP-session
  scoped) — it is not a global background migration.
- The count covers old-schema **frontmatter** items only.
  Frontmatter-less `.backlog/*.md` files are a separately-tracked,
  out-of-scope blind spot — the prompt/banner must not imply
  "migration handled" generally.

**No dispatch.** Migration is the user's choice via the prompt; SP
never auto-migrates.

**Rule-5 coverage — intentionally not extended (read this):** the Stop
rhythm enforcer's rule 5 (`floor-signal-acknowledgment`) is the runtime
backstop that catches silently-ignored actionable floor signals.
`oldschema` is deliberately **not** added to rule 5's covered-signal set
in this change. This is not an oversight. The reliable handling of this
signal rests on the floor + orientation path, which is empirically
verified (real BAM-MVP transcripts show the model acts on actionable
floor signals at a high rate, versus the prior prose trigger's 0%).
Extending the audit backstop to `oldschema` is a tracked hardening
follow-up (`.backlog/harden-migration-signal-stop-rule-backstop.md`),
not part of this scope. A future reader should not conclude rule-5
coverage was forgotten.

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
