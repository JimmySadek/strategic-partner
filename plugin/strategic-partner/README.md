# Strategic Partner — Claude Code plugin

This directory is the **plugin packaging** of Strategic Partner (SP). Shared
advisory policy stays aligned with the skill-first install, while command
namespaces, install resolution, startup entry hooks, and voice delivery are
deliberately plugin-native. The plugin also carries a revised voice and startup
behavior aimed at making SP feel like a thinking partner rather than a protocol
runner.

Status: **supported plugin packaging**. The standalone skill remains supported
too; use the switch commands when you want to move between install shapes.

## What's inside

| Component | Path | Notes |
|---|---|---|
| Skill | `skills/strategic-partner/SKILL.md` | Full standalone-skill behavior, minus the 260-line inlined hook block (now `hooks/hooks.json`), plus the Presence revisions (see below) |
| Commands | `commands/*.md` | The shared subcommands under `/strategic-partner-plugin:<name>`, plus `/strategic-partner-plugin:switch-to-skill` for returning to the standalone skill |
| Hooks | `hooks/hooks.json` + `hooks/entry.sh` | UserPromptExpansion for typed commands, PreToolUse for model-invoked Skill activation and the source guard, SessionStart for the resident advisor, UserPromptSubmit compatibility/relay, and one-shot Stop checks for missing startup or closure ceremonies |
| Guard chain | `hooks/guard-impl.sh`, `hooks/context-file-guard.sh`, `.scripts/context-file-scan/` | Same source-file-blocking logic as the standalone skill, including writes to `/tmp`, `/private/tmp`, and `$TMPDIR` for scratchpad file tools |
| Reference bundle | `skills/strategic-partner/references/`, `…/assets/templates/`, `…/.scripts/migrate-backlog.sh` | Shared advisory policy stays aligned with the standalone skill; startup mechanics and continuation commands intentionally use plugin paths and names |
| Voice | `output-styles/strategic-partner-voice.md` | Native plugin component (no copy-install, no staleness); style v7-plugin |
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

Every activation also creates a startup-pending marker until Stop confirms the
floor, visible project recenter, and orientation question. Clear session-end
intent is checked for the full handoff evidence set. Either ceremony may block
Stop once for a corrective turn; `stop_hook_active` prevents loops. The armed
state remains per-session, and `/clear` starts a new lifecycle boundary.

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
  states the position and stops. The four protocol-mandated question points are
  unchanged.
- **Voice v7-plugin** — the output style keeps plain-English discipline,
  deliberate visuals, and the anti-sycophancy rules, and drops per-turn ceremony
  (mandatory per-section emoji, five response templates, the 18-item pre-send
  checklist) in favor of five checks, plus a visible-first startup/status shape
  so the useful recenter appears before the question widget.
- **Floor fields adapted** — install-mechanics checks that plugins make
  obsolete (command symlinks, output-style copy staleness) now report
  `plugin-native` and stay silent in orientation.

Everything else — the advisory/source boundary, the context-file stewardship
gate, fence emission, closure ledger, delivery protocols, backlog stewardship —
is carried over unchanged.

## Install (skills-dir route, no marketplace)

Copy or symlink this directory into Claude Code's skills directory:

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
{ "agent": "strategic-partner:sp-advisor" }
```

The session gate detects this at SessionStart, runs the startup floor once at
session open (off the prompt path — something the skill-first install cannot
do), and arms the advisory guard for that session only.

## MCP / Serena — deliberate external dependency

A plugin **can** bundle an MCP server (a `.mcp.json` at plugin root — the
official Serena plugin itself ships exactly that, via `uvx`). Note that
plugin-bundled MCP servers **auto-connect with no approval prompt** the moment
the plugin is enabled — unlike project-level `.mcp.json` servers, which Claude
Code asks the user to approve first. This plugin deliberately does **not**
bundle Serena, for three reasons (the missing consent gate strengthens all
three):

1. **Double registration.** Most SP users already have Serena (its own plugin
   or a user-level MCP entry). Bundling a second instance duplicates every
   tool and its token cost, with no dedup mechanism.
2. **Guard coverage.** SP's Serena write-guard matches the tool prefix of the
   standalone Serena plugin (`mcp__plugin_serena_serena__`). A bundled copy
   would register under a different prefix and its write tools would bypass
   the guard — bundling would be actively less safe.
3. **Weight.** Serena pulls a Python toolchain at session start. SP works
   without it (the floor reports `memory=missing` and SP degrades gracefully),
   so forcing the dependency on every install is not the smallest change.

To get memory features, install Serena once from the official marketplace
(`/plugin install serena@claude-plugins-official`) — SP detects it
automatically.

## Known limitations

- **Namespacing:** `/strategic-partner` becomes
  `/strategic-partner-plugin:strategic-partner`; `/sp` and `/advisor` no longer
  resolve as typed plugin commands (natural-language triggering still works). No
  alias mechanism exists in the plugin format.
- **`:update` subcommand:** still targets the git/skillshare install flow. On
  the skills-dir route this is correct only if the copied directory is a
  symlink back into the repo; a plain copy must be re-copied after updates.
- **Serena write-guard prefix:** the guard covers the official Serena plugin's
  tool prefix only — same as the standalone skill today.
