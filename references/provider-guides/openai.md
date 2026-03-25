# OpenAI / GPT-5.4 — Prompt Format Guide

Provider-specific format reference for the strategic-partner advisor.
Load this guide when crafting prompts that target OpenAI sessions.

**When to use**: Codex CLI, ChatGPT, OpenAI API sessions.

**Core principle**: GPT-5.4 prioritizes early instructions and benefits from flat,
explicit structure. Critical rules placed first get the strongest adherence.
Uses XML-based tags but with different tag names and conventions from Claude.

---

## Template

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

---

## Tag Reference

| Tag | Purpose | Required |
|---|---|---|
| `<task>` | Single-paragraph goal statement | Yes |
| `<critical_rules>` | Non-negotiable constraints — placed FIRST for maximum adherence | Yes |
| `<execution_order>` | Flat numbered steps — no nesting | Yes |
| `<edge_cases>` | Ambiguity handling and exception rules | When ambiguity exists |
| `<output_contract>` | Exact deliverables, file list, commit message | Yes |
| `<verification_loop>` | Pre-finalization checks | Yes |

### `<task>`

A single, clear paragraph describing what the executor should accomplish.
Keep it focused — one goal, not multiple objectives.

### `<critical_rules>`

Non-negotiable constraints placed at the top of the prompt. GPT-5.4 gives
stronger adherence to rules encountered early. This is the most important
structural difference from Claude prompts.

### `<execution_order>`

A flat numbered list of steps. Never nest bullets — if a step has sub-steps,
break them into a separate section or separate numbered items. GPT-5.4
follows flat lists more reliably than hierarchical ones.

### `<edge_cases>`

How to handle ambiguity or exceptions. Use `If X → do Y` format.
Particularly important for GPT-5.4 mini/nano variants which are more literal.

### `<output_contract>`

Exact deliverables and their format. Includes file paths and the expected
commit message. Acts as the definitive reference for what "done" looks like.

### `<verification_loop>`

Pre-completion checks the executor runs before committing. Similar to
Claude's `<verification>` but named to emphasize the iterative check pattern.

---

## Prompt Rules

1. **Critical rules FIRST** — GPT-5.4 prioritizes early instructions more strongly
2. **Flat structure** — never nest bullets; if a step has sub-steps, make them a separate section
3. **One example** — include one correct output example when the expected format isn't obvious
4. **No ambiguity** — GPT-5.4 mini/nano variants are more literal and make fewer assumptions
5. **Phase field** — for long-running workflows, note that the executor should preserve the phase field to prevent preambles being misinterpreted

---

## Key Differences from Claude

| Aspect | Claude 4.x | GPT-5.4 |
|---|---|---|
| Critical rules placement | Inside `<instructions>` | Dedicated `<critical_rules>` tag, placed FIRST |
| List style | Nested bullets OK | Flat lists only — split into sections instead |
| Verification | `<verification>` checklist | `<verification_loop>` with pre-finalization checks |
| Context | `<context>` with file list + constraints | `<task>` for goal + `<execution_order>` for file reads |
| Orchestration | `<orchestration>` for multi-agent | Not applicable — GPT-5.4 uses single-agent model |
| Mini/nano variants | N/A | Be more explicit about execution order (more literal) |

---

## Examples

### Simple Bug Fix

```
/[quick-task skill from routing matrix]

<task>
Fix token validation in docker/entrypoint.sh — HTTP 500 responses are silently
passed through instead of triggering a retry with backoff.
</task>

<critical_rules>
1. Network failures (timeout, DNS) must still pass through (offline tolerance).
2. Max 2 retries with 1s backoff — no infinite loops.
3. Log retry attempts to stderr, not stdout.
</critical_rules>

<execution_order>
1. Read docker/entrypoint.sh — focus on validate_stored_token() around line 120-140.
2. Read CLAUDE.md — "CMRAD Credential Persistence" section for credential conventions.
3. Update validate_stored_token() to detect HTTP 500 and retry.
4. Preserve existing HTTP 401 handling (treat as expired).
5. Add stderr logging for retry attempts.
</execution_order>

<edge_cases>
- If HTTP 500 persists after 2 retries → treat token as expired (same as 401).
- If network timeout occurs → pass through without retry (offline tolerance).
- If response code is anything other than 200, 401, or 500 → pass through.
</edge_cases>

<output_contract>
- Files to modify: docker/entrypoint.sh
- Expected commit: "fix(auth): retry token validation on HTTP 500 with backoff"
</output_contract>

<verification_loop>
1. [ ] HTTP 401 → token treated as expired (existing behavior preserved)
2. [ ] HTTP 500 → retry up to 2x, then treat as expired
3. [ ] Network timeout → pass through (no retry)
4. [ ] Successful validation → proceed normally
</verification_loop>
```
