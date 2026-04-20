# Implementation Prompt Crafting Guide

Reference file for the strategic-partner advisor. Standards for crafting implementation
prompts across target models.

```
Discovery Protocol → Alternatives Analysis → Routing Decision Tree → Parallelization Check → Quality Check → Format Selection (Claude XML / GPT-5.4 XML / Gemini MD / Hybrid) → Deliverable Type (Prompt vs Script) → Post-Craft Verification → Save Decision → Launcher
```

---

## Prompt Quality Requirements

Every implementation prompt must:

1. **Skill resolved via the routing decision tree** (see `references/skill-routing-matrix.md` for the base matrix) — walk the scope + complexity tree (see Mandatory Pre-Craft Analysis) before writing line 1. Never default to a remembered skill name or copy one from an example. The first line must be the bare skill command — no backticks, no headers above it, no "Run:" prefix
2. **Be fully self-contained** — the implementer has no access to the advisor conversation
3. **Specify exactly which files to read** — before touching anything
4. **List deliverables precisely** — files, functions, tests, CHANGELOG entries
5. **Include project constraints** — pre-existing failures, feature flags, naming conventions
6. **Specify the model** — every prompt involving agents must name Opus or Sonnet explicitly
7. **End with the expected commit message** — conventional-commit format
8. **Leave no ambiguity** — nothing that would require follow-up questions
9. **Match format to target model** — Claude: XML tags; GPT-5.4: flat XML tags; Gemini: Markdown headers (see Format Selection)
10. **Specify the target branch** — if the project uses feature branches, name the branch in the prompt's `<context>` section so the implementer works in the right place
11. **Include NOT-in-scope exclusions** for multi-file prompts — name specific adjacent temptations the executor will face (optional for single-file fixes)
12. **Label recommendations [✅ SAFE] or [⚠️ RISK]** — signal whether a recommendation is established practice or an opinionated position (skip for factual statements)

---

## 🔴 Mandatory Pre-Craft Analysis

**🚨 STOP. Complete both analyses below BEFORE writing any prompt.** These are not
optional guidance — skipping them is a quality gate failure.

### Step 0: Discovery Protocol

Before routing, confirm you can answer all 4 discovery questions:

1. **Goal**: What is the user trying to achieve? (the outcome, not the task) — **see Premise Challenge below**
2. **Prior work**: What has already been tried or decided? (check handoff files, Serena decision_log, conversation history)
3. **Constraints**: What constraints exist? (CLAUDE.md rules, tech stack, time, existing patterns)
4. **Definition of done**: What does "done" look like? (concrete, verifiable deliverables)

If ANY answer is unknown or ambiguous, use `AskUserQuestion` to clarify BEFORE
proceeding to routing. Do not guess — the prompt cannot ask follow-up questions.

For continuation tasks (handoff or prior prompt), answers 2 and 3 may already be
established. Still verify 1 and 4 — goals shift and definitions of done evolve.
Alternatives (Step 0b) may also be pre-decided in continuation sessions.

If all 4 are answerable from conversation context, state your understanding of each
briefly (1 line per question) and proceed to Step 0b. Do not ask questions you can
answer yourself — but do state the answers so the user can correct misunderstandings.

**Quality gate**: If you reach Step 0b (Alternatives) without being able to articulate
the goal and definition of done, STOP and go back. A well-routed prompt for the
wrong goal is worse than no prompt at all.

#### Premise Challenge (conditional depth increase on Q1)

When a request assumes a solution rather than stating a problem, push harder on Q1
before accepting the framing. This is not a separate protocol — it is a conditional
escalation that activates when smell triggers fire.

**Trigger conditions** — any one activates the challenge:

| # | Trigger | Example |
|---|---------|---------|
| 1 | Names a specific technology as the starting point | "add caching", "use Redis" |
| 2 | Describes HOW before WHY | "refactor to use GraphQL" |
| 3 | Assumes a root cause without evidence | "the database is slow" |
| 4 | Solution-shaped rather than problem-shaped | "build a queue" vs "users see stale data" |

**When any trigger fires**, ask via `AskUserQuestion`:
- "What evidence points to [assumed cause]?"
- "What happens if we do nothing?"
- "Is there a simpler explanation?"

**When no triggers fire**, Q1 proceeds as written — no extra questions.

**Edge case**: If the user has already provided evidence and rationale (e.g., in a
handoff, prior session, or detailed request), acknowledge it and move on. Premise
challenge is a smell check, not an interrogation.

### Step 0b: Alternatives Analysis

After discovery and BEFORE routing, for non-trivial tasks the SP presents 2–3 distinct
approaches. The user picks a path via `AskUserQuestion`. THEN the SP routes and crafts.

```
Discovery (Step 0) → Alternatives (Step 0b) → Routing (Step 1) → Craft
                          ↑                                         ↑
                    "Which path?"                          "Here's the prompt"
```

**Three paths:**

| Path | Description | Purpose |
|---|---|---|
| **A — Minimal** | Smallest change that solves the stated problem | Low risk, fast, may leave debt |
| **B — Recommended** | What the SP would actually suggest, with rationale | Balanced — the SP's best judgment |
| **C — Lateral** | Reframing the problem or a creative alternative | May unlock a better outcome entirely |

