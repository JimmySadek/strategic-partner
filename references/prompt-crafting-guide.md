# Implementation Prompt Crafting Guide

Reference file for the strategic-partner advisor. Standards for crafting implementation
prompts across target models.

```
Quality Check → Format (XML/MD/Hybrid) → Deliverable Type (Prompt vs Script) → Save Decision → Launcher
```

---

## Prompt Quality Requirements

Every implementation prompt must:

1. **Skill resolved from the routing matrix** — look up the best skill for this specific task before writing line 1. Never default to a remembered skill name or copy one from an example. The first line must be the bare skill command — no backticks, no headers above it, no "Run:" prefix
2. **Be fully self-contained** — the implementer has no access to the advisor conversation
3. **Specify exactly which files to read** — before touching anything
4. **List deliverables precisely** — files, functions, tests, CHANGELOG entries
5. **Include project constraints** — pre-existing failures, feature flags, naming conventions
6. **Specify the model** — every prompt involving agents must name Opus or Sonnet explicitly
7. **End with the expected commit message** — conventional-commit format
8. **Leave no ambiguity** — nothing that would require follow-up questions
9. **Use XML structure for Claude targets** — `<context>`, `<instructions>`, `<orchestration>`, `<verification>` tags
10. **Specify the target branch** — if the project uses feature branches, name the branch in the prompt's `<context>` section so the implementer works in the right place

---

## Claude 4.x Prompt Format (Primary)

Most prompts target Claude Code sessions. Use XML structure:

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
    Agent A (Sonnet 4.6): [task + expected output]
    Agent B (Sonnet 4.6): [task + expected output]
  Phase 2 (sequential):
    Agent C (Opus 4.6): [synthesis task]
</orchestration>

<verification>
  - [ ] [Specific check]
  - [ ] Run: [test command]
  - [ ] Verify: [expected outcome]
</verification>

Expected commit: "type(scope): description"
```

---

## Gemini Prompt Format

When the target session runs Gemini (not Claude):

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

## Real Examples

> **Note**: These examples use specific skill names from one environment for
> concreteness. When crafting actual prompts, **always resolve the skill command
> from the routing matrix** — never copy a skill name from these examples directly.

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
    Agent 1 (Sonnet 4.6): Write docker/cli/teams.py + update __init__.py
    Agent 2 (Sonnet 4.6): Add list_teams tool to cmrad_mcp.py
</orchestration>

<verification>
  - [ ] `python -c "from cli.teams import TeamsWizard"` succeeds
  - [ ] MCP tool list_teams appears in tool registry
  - [ ] Both use Config.versioned_api_base() not hardcoded URLs
</verification>

Expected commit: "feat(cli): add list teams wizard and MCP tool"
```

---

## Skill Chain Embedding

When a task requires multiple implementation sessions (a skill chain):

1. **List the full chain** in the first prompt with what each step produces
2. **Mark entry points** — which prompt to run first, what to verify before the next
3. **Carry context forward** — each prompt after the first should reference outputs of the prior
4. **Be explicit about ordering** — "Run this AFTER prompt A has been committed"
5. **Specify model per step** — each agent spawn in the chain gets an explicit model

Example (resolve each skill from the routing matrix):
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

## Prompt Save Decision

```
Is the prompt >80 lines OR >3 deliverables OR >1 prompt pending in session?
  YES → Save to .prompts/[milestone]/[descriptor].md
        Display: COPY-PASTEABLE LAUNCHER (see Launcher Format below)
  NO  → Present inline — skill command as first line, no backtick wrapping
```

When saving to `.prompts/`:
- Use descriptive filenames: `phase1-auth-middleware.md`, `bugfix-token-expiry.md`
- Group by milestone/version: `.prompts/v1.4/`, `.prompts/v1.5/`
- Always AskUserQuestion before saving (ask-before-act applies)

---

## Launcher Format

When a prompt is saved to `.prompts/`, display a launcher the user can copy-paste
into a new Claude Code session:

**COPY THIS INTO NEW SESSION:**

══════════════════ START 🟢 COPY ══════════════════
/[skill-name]

Read the implementation prompt at .prompts/[milestone]/[descriptor].md and execute all deliverables.
══════════════════= END 🛑 COPY ═══════════════════

Requirements:
- Label ("COPY THIS INTO NEW SESSION") is always outside the ═══ fence
- First line inside fence: bare skill command (no backticks) — dynamic per task
- Second line: Read instruction pointing to the saved file
- Nothing else — no headers, no summaries, no backticks around commands
- When multiple prompts exist, each gets its own START/END block

---

## Anti-Patterns

- ❌ **Vague deliverables**: "update the tests" → specify which test file, which cases
- ❌ **Missing context**: "fix the auth bug" → specify the symptom, file, line range
- ❌ **Assumed knowledge**: "use the same pattern as before" → spell it out
- ❌ **Skill omission**: starting with implementation details → start with skill invocation
- ❌ **Hardcoded skill names**: copying `/gsd:quick` or `/feature-dev` from examples or memory → always look up the routing matrix for the best match
- ❌ **Ambiguous ordering**: "also do X" → explicitly state if X is sequential or parallel
- ❌ **Backtick-wrapped commands**: `` `/gsd:quick` `` renders as code, not executable → bare command
- ❌ **Headers before skill command**: `# Implementation Prompt` above the command → skill command must be line 1
- ❌ **No launcher for saved prompts**: "go read .prompts/v1.5/phase1.md" → provide COPY-PASTEABLE LAUNCHER block
- ❌ **Missing model specification**: "Spawn an agent" without specifying sonnet/opus
- ❌ **XML for Gemini**: Using `<context>` tags in prompts meant for Gemini sessions
- ❌ **Over-prompting**: "Always use Serena for every search" → use conditional triggers
- ❌ **Claude 3.x workarounds**: Excessive repetition, sycophancy-bait phrasing
- ❌ **Prompt for config edits**: Writing a Claude prompt to edit JSON configs → generate a `.scripts/` bash script instead
- ❌ **Manual steps in markdown**: "Run these commands: 1. cd ... 2. npm install ..." → wrap in an executable script
- ❌ **Script without pre-flight**: Missing directory/tool checks → always validate prerequisites
- ❌ **Destructive scripts**: Overwriting entire config files → merge into existing (use Python/jq for JSON)
