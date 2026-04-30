# Floor Sentinel Protocol — Canonical Reference

This is the canonical reference for the SP startup-floor sentinel only.
The broader startup orientation protocol (mode detection, environment
discovery, orientation rendering) lives in
`references/startup-checklist.md`.

The floor runs **unconditionally on every user prompt** via the
UserPromptSubmit hook in SKILL.md frontmatter. The startup orientation
runs only on first invocation. Splitting them clarifies which protocol
applies when.

---

## What the Floor Does

The floor sentinel is a Bash hook that fires on every UserPromptSubmit
event (every time the user sends a prompt to Claude Code). It runs seven
groups of cheap, parallel checks against the project state, then emits a
single summary line — `SP-FLOOR-COMPLETE` — that the SP reads as
context-injected text in the same turn.

The summary line carries a fingerprint of the project's current state:
project conventions present, persistent memory present, working memory
counts, git state, version diff, and routing matrix freshness. The SP
uses this to make orientation and dispatch decisions without re-running
the same checks itself.

---

## The Seven Groups

Each group runs in a sub-shell so a failure in one cannot abort the
others. All groups together must complete in well under the 10-second
hook timeout.

### Group 1 — Environment

Detects:

- **`g1.model`** — the model ID for the current session (from the hook
  payload's `.model` field, or `unknown` if missing)
- **`g1.self_repair`** — whether `${HOME}/.claude/commands/strategic-partner/`
  symlink count matches the source `commands/` directory (`ok` /
  `mismatch` / `missing`)
- **`g1.codex`** — `available` if `codex` is on PATH, `missing` otherwise
- **`g1.context_window`** — `1m` if the model identifier matches `1m`
  (case-insensitive) or `SP_CONTEXT_WINDOW=1M` is set; `default`
  otherwise
- **`g1.auto_memory`** — `available` if `${HOME}/.claude/projects` exists,
  `unknown` otherwise

### Group 2 — Project Conventions

Detects:

- **`g2.claude_md`** — `present lines=N` if `$cwd/CLAUDE.md` exists,
  `missing` otherwise
- **`g2.rules_dir`** — `present count=N` if `$cwd/.claude/rules/` exists,
  `missing` otherwise

### Group 3 — Persistent Memory

Reads `.serena/memories/` files directly (hooks cannot call Serena MCP
tools). Detects:

- **`g3.serena_memories`** — `present count=N` if `.serena/memories/`
  exists with `.md` files
- **`g3.project_overview`** — `present` if `project_overview.md` exists
- **`g3.decision_log`** — `present lines=N` if `decision_log.md` exists

### Group 4 — Working Memory

Reads `.handoffs/findings-*.md` and `.backlog/*.md` for counts and
frontmatter. Detects:

- **`g4.findings`** — count of `findings-*.md` files
- **`g4.backlog_count`** — count of `.backlog/*.md` files
- **`g4.backlog_item`** — one line per backlog item with `name`, `status`,
  `title` extracted from YAML frontmatter

### Group 5 — Git State

Runs timeout-bounded git commands (1 second each). Detects:

- **`g5.branch`** — current branch name
- **`g5.status`** — `clean` or `dirty changed=N`
- **`g5.last_commit`** — first 80 chars of `git log --oneline -1`
- **`g5.git`** — `missing` if `.git/` not present

### Group 6 — Version

Compares local SKILL.md `version:` field against the latest GitHub
release. Uses a bounded curl (`--max-time 8`) and tolerates GitHub's
pretty-printed JSON (whitespace between key and value). Detects:

- **`g6.local`** — local version string from `SKILL.md`
- **`g6.remote`** — remote version from GitHub releases, or `unreachable`
  if the curl failed
- **`g6.diff`** — `current` / `behind` / `unreachable` / `unknown`

### Group 7 — Routing Matrix Freshness

Detects whether the Serena `skill_routing_matrix.md` memory is recent
enough to trust without rebuilding:

- **`g7.routing`** — `fresh age_seconds=N` (file mtime within the last
  hour), `stale age_seconds=N` (older than an hour), or `missing` if the
  file does not exist

The 1-hour staleness window is a heuristic balancing freshness against
dispatch overhead. New skills installed since the last build will not be
visible until the matrix is rebuilt; the SP surfaces stale matrices in
orientation per the Floor-Signal Handling table in SKILL.md.

---

## Summary Line — `SP-FLOOR-COMPLETE`

After all seven groups complete, the hook writes the full per-group
results to `/tmp/sp-floor-${KEY}.txt` and emits a single summary line on
stdout (which Claude Code injects into the model's context for the
current turn):

```
SP-FLOOR-COMPLETE key=KEY session=SID model=MODEL conventions=present|missing memory=ok|missing findings=N backlog=N git=clean|dirty version=current|behind|unreachable|unknown routing=fresh|stale|missing. Full results: /tmp/sp-floor-${KEY}.txt
```

The SP reads this line and acts on the seven status fields per the
Floor-Signal Handling table (SKILL.md § Floor-Signal Handling).

For per-field remediation patterns (which agent to dispatch, which
model, which prompt skeleton, which verification), see
`references/floor-signal-handling.md`.

---

## Schema, Key, and RELAY_KEY

The hook uses two stable identifiers:

- **`KEY`** — first 16 chars of `sha256(session_id|cwd_hash|tp_hash|skill_version|floor_schema_version|prompt_class)`.
  This is the floor's own cache key. The marker file
  `/tmp/sp-floor-${KEY}.flag` ensures the floor runs **once per
  unique combination of (session, cwd, transcript, skill version,
  floor schema version, prompt class)** — repeated prompts in the same
  session reuse the same KEY and skip the floor.

- **`RELAY_KEY`** — first 16 chars of `sha256(session_id|cwd_hash|tp_hash|skill_version|rule_schema_version)`.
  This is the rhythm enforcer's relay channel. The Stop hook writes
  violations to `/tmp/sp-rule-violations-${RELAY_KEY}.log`, and the next
  UserPromptSubmit cycle reads that log and surfaces the count to the
  SP via the same context-injection mechanism. This decouples the floor
  from the rhythm enforcer — they share session identity but
  schema-version their key independently so a schema bump on one does
  not invalidate the other's cache.

Both keys are deterministic for a given session — the same prompt
shape in the same session always produces the same KEY/RELAY_KEY pair.

The schema versions (`floor_schema_version="v3"`,
`rule_schema_version="v1"`) bump when the protocol's emitted format
changes in a way that requires Claude Code to invalidate the cached
marker. Bumping the schema version forces the next prompt to re-run the
floor / re-read the violations log.

---

## Carve-Out for Utility Subcommands

Three subcommands are exempt from the floor and the rhythm enforcer:

- `/strategic-partner:help`
- `/strategic-partner:copy-prompt`
- `/strategic-partner:update`

These are stateless utility commands — the user just wants the
subcommand to run, not a full advisory orientation. Running the floor
on them adds latency without informing any decision the subcommand
will make.

The carve-out is enforced by a Perl regex check at the top of the hook:

```
if printf '%s' "$prompt" | perl -e 'undef $/; $_=<STDIN>; exit($_ =~ /\A\s*\/(strategic-partner|advisor|sp):(help|copy-prompt|update)\s*\z/ ? 0 : 1)' 2>/dev/null; then
  exit 0
fi
```

When the carve-out matches, the hook exits 0 immediately — no
SP-FLOOR-COMPLETE line, no /tmp markers, no rhythm-enforcer relay. The
SP body still runs normally; it just does not get the context-injected
floor summary on these specific utility invocations.

---

## Cross-Reference

| Reference | Relationship |
|---|---|
| `SKILL.md` § Floor-Signal Handling | Summary table — what action to take per non-clean signal |
| `references/floor-signal-handling.md` | Per-pattern dispatch examples (agent type, model, prompt skeleton, verification) |
| `references/startup-checklist.md` | Broader startup orientation (mode detection, environment discovery, orientation rendering) |
| `references/hooks-integration.md` | Hook lifecycle and integration patterns (which hooks fire when) |
