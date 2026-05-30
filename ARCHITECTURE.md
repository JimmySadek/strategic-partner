# Strategic Partner — Architecture

Internal architecture reference for the strategic-partner skill. Maintainer-facing; not required reading for users.

---

## File layout

```
strategic-partner/
  SKILL.md                              # Lean hub — identity, core behaviors, routing dispatch
  setup                                 # Command registration script (run after install/update)
  audit-permissions                     # Permission audit helper (Python 3.6+)
  .claude/rules/
    source-editing.md                   # Path-scoped behavioral rules for editing SP source (loaded only when editing SKILL.md / hooks/ / references/ / commands/ / tests/)
  hooks/
    guard-impl.sh                       # PreToolUse hook — blocks source edits in SP sessions
    lib/
      validators.sh                     # Shared validator logic (AUQ / tool-availability / fence-write coupling) — used by Layer 3 lint
  .scripts/
    context-file-scan/
      scan.sh                           # Main scanner orchestrator
      lib/                              # Helper functions (utils, output, layer probe, etc.)
      rules/
        structural.sh                   # S1-S9 structural detection rules
        behavioral.sh                   # B1-B8 behavioral detection rules
    release-publish.sh                  # GitHub release automation (Step 7 of release process)
  commands/
    help.md                             # Subcommand reference
    copy-prompt.md                      # Clipboard copy for fenced prompts
    handoff.md                          # Context handoff trigger
    status.md                           # Status briefing
    update.md                           # Version check + self-update
    codex-feedback.md                   # Cross-model adversarial review via Codex CLI
    context-file-scan.md                # Drift scanner for CLAUDE.md / AGENTS.md / GEMINI.md per the v6.0 policy
    backlog.md                          # Backlog review — parked items with trigger evaluation
  references/
    startup-checklist.md                # Identity commands, env vars, fire-and-verify agents
    floor.md                            # Startup-floor sentinel protocol (7 groups, summary line, carve-out rules)
    floor-signal-handling.md            # Per-pattern remediation for non-clean floor signals (worked examples)
    closure-floor.md                    # Closure-floor protocol (8 groups, state machine, anti-patterns)
    prompt-crafting-guide.md            # Routing tree, parallelization check, quality gates
    fast-lane.md                        # Simplicity scoring, consent flows, dispatch protocol
    context-handoff.md                  # Env var baseline, two-tier thresholds, split writes
    orchestration-playbook.md           # Model selection, parallelization heuristics, worktree isolation
    skill-routing-matrix.md             # Dynamic discovery protocol, task categories, and routing rules
    partner-protocols.md                # Session naming, /insights, version bumps, partner adaptation
    hooks-integration.md                # Hook event reference and integration patterns
    cognitive-patterns.md               # Named thinking heuristics for architecture and trade-offs
    companion-script-spec.md            # Spec for the optional companion-script integration
    pipeline/
      bootstrap.md                      # Pipeline stage 1 — prereq check (Q1/Q4 fresh-session)
      router.md                         # Pipeline stage 2 — 4-channel decision classification
      egress.md                         # Pipeline stage 3 — composite materiality gate
      asking-pattern.md                 # Pipeline stage 4 — AUQ depth modulation
      silent-log.md                     # Silent-channel surfacing format + prohibitions
      user-output-style.md              # Internal-vocabulary → plain-English translation layer
    provider-guides/
      anthropic.md                      # Claude XML prompt format template
      openai.md                         # GPT-5.5 prompt format template
      google.md                         # Gemini Markdown prompt format template
  assets/templates/
    prompt-template.md                  # Implementation prompt skeleton
    handoff-template.md                 # Session handoff skeleton (with /insights section)
  schemas/
    scanner-findings.json               # JSON schema contract for scanner findings (rule_id pattern, finding shape)
  docs/
    v4.0-implementation-decisions.md    # Decision log for audit findings F1-F12
  claudedocs/
    INCIDENTS.md                        # Incident archaeology — one entry per INC-YYYY-MM-DD ID, referenced by Provisional Guards
    gstack-*.md                         # Reference research notes from gstack ecosystem analysis
  tests/
    RUNBOOK.md                          # Manual fixture-review protocol
    lint-transcripts.sh                 # Release-time lint — AUQ / tool-availability / fence-write coupling / identity-reset rules against JSONL transcripts and handoffs
    lint-voice.sh                       # Release-time voice lint — scans CHANGELOG / README / commands/ for jargon-loaded patterns
    fixtures/
      v5.12.0/                          # F1-F5 regression fixtures for AUQ Materiality Gate
        F1-alpha-beta-gamma-planning-reconciliation.md
        F2-calendar-native-rehearsal-coordination.md
        F3-calendar-native-internal-bookkeeping.md
        F4-precedence-conflict-direct-rule-boundary.md
        F5-bootstrap-fresh-session-context-shift.md
      v5.13.0/                          # C1-C5 comprehension fixtures for voice overhaul
        C1-plain-english-opening-and-glossing.md
        C2-housekeeping-vs-user-status.md
        C3-position-greek-visual-aids.md
        C4-multi-step-workflow-decomposition.md
        C5-partner-profile-general-user-default.md
      v5.14.0/                          # V1-V7 regression fixtures for response envelopes + voice-fix
        V1-conversational-acknowledgment.md
        V2-closure-walk-through.md
        V3-auq-must-be-auq.md
        V4-hygiene-auto-execute.md
        V5-fenced-prompt-emission.md
        V6-analytical-dense-vocabulary.md
        V7-friend-perspective-jargon.md
      v5.15.0/                          # voice-lint and voice-transcript fixtures
        voice-lint/
        voice-transcript/
```