Each path: 2–3 sentences + the key trade-off. The SP states which path it recommends
and why. Present via `AskUserQuestion`:
`[Path A — Minimal]` `[Path B — Recommended]` `[Path C — Lateral]` `[Just do what you'd recommend]`

**Example — "Add caching to the API layer":**

| Path | Approach | Trade-off |
|---|---|---|
| **A — Minimal** | Add response-level HTTP cache headers (`Cache-Control`, `ETag`) on the 3 slowest endpoints. No new infrastructure. | Fast to ship, but only helps repeat requests from the same client. |
| **B — Recommended** | Introduce an in-process LRU cache (e.g., `lru-cache` or `@isaacs/ttlcache`) keyed by query params, with a 60s TTL. Requires invalidation strategy for write-after-read. | Covers all clients, moderate complexity, no external dependencies. |
| **C — Lateral** | Profile the actual bottleneck first (`--inspect` + flame graph). The "slow API" may be N+1 queries or missing indexes — caching would mask the real problem. | Slower to start, but might eliminate the need for caching entirely. |

**→ Recommendation: Path C.** The request assumes caching is the fix, but we haven't
confirmed what's actually slow. 30 minutes of profiling could save a week of cache
invalidation bugs.

**Skip conditions** (alternatives NOT required):

| Condition | Rationale |
|---|---|
| Fast Lane tasks (scored 4–5/5 on simplicity) | Mechanical — no design judgment needed |
| Continuation tasks with approach already decided | Re-litigating wastes time |
| Single-file mechanical changes | One obvious path |
| User explicitly overrides ("just do X") | User has already chosen |

**Quality gate**: If alternatives are required (non-trivial task, not skipped) but
not presented before routing, the prompt **FAILS**. Go back to Step 0b.

### Step 1: Routing Decision Tree

Replace flat matrix lookup with structured routing. Walk the tree top-to-bottom.

**Scope routing** (determines skill category):

```
What is the scope of this task?
├── Single file, single concern
│   └── quick-task skill (look up in routing matrix — see references/skill-routing-matrix.md)
├── Focused feature (1-3 files, clear spec)
│   └── feature-dev skill (look up in routing matrix)
├── Multi-phase feature (4+ files, needs design)
│   └── plan + execute workflow (look up in routing matrix)
├── Bug investigation
│   └── debugging skill (look up in routing matrix)
├── Code quality pass (lint, refactor, cleanup)
│   └── analyze + improve chain (look up in routing matrix)
└── Architecture change (new patterns, system redesign)
    └── research + design + plan + execute chain (look up in routing matrix)
```

**Complexity routing** (determines deliverable type):

```
What is the complexity?
├── Mechanical (config, setup, file moves, JSON/YAML edits)
│   └── Generate .scripts/ bash script — no prompt needed
├── Requires code reasoning (design decisions, bug fixing, refactoring)
│   └── Generate implementation prompt
└── Mixed (some mechanical setup + some code reasoning)
    └── Generate BOTH: .scripts/ for mechanical part, .prompts/ for judgment part
```

**After routing**: The skill command on line 1 of the prompt MUST match the
decision tree output. If it doesn't, re-route — don't rationalize a mismatch.

### Step 2: Parallelization Check (Thinking Tool)

Answer all four questions before writing the prompt body. Record answers explicitly.
Use this as a thinking tool to decide whether `<orchestration>` adds value — not as
a hard fail gate. Opus 4.7 plans parallelism well by default; `<orchestration>` is
for cases where the executor needs explicit coordination instructions.

| # | Question | If YES → | If NO → |
|---|----------|----------|---------|
| 1 | Can this task be split into 2+ independent file changes? | Consider `<orchestration>` with parallel agents | Continue |
| 2 | Does this task have a research phase and a build phase? | Consider sequential phases, parallel within each | Continue |
| 3 | Are there 3+ deliverables that don't depend on each other? | Consider parallel agent per deliverable group | Continue |
| 4 | Is this a single-file, single-concern change? | No orchestration needed, single skill | Re-evaluate Q1-3 |

**Recommendation**: If YES answers on Q1-3 indicate **genuine parallelism**
(independent subtasks, no shared state, latency-hiding matters), add an
`<orchestration>` section. If the parallelism is incidental or the executor
can plan it alone, skip the section — an unnecessary `<orchestration>` block
adds noise without value.

### Step 3: Delivery Routing

Determine HOW the prompt will be delivered. This decision happens here — during
pre-craft analysis — not as an afterthought after crafting.

```
How should this task be delivered?
├── Run the 5-question simplicity assessment:
│   1. Does it require design judgment?
│   2. Are there multiple valid implementations?
│   3. Are requirements uncertain or ambiguous?
│   4. Does it cross architectural boundaries?
│   5. Could it break unrelated functionality?
│
├── Score 5/5 or 4/5 NO?
│   └── Fast Lane — present dispatch option via AskUserQuestion
│         [Dispatch via agent] [Give me the prompt] [Bigger than it looks]
│         (4/5: mention the one concern to user)
├── Score 3/5 NO?
│   └── Borderline — present dispatch as an option alongside full prompt
└── Score ≤2/5 NO or otherwise
    └── Full prompt — ══ fences (inline or saved per size rules)
```

