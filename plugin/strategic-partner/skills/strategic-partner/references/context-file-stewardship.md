# Context-File Stewardship

This is the canonical Strategic Partner policy for always-loaded agent context
files: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, and path-scoped
`.claude/rules/*.md` files. Older context-file policy drafts and scanner
template briefs are historical only and must not be used as runtime authority.

## Principles

- Root context files are last-resort instructions. They hold concise,
  project-wide rules a future session must load immediately.
- Target root context files under 200 lines. Once a file is already large,
  prefer replacement, extraction, or a pointer over a net append.
- Never store session journeys, ticket histories, implementation reports,
  commit trails, file lists, local/unpushed status, browser-verification
  trails, or page-by-page narratives in an always-loaded context file.
- Path-scoped rules belong in `.claude/rules/*.md`, not in a root context file.
- Decisions, rationale, architecture notes, known gotchas, and evolving
  project knowledge belong in memory or reference docs.
- Mechanically enforceable behavior belongs in hooks, settings, tests, linters,
  or scripts. A context file may keep a short pointer only when every session
  truly needs to know the enforcement layer exists.
- Imports are not a bloat fix. In Claude Code, imported files still expand into
  startup context. Use links or read-when-needed pointers for reference docs.

## Placement Gate

Before proposing or writing context-file text, classify the candidate:

| Candidate | Destination |
|---|---|
| Concise project-wide rule needed every session | Root context file |
| Rule scoped to files, directories, or file types | `.claude/rules/*.md` |
| Enforceable rule | Hook/settings/test/script |
| Decision, rationale, convention, architecture, gotcha | Memory or reference docs |
| Session journey, implementation result, commit list | `.handoffs/` |
| Deferred work | `.backlog/` |
| Runnable procedure | `.scripts/` or reference docs |

## Required Runtime Behavior

- Scanner audits are read-only and advisory.
- Proposed context-file additions must run proposal preflight and surface the
  verdict before asking the user to accept exact text.
- Tool writes to context files must run the hard write guard. The guard blocks
  high-confidence session dumps, literal shell mutations to context-file paths,
  and destructive full-file replacements; it allows concise additions and
  extraction-shaped shrink replacements.
- Shell-command handling is a high-confidence tripwire, not a shell parser.
  Context-file changes should use `Edit` / `Write` / `MultiEdit`, where the
  guard can inspect the actual proposed file content.
- If preflight or the guard cannot prove a risky context-file mutation is safe,
  it blocks with a plain-English reason and a safer destination.