---

## Behavioral gates

### Pre-build decision checklist (Advisory Completion Gate)

Before any prompt, dispatch, or script is crafted, the advisor verifies five hard conditions:

1. Problem is framed (not solution-shaped)
2. Alternatives explored
3. Trade-offs surfaced
4. User confirmed direction
5. Definition of done established

If any condition is unmet, the advisor stays in advisory mode. Prevents the most common failure mode: jumping from brainstorming to implementation before thinking is done.

### Return-to-planning (Advisory Reset)

After every implementation cycle (user runs a prompt, or an agent completes a dispatch), the advisor explicitly resets to advisory mode and announces: "Back in advisory mode. I am reviewing the result, not continuing the build." Prevents implementation momentum from carrying into the next decision.

### Source-edit safety guard

A `PreToolUse` hook blocks `Edit`/`Write`/`Bash` mutations on source files when the advisor is active. Exit code 2 hard-blocks the tool call. Paired with the three behavioral gates above for defense in depth.

### Premise Challenge triggers

Every request is evaluated against six trigger conditions before being accepted at face value:

1. Names a technology before stating a problem
2. Describes how before why
3. Assumes a root cause without evidence
4. Frames a solution instead of a problem
5. Carries forward an unverified derivative finding from a previous session
6. Asks to improve a context file (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`) without scanning it first

When any trigger fires, the advisor pushes back with pointed questions before any work begins.

---

## Prompt quality checklist

Every crafted prompt renders a visible pass/fail table of 13 quality checks BEFORE the prompt body:

1. Skill routing
2. File context
3. Deliverables
4. Verification commands
5. Commit message
6. Format match (Anthropic XML / OpenAI / Gemini)
7. Copy-safety (no leaked XML)
8. Scope exclusions
9. Model-aware blocks
10. Hallucination prevention blocks
11. Background dispatch settings
12. Confidence labels
13. Provider-specific format

The check runs in the response, not in invisible reasoning — every crafted prompt can be audited without trusting hidden cognition.

---

## Memory architecture

Strategic Partner stewards four persistence layers:

- `CLAUDE.md` — project rules and conventions
- `.claude/rules/` — path-scoped behavioral rules (load only when matching files are edited)
- Auto-memory — session-spanning facts about user, feedback, project context
- Serena memory — semantic code navigation + cross-session decision log

Substantive decisions write to Serena as one coherent block when an advisory stretch ends. Factual corrections write immediately as routine hygiene. The session-end closure checklist catches anything missed.

---

## Cognitive patterns

14 named thinking heuristics (Bezos one-way doors, Munger inversion, Jobs focus-as-subtraction, and 11 more) are wired to specific decision points with mandatory triggers and actions. They fire automatically at the right moments — not a decorative reference table. Full list and trigger definitions live in `references/cognitive-patterns.md`.

---

## Startup status check

At session start and on each subcommand transition, a Claude Code hook gathers a snapshot of session-relevant facts:

- Active model
- Project conventions (`CLAUDE.md` / `AGENTS.md` / `GEMINI.md`)
- Persistent memory state
- Working memory counts
- Git state (clean / dirty branch)
- Version freshness (compare local against GitHub releases)
- Installed-tool picker freshness (inventory-hash mismatch)

A summary line is injected into the advisor's context. The hook deduplicates within a session — once the advisor has the snapshot, repeat prompts skip the gather.

Per-pattern remediation for non-clean signals (e.g., dirty git tree → surface with acknowledgment; missing memory → ask before dispatching the heavier Serena onboarding) is defined in `references/floor-signal-handling.md`.

---

## Per-turn rhythm enforcer

At the end of every assistant turn, a `Stop` hook scans the response for five common drift patterns:

1. Questions buried in prose (instead of using the structured-question tool)
2. Missing identity-reset announcement after agent dispatches return
3. First-person tool-availability claims without an actual tool call
4. Execution prompts written without writing the expected handoff file
5. Silent ignores of any non-clean signal from the startup status check

Violations carry forward to the next turn as a one-line note; the advisor self-corrects on next prompt.

---

## Session findings and backlog

Feedback captured during sessions is automatically logged to a session findings file. At natural session boundaries, the advisor offers to promote findings to a persistent backlog (`.backlog/[item].md` files with an explicit `trigger:` field). Items surface at startup when their triggers are met.

The backlog is the durable artifact for deferred work — commit messages and CHANGELOG entries are not sufficient on their own (per CLAUDE.md Provisional Guard "Deferred work needs durable artifacts").

---

## Closure walk-through

Session-end detection triggers an 8-group closure floor walked in the body of `/strategic-partner:handoff`:

1. Staleness verification
2. Architecture drift scan
3. Installed-tool picker verification
4. Persistent memory ledger
5. Project conventions ledger
6. Working memory ledger
7. Workspace ledger (with active backlog management)
8. Working tree closure

Each group runs a verification command, marks one of six states (rendered in plain English with status emojis in the user-facing layer: ✅ Checked, ✅ Already handled, 🟡 Needs your input, ⏭️ Skipped (you declined), ➖ Doesn't apply, 🚨 Uncommitted source changes), and either takes hygiene actions automatically or surfaces a structured question when there's a genuine decision to make.

A Post-Handoff Verification step gates the close with four lightweight checks (continuation prompt present, SP invocation included, findings file surfaced, `.gitignore` covers session-work directories) before the session ends.

---

## Optional background execution (Fast Lane)

For small mechanical tasks, the advisor may offer to dispatch a prepared prompt to a background agent instead of asking the user to paste it into a fresh session. Full mechanics — simplicity scoring, consent flows, dispatch protocol — live in `references/fast-lane.md`. Two key invariants:

1. The pre-build decision checklist must pass before any background dispatch
2. The advisor still thinks first, presents alternatives, and gets user consent before dispatching

Foreground (in-session) dispatches do not notify; backgrounded dispatches fire a single desktop notification at completion so the user can walk away during a 3-5 minute window and come back to the conclusion.

---

## Cross-model review modes

`/strategic-partner:codex-feedback` supports two modes:

- **Mode A — Pre-decision sounding board.** Used during advisory sessions to get an independent second opinion before committing to a path.
- **Mode B — Post-commit evidence audit.** Used at the Step 2b release-gate to adversarially review the proposed push diff against the prior release tag.

Both modes synthesize three-way perspectives (user / advisor / Codex). Verdict surfaces as GO / CONDITIONAL GO / NO-GO; CONDITIONAL GO requires re-running the audit after addressing conditions.

---

## Context handoff

When the conversation grows large, the advisor monitors context pressure and triggers a structured handoff before degradation. The handoff:

1. Writes a session-end markdown file to `.handoffs/` with all decisions, deliverables, and the continuation prompt
2. Splits writes between Serena memory (decisions) and the file (everything else)
3. Surfaces a fresh-session pickup prompt that includes the SP invocation, the handoff file path, and current state

The continuation session loads with full state via Serena memory + handoff file.

---

## Provider-specific prompt formatting

The advisor adapts prompt structure to the target model:

- **Anthropic / Claude** — XML tags (`<task>`, `<files_to_read>`, `<deliverables>`, `<verification>`)
- **OpenAI / GPT-5.5** — Markdown sections with explicit role labels
- **Google / Gemini** — Markdown sections with imperative framing

Provider guides live in `references/provider-guides/`.

---

## 1M context advisory

On 1M-context models (Opus 4.8), the advisor surfaces a one-time orientation note: autocompact defaults to ~95% (~950K), known Anthropic issues cause erratic behavior above ~256K tokens, and users can consider wrapping up or triggering handoff around 250K for reliable retrieval. Pure advisory; no settings changed.

---

## Release-time enforcement layers

Two automated checks run at release time:

- **`tests/lint-transcripts.sh`** — scans recent `.handoffs/` and JSONL transcripts for four behavioral rule violations (structured-question-must-be-structured-question, tool-availability claims without actual call, execution-prompt-without-handoff-file, identity-reset announcement after dispatch). Layer 3 backstop.
- **`tests/lint-voice.sh`** — scans CHANGELOG / README / commands/ for jargon-loaded patterns (function-call notation in prose, incident IDs, direction/layer refs, raw line refs, lowercase deliverable refs, placeholder strings). Plus a heuristic warn-only check for internal terms without a gloss on first occurrence.

Both lints are mandatory for non-docs-only pushes per CLAUDE.md § Steps 2a and 2c.

---

## Release process

The release process is documented in `CLAUDE.md` § "Release Process (Mandatory Before Push)". Highlights:

- Three-file version bump (`SKILL.md` / `README.md` / `CHANGELOG.md`)
- Hook verification (if release touches hooks)
- Codex Step 2b pre-release adversarial review (mandatory for non-docs-only pushes)
- Voice lint Step 2c (mandatory for non-docs-only pushes)
- README review at two levels (factual + first-time-user clarity), with hard structural constraints (300-line ceiling, "What's new" capped at current release only, "Under the hood" capped at 5 bullets, no SP-internal vocabulary without one-line gloss)
- GitHub Release creation via `.scripts/release-publish.sh`

---

## Provisional Guards

Bug-driven rules with named incidents, expiration dates, and review cadence. Each guard names the pattern, the past incident that motivated it, and a review date. Lives in `CLAUDE.md` § "Provisional Guards". Incident archaeology in `claudedocs/INCIDENTS.md`.
