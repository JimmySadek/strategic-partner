<p align="center">
  <img src="assets/images/banner.png" alt="Strategic Partner - Chief of Staff for Claude Code" width="100%">
</p>

[![Version](https://img.shields.io/badge/version-7.1.0-blue)](CHANGELOG.md)

# strategic-partner

A strategic advisory skill for Claude Code (an installable add-on that extends Claude Code's behavior) that separates thinking from building. It thinks with you in one session — asking the right questions, challenging assumptions, framing problems before jumping to solutions. Then it packages implementation for fresh sessions where the full context window is available. Decisions persist. Context stays clean.

> **What's new** — **7.1.0** restores a behavior that had quietly regressed: on small, reversible, single-concern changes, the advisor again reliably offers to run the work for you in the same session — dispatching an agent — instead of always handing you a prompt to paste. That offer now names the specific specialist agent, so a wrong pick is easy to catch before it runs; bigger or riskier changes still go out as a full prompt, exactly as before. See [CHANGELOG.md](CHANGELOG.md) for the full list and prior releases — including 7.0.x, which consolidated the advisor's decision engine and added a self-check that catches the advisor defending its own conclusion.

---

## The problem

AI coding assistants degrade as conversations grow. Every tool call, file read, and back-and-forth exchange pushes the original instructions further from the model's attention. By the time you're deep into implementation, the careful thinking from earlier has been diluted by hundreds of intermediate results.

Think of it like a meeting that started with a clear agenda but kept going for six hours. By hour four, decisions are being made on autopilot — not because anyone stopped caring, but because the original focus got buried under everything that came after.

Most workflows ignore this. You open one session, plan and build in the same window, and by the time you're in the weeds, decisions are being made mid-build with degraded instruction-following. When context fills up completely, everything is lost.

The strategic partner fixes this by enforcing a separation: persistent advisory context where decisions accumulate, and disposable execution context where clean context matters most.

---

## Who is this for

**Solo developers** — A second brain that interrogates your assumptions before you build, picks the right tool, and remembers decisions across sessions so you don't re-litigate them.

**Team leads** — Consistent prompt quality across implementation sessions, with a decision log that survives context resets. Your architectural intent carries forward even when execution happens in fresh windows.

**Non-technical PMs** — You can describe what you need in plain language. The advisor handles the translation into technical prompts, breaks large features into phased delivery, and reports back in terms you can act on. You never need to know which skill or model is best for a task.

---

## How it works

### Two sessions, one loop

**Strategic Partner (SP for short)** runs the advisor in one session. Your installed implementation skills (or background agents) execute in another.

```
+---------------------------------+     +---------------------------------+
|  SESSION 1: ADVISOR (persistent) |     |  SESSION 2: EXECUTOR (ephemeral) |
|                                  |     |                                  |
|  /strategic-partner              |     |  /feature-dev                    |
|                                  |     |  (or whatever skill SP chose)    |
|  - Thinks with you               |     |  - Builds what SP specified      |
|  - Challenges your assumptions   |     |  - Follows the prompt exactly    |
|  - Crafts implementation prompts |     |  - Commits when done             |
|  - Routes to the right skill     |     |  - You close this when finished  |
|  - Tracks decisions and state    |     |                                  |
|  - Stays open across phases      |     |  Opens fresh for each prompt.    |
|                                  |     |  No accumulated context.         |
|  YOU KEEP THIS ONE OPEN.         |     |  DISPOSABLE.                     |
+----------------+-----------------+     +----------------+-----------------+
                 |                                        |
                 |  1. SP crafts prompt ----------------> |
                 |                                        |  2. You paste & run
                 |                                        |
                 |  4. SP reviews, plans next  <--------- |  3. You report back
                 |                                        |     what happened
                 +----------------------------------------+
```

You describe what you need. The SP asks clarifying questions, then delivers a self-contained prompt targeting the right skill with the right model. You paste that prompt into a fresh session — full context window, zero accumulated baggage. When it finishes, you report back. The SP reviews the actual diff of what landed — not just your summary — extracts lessons, and crafts the next prompt.

**The SP never builds. The executor never decides.** That separation is what makes both work.

Before routing anything, the SP checks whether the request is a solution wearing a problem's clothes, presents alternatives where a decision is warranted, and returns to planning mode after every implementation cycle — the walk-through below shows this in practice.

### Optional background execution for small tasks

For small mechanical tasks, the SP may offer to dispatch the prepared prompt to a background agent instead of asking you to paste it into a fresh session. Same roles, same separation: SP decides what gets built and why; the agent executes what SP specifies. This optional shortcut is a delivery mechanism, not a personality change — the SP still thinks first, presents alternatives, and gets your consent before dispatching.

---

## What you get

Your team needs to build a **user onboarding flow** for a SaaS product. Here's what happens:

You open Claude Code and type:

```
/strategic-partner
```

Then say: *"We need to build an onboarding flow"*

**Strategic Partner responds:**

> That's a solution wearing a problem's clothes — "onboarding flow" names a feature, not the problem underneath.
>
> Before we scope this — what user problem does onboarding solve? Are new users dropping off? Confused by the setup? Missing a key activation step?

You clarify: *"New signups aren't completing setup — 60% drop off before connecting their first data source."*

> Good. This touches **auth**, **UI**, **backend state**, and **email triggers** — 4 concern areas. Your `CLAUDE.md` (the project-rules file Claude Code reads automatically) says React + Tailwind, no component library for modals yet.
>
> **Path A (Minimal):** 3-step inline wizard, no modal, connects existing setup flow. Ships fast, might need rework later.
> **Path B (Recommended):** Dedicated onboarding route with progress tracking, broken into 3 phases. Solid foundation.
> **Path C (Lateral):** Skip the wizard — auto-detect the user's intent from their first actions and surface contextual setup prompts. Higher effort, potentially higher activation.
>
> I'd go with **Path B** — it balances speed with a foundation that won't need rework. Path C is interesting but unproven for your user volume.

You pick Path B. The SP delivers 3 ready-to-paste prompts:

| Phase | Target skill | What it does |
|-------|-------------|-------------|
| **1 — Research** | *[picked from your installed tools]* | Read 5 files, map existing auth flow, identify where onboarding state should live |
| **2 — Build UI** | *[picked from your installed tools]* | WelcomeScreen + 3-step wizard, mock data only, no backend calls yet |
| **3 — Wire up** | *[picked from your installed tools]* | Connect wizard to user state, trigger welcome email on step 3 completion |

Each prompt includes: files to read first, constraints from CLAUDE.md, verification checklist, [✅ SAFE]/[⚠️ RISK] labels on key recommendations, expected commit message, and explicit NOT-in-scope exclusions.

You paste each phase into a fresh session and report back; the SP reviews what landed and hands you the next one (the loop from "How it works" above), until the feature ships.

### The key difference

| Aspect | Normal session | With the SP |
|--------|---------------|-------------|
| **Planning** | Discovered mid-build | Surfaced before any work starts |
| **Assumptions** | Unchallenged | Premise-checked, alternatives explored |
| **Big tasks** | One session, degrades at scale | Phased prompts, each with full context |
| **Knowledge** | Dies with the session | Persists via saved project notes and handoff files (saved snapshots a fresh session resumes from) |
| **Tool selection** | You pick | SP picks dynamically from your installed tools |
| **Confidence** | Implicit | [✅ SAFE]/[⚠️ RISK] labels on recommendations |

---

## Quick start

### Install

```bash
# Via npx (recommended)
npx skills add https://github.com/JimmySadek/strategic-partner

# Manual — clone to your preferred skills directory
git clone https://github.com/JimmySadek/strategic-partner.git <your-skills-dir>/strategic-partner
```

### Setup

After install completes, change into the install directory and run setup:

```bash
cd /path/to/strategic-partner    # the directory created by npx or git clone
./setup
```

Registers subcommands with Claude Code and installs the voice style (the formatting/tone profile that makes replies scannable for non-technical readers). If you already have a copy of the voice style, `setup` keeps yours and warns — without overwriting — when your installed copy is stale, unstamped (an older copy with no version marker), or missing. Optional: `./setup --audit-permissions` checks for permission gaps that cause friction in advisory sessions.

> **Tip:** You can also skip this terminal step. When you invoke `/strategic-partner` in Claude Code for the first time, the advisor detects the missing setup and offers to run it for you with a single yes/no prompt. The manual `./setup` invocation above remains the bootstrap-safe path — still the right choice for headless installs or scripted setup.

### Run

```
/strategic-partner
```

Resume from a previous session by passing a handoff file path:

```
/strategic-partner .handoffs/onboarding-flow-0304-1430.md
```

### Aliases

`/strategic-partner`, `/advisor`, `/sp` all invoke the same skill.

---

## What's included

The advisor operates through a lean core (SKILL.md) that loads reference material on demand:

- **Strategic advisory and prompt crafting** — the core loop: discover, challenge premises, present alternatives, route, craft, review. Prompts adapt to the target model and ship with hallucination-prevention and scope-discipline blocks built in.
- **Pre-build decision discipline** — every request is premise-checked, non-trivial tasks get three distinct approaches (minimal / recommended / lateral) before any routing, and recommendations carry [✅ SAFE] or [⚠️ RISK] confidence labels.
- **Plain-English partnership voice** — replies a non-technical reader can follow: decisions surfaced as structured choices, visual aids where they help, and anti-sycophancy rules that ban both empty agreement and performative pushback. The voice rules live in the skill core itself; the installable style file is a derived mirror kept in lockstep by a release-time check.
- **Skill and tool picking** — the advisor matches each task to the best of your installed tools and names its pick before anything runs, so a wrong choice gets caught early.
- **Cross-model adversarial review** — for high-stakes decisions, the advisor can send a curated brief to OpenAI's Codex CLI for an independent second opinion and synthesize the three-way view. Optional — requires Codex CLI installed.
- **Rules-file drift detection** — `/strategic-partner:context-file-scan` checks your project's rules file (`CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`) against 17 drift patterns, with interactive, report-only, and release-gate modes.
- **Cross-session memory and handoffs** — decisions, findings, and parked work survive across sessions, and when context fills, a handoff file lets a fresh session pick up exactly where the last one stopped. Backlog review flags work that already shipped and asks before closing it.
- **Hands-off execution options** — small reversible tasks can be dispatched to a background agent with a desktop notification on completion; and when a bigger task fits a hands-off run, the advisor offers a ready-made `/goal` autonomous-run suggestion in chat — never written into the prompt or any saved file.

Mechanism detail lives in [ARCHITECTURE.md](ARCHITECTURE.md).

### Under the hood

- **Implementation boundary** — a safety guard in Claude Code blocks accidental source edits in advisor sessions, paired with three behavioral gates (pre-build decision checklist, return-to-planning after execution)
- **Memory architecture** — stewards four persistence layers (`CLAUDE.md`, `.claude/rules/`, auto-memory, Serena memory) so decisions survive across sessions
- **Visible prompt quality checklist** — every crafted prompt renders a pass/fail table of 14 quality checks (skill routing, verification commands, and more) before the prompt body, so dispatches can be audited without trusting hidden reasoning
- **Startup status check** — at session start and on each subcommand, a hook (a small script Claude Code runs automatically at those moments) injects a one-line snapshot of project state into the advisor's context — conventions, memory, backlog, git status, version and setup health
- **1M-context session advisory** — on 1M-context sessions (such as Opus 4.8's 1M mode), the advisor surfaces a one-time orientation note: known Anthropic issues cause erratic behavior above ~256K tokens; consider wrapping up or triggering a handoff around 250K for reliable retrieval

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full file layout and mechanism detail.

---

## Subcommands

| Command | What it does |
|---------|-------------|
| `/strategic-partner:help` | List all subcommands |
| `/strategic-partner:copy-prompt` | Copy a recently emitted prompt to the OS clipboard |
| `/strategic-partner:handoff` | Trigger a context handoff with split writes |
| `/strategic-partner:status` | Where we stand, what's done, what's next |
| `/strategic-partner:update` | Check for updates and self-update to latest version |
| `/strategic-partner:codex-feedback` | Cross-model adversarial review via Codex CLI (GPT-5.5) |
| `/strategic-partner:context-file-scan` | Detect drift in `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` rules files (17 patterns) |
| `/strategic-partner:backlog` | Triage the project backlog (items grouped by lifecycle state, with an action menu) — including a scan that flags backlog work which has already shipped and asks before closing it |

---

## Requirements

- **Claude Code** — the skill runs inside Claude Code sessions
- **`jq`** (a small command-line JSON processor) — used by the rules-file scanner and the startup/status hooks. Install via `brew install jq` (macOS) or `apt install jq` / `dnf install jq` (Linux). Without `jq`, the rules-file scanner won't run and the startup snapshot is reduced — nothing blocks your session.
- **Serena MCP** (recommended) — an MCP server (a tool plugin Claude Code can call) that provides cross-session memory and semantic code navigation
- **Context7 MCP** (optional) — for library documentation lookup
- **Codex CLI** (optional) — for cross-model adversarial review

The skill works without Serena, but loses cross-session memory and semantic code navigation. `jq` is strongly recommended — the rules-file scanner requires it, and the startup snapshot is reduced without it.

### Supported platforms

| Platform | Status |
|---|---|
| macOS 13.0+ / Linux (GNU coreutils) | ✅ Fully supported |
| Windows WSL2 (recommended) / WSL1 | ✅ Supported — inherits Linux support (WSL1: Claude Code sandboxing unavailable per Anthropic) |
| Windows native (Git Bash / MSYS2 / Cygwin) | ⚠️ Experimental — symlink/interpreter/install-path limits; needs `SP_ALLOW_NATIVE_WINDOWS=1`. Use WSL2 |
| Windows native (cmd / PowerShell) | ❌ Unsupported — Claude Code requires a Bash-compatible shell |

---

## Staying updated

Every SP session checks for updates in the background and surfaces a one-line notice when a newer version is available. Run `/strategic-partner:update` to fetch the latest version — it detects whether you installed via skills or git clone, uses the right method, and re-runs `./setup` to refresh command registrations and flag a stale voice style if your installed copy is behind the shipped one. When an update introduces new subcommands, restart your Claude Code session so the CLI picks up the new registrations.

---

## Troubleshooting

| Scenario | What happens | What to do |
|---|---|---|
| **Serena MCP unavailable** | Cross-session memory and semantic navigation disabled | SP falls back to Grep/Glob. Memory features degrade but prompt crafting works. |
| **Skills missing** | The installed-tool picker can't match a task to an installed skill | SP routes to built-in Agent types (always available) or suggests installing the skill. |
| **No automatic warning before context fills up** | SP relies on self-assessed thresholds and periodic checks | A user-owned hook (Claude Code's pre-fill warning event — the signal Claude Code fires just before it compacts a full context) can serve as an extra backstop if you choose to configure one. |
| **Sub-agents hit permission walls** | Background agents can't prompt for approval | Specify `mode` on every agent spawn. Pre-approve `WebFetch(*)` and `WebSearch(*)` in `~/.claude/settings.json` for research agents. Run `./setup --audit-permissions` to check for gaps. |
| **Implementation session fails** | Executor reports errors or incomplete work | Report back to the SP. It will diagnose, rewrite the prompt with a different approach, and suggest retry. |
| **Codex CLI not found** | Cross-model review unavailable | Install from [github.com/openai/codex](https://github.com/openai/codex) and run `codex login`. Feature is optional. |

---

## License

MIT
