# SP Project — Incident Archaeology

This file accumulates incident write-ups for SP project incidents that produced Provisional Guards or otherwise shaped SP process. Each entry is identified by an `INC-YYYY-MM-DD` ID matching the date the incident occurred and is referenced by one or more guards in CLAUDE.md's `## Provisional Guards` section. New entries follow the same `## INC-YYYY-MM-DD — <one-line summary>` heading pattern.

## INC-2026-03-30 — Hook command relies on `${CLAUDE_SKILL_DIR}` (v5.4.0 → v5.4.1)

### What happened

v5.4.0 shipped on 2026-03-30 with a new PreToolUse hook (`hooks/guard-impl.sh`) intended to enforce SP's role boundary by blocking source-code edits while allowing writes to a specific set of paths (`.prompts/`, `.handoffs/`, `.scripts/`, `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `SKILL.md`, `.claude/`, `.gitignore`). Three design choices in that release became the failure surface:

- The hook command in `SKILL.md` frontmatter referenced `${CLAUDE_SKILL_DIR}` for path resolution to `guard-impl.sh`.
- `guard-impl.sh` itself carried a `${CLAUDE_SKILL_DIR}` fallback in case the variable was not expanded by the harness at command-string time.
- The hook read the current tool name from a `CLAUDE_TOOL_NAME` environment variable and used a permissive matcher pattern (`""`) that fired on every PreToolUse event.

All three decisions assumed Claude Code populated the named variables and routed every tool call through the matcher. None of those assumptions held.

### Why it broke

`CLAUDE_SKILL_DIR` is not set by Claude Code. It expanded to the empty string, so the hook command failed on any install path that wasn't the default skillshare layout. Users on git clones or alternate directory configurations hit the failure on their next session — the hook errored before it could allow anything through, and exit code 2 from a PreToolUse hook blocks the tool call. Because the matcher fired on every tool, the block was effectively total: Read, Glob, Grep, Skill, and meta operations all paid the cost.

`CLAUDE_TOOL_NAME` had the same character — a phantom variable. Claude Code passes `tool_name` via the stdin JSON payload to the hook, not via the environment. With no tool name, the hook couldn't distinguish guarded from unguarded calls and treated all tool invocations identically.

The permissive matcher compounded both problems: even if path resolution had worked, the hook would still have fired on read-only and meta tools where the guard had no business running. Every session paid the hook cost on every tool call.

### Fix shipped

v5.4.1 shipped on 2026-03-31, one day after v5.4.0, with three changes:

1. **Inlined the guard logic into `SKILL.md` frontmatter.** The hook no longer depends on resolving an external `hooks/guard-impl.sh` path — the full guard is self-contained in the frontmatter and works on any install path (skillshare default, git clone, alternate directory layouts).
2. **Switched tool-name extraction from environment variable to stdin JSON.** The hook now parses `tool_name` from the stdin JSON payload, which is the documented Claude Code mechanism for passing tool context to hooks.
3. **Narrowed the matcher to guarded tools only.** The matcher pattern changed from `""` to `Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__plugin_serena_serena__`, so the hook fires only on the tools the guard actually governs. Read, Glob, Grep, Skill, and other non-guarded tools no longer pay the cost.

### Lesson formalized as Provisional Guard

The lesson is captured in CLAUDE.md's `## Provisional Guards` section as: *Don't use `${CLAUDE_*}` env vars in hook commands.* The guard names the affirmative alternative — inline the values, use deterministic path resolution, or grep `CHANGELOG.md` for prior incidents with the variable name before relying on it — and lists `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_TOOL_NAME}`, and any other unverified `CLAUDE_*` variable as in scope.

### Related codification

Several months after the incident, during the v5.9.0 release-review cycle (2026-04-21), two release-runbook items were added to CLAUDE.md's `### 2a. Hook Verification` step to catch this class of bug at verification time rather than after ship:

- **§2a item 4 — runtime-input fuzzing** for hooks parsing JSON or env vars: vary whitespace, quoting, missing optional fields, and non-JSON input through the reference script and confirm graceful handling rather than abort-on-error. The author's own test set represents what the author thought about; fuzzing represents what the runtime will actually send.
- **§2a item 5 — CHANGELOG cross-reference** for `${CLAUDE_*}` env vars and path-resolution patterns: before endorsing any hook command that uses one, grep `CHANGELOG.md` for that variable or pattern. Prior release notes are authoritative on what doesn't work in this harness, and a historical entry is the fastest way to avoid re-introducing the same bug.

These checks are preventive; the lesson came from this incident plus a small number of subsequent near-misses with related variables. Together with the Provisional Guard above, they form the current mitigation surface for this failure mode.
