# Implementation Prompt Crafting Guide

Reference file for the strategic-partner advisor. Standards for crafting implementation
prompts across target models.

```
Routing Decision Tree → Parallelization Check → Quality Check → Format Selection (Claude XML / GPT-5.4 XML / Gemini MD / Hybrid) → Deliverable Type (Prompt vs Script) → Post-Craft Verification → Save Decision → Launcher
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

---

## 🔴 Mandatory Pre-Craft Analysis

**🚨 STOP. Complete both analyses below BEFORE writing any prompt.** These are not
optional guidance — skipping them is a quality gate failure.

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

### Step 2: Mandatory Parallelization Check

Answer all four questions before writing the prompt body. Record answers explicitly.

| # | Question | If YES → | If NO → |
|---|----------|----------|---------|
| 1 | Can this task be split into 2+ independent file changes? | Add `<orchestration>` with parallel agents | Continue |
| 2 | Does this task have a research phase and a build phase? | Sequential phases, parallel within each | Continue |
| 3 | Are there 3+ deliverables that don't depend on each other? | Parallel agent per deliverable group | Continue |
| 4 | Is this a single-file, single-concern change? | No orchestration needed, single skill | Re-evaluate Q1-3 |

**🔴 Quality gate**: If the answer to ANY of Q1-3 is **YES** and the prompt
lacks an `<orchestration>` section, **the prompt FAILS**. Go back and add
orchestration before proceeding.

---

## Format Selection

After routing and parallelization analysis, determine the prompt format based on the
target model. This is the **first structural decision** before writing the prompt body.

```
Which model runs the target session?
├── Claude (Claude Code, Claude API, Anthropic SDK)
│   └── XML structure: <context>, <instructions>, <orchestration>, <verification>
│       → See "Claude 4.x Format" below
│
├── GPT-5.4 / OpenAI (Codex CLI, ChatGPT, OpenAI API)
│   └── XML structure: <task>, <critical_rules>, <execution_order>, <edge_cases>, <output_contract>, <verification_loop>
│       → See "GPT-5.4 Format" below
│
├── Gemini (Gemini CLI, Gemini API)
│   └── Markdown structure with ## headers
│       → See "Gemini Format" below
│
└── Unknown or multi-model
    └── Default to Claude XML — most structured, degrades gracefully
```

---

## Claude 4.x Format

XML tag structure for Claude targets (Claude Code, Claude API, Anthropic SDK):

```
/[skill-name]

<context>
  Read first (in order):
  1. path/to/file — what to look for
  2. path/to/file — what to look for

  Project conventions:
  - [relevant CLAUDE.md rules]
  - [relevant Serena memory gotchas]
</context>

<instructions>
  [Clear, direct task description — 2-3 sentences max]

  Deliverables:
  1. [Specific file + what changes]
  2. [...]

  Constraints:
  - [Project-specific rules from CLAUDE.md]
  - [Pattern to follow from existing codebase]
</instructions>

<orchestration>
  [Only include if multi-agent work needed]
  Phase 1 (parallel):
    Agent A (Sonnet 4.6, mode: "auto"): [task + expected output]
    Agent B (Sonnet 4.6, mode: "auto"): [task + expected output]
  Phase 2 (sequential):
    Agent C (Opus 4.6, mode: "acceptEdits"): [synthesis task]
</orchestration>

<verification>
  - [ ] [Specific check]
  - [ ] Run: [test command]
  - [ ] Verify: [expected outcome]
</verification>

Expected commit: "type(scope): description"
```

---

## GPT-5.4 Format

XML-based tag structure, different tags from Claude. GPT-5.4 prioritizes early instructions
and benefits from flat, explicit structure.

```
/[skill-name]

<task>
[What the executor should accomplish — clear, single-paragraph goal]
</task>

<critical_rules>
[Non-negotiable constraints — placed FIRST for maximum adherence]
1. Rule one.
2. Rule two.
</critical_rules>

<execution_order>
[Exact sequence of steps — flat numbered list, no nesting]
1. Read these files first: [list]
2. [Step]
3. [Step]
</execution_order>

<edge_cases>
[How to handle ambiguity or exceptions]
- If X happens → do Y.
- If unsure about Z → ask, don't assume.
</edge_cases>

<output_contract>
[Exact deliverables and format]
- Files to create/modify: [list]
- Expected commit: "type(scope): description"
</output_contract>

