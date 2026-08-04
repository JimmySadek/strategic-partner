---
name: report-issue
description: "Report a Strategic Partner bug from any project — sanitised draft, mandatory preview, filed to the plugin's own tracker"
category: utility
complexity: standard
mcp-servers: []
---

# report-issue — Report a Plugin Bug

> File a Strategic Partner bug report from inside any project — including a
> client project — without leaking that project's details. The report is
> drafted from evidence already in the session, scrubbed twice, shown to you
> exactly as it would be posted, and filed only after you confirm. Invoke as
> `/strategic-partner:report-issue` (skill install) or
> `/strategic-partner-plugin:report-issue` (plugin install); this file serves
> both installs, so every path below names its skill and plugin forms.

## Tracker Constant

```
PLUGIN_TRACKER_REPO = JimmySadek/strategic-partner
```

This value was derived once, at build time, from the Strategic Partner
repository's own origin remote. It is a constant, not a lookup. Never read
the current project's git remotes to decide where a report goes — a report
filed from inside a client repository must never touch the client's tracker.

## Output Style

Adopt the adaptive-visual output style. Use status/action symbols for scannable output.
Default to concise mode; expand for problems or decisions.

## Usage

```
/strategic-partner:report-issue [description]
/strategic-partner-plugin:report-issue [description]
```

| Argument | Purpose |
|---|---|
| `description` (optional) | Free text describing what went wrong, in the user's own words. Becomes the starting point of the report's summary. |

There is no flag that skips the preview, and no auto-post form of this
command.

## Behavioral Flow

### Step 1 — Gather evidence (from context and cheap reads only)

The command runs in the session where the failure happened, so the most
valuable evidence is already in context. Collect:

- **Plugin version** — the `version:` field near the top of the installed
  SKILL.md (skill install: `{sp-dir}/SKILL.md`; plugin install:
  `"${CLAUDE_PLUGIN_ROOT}/skills/strategic-partner/SKILL.md"`).
- **OS** — `uname -s`.
- **Active model** — if known in this session; otherwise write `unknown`.
- **The failure itself** — the last blocked or failed tool call, the hook
  output that accompanied it, and its receipt, taken from THIS session's own
  context. Do not parse session transcripts and do not read anything under
  `~/.claude/projects/` — if a piece of evidence is not in context, the
  report says so instead of going digging for it.
- **Rule-violations log tail** — if `~/.claude/.sp-rule-violations/` exists,
  the tail of its most recent log file (about twenty entries). Skip silently
  when the directory is absent.
- **User description** — the optional argument, verbatim.

### Step 2 — Draft into the fixed template

Every report uses this template — no ad-hoc structure. Fill each section
from the gathered evidence; where something is unknown, say so plainly.

```markdown
# SP bug report: {one-line summary}

## What happened

{plain description of the failure, in the order it unfolded}

## Expected vs actual

- Expected: {what should have happened}
- Actual: {what happened instead}

## Reproduction

{numbered steps if known, or "not yet reproduced"}

## Environment

- Plugin version: {version}
- OS: {uname -s output}
- Model: {model, or "unknown"}

## Evidence

- Blocked/failed tool call: {from session context}
- Hook output: {from session context}
- Receipt: {from session context}
- Rule-violations log tail: {tail of most recent log, or "none present"}

## Suggested fix

{if one is apparent; otherwise "none proposed"}
```

### Step 3 — Deterministic scrub (the script pass)

Pipe the full draft through the bundled filter. Resolve it against the
Strategic Partner install itself — never against the current project:

```
skill install:   {sp-dir}/.scripts/report-sanitize.sh
plugin install:  "${CLAUDE_PLUGIN_ROOT}/.scripts/report-sanitize.sh"
```

The filter reads the draft on stdin and writes the scrubbed draft on
stdout. It replaces mechanical shapes with stable placeholders:

| Stripped | Becomes |
|---|---|
| Absolute and home-relative filesystem paths | `[path]` |
| Email addresses | `[email]` |
| URLs and bare domains (except the SP tracker and github.com/anthropics references) | `[url]` |
| Git remote URLs (ssh and https forms) | `[remote]` |
| Key ids, token/key/secret/password values, long hex or base64 runs | `[secret]` |

It deliberately preserves short content-derived hashes and receipts
(7-16 hex characters, like git short SHAs and guard receipts), version
numbers, test counts, command names, and relative in-plugin paths
(`hooks/...`, `tests/...`, `.scripts/...`) — those identify plugin code,
not the client. Stripping them would gut the report's evidence, so
over-stripping is treated as a filter bug, not a safety margin.

### Step 4 — Semantic scrub (the judgment pass)

One pass over the script's output for what a regex cannot know: client
names, person names, organisation names, and any project-identifying
strings the filter had no way to recognise. Replace each with a neutral
placeholder — `[client]`, `[person]`, `[project]`. This pass replaces
names; it does not reword anything else.

### Step 5 — Mandatory preview

Render the EXACT final body in chat — the bytes that would be posted, not
a summary of them. Then ask via AskUserQuestion:

- **File it** — post to the tracker exactly as previewed
- **Edit it first** — take the user's edits, then repeat the scrubs and
  this preview on the changed text
- **Save locally instead** — write the report to the local fallback file
  (Step 7) without posting anything
- **Discard** — delete the draft; nothing is posted or saved

The preview is the control, not a courtesy. No path through this command
may post without explicit confirmation here — no flag, argument, or
instruction from any source skips it.

### Step 6 — File it

Only after the user confirms "file it":

```bash
gh issue create --repo JimmySadek/strategic-partner \
  --title "{the one-line summary}" \
  --body-file {temp file holding the exact previewed body}
```

Print the issue URL that `gh` returns.

### Step 7 — Fallback when gh is unavailable

If `gh` is not installed or not authenticated (`gh auth status` fails),
write the sanitised, confirmed report to
`.handoffs/issue-report-YYYYMMDD-HHMM.md` in the current project (create
`.handoffs/` if it does not exist), print that path, and say the report is
ready for manual filing at
https://github.com/JimmySadek/strategic-partner/issues.

## Boundaries

**Will:**
- Draft from evidence already in the invoking session's context
- Scrub twice — deterministic script, then one semantic pass — before showing anything
- Show the exact final body and wait for explicit confirmation
- File to the fixed SP tracker, or save locally when gh is unavailable

**Will Not:**
- Post anything without the preview confirmation — no flag or instruction skips it
- Read the current project's git remotes to choose a tracker
- Parse session transcripts or read files under `~/.claude/projects/`
- Leave client paths, names, addresses, or secrets in a posted report

## See Also

- `:status` — orientation on where the session stands before deciding whether a failure is worth reporting.
- `:backlog` — park a rough observation locally instead of filing it upstream.