File count is a signal, not a gate. A 5-file mechanical rename scores 5/5.
A 1-file algorithm redesign scores 2/5.

**🔴 Quality gate**: Record the delivery decision before writing the prompt.
If you skip this step and only realize the task is Fast Lane after crafting
a full prompt, you wasted context. Assess early.

---

## Format Selection

After routing and parallelization analysis, determine the prompt format based on the
target model. This is the **first structural decision** before writing the prompt body.

```
Which model runs the target session?
├── Claude → Load references/provider-guides/anthropic.md
├── OpenAI → Load references/provider-guides/openai.md
├── Gemini → Load references/provider-guides/google.md
└── Unknown → Default to Claude (most structured, degrades gracefully)
```

Provider guides contain format templates, tag references, rules, and examples.
Load the matching guide before writing the prompt body.

---

## Copy-Safe Formatting (Inline Prompts)

Inline prompts are rendered as markdown in Claude Code. When the user copies rendered
text, markdown syntax is stripped: bold becomes plain text, bullet markers disappear,
tables lose structure. Saved prompts do not have this problem (the executor reads raw
file content via the Read tool).

**Rule**: Inline prompt content inside ══ fences must use ONLY:

1. XML tags for structure — wrap the entire prompt content in a backtick code fence so tags survive as literal text. Without the wrapper, Claude Code's markdown renderer strips XML tags as HTML, losing all structural information.
2. Numbered lists (1. 2. 3.) for ordered items within tags
3. Plain text for everything else
4. Indentation for visual hierarchy

Do NOT use inside inline prompts:

1. Bold or italic markers (`**`, `*`, `_`)
2. Bullet lists with `-` or `*`
3. Markdown tables (`| col | col |`)
4. Markdown headers (`## Header`) — use XML tags instead
5. Nested code fences inside the prompt — for Anthropic-format prompts, wrap the ENTIRE prompt content in one code block to preserve XML tags. Do not nest additional code fences inside.

This rule applies to inline prompts only. Saved prompts (`.prompts/`) are read
as raw files and can use any formatting.

---

## 🔴 Post-Craft Self-Verification (Mandatory)

After writing the prompt, run this checklist before presenting it. **Every item
must pass.** If any item fails, fix the prompt — do not present a failing prompt.

| # | Check | ❌ Fails If... |
|---|-------|---------------|
| 1 | Skill command on line 1 matches routing decision tree | Copied from memory or example |
| 2 | `<context>` lists specific files with what to look for | Says "read the codebase" or "see relevant files" |
| 3 | `<instructions>` has numbered deliverables with file paths | Vague like "update the tests" |
| 4 | `<orchestration>` present if genuine parallelism warrants it | Q1-3 indicated independent subtasks with no shared state but no orchestration section |
| 5 | Each agent spawn has explicit model AND mode | Unspecified model or missing mode parameter |
| 6 | `<verification>` has testable checkboxes with commands/outcomes | Says "verify it works" without specifying HOW |
| 7 | Expected commit uses conventional-commit format | Missing or malformed `type(scope): description` |
| 8 | Prompt is fully self-contained | References "our earlier discussion" or "current approach" |
| 9 | Format matches provider guide (see references/provider-guides/) | Claude prompt uses Markdown, GPT-5.4 uses Claude tags, or Gemini uses XML |
| 10 | Inline prompt is copy-safe (no markdown formatting inside ══ fences) | Uses bold, `-` bullets, or tables inside an inline prompt |
| 11 | `<not-in-scope>` present for multi-file prompts with specific exclusions (see NOT-in-Scope Sections) | Missing for multi-file prompt, or contains vague platitudes ("keep changes minimal") instead of naming specific files, functions, or patterns to leave alone |
| 12 | Recommendations within the prompt are labeled [✅ SAFE] or [⚠️ RISK] where applicable | Opinionated recommendation presented as fact without signaling confidence level |
| 13 | Relevant blocks included for target model/task (see Reusable Prompt Blocks) | Missing blocks when task shape or target model clearly warrants them (e.g., multi-file refactor without `<subagent_usage>`, pattern-application task without `<scope_explicit>`, long agentic task without `<context_awareness>`) |

**🚨 If any row fails**: Fix the prompt before presenting. Do not present with
a note saying "you might want to add..." — the prompt must be complete.

---

## NOT-in-Scope Sections

`<not-in-scope>` sections name specific files, features, or patterns the executor
must NOT touch, even if they seem related. Without explicit exclusions, executors
fill silence with scope creep — refactoring adjacent code, updating tangential tests,
or "improving" things that weren't asked for. This section prevents that.

### When required

| Prompt type | Requirement |
|---|---|
| Multi-file (2+ files modified) | **Mandatory** — prompt FAILS verification without it |
| Single-file changes | Optional — include if adjacent temptations are obvious |

### What makes a good exclusion

Each exclusion must name a **specific temptation** — a concrete file, function, module,
or pattern the executor will encounter and might be tempted to change. Generic warnings
("keep changes minimal") do nothing because the executor doesn't know what "minimal" means
in this codebase.

