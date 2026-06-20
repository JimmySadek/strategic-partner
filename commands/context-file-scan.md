---
name: context-file-scan
description: "Read-only drift scanner for CLAUDE.md / AGENTS.md / GEMINI.md and .claude/rules"
category: advisory
complexity: advanced
mcp-servers: []
---

# /strategic-partner:context-file-scan

Read-only analysis of always-loaded context files against
`references/context-file-stewardship.md`. The scanner reports; it never edits
files. Actual writes are protected separately by the PreToolUse context-file
guard.

## Usage

```bash
/strategic-partner:context-file-scan [--file PATH] [--report-only]
                                     [--release-gate] [--no-suggest-tools]
```

| Flag | Purpose |
|---|---|
| `--file PATH` | Target file. Defaults to `CLAUDE.md`, then `AGENTS.md`, then `GEMINI.md` in the current project. |
| `--report-only` | Emit one markdown report instead of per-finding questions. |
| `--release-gate` | Non-interactive gate mode. Exit 4 when warn+ findings are not covered by exceptions. |
| `--no-suggest-tools` | Omit optional tool-install suggestions. |

## Rendering

Run `.scripts/context-file-scan/scan.sh` with the selected flags and render the
JSON findings in priority order:

1. S10 high-confidence session narrative dump
2. S1 size breach
3. S2 misplaced layer content
4. S3 stale entries
5. S5 provisional guard expiry
6. S8 large `@` imports
7. S6 inline shell
8. S4 reactive rule without positive direction
9. S9 SP-flavored framing
10. S7 duplicated skill behavior
11. B1-B8 behavioral guardrail findings

For each finding, use plain project-specific language:

- State what was detected and why it matters.
- Name the safer destination when one exists.
- Show a small replacement or extraction example when useful.
- Ask before any follow-up write.

Do not call the file noncompliant, wrong, or policy-violating. The scanner is
an advisory review surface; the hard write guard handles enforcement.

## Report Mode

Report-only output should include:

```markdown
# Context File Scan Report — {YYYY-MM-DD}

**Files scanned:** {primary_path} + {N} companion(s)
  - {path} — {lines} lines / {chars} chars ({band})
**Adjacent layers detected:** {layers}
**Findings:** {total} total — {structural} structural, {behavioral} behavioral

## Findings — {source_file}

### {N}. {title} — {severity}

{plain-English finding}

**Suggested action:** {destination or action}

## Summary

{short project-specific summary}
```

For release-gate mode, also surface:

- Pass: `Release gate: pass`
- Fail: `Release gate: FAIL — N warn+ findings without exception coverage`
- Error: `Release gate: ERROR — .scanner-exceptions.json is malformed`

## Proposal Preflight

Before proposing exact context-file text, run:

```bash
.scripts/context-file-scan/proposal-preflight.sh \
  --target <CLAUDE.md|AGENTS.md|GEMINI.md|.claude/rules/file.md> \
  --snippet <file-or-> \
  --mode append
```

For full-file replacement checks, use `--mode replacement`. Surface the returned
`verdict`, `destination`, `reason`, `size_delta`, and `receipt` before asking
the user to accept the text.

## See Also

- `references/context-file-stewardship.md` — canonical policy.
- `.scripts/context-file-scan/` — scanner and preflight implementation.
- `hooks/context-file-guard.sh` — hard write guard for actual mutations.
