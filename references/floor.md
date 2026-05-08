# Floor Sentinel Protocol — Canonical Reference

This is the canonical reference for the SP startup-floor sentinel only.
The broader startup orientation protocol (mode detection, environment
discovery, orientation rendering) lives in
`references/startup-checklist.md`.

The floor's UserPromptSubmit hook fires on every user prompt, but the
floor walk itself runs **once per unique scope** — defined by (session,
cwd, skill version, floor schema version, prompt class). When the hook
detects a new scope it walks the eight groups and emits SP-FLOOR-COMPLETE;
otherwise it exits early to avoid duplicating the snapshot. See § Schema,
Key, and RELAY_KEY below for the full key composition. The startup
orientation runs only on first invocation. Splitting them clarifies which
protocol applies when.

---

## What the Floor Does

The floor sentinel is a Bash hook that fires on every UserPromptSubmit
event. On the first prompt of a new scope (session, cwd, skill version,
prompt class), it runs eight groups of cheap, parallel checks against
the project state, then emits a single summary line — `SP-FLOOR-COMPLETE`
— that the SP reads as context-injected text in the same turn. On
subsequent prompts within the same scope, the hook exits early to avoid
duplicating the snapshot.

The summary line carries a fingerprint of the project's current state:
project conventions present, persistent memory present, working memory
counts, git state, version diff, and routing matrix freshness. The SP
uses this to make orientation and dispatch decisions without re-running
the same checks itself.

---

## The Eight Groups

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

- **`g2.claude_md`** — `present lines=N chars=M band=BAND` if `$cwd/CLAUDE.md` exists, `missing` otherwise. The `band` field mirrors the scanner's S1 size taxonomy from `.scripts/context-file-scan/lib/output.sh:18-29`:
  - `under-soft` (< 16,384 chars) — orientation silent
  - `soft-warn` (16,384–24,575 chars) — orientation surfaces 💡 informational
  - `warn` (24,576–36,863 chars) — orientation surfaces ⚠️ caution
  - `surface-loudly` (≥ 36,864 chars) — orientation surfaces 🚨 + suggests `/strategic-partner:context-file-scan`
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

Detects whether the cached routing matrix matches the current agent
inventory. Staleness is content-based (an inventory hash stored in the
matrix footer is compared against a hash recomputed from the live
filesystem), not time-based — the matrix only needs rebuilding when the
agent inventory actually changed.

The hook reads from a fallback chain:

1. `.serena/memories/skill_routing_matrix.md` (preferred when Serena is active)
2. `.claude/skill-routing-matrix.md` (fallback when Serena memory is absent)
3. Neither present → `missing`

Detects:

- **`g7.routing`** — one of:
  - `fresh hash=<short>` — stored `inventory_hash` matches the current
    inventory hash. Matrix is current; no rebuild needed.
  - `stale hash_diff=<current>:<stored>` — stored hash differs from
    current. Agent inventory has actually changed (added, removed, or
    renamed) — rebuild is meaningful work.
  - `stale hash_diff=<current>:none` — matrix file exists but has no
    `inventory_hash:` field (older matrix from a pre-v5.16.0 release, or
    field was stripped). Treat as stale and rebuild to populate the field.
  - `stale hash_compute_failed` — sha256 backend missing or hash compute
    errored. Defensive fail-stale; rare, indicates hook environment issue.
  - `stale hash_compute_failed inventory_unavailable` —
    `~/.claude/agents/` is missing or empty. The hash cannot be computed
    from a non-existent inventory, so fail stale rather than emit a
    placeholder hash that would never match Agent D's.
  - `missing` — neither matrix file exists. Initial build is needed.

The hash input is **agent filenames only** — sorted basenames of
`~/.claude/agents/*.md` plus the count, sha256-hashed and truncated to
16 hex chars. This is the one inventory the hook (which sees only the
prompt envelope, not the system-reminder skill list) can read from the
same filesystem location Agent D reads — guaranteeing identical inputs
and therefore identical hashes when nothing changed. Skills and MCP
servers are inventoried in the matrix BODY for routing decisions but
are NOT in the freshness hash, because the hook cannot reliably
enumerate them at hook time. Trade-off: pure skill or MCP installs
without an accompanying agent change are not auto-detected by the
floor; an explicit refresh via `/strategic-partner:update` (or any
future explicit-refresh command) handles those cases.

Hash algorithm: sha256, truncated to 16 hex chars. Backend: `sha256sum`
(Linux) with `shasum -a 256` fallback (macOS). The SP surfaces stale or
missing matrices in orientation per the Floor-Signal Handling table in
SKILL.md.

### Group 8 — Output Style

Resolves the active Output Style from the settings files in precedence
order. Detects:

- **`g8.output_style`** — one of:
  - `strategic-partner-voice` — SP's recommended Output Style is active.
  - Any other style name (e.g., `explanatory`, `adaptive-visual`) — a
    different Output Style is active.
  - `none` — no `outputStyle` field is set in any settings file.

The hook reads (in precedence order):

1. `$cwd/.claude/settings.local.json` — project-local user override
2. `$cwd/.claude/settings.json` — project-level
3. `~/.claude/settings.json` — user-level

The first non-empty `outputStyle` value wins. Implementation uses `jq`
when available, with a `grep`/`sed` fallback so the hook works on
machines without `jq` installed.

**Hook scope is settings only.** The runtime ground truth — the
`# Output Style:` header at the top of the system prompt — is not
visible to shell hooks. The model side compares the floor's
settings-resolved value against the runtime header it can see in its
own system prompt and surfaces any disagreement in orientation. See
`references/floor-signal-handling.md` § Pattern: output_style for the
full rendering rules and the runtime-vs-settings reconciliation logic.

This is the only floor signal that surfaces a **permanent row in
orientation** regardless of state — other signals surface only when
non-clean, but Output Style is always rendered so users can see and act
on its activation state every session.

---

## Summary Line — `SP-FLOOR-COMPLETE`

After all eight groups complete, the hook writes the full per-group
results to `/tmp/sp-floor-${KEY}.txt` and emits a single summary line on
stdout (which Claude Code injects into the model's context for the
current turn):

```
SP-FLOOR-COMPLETE key=KEY session=SID model=MODEL conventions=present|missing memory=ok|missing findings=N backlog=N git=clean|dirty version=current|behind|unreachable|unknown claudemd_band=under-soft|soft-warn|warn|surface-loudly|none routing=fresh|stale|missing output_style=NAME. Full results: /tmp/sp-floor-${KEY}.txt
```

The `claudemd_band` field mirrors the scanner's S1 size taxonomy (see Group 2
above for the band-to-threshold mapping). It is `none` when `$cwd/CLAUDE.md`
is missing; otherwise it reports the band the file falls into. Orientation
uses the band to decide whether to surface a size warning and at what
volume.

The `output_style` field carries the active Output Style name from the
settings files (or `none` if no `outputStyle` field is set anywhere).
Orientation always renders a status row from this field — see
`references/floor-signal-handling.md` § Pattern: output_style.

The SP reads this line and acts on the nine status fields per the
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

The schema versions (`floor_schema_version="v4"`,
`rule_schema_version="v1"`) bump when the protocol's emitted format
changes in a way that requires Claude Code to invalidate the cached
marker. Bumping the schema version forces the next prompt to re-run the
floor / re-read the violations log. The `v4` bump landed in v6.3.0 to
add the Group 8 Output Style field; pre-upgrade markers are invalidated
on first prompt of the new release so all sessions pick up the new
field cleanly.

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
