---
name: context-file-scan
description: "Drift scanner for CLAUDE.md / AGENTS.md / GEMINI.md per the v6.0 policy"
category: advisory
complexity: advanced
mcp-servers: []
---

# /strategic-partner:context-file-scan — Context-File Drift Scanner

> Read-only analysis of `CLAUDE.md` (or `AGENTS.md` / `GEMINI.md`) against
> the v6.0 unified policy. Reports findings with locked output templates;
> never mutates files.

## Output Style

Adopt the adaptive-visual output style. Use scannable status symbols
(✅ ⚠️ ❌ 🔍) and group multi-finding output under per-source-file
headings.

## What this subcommand does

Runs `.scripts/context-file-scan/scan.sh` against a target context file,
discovers companion files via depth-1 pointer-following from the file's
Behavioral Guardrails section, runs the locked 16-rule detection set
(8 structural + 8 behavioral), and renders findings using the policy
C6 templates from `.handoffs/claudemd-policy-v1-draft-0504.md` Part C.

The scanner is **always advisory**. Per policy C2, the scanner reports;
the user decides. The `[Apply suggestion]` action emits a copy-paste-ready
diff or snippet to stdout — it does NOT mutate files in v1 (locked
mini-decision 13). True file mutation is deferred to v6.1+.

## Arguments

```
/strategic-partner:context-file-scan [--file PATH] [--report-only]
                                     [--release-gate] [--no-suggest-tools]
```

| Flag | Purpose |
|---|---|
| `--file PATH` | Target file. Auto-detects in priority order if absent: `CLAUDE.md` > `AGENTS.md` > `GEMINI.md`. |
| `--report-only` | Skip per-finding `AskUserQuestion`. Emit a single markdown report to stdout (Mode B). |
| `--release-gate` | Run gate-mode (implies `--report-only`). Exit 4 on any uncovered warn-or-higher finding. Used by the v6.0 release pre-push step. |
| `--no-suggest-tools` | Suppress the optional "consider installing Serena" suggestion sidebar. Pure compliance check. |

## Behavioral Flow

### Step 1 — Compute MCP-availability flags

Inspect the current session's tool inventory. Set:

- `SERENA_AVAILABLE`: `true` if Serena memory tools are present in the
  session, else `false`.
- `CONTEXT7_AVAILABLE`: `true` if Context7 tools are present, else `false`.

Pass these via `--serena-available` / `--context7-available` to the
scanner so its layer probe routes correctly. The scanner's probe also
falls back to filesystem heuristics when a flag is absent.

### Step 2 — Dispatch the scanner

```bash
.scripts/context-file-scan/scan.sh \
  ${FILE_FLAG} \
  ${REPORT_FLAG} \
  ${GATE_FLAG} \
  ${TOOLS_FLAG} \
  --serena-available ${SERENA_AVAILABLE} \
  --context7-available ${CONTEXT7_AVAILABLE}
```

The scanner emits a single JSON document on stdout. Capture it; route
to Mode A or Mode B rendering based on the flags.

### Step 3 — Mode A rendering (default — interactive)

When neither `--report-only` nor `--release-gate` was set, render one
`AskUserQuestion` per finding in this priority order (per spec § 1.2):

1. **S5** — Provisional Guard expiry (time-sensitive)
2. **S3** — Stale entries (accuracy issue, easy fix)
3. **S1** — Size breach (gives context for layer findings)
4. **S2** — Layer violation (largest improvement lever)
5. **S7** — Re-asserted skill behavior
6. **S8** — `@` imports of large files
7. **S6** — Inline shell
8. **S4** — Reactive without positive direction
9. **B1** — Missing behavioral baseline (most common gap)
10. **B2 / B3 / B4** — Hybrid pattern broken
11. **B5** — Behavioral rule without example
12. **B6** — Behavioral rule in wrong layer
13. **B7** — Behavioral rule duplication
14. **B8** — Drift from Karpathy baseline

For each finding, compose the AskUserQuestion using the locked C6
template for that `rule_id`:

| rule_id | Title (verbatim, locked) |
|---|---|
| S1 | Size breach |
| S2 | Layer violation |
| S3 | Stale entries |
| S4 | Reactive without positive direction |
| S5 | Provisional Guard expiry |
| S6 | Inline shell |
| S7 | Re-asserted skill behavior |
| S8 | `@` imports of large files |
| B1 | Missing behavioral baseline |
| B2 | Hybrid broken — stub without rules file |
| B3 | Hybrid broken — rules file without stub |
| B4 | Full content inlined when hybrid would be cleaner |
| B5 | Behavioral rule without example |
| B6 | Rule belongs in enforcement layer |
| B7 | Behavioral rule duplication |
| B8 | Drift from Karpathy baseline |

Body text fills the C6 template substitutions from
`finding.template_substitutions`. The standard option set for each
finding is:

```
[Apply suggestion]  [Acknowledge — keep as-is]  [{exception_label}]  [File for later]
```

Where `{exception_label}` comes from `finding.exception_label`
(rule-specific text per policy C6 — locked verbatim).