**Good — specific and actionable:**

```xml
<not-in-scope>
  1. Do NOT refactor the existing UserService class — only add the new method
  2. Do NOT update the migration files — schema changes are a separate PR
  3. Do NOT add error handling to the legacy endpoints in routes/v1/
  4. Do NOT convert existing tests to the new test helper pattern
</not-in-scope>
```

**Bad — vague platitudes that provide no guidance:**

```
Do NOT in scope:
- Don't make unnecessary changes
- Keep the scope focused
- Avoid breaking things
- Only change what's needed
```

### How to identify exclusions

When crafting a multi-file prompt, ask: "What adjacent changes will the executor see
an opportunity for and be tempted to make?" Common categories:

- **Refactoring neighbors**: Files the executor must read but must not refactor
- **Pattern migration**: Existing code using an old pattern that the new code replaces — don't migrate the old code in this prompt
- **Test expansion**: Existing tests that could be updated to use the new feature but shouldn't be touched here
- **Dependency upgrades**: Libraries that could be bumped while making the change
- **Style fixes**: Linting or formatting issues the executor will notice in files they're reading

---

## Real Examples

> **Note**: These examples use specific skill names from one environment for
> concreteness. When crafting actual prompts, **always resolve the skill command
> from the routing matrix** (see `references/skill-routing-matrix.md`) — never copy a skill name from these examples directly.

### Example 1: Simple Bug Fix

```
/[quick-task skill from routing matrix]

<context>
  Read first:
  1. docker/entrypoint.sh — the auth flow around line 120-140
  2. CLAUDE.md — "CMRAD Credential Persistence" section

  Project conventions:
  - Credentials stored as email\ntoken (chmod 600)
  - Environment-scoped: cmrad_credentials.dev / cmrad_credentials.prod
</context>

<instructions>
  Fix token validation failing silently when the research API returns HTTP 500.
  Currently only 401 is treated as "expired" — 500 should trigger a retry with
  backoff, not a silent pass-through.

  Deliverables:
  1. docker/entrypoint.sh — update validate_stored_token() to retry on 500

  Constraints:
  - Network failures (timeout, DNS) must still pass through (offline tolerance)
  - Max 2 retries with 1s backoff
  - Log retry attempts to stderr
</instructions>

<verification>
  - [ ] HTTP 401 → token treated as expired (existing behavior)
  - [ ] HTTP 500 → retry up to 2x, then treat as expired
  - [ ] Network timeout → pass through (no retry)
  - [ ] Successful validation → proceed normally
</verification>

Expected commit: "fix(auth): retry token validation on HTTP 500 with backoff"
```

### Example 2: Multi-Agent Feature

```
/[feature implementation skill from routing matrix]

<context>
  Read first:
  1. docker/cli/ — understand existing CLI wizard patterns
  2. docker/mcp/cmrad_mcp.py — current MCP server implementation
  3. CLAUDE.md — "API has two namespaces" section

  Project conventions:
  - Python CLI uses rich library for formatting
  - MCP server uses FastMCP framework
</context>

<instructions>
  Add a new "list teams" wizard to the CLI that fetches teams from the
  versioned API endpoint /api/1.0/teams.

  Deliverables:
  1. docker/cli/teams.py — new wizard module
  2. docker/cli/__init__.py — register the new wizard
  3. docker/mcp/cmrad_mcp.py — add list_teams tool

  Constraints:
  - Use Config.versioned_api_base() for the endpoint (strips /research suffix)
  - Follow existing wizard patterns (see docker/cli/credentials.py as reference)
  - Handle auth errors gracefully (token expired → redirect to login)
</instructions>

<orchestration>
  Spawn 2 agents in parallel:
    Agent 1 (Sonnet 4.6, mode: "acceptEdits"): Write docker/cli/teams.py + update __init__.py
    Agent 2 (Sonnet 4.6, mode: "acceptEdits"): Add list_teams tool to cmrad_mcp.py
</orchestration>

<verification>
  - [ ] `python -c "from cli.teams import TeamsWizard"` succeeds
  - [ ] MCP tool list_teams appears in tool registry
  - [ ] Both use Config.versioned_api_base() not hardcoded URLs
</verification>

Expected commit: "feat(cli): add list teams wizard and MCP tool"
```

### Example 3: Failing Prompt (What NOT to Do)

> **Note**: This example shows what goes wrong when the post-craft verification
> checklist is skipped. Every issue below maps to a specific checklist item.

```
/sc:implement

Fix the authentication flow. It's broken when users try to log in
with SSO. Check the auth files and make it work.

Also update the tests.

Expected commit: "fix: auth"
```

**Failures (mapped to post-craft verification checklist):**

| # | Check | Issue |
|---|-------|-------|
| 1 | Skill from routing tree | No routing decision documented — copied from memory? |
| 2 | Self-contained | "SSO" and "broken" need context the implementer doesn't have |
| 3 | Files to read | "Check the auth files" — no file paths |
| 4 | Numbered deliverables | No deliverables section — "make it work" is not a deliverable |
| 5 | Model + mode | N/A (no orchestration) |
| 6 | Verification | No verification section |
| 7 | Commit format | "fix: auth" lacks scope and description |
| 8 | No ambiguity | Requires follow-up questions the implementer can't ask |
| 9 | Format matches target | No XML structure — missing context, instructions, verification |