<verification_loop>
[Pre-completion checks — executor verifies before committing]
1. [ ] Check one
2. [ ] Check two
</verification_loop>
```

### Claude vs GPT-5.4 Comparison

| Aspect | Claude 4.x | GPT-5.4 |
|---|---|---|
| Critical rules placement | Inside `<instructions>` | Dedicated `<critical_rules>` tag, placed FIRST |
| List style | Nested bullets OK | Flat lists only — split into sections instead |
| Verification | `<verification>` checklist | `<verification_loop>` with pre-finalization checks |
| Context | `<context>` with file list + constraints | `<task>` for goal + `<execution_order>` for file reads |
| Orchestration | `<orchestration>` for multi-agent | Not applicable — GPT-5.4 uses single-agent model |
| Mini/nano variants | N/A | Be more explicit about execution order (more literal) |

### GPT-5.4 Prompt Rules

1. **Critical rules FIRST** — GPT-5.4 prioritizes early instructions more strongly
2. **Flat structure** — never nest bullets; if a step has sub-steps, make them a separate section
3. **One example** — include one correct output example when the expected format isn't obvious
4. **No ambiguity** — GPT-5.4 mini/nano variants are more literal and make fewer assumptions
5. **Phase field** — for long-running workflows, note that the executor should preserve the phase field to prevent preambles being misinterpreted

---

## Gemini Format

When the target session runs Gemini (see Format Selection above):

- Use Markdown headers and bullet points
- Plain language instructions — no XML tags
- Gemini doesn't benefit from XML structure
- Include the same information (context, deliverables, constraints) in Markdown form

---

## Hybrid Prompts (Claude Orchestrating Gemini)

When a Claude session writes content consumed by Gemini:

- Outer prompt: XML (for Claude to parse)
- Inner content: Markdown (for Gemini to consume)
- Clear delineation: "The following Markdown content is for Gemini, not for you to execute"

---

## Claude 4.x Prompt Rules

1. **No blanket tool instructions** → conditional triggers only ("use Serena find_symbol IF looking up a named symbol")
2. **XML tags are native** → Claude is trained on XML-structured data, use them for structure
3. **Self-check verification blocks** → Anthropic-recommended pattern for quality
4. **Remove 3.x workarounds** → no excessive repetition, no sycophancy-bait phrasing
5. **Frame questions neutrally** → reduced sycophancy in 4.x, leverage it
6. **No prefill tricks** → use explicit format instructions instead
7. **Examples in `<example>` tags** → 3-5 diverse examples yield best results when needed

---

## 🔴 Post-Craft Self-Verification (Mandatory)

After writing the prompt, run this checklist before presenting it. **Every item
must pass.** If any item fails, fix the prompt — do not present a failing prompt.

| # | Check | ❌ Fails If... |
|---|-------|---------------|
| 1 | Skill command on line 1 matches routing decision tree | Copied from memory or example |
| 2 | `<context>` lists specific files with what to look for | Says "read the codebase" or "see relevant files" |
| 3 | `<instructions>` has numbered deliverables with file paths | Vague like "update the tests" |
| 4 | `<orchestration>` present if parallelization check triggered | Q1-3 answered YES but no orchestration section |
| 5 | Each agent spawn has explicit model AND mode | Unspecified model or missing mode parameter |
| 6 | `<verification>` has testable checkboxes with commands/outcomes | Says "verify it works" without specifying HOW |
| 7 | Expected commit uses conventional-commit format | Missing or malformed `type(scope): description` |
| 8 | Prompt is fully self-contained | References "our earlier discussion" or "current approach" |
| 9 | Format matches target model (see Format Selection) | Claude prompt uses Markdown, GPT-5.4 uses Claude tags, or Gemini uses XML |

**🚨 If any row fails**: Fix the prompt before presenting. Do not present with
a note saying "you might want to add..." — the prompt must be complete.

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
  2. Design — Agent(Opus 4.6, [architect-agent]) → produces component spec
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
/[skill-name]

[Full prompt content — XML-structured, self-contained]

Expected commit: "type(scope): description"
══════════════════= END 🛑 COPY ═══════════════════

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
- ❌ **Claude 3.x workarounds**: Excessive repetition, sycophancy-bait phrasing
- ❌ **Prompt for config edits**: Writing a Claude prompt to edit JSON configs → generate a `.scripts/` bash script instead
- ❌ **Manual steps in markdown**: "Run these commands: 1. cd ... 2. npm install ..." → wrap in an executable script
- ❌ **Script without pre-flight**: Missing directory/tool checks → always validate prerequisites
- ❌ **Destructive scripts**: Overwriting entire config files → merge into existing (use Python/jq for JSON)
- ❌ **Missing routing rationale**: Presenting fenced prompt without the `> 🎯 Routing:` line → always explain the skill choice (or no-skill choice) before the fences
- ❌ **Premature "what's next?"**: Offering follow-up options immediately after a prompt → STOP and wait for user to report back from execution
- ❌ **Skipped parallelization check**: Writing prompt without answering the 4-question checklist → ALWAYS complete the parallelization check before writing
- ❌ **Missing orchestration when required**: Parallelization check answered YES to Q1-3 but no `<orchestration>` section → prompt FAILS quality gate
- ❌ **Skipped routing decision tree**: Picking a skill from memory instead of walking the scope + complexity tree → ALWAYS route through the decision tree
- ❌ **Skipped post-craft verification**: Presenting prompt without running the 8-item checklist → ALWAYS verify before presenting
- ❌ **Intuitive routing**: "This feels like a quick-task" without walking the tree → trust the tree, not intuition