When the user picks `[Apply suggestion]`, emit the diff or snippet
contained in `finding.suggested_action.preview_command` to stdout. Do
NOT mutate files. The label "[Apply suggestion]" stays per locked
mini-decision 13 — v1 is "show what to change", not "change it".

### Step 4 — Mode B rendering (report-only / release-gate)

When `--report-only` or `--release-gate` was set, the scanner emits the
full JSON and the agent should NOT compose AskUserQuestion calls.
Instead, render a single markdown report using the locked Mode-B
template:

```markdown
# Context File Scan Report — {YYYY-MM-DD}

**Files scanned:** {primary_path} + {N} companion(s)
  - {primary_path} — {N}K chars ({band})
  - {companion_path} — {N}K chars ({band})  [each companion on its own line]
**Adjacent layers detected:** {comma-separated layers_present}
**Findings:** {total} total — {N} structural, {N} behavioral

---

## Findings — {primary_path}

### {N}. {Finding title} — {severity}

{approved_wording_with_substitutions_filled_in}

**Suggested action:** {suggested_action.type, layer_target, fallback_used}

{If show-don't-tell applies — sample diff or copy-paste-ready content}

[repeat per finding in this source file]

---

## Findings — {companion_path}  [section appears only when this file has findings]
[same format]

---

## Tool Suggestions (optional — omit if --no-suggest-tools)

{Only when a primary destination layer was unavailable for any finding}
- {Tool name} would enable {capability}. Optional install: {URL}.

---

## Defensive Exceptions (optional — omit if none)

{Codex finding #12: render the contents of
`release_gate.coverage.unused_exceptions` if any entries exist. These
are exception entries whose fingerprint matched no current finding —
typically because a prior bug was fixed or the source content shifted.
The user reviews these to decide whether to remove or keep for forward
coverage.}

- {rule_id} on {source_file}/{section_anchor}: {subject} (accepted {accepted_at}, review {review_at})

---

## Summary

{One-paragraph plain-English summary; per-source-file breakdown when
multi-file}.
```

For `--release-gate` mode, also surface the gate verdict:

- **Pass (exit 0)**: "✅ Release gate: pass — N warn+ findings covered by exceptions, M info findings non-blocking."
- **Fail (exit 4)**: "❌ Release gate: FAIL — N warn+ findings without exception coverage. Review .scanner-exceptions.json or fix the underlying CLAUDE.md content."
- **Error (exit 5)**: "❌ Release gate: ERROR — `.scanner-exceptions.json` is malformed (parse error / fingerprint mismatch / missing required field / schema_version != v1). Fix the file and retry."

### Step 5 — Handle exit codes

Exit codes from the scanner (per spec § 1.1):

| Code | Meaning |
|---|---|
| 0 | Success or covered |
| 2 | Target file not found / user cancelled |
| 3 | Unreadable / non-UTF-8 / jq missing |
| 4 | `--release-gate`: uncovered warn+ findings |
| 5 | `--release-gate`: `.scanner-exceptions.json` is malformed |

Surface non-zero exits to the user. For exit 3 specifically with "jq
missing", suggest `brew install jq` (macOS) or distro equivalent.

## Voice discipline

Per policy C1 + spec § 8.4:

- Use "Different from SP default" — never "noncompliant", "wrong", "violation"
  except inside the locked C6 template-label allowlist (e.g., the title
  "Layer violation" — that's the canonical template label).
- Show, don't tell — rendered findings include sample diffs / copy-paste
  content for actionable suggestions per C4.
- Project-specific framing — never push SP-flavored conventions onto a
  project that didn't ask. The scanner improves the user's project, not
  Strategic Partner's brand. Skip "strategic-partner" mentions in
  suggestion text (the slash command name is fine).
- The locked exception-option text from `finding.exception_label`
  renders verbatim — do not paraphrase.

## Examples

### Example 1 — Default mode against SP's own CLAUDE.md

```
$ /strategic-partner:context-file-scan
🔍 Scanning CLAUDE.md (23K chars, soft-warn band)...
🔍 Adjacent layers detected: serena, claude-rules, claude-hooks, claudedocs, conventional-state
🔍 Companion file: .claude/rules/source-editing.md (13K chars)

Found 23 findings. Walking through them by priority.

[AskUserQuestion #1] 🔍 Detected: Layer violation (warn) — Where to Look
   {wording from C6 template ...}
   [Apply suggestion] [Acknowledge — keep inline for this project] [File for later]
```

### Example 2 — Report-only mode

```
$ /strategic-partner:context-file-scan --report-only
# Context File Scan Report — 2026-05-05
**Files scanned:** CLAUDE.md + 1 companion ...
{markdown report}
```

### Example 3 — Release gate

```
$ /strategic-partner:context-file-scan --release-gate
{markdown report}
❌ Release gate: FAIL — 4 warn+ findings without exception coverage.
$ echo $?
4
```

## See Also

- `.prompts/claudemd-policy/scanner-design-spec.md` — locked design
  contract (1320 lines).
- `.handoffs/claudemd-policy-v1-draft-0504.md` Part C — locked output
  templates (especially C6 Detection Inventory).
- `schemas/scanner-findings.json` — JSON Schema for the finding object.
- `.scripts/context-file-scan/` — scanner source.