Apply the post-craft verification checklist row by row. The corrected version would look like Example 1.

---

## Skill Chain Embedding

When a task requires multiple implementation sessions (a skill chain):

1. **List the full chain** in the first prompt with what each step produces
2. **Mark entry points** — which prompt to run first, what to verify before the next
3. **Carry context forward** — each prompt after the first should reference outputs of the prior
4. **Be explicit about ordering** — "Run this AFTER prompt A has been committed"
5. **Specify model per step** — each agent spawn in the chain gets an explicit model

Example (resolve each skill from the routing matrix — see `references/skill-routing-matrix.md`):
```
Prompt chain (run in order):
  1. Explore — Agent(Sonnet 4.6, [explorer-agent]) → produces architecture notes
  2. Design — Agent(Opus 4.7, [architect-agent]) → produces component spec
  3. Build — /[implementation skill] → implements from spec
  4. Review — /[review skill] → validates before merge
```

---

## Deliverable Type Routing

Before deciding format, determine what kind of deliverable this is:

```
Is this task deterministic terminal/filesystem operations
(config edits, package installs, file moves, directory setup,
 JSON/YAML editing, git operations, environment setup)?
  YES → Generate operational script (.scripts/)
  NO  → Generate implementation prompt (.prompts/ or inline)
  MIXED → Both: .scripts/ for mechanical part, .prompts/ for judgment part
```

**Signals that point to a script:**
- The task is a sequence of shell commands with predictable outcomes
- No AI judgment needed — a human could follow the steps mechanically
- File edits are data-driven (JSON config, YAML, env vars), not logic-driven
- The task involves installing, configuring, or setting up tooling
- The deliverable is "run these commands" not "write this code"

**Signals that point to a prompt:**
- The task requires understanding existing code and making design decisions
- Bug fixing, feature implementation, refactoring — anything needing code reasoning
- The output depends on reading and interpreting codebase patterns
- Creative problem-solving, architecture, testing strategies

---

## Script Format (for `.scripts/` deliverables)

When the deliverable is an operational script:

```bash
#!/bin/bash
# ============================================================
# [Project Name] — [Script Purpose]
# [Brief description of what this script does]
#
# Prerequisites: [what must exist/run before this]
# IMPORTANT: [critical warnings, e.g., "Close Obsidian first!"]
# ============================================================
set -euo pipefail

# --------------------------------------------------
# Pre-flight checks
# --------------------------------------------------
# Verify directories, tools, processes as needed

# --------------------------------------------------
# 1/N  [Step description]
# --------------------------------------------------
echo "1/N  [Step description]..."
# ... commands ...
echo "  ✅ [What was done]"

# ... repeat for each step ...

# --------------------------------------------------
# Done
# --------------------------------------------------
echo ""
echo "============================================================"
echo "✅  [Summary of what was accomplished]"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. [What to do after running this script]"
```

**Script quality standards:**
- `set -euo pipefail` — fail fast on errors
- Pre-flight checks: verify directories exist, required tools installed, conflicting
  processes not running (e.g., `pgrep -x "Obsidian"`)
