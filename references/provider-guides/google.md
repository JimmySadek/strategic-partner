# Google / Gemini — Prompt Format Guide

Provider-specific format reference for the strategic-partner advisor.
Load this guide when crafting prompts that target Gemini sessions.

**When to use**: Gemini CLI, Gemini API sessions.

**Core principle**: Gemini works best with Markdown-structured prompts using
`##` headers for section separation. No XML tags — plain language with clear
visual hierarchy.

---

## Template

```
/[skill-name]

## Task

[Clear, direct task description — what the executor should accomplish]

## Files to Read

1. path/to/file — what to look for
2. path/to/file — what to look for

## Project Conventions

- [relevant project rules]
- [relevant naming conventions or patterns]

## Deliverables

1. [Specific file + what changes]
2. [Specific file + what changes]

## Constraints

1. [Non-negotiable rule]
2. [Non-negotiable rule]

## Verification

1. [ ] [Specific check with command or expected outcome]
2. [ ] [Specific check with command or expected outcome]

Expected commit: "type(scope): description"
```

---

## Formatting Rules

1. **Use `##` headers** for major sections — Gemini benefits from clear visual
   section separation via headers
2. **Numbered lists over nested bullets** — numbered lists work better than
   nested bullets for Gemini's instruction following
3. **No XML tags** — Gemini doesn't benefit from XML structure; Markdown
   headers provide equivalent organization
4. **Plain language** — direct, clear instructions without structural markup
5. **One concern per section** — keep each `##` section focused on a single topic
6. **Flat hierarchy** — prefer `##` sections over deeply nested sub-headers

---

## Hybrid Patterns (Claude Orchestrating Gemini)

When a Claude session writes content that will be consumed by Gemini:

- **Outer prompt**: XML (for Claude to parse and orchestrate)
- **Inner content**: Markdown (for Gemini to consume and execute)
- **Clear delineation**: "The following Markdown content is for Gemini, not for you to execute"

### Hybrid Template

```
<instructions>
  Generate the following Markdown prompt for a Gemini session.
  Do not execute it — write it to .prompts/[descriptor].md.

  The following Markdown content is for Gemini, not for you to execute:

  ## Task
  [Task description written in Gemini-friendly Markdown]

  ## Files to Read
  1. [file paths]

  ## Deliverables
  1. [deliverables in Markdown format]

  ## Verification
  1. [ ] [checks]
</instructions>
```

This pattern appears when the strategic partner operates in a Claude session
but the user will execute the resulting prompt in a Gemini environment.

---

## Examples

### Simple Bug Fix

```
/[quick-task skill from routing matrix]

## Task

Fix token validation in docker/entrypoint.sh. HTTP 500 responses are silently
passed through instead of triggering a retry with backoff.

## Files to Read

1. docker/entrypoint.sh — the auth flow around line 120-140, specifically validate_stored_token()
2. CLAUDE.md — "CMRAD Credential Persistence" section for credential conventions

## Project Conventions

- Credentials stored as email\ntoken (chmod 600)
- Environment-scoped: cmrad_credentials.dev / cmrad_credentials.prod

## Deliverables

1. docker/entrypoint.sh — update validate_stored_token() to retry on HTTP 500

## Constraints

1. Network failures (timeout, DNS) must still pass through (offline tolerance)
2. Max 2 retries with 1s backoff
3. Log retry attempts to stderr

## Verification

1. [ ] HTTP 401 → token treated as expired (existing behavior)
2. [ ] HTTP 500 → retry up to 2x, then treat as expired
3. [ ] Network timeout → pass through (no retry)
4. [ ] Successful validation → proceed normally

Expected commit: "fix(auth): retry token validation on HTTP 500 with backoff"
```

### Feature Implementation

```
/[feature implementation skill from routing matrix]

## Task

Add a new "list teams" wizard to the CLI that fetches teams from the
versioned API endpoint /api/1.0/teams.

## Files to Read

1. docker/cli/ — understand existing CLI wizard patterns
2. docker/cli/credentials.py — reference implementation for wizard structure
3. docker/mcp/cmrad_mcp.py — current MCP server implementation
4. CLAUDE.md — "API has two namespaces" section

## Project Conventions

- Python CLI uses rich library for formatting
- MCP server uses FastMCP framework
- Use Config.versioned_api_base() for versioned endpoints (strips /research suffix)

## Deliverables

1. docker/cli/teams.py — new wizard module following existing patterns
2. docker/cli/__init__.py — register the new wizard
3. docker/mcp/cmrad_mcp.py — add list_teams tool

## Constraints

1. Use Config.versioned_api_base() for the endpoint — no hardcoded URLs
2. Follow existing wizard patterns from docker/cli/credentials.py
3. Handle auth errors gracefully (token expired → redirect to login)

## Verification

1. [ ] `python -c "from cli.teams import TeamsWizard"` succeeds
2. [ ] MCP tool list_teams appears in tool registry
3. [ ] Both use Config.versioned_api_base() not hardcoded URLs

Expected commit: "feat(cli): add list teams wizard and MCP tool"
```
