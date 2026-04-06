# Anthropic / Claude — Prompt Format Guide

Provider-specific format reference for the strategic-partner advisor.
Load this guide when crafting prompts that target Claude sessions.

**When to use**: Claude Code, Claude API, Anthropic SDK sessions.

**Core principle**: Claude is trained on XML-structured data. XML tags are native
to Claude and provide the most reliable structure for complex prompts.

---

## Template

```
/[skill-name]

<context>
  Read first (in order):
  1. path/to/file — what to look for
  2. path/to/file — what to look for

  Project conventions:
  1. [relevant CLAUDE.md rules]
  2. [relevant Serena memory gotchas]
</context>

<instructions>
  [Clear, direct task description — 2-3 sentences max]

  Deliverables:
  1. [Specific file + what changes]
  2. [...]

  Constraints:
  1. [Project-specific rules from CLAUDE.md]
  2. [Pattern to follow from existing codebase]
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
  1. [ ] [Specific check]
  2. [ ] Run: [test command]
  3. [ ] Verify: [expected outcome]
</verification>

Expected commit: "type(scope): description"
```

> **Note**: When this template is used in inline prompts (══ fences), wrap the entire
> prompt content in a code block (triple backticks) to preserve XML tags — Claude Code's
> markdown renderer strips XML as HTML without this wrapper. Use numbered lists and plain
> text within tags. Saved prompts (`.prompts/`) do not need the wrapper — the Read tool
> returns raw content with tags intact.

---

## Tag Reference

| Tag | Purpose | Required |
|---|---|---|
| `<context>` | Files to read (ordered) + project conventions | Yes |
| `<instructions>` | Task description, numbered deliverables, constraints | Yes |
| `<orchestration>` | Multi-agent coordination — phases, models, modes | Only if parallelization check triggered |
| `<verification>` | Testable checkboxes with commands and expected outcomes | Yes |

### `<context>`

Lists specific files the implementer should read before touching anything.
Each file entry includes what to look for in that file. Also includes
project conventions from CLAUDE.md and known gotchas.

### `<instructions>`

The core task. Structured as:
1. **Task description** — 2-3 sentences, clear and direct
2. **Deliverables** — numbered list with specific file paths and what changes
3. **Constraints** — project-specific rules, patterns to follow

### `<orchestration>`

Only include when the parallelization check (see prompt-crafting-guide.md)
indicates multi-agent work is needed. Structure as phases:
- **Parallel phases**: agents that can run simultaneously
- **Sequential phases**: agents that depend on prior phase output
- Each agent spawn requires explicit **model** (Sonnet 4.6, Opus 4.6) and **mode** parameter

### `<verification>`

Testable checkboxes the implementer runs before committing. Each item should
specify HOW to verify (command to run, expected output, condition to check).
Never say "verify it works" — specify the concrete check.

---

## Prompt Rules

1. **No blanket tool instructions** — conditional triggers only ("use Serena find_symbol IF looking up a named symbol")
2. **XML tags are native** — Claude is trained on XML-structured data, use them for structure
3. **Self-check verification blocks** — Anthropic-recommended pattern for quality
4. **Remove 3.x workarounds** — no excessive repetition, no sycophancy-bait phrasing
5. **Frame questions neutrally** — reduced sycophancy in 4.x, leverage it
6. **No prefill tricks** — use explicit format instructions instead
7. **Examples in `<example>` tags** — 3-5 diverse examples yield best results when needed

---

## Claude-Specific Behaviors

These characteristics distinguish Claude from other providers and affect how
prompts should be structured:

| Aspect | Claude Behavior |
|---|---|
| Critical rules placement | Inside `<instructions>` as constraints |
| List style | Nested bullets OK — Claude handles hierarchy well |
| Verification | `<verification>` checklist with specific commands |
| Context | `<context>` with ordered file list + project conventions |
| Orchestration | `<orchestration>` for multi-agent coordination (phases, models, modes) |
| Tag parsing | Native XML understanding — tags provide reliable structure |

---

## Examples

### Simple Bug Fix

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

### Multi-Agent Feature

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