- Numbered progress: `echo "1/N Description..."` for each major step
- Idempotent where possible: merge into existing config, check before creating
- Inline Python/jq for JSON manipulation (don't overwrite entire files)
- Summary at end with next steps
- Descriptive filename: `03-configure-plugins.sh`, `setup-git-remote.sh`

**Script display format (parallel to the prompt launcher):**

**RUN THIS IN TERMINAL:**

```
══════════════════ START 🟢 RUN ═══════════════════
chmod +x .scripts/[descriptor].sh && .scripts/[descriptor].sh
══════════════════= END 🛑 RUN ════════════════════
```

Label is always **outside** the `══` fence, matching the prompt launcher convention.

**Script save decision:**
Always save scripts to `.scripts/[descriptor].sh`. Scripts are never presented inline
(unlike short prompts) — they are always files because they need to be executable.

---

## Delivery Decision

The Fast Lane assessment was already made in Step 3 of the pre-craft analysis.
This section covers the **save/inline decision for full prompts**.

```
Save Decision:
├── >250 lines OR >5 deliverables?
│   ├── YES → Save to .prompts/[milestone]/[descriptor].md
│   └── NO  → Present inline with ══ fences
```

**Quality gate**: The prompt MUST still pass all quality requirements
(routing, self-contained, verification steps) regardless of delivery mechanism.
A fast lane prompt is shorter, not lower quality.

---

## Prompt Presentation Decision (Single Evaluation — No Redundant Questions)

This is the **only** decision point for how a prompt is presented. Evaluate once,
act immediately. Do NOT present the prompt and then ask about presentation format —
that wastes tokens and looks redundant to the user.

```
Is the prompt >250 lines OR >5 deliverables?
  YES → Save to .prompts/[milestone]/[descriptor].md
        AskUserQuestion before saving (ask-before-act applies)
        Display: COPY-PASTEABLE LAUNCHER (see Launcher Format below)
  NO  → Present inline WITH ═══ fences — immediately, no confirmation needed
        The ═══ fences ARE the presentation. Do not show the prompt first
        and then ask "inline or save?" — that is the exact anti-pattern this
        rule prevents.
```

**Why 250 lines?** Implementation prompts run in fresh sessions with a full context
window. They also leverage `<orchestration>` sections that fan out to subagents —
the prompt is a compact orchestration plan, not a monolithic task consuming the
entire context.

When saving to `.prompts/`:
- Use descriptive filenames: `phase1-auth-middleware.md`, `bugfix-token-expiry.md`
- Group by milestone/version: `.prompts/v1.4/`, `.prompts/v1.5/`
- Always AskUserQuestion before saving (ask-before-act applies)

---

## ═══ Fence Format (Mandatory for ALL Prompts)

The ═══ fences are mandatory for **every** prompt — inline AND saved. They give
the user a clear, unambiguous copy boundary.

### Inline Prompt (≤250 lines AND ≤5 deliverables)

Present the full prompt inside the fences. This is a one-shot output — no follow-up
question needed.

> **🎯 Routing**: `[skill-from-routing-matrix]` — [why this skill fits: task scope, complexity, what it handles that alternatives don't].

**COPY THIS INTO NEW SESSION:**

══════════════════ START 🟢 COPY ══════════════════
````
/[skill-name]

<context>
  ...
</context>

<instructions>
  ...
</instructions>

<verification>
  ...
</verification>

Expected commit: "type(scope): description"
````
══════════════════= END 🛑 COPY ═══════════════════

> **Note**: The backtick code fence wrapper is required for Anthropic-format
> prompts (which use XML tags). Claude Code's markdown renderer strips XML as HTML without
> this wrapper, losing all structural information. Non-Anthropic formats (GPT-5.4, Gemini)
> that don't use XML tags do not need the wrapper.

### Saved Prompt Launcher (>250 lines OR >5 deliverables)

When a prompt is saved to `.prompts/`, display a short launcher the user can
copy-paste into a new Claude Code session:

> **🎯 Routing**: `[skill-from-routing-matrix]` — [why this skill fits: task scope, complexity, what it handles that alternatives don't].

**COPY THIS INTO NEW SESSION:**

══════════════════ START 🟢 COPY ══════════════════
/[skill-name]

Read the implementation prompt at .prompts/[milestone]/[descriptor].md and execute all deliverables.
══════════════════= END 🛑 COPY ═══════════════════

### Requirements (both formats)
- Label ("COPY THIS INTO NEW SESSION") is always outside the ═══ fence
- First line inside fence: bare skill command (no backticks) — dynamic per task
- Nothing else outside the fences — no headers, no summaries, no backticks around commands
- When multiple prompts exist, each gets its own START/END block
- **Routing rationale is mandatory BEFORE the fences** — a `> 🎯 Routing:` blockquote explaining why this skill was chosen (or why no skill was needed). This educates the user on SP routing decisions

### Post-Prompt Protocol: Wait for Report Back

After delivering a fenced prompt or script launcher: **close the END 🛑 fence first**,
then state you're waiting for the report back OUTSIDE the fence. Do not offer follow-up
options, suggest next tasks, or present "what's next?" menus. The wait message is your
prose to the user, not part of the copyable prompt — it must come after the closed fence.

The user will execute the prompt in a separate session and return with results.
Resume only when they report back. Neither side skips their turn.

**When the user reports back:**
1. Verify: "Did it commit?" → check `git log --oneline -3` if available
2. Review: Ask about any issues, unexpected behavior, or deviations
3. Assess: Is the task complete? Follow-up fixes needed?
4. Extract: Any lessons learned for CLAUDE.md or Serena memory?
5. Then — and only then — propose the next task or prompt

---

## Anti-Patterns

- ❌ **Vague deliverables**: "update the tests" → specify which test file, which cases
- ❌ **Missing context**: "fix the auth bug" → specify the symptom, file, line range
- ❌ **Assumed knowledge**: "use the same pattern as before" → spell it out
- ❌ **Skill omission**: starting with implementation details → start with skill invocation
- ❌ **Hardcoded skill names**: copying a skill name from examples, memory, or prior prompts → always look up the routing matrix (see `references/skill-routing-matrix.md`) for the best match for THIS specific task
- ❌ **Ambiguous ordering**: "also do X" → explicitly state if X is sequential or parallel
- ❌ **Backtick-wrapped commands**: wrapping the skill command in backticks renders as code, not executable → bare command on line 1
- ❌ **Headers before skill command**: `# Implementation Prompt` above the command → skill command must be line 1
- ❌ **No launcher for saved prompts**: "go read .prompts/v1.5/phase1.md" → provide COPY-PASTEABLE LAUNCHER block
- ❌ **Missing model specification**: "Spawn an agent" without specifying sonnet/opus
- ❌ **Missing mode on agent spawns**: Background agents fail silently without mode specification → always include `mode` parameter
- ❌ **Format mismatch**: Using Claude XML tags for GPT-5.4 or Gemini targets, or GPT-5.4 tags for Claude → match the format from Format Selection to the target model
- ❌ **Over-prompting**: "Always use Serena for every search" → use conditional triggers
- ❌ **Pre-4.x holdovers**: Excessive repetition, sycophancy-bait phrasing
- ❌ **Prompt for config edits**: Writing a Claude prompt to edit JSON configs → generate a `.scripts/` bash script instead
- ❌ **Manual steps in markdown**: "Run these commands: 1. cd ... 2. npm install ..." → wrap in an executable script
- ❌ **Script without pre-flight**: Missing directory/tool checks → always validate prerequisites
- ❌ **Destructive scripts**: Overwriting entire config files → merge into existing (use Python/jq for JSON)
- ❌ **Missing routing rationale**: Presenting fenced prompt without the `> 🎯 Routing:` line → always explain the skill choice (or no-skill choice) before the fences
- ❌ **Premature "what's next?"**: Offering follow-up options immediately after a prompt → STOP and wait for user to report back from execution
- ❌ **Skipped parallelization check**: Writing prompt without answering the 4-question checklist → ALWAYS complete the parallelization check before writing
- ❌ **Missing orchestration when genuinely parallel**: Q1-3 indicated independent subtasks with no shared state, but no `<orchestration>` section → add one. Conversely, don't force `<orchestration>` when Q1-3 fires on incidental parallelism — an unnecessary block adds noise
- ❌ **Skipped routing decision tree**: Picking a skill from memory instead of walking the scope + complexity tree → ALWAYS route through the decision tree
- ❌ **Skipped post-craft verification**: Presenting prompt without running the 13-item checklist → ALWAYS verify before presenting
- ❌ **Intuitive routing**: "This feels like a quick-task" without walking the tree → trust the tree, not intuition
- ❌ **Markdown in inline prompts**: Using bold, `-` bullets, or `| tables |` inside ══ fences — stripped on copy-paste → use XML tags + numbered plain text instead
- ❌ **Missing not-in-scope**: Multi-file prompt without a `<not-in-scope>` section → executors fill silence with features; name the specific adjacent changes to leave alone
- ❌ **Vague scope exclusions**: "Don't change unrelated code" or "keep changes minimal" → name the exact files, modules, or patterns the executor should not touch (e.g., "Do NOT migrate existing tests to the new pattern")
- ❌ **Unlabeled opinionated recommendations**: Presenting a judgment call as if it were established practice → label with [⚠️ RISK] so the user/executor can calibrate trust. Factual statements don't need labels

---

## Reusable Prompt Blocks

Blocks are copy-paste XML snippets that encode Anthropic-published prompting
patterns for Claude 4.x executors. The SP includes relevant blocks in a crafted
prompt based on task shape and target model. Each block has a **Trigger** (when
to include it) and a **Models** note (which models benefit most).

### Block 1: `<investigate_before_answering>`

**XML snippet** (exact text, verbatim):
```xml
<investigate_before_answering>
Never speculate about code you have not opened. If the user references a specific file, you MUST read the file before answering. Make sure to investigate and read relevant files BEFORE answering questions about the codebase. Never make any claims about code before investigating unless you are certain of the correct answer — give grounded and hallucination-free answers.
</investigate_before_answering>
```
**Trigger**: Any prompt where the executor will make claims about existing code (investigation, review, refactoring, implementation touching existing files).
**Models**: Universal — applies to Opus 4.7, Sonnet 4.6, Haiku 4.5. Particularly valuable for hallucination-prone workloads.
**Source**: Anthropic official Opus 4.7 prompting guide.

### Block 2: `<avoid_over_engineering>`

**XML snippet**:
```xml
<avoid_over_engineering>
Only make changes that are directly requested or clearly necessary. Keep solutions simple and focused:

- Scope: Don't add features, refactor code, or make "improvements" beyond what was asked. A bug fix doesn't need surrounding code cleanup. A simple feature doesn't need extra configurability.
- Documentation: Don't add docstrings, comments, or type annotations to code you didn't change. Only add comments where the logic isn't self-evident.
- Defensive coding: Don't add error handling, fallbacks, or validation for scenarios that can't happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs).
- Abstractions: Don't create helpers, utilities, or abstractions for one-time operations. Don't design for hypothetical future requirements. The right amount of complexity is the minimum needed for the current task.
</avoid_over_engineering>
```
**Trigger**: Any implementation prompt (bug fix, feature add, refactor). Especially important on Opus 4.5+ which has an overengineering tendency.
**Models**: Universal, most relevant for Opus 4.5/4.6/4.7.
**Source**: Anthropic official guide "Overeagerness" section.

### Block 3: `<subagent_usage>`

**XML snippet**:
```xml
<subagent_usage>
Use subagents when tasks can run in parallel, require isolated context, or involve independent workstreams that don't need to share state. For simple tasks, sequential operations, single-file edits, or tasks where you need to maintain context across steps, work directly rather than delegating.

Do not spawn a subagent for work you can complete directly in a single response (e.g., refactoring a function you can already see).
Spawn multiple subagents in the same turn when fanning out across items or reading multiple files.
</subagent_usage>
```
**Trigger**: Any prompt where the executor may spawn agents. Multi-file refactors, research tasks, fan-out work.
**Models**: Most valuable on Opus 4.7 (spawns fewer subagents by default — needs explicit guidance when fan-out IS warranted). Also useful on Opus 4.6 (overuses subagents — needs restraint).
**Source**: Anthropic official Opus 4.7 guide, Subagent orchestration section.

### Block 4: `<use_parallel_tool_calls>`

**XML snippet**:
```xml
<use_parallel_tool_calls>
If you intend to call multiple tools and there are no dependencies between the tool calls, make all of the independent tool calls in parallel. Prioritize calling tools simultaneously whenever the actions can be done in parallel rather than sequentially. For example, when reading 3 files, run 3 tool calls in parallel to read all 3 files into context at the same time. Maximize use of parallel tool calls where possible to increase speed and efficiency. However, if some tool calls depend on previous calls to inform dependent values like the parameters, do NOT call these tools in parallel and instead call them sequentially. Never use placeholders or guess missing parameters in tool calls.
</use_parallel_tool_calls>
```
**Trigger**: Any tool-heavy prompt (investigation, multi-file reads, research).
**Models**: Universal; boosts parallel call rate to ~100% across all 4.x models.
**Source**: Anthropic official guide, "Optimize parallel tool calling" section.

### Block 5: `<conservative_actions>`

**XML snippet**:
```xml
<conservative_actions>
Consider the reversibility and potential impact of your actions. Take local, reversible actions like editing files or running tests freely, but for actions that are hard to reverse, affect shared systems, or could be destructive, ask the user before proceeding.

Examples of actions that warrant confirmation:
- Destructive operations: deleting files or branches, dropping database tables, rm -rf
- Hard to reverse operations: git push --force, git reset --hard, amending published commits
- Operations visible to others: pushing code, commenting on PRs/issues, sending messages, modifying shared infrastructure

When encountering obstacles, do not use destructive actions as a shortcut. Do not bypass safety checks (e.g., --no-verify) or discard unfamiliar files that may be in-progress work.
</conservative_actions>
```
**Trigger**: Any prompt that could touch shared state — migrations, git push, PR creation, deployment, external service calls.
**Models**: Universal. Particularly important on Opus 4.6 which is action-eager.
**Source**: Anthropic official guide, "Balancing autonomy and safety" section.

### Block 6: `<scope_explicit>`

**XML snippet** (template — customize the directive per task):
```xml
<scope_explicit>
Apply [DIRECTIVE] to [SCOPE]. [COUNTER-EXAMPLE if useful: "not just the first section" / "every file matching this pattern" / etc.].
</scope_explicit>
```
**Trigger**: Pattern-application prompts where scope could be ambiguous ("format all headings", "update every example in this file"). Required on Opus 4.7 because literal instruction following means the model won't generalize silently.
**Models**: Critical on Opus 4.7 (literal interpretation). Helpful on all 4.x models.
**Source**: Anthropic official guide, "More literal instruction following" section.

### Block 7: `<context_awareness>`

**XML snippet**:
```xml
<context_awareness>
Your context window will be automatically compacted as it approaches its limit, allowing you to continue working indefinitely from where you left off. Do not stop tasks early due to token budget concerns. As you approach your token budget limit, save your current progress and state to memory before the context window refreshes. Be persistent and complete tasks fully, even if the end of your budget is approaching. Never artificially stop any task early regardless of the context remaining.
</context_awareness>
```
**Trigger**: Long-horizon agentic tasks that may span multiple context windows. Implementation plans with 5+ deliverables, multi-day refactors, large migrations.
**Models**: Opus 4.7, Sonnet 4.6, Haiku 4.5 (all context-aware). NOT for single-task prompts that fit comfortably in one context.
**Source**: Anthropic official guide, "Context awareness and multi-window workflows" section.

### How to use this library

- Blocks are optional scaffolding; not every prompt needs every block
- Include blocks that match the task shape (see each block's **Trigger**)
- Blocks with model-specific value (Block 3, Block 6) are more important when that model is the target
- Multiple blocks stack — they're independent and don't conflict
- Blocks go in the `<task>` or `<context>` section of the prompt, adjacent to instructions
- Place blocks AFTER the main `<task>` declaration so they act as constraints on task interpretation

### Model-Aware Block Selection

When crafting a prompt, consider which blocks the TARGET model benefits from most:

| Target Model | Essential Blocks | Useful Blocks | Skip |
|---|---|---|---|
| Opus 4.7 | investigate_before_answering, avoid_over_engineering, subagent_usage, scope_explicit | use_parallel_tool_calls, conservative_actions, context_awareness | — |
| Sonnet 4.6 | investigate_before_answering, avoid_over_engineering, use_parallel_tool_calls | conservative_actions, context_awareness | subagent_usage (less critical — Sonnet orchestrates well) |
| Haiku 4.5 | investigate_before_answering | avoid_over_engineering | subagent_usage, context_awareness (Haiku is for narrow tasks) |

Effort recommendations also differ:
- **Opus 4.7**: xhigh (Claude Code default) for coding/agentic; high minimum for intelligence-sensitive
- **Sonnet 4.6**: high (API default); medium for latency-sensitive
- **Haiku 4.5**: low to medium depending on task

If target model is unknown or mixed, default to Opus 4.7's essential blocks —
they work on all 4.x models.
