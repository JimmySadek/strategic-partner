# Strategic Partner — Claude Code plugin

This directory is the **plugin packaging** of Strategic Partner (SP). Shared
advisory policy stays aligned with the skill-first install, while command
namespaces, install resolution, startup entry hooks, and voice delivery are
deliberately plugin-native. The plugin also carries a revised voice and startup
behavior aimed at making SP feel like a thinking partner rather than a protocol
runner.

Status: **supported plugin packaging, and the successor to the standalone
skill install.** The standalone skill is deprecated as of 2026-08-07 — it
still works and still receives updates, and no removal is scheduled. Use the
switch commands to move between shapes.

## What's inside

| Component | Path | Notes |
|---|---|---|
| Skill | `skills/strategic-partner/SKILL.md` | Full standalone-skill behavior, minus the inlined hook block (now `hooks/hooks.json`), plus the Presence revisions (see below) |
| Commands | `commands/*.md` | The shared subcommands under `/strategic-partner-plugin:<name>`, plus `/strategic-partner-plugin:switch-to-skill` for returning to the standalone skill |
| Hooks | `hooks/hooks.json` + `hooks/entry.sh` | UserPromptExpansion for typed commands, PreToolUse for model-invoked Skill activation and the source guard, SessionStart for the resident advisor, UserPromptSubmit compatibility/relay, startup-quality tracking, and the one-shot closure check |
| Guard chain | `hooks/guard-impl.sh`, `hooks/context-file-guard.sh`, `.scripts/context-file-scan/` | Same source-file-blocking logic as the standalone skill, including writes to `/tmp`, `/private/tmp`, and `$TMPDIR` for scratchpad file tools |
| Reference bundle | `skills/strategic-partner/references/`, `…/assets/templates/`, `…/.scripts/migrate-backlog.sh` | Shared advisory policy stays aligned with the standalone skill; startup mechanics and continuation commands intentionally use plugin paths and names |
| Voice | `output-styles/strategic-partner-voice.md` | Native plugin component (no copy-install, no staleness) |
| Resident advisor | `agents/sp-advisor.md` + `settings.json.example` | Opt-in only — see below |

## The session gate (why this plugin is safe to enable globally)

Plugin hooks fire in **every** session while a plugin is enabled. SP's guard
must not block source edits in ordinary executor sessions. `hooks/entry.sh`
therefore scopes every hook to sessions where SP is actually active, arming on
three structural activation signals only (never transcript content sniffing):

```
Typed SP invocation (UserPromptExpansion, with UserPromptSubmit fallback), including:
  /strategic-partner-plugin:strategic-partner
  /strategic-partner-plugin:handoff (and other non-utility subcommands)
  /strategic-partner..., /sp, /advisor              →  armed
Utility prompts :help / :copy-prompt / :update      →  not armed
Skill tool invoked with …strategic-partner          →  armed + startup floor
SessionStart agent_type or settings select sp-advisor → armed + startup floor
Anything else                                       →  every hook exits 0 in a few ms
```

The matcher also accepts trial or custom plugin namespaces containing
`strategic-partner` for the same subcommand set.

Every activation also creates a startup-pending marker so Stop can observe the
floor and visible project recenter once. Missing startup evidence is logged and
the marker is cleared; it never blocks a useful answer or requires an artificial
closing question. Clear session-end intent is still checked for the full handoff
evidence set, and closure may block Stop once for a corrective turn.
`stop_hook_active` prevents loops. The armed state remains per-session, and
`/clear` starts a new lifecycle boundary.

## Behavior changes vs standalone SP (deliberate)

Packaging alone cannot fix a mechanical-feeling advisor, so this plugin also
revises the advisory behavior:

- **Presence Over Protocol** — a new top-level SKILL.md section: start from the
  user's situation, hold a point of view, one best next move, push back on weak
  premises, structure only when it helps, boundaries without paperwork.
- **Compact but useful orientation** — startup and status show a visible
  recenter first, then use the question widget with a compact fact echo. A
  status table only appears when 3+ signals need attention. Green-row
  dashboards are explicitly banned. Closing question options are drawn from
  live project state, not a generic menu.
- **Questions rebalanced** — `AskUserQuestion` remains the only way to ask, but
  analysis no longer *owes* a question: when the analysis points one way, SP
  states the position and stops. The protocol-mandated question points are
  unchanged.
- **Voice** — the output style keeps plain-English discipline,
  deliberate visuals, and the anti-sycophancy rules, and drops per-turn ceremony
  (mandatory per-section emoji, a template per response shape, the long pre-send
  checklist) in favor of a shorter set of checks, plus a visible-first startup/status shape
  so the useful recenter appears before the question widget.
- **Floor fields adapted** — install-mechanics checks that plugins make
  obsolete (command symlinks, output-style copy staleness) now report
  `plugin-native` and stay silent in orientation.

Everything else — the advisory/source boundary, the context-file stewardship
gate, fence emission, closure ledger, delivery protocols, backlog stewardship —
is carried over unchanged.

## Install

**Through Claude Code (the managed route):**

```
/plugin marketplace add JimmySadek/strategic-partner
/plugin install strategic-partner-plugin@strategic-partner
/reload-plugins
```

Claude Code keeps this copy separate from your working tree — if you already
have a manual copy in the skills directory, retire it before reloading or both
will load.

**By hand (copy or symlink):** copy this directory into Claude Code's skills
directory.

```bash
cp -R plugin/strategic-partner ~/.claude/skills/strategic-partner-plugin
```

Claude Code treats any skills-dir directory containing
`.claude-plugin/plugin.json` as a plugin. Restart (or `/reload-plugins`) and
the skill is available as `/strategic-partner-plugin:strategic-partner`, the
commands as `/strategic-partner-plugin:<name>`, and the voice style in
`/config`.

Do **not** run this alongside an active standalone SP session doing real work:
both guards would fire (verdicts are identical, so this is redundant rather
than harmful, but trial runs should stay isolated).

## Resident advisor (opt-in only)

`agents/sp-advisor.md` defines a main-thread advisory persona. The pairing
settings file ships **disabled** (`settings.json.example`) because a plugin
`settings.json` with an `agent` key would force EVERY session — including
executor sessions — into advisory mode.

To opt in for one project, add to that project's `.claude/settings.json`:

```json
{ "agent": "sp-advisor" }
```

The session gate detects this at SessionStart, runs the startup floor once at
session open (off the prompt path — something the skill-first install cannot
do), and arms the advisory guard for that session only.

## MCP / Serena — SP-managed now, plugin-owned next

Strategic Partner owns the Serena experience it recommends. Run
`/strategic-partner-plugin:serena` to check the current setup. If Serena is
missing, outdated, noisy, partially configured, or duplicated, the command
explains the impact, previews the exact changes, and offers a reversible fix.
Healthy setups stay quiet.

During the current dual skill/plugin period, both distributions use one stable
user-level Serena server. The supported launcher uses Claude's Serena context,
binds to the exact current repository or worktree, and prevents the dashboard
from opening a browser tab automatically. Existing `.serena` memories and
project artifacts are not moved or rewritten.

**Plugin-owned auto-connect is the declared destination.** It is intentionally
gated, not rejected. Before this plugin ships an automatic MCP connection, SP
must prove the stable runtime, observe and guard the plugin-owned namespace,
migrate existing standalone registrations without duplicates, and pass cold
session tests for exact-worktree activation, quiet startup, memory preservation,
and rollback. Until those gates pass, bundling a second server would create the
very conflict the steward is designed to prevent.

## Known limitations

- **Namespacing:** `/strategic-partner` becomes
  `/strategic-partner-plugin:strategic-partner`; `/sp` and `/advisor` no longer
  resolve as typed plugin commands (natural-language triggering still works). No
  alias mechanism exists in the plugin format.
- **`:update` subcommand:** reports your version, whether a newer release
  exists, and what is missing from the bundle — then lists the places updating
  can happen and lets you pick the one matching how you installed it. It does not
  work that out for you, and it performs no update: nothing is created, moved,
  replaced, or deleted, and it runs no git command. Installed through Claude
  Code, updating is `/plugin marketplace update strategic-partner` followed by
  `/plugin update strategic-partner-plugin@strategic-partner`, then a restart —
  both commands are needed, because the first only refreshes the catalog. Or turn
  on background auto-update once under `/plugin` → **Marketplaces**; it is off by
  default for third-party listings. Running from your own clone or a copy you
  placed yourself, updating stays yours to do. Note that installing through
  Claude Code creates a separate managed copy rather than adopting the directory
  you already have — retire the old one before reloading, or both will load.
- **Serena connection ownership:** auto-connect remains on the published
  roadmap while the plugin uses the shared, SP-managed user-level runtime.
