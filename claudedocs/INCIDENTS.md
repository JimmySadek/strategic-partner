# SP Project — Incident Archaeology

This file accumulates incident write-ups for SP project incidents that produced Provisional Guards or otherwise shaped SP process. Each entry is identified by an `INC-YYYY-MM-DD` ID matching the date the incident occurred and is referenced by one or more guards in `claudedocs/provisional-guards.md`. New entries follow the same `## INC-YYYY-MM-DD — <one-line summary>` heading pattern.

## INC-2026-07-13 — Serena utility armed the advisory startup ceremony

### What happened

During the fourth Serena stewardship validation run, the plugin correctly
opened the utility command and reached the repair flow. While the repair task
was running, the Stop hook blocked repeatedly because it expected a visible
project recenter and an advisory `AskUserQuestion`. Those requirements belong
to a full Strategic Partner advisory session, not to the focused Serena setup
utility.

### Why it broke

The plugin has two activation paths. `UserPromptExpansion` already classified
the namespaced `:serena` command as a utility and left the advisory ceremony
unarmed. The compatibility `UserPromptSubmit` parser duplicated the command
list, included `serena`, and exempted only `help`, `copy-prompt`, and `update`.
The same typed command therefore received opposite answers depending on which
hook event processed it. The fallback path created the per-session startup
marker, and the Stop hook then enforced a ceremony the utility never promised.

### Fix implemented

- Added `serena` to the explicit ceremony exemptions in both prompt classifiers
  and the legacy `:serena` argument path.
- Added a separate per-session utility-guard marker. Serena keeps the source
  mutation guard without creating the advisory active or startup-pending
  markers consumed by the Stop hook.
- Added a utility transcript replay proving both plugin and legacy command
  shapes skip the startup floor, create no advisory markers, retain source
  protection, and never produce a Stop block while the repair is running.

### Guard produced

`claudedocs/provisional-guards.md` now requires every plugin utility command to
be tested through both command-expansion and prompt-submit activation paths.
One classifier passing is insufficient while the compatibility path exists.

## INC-2026-07-10 — Exact confirmation blocked because transcript rows were joined by position

### What happened

During the v7.5.1 pre-release review, the user selected the exact required
option, `Dispatch now — general-purpose`. The plugin guard rejected the Agent
call twice and claimed no valid confirmation existed. The visible question and
answer matched, including the agent type.

The live transcript showed the question at row 542 and its answer at row 548.
Five runtime metadata rows — `last-prompt`, `ai-title`, `mode`,
`permission-mode`, and `bridge-session` — appeared between them. Both guarded
confirmation paths read row `question + 1` as the answer, so they inspected the
first metadata row instead of the matching tool result. The same assumption was
present in the newer `.sp-managed` activation path.

### Why it broke

The v7.4.4 decision-engine fix correctly bound authorization to the selected
option label and exact agent, but its fixtures placed every answer immediately
after its question. The implementation therefore preserved an unverified row-
adjacency assumption. v7.5.0 normalized visually similar dash characters and
whitespace, but that representation fix could not help when the parser read the
wrong event entirely.

Claude Code already exposes the stable relationship the guard needs:
`AskUserQuestion` has a tool-use ID, its answer is a `tool_result` carrying the
same `tool_use_id`, and the protected PreToolUse call has its own
`tool_use_id`. Row position and metadata row names are not part of that
identity contract.

### Fix implemented

- Replaced the duplicated adjacency parsers with one shared confirmation engine
  used by agent dispatch and `.sp-managed` activation.
- Correlated questions and answers by matching tool-use IDs, so any number or
  kind of metadata rows can appear between them.
- Bound each confirmation to the current protected action ID and blocked reuse
  after an earlier Agent, Task, or trust-marker write consumed it.
- Preserved exact selected-label, exact-agent, exact-marker, staleness, unreadable
  transcript, and no-`jq` fail-closed behavior.
- Added a distinct `answer_not_found_in_window` reason and plain recovery message
  so transcript-window drift is immediately diagnosable.

### Verification

The guard regression harness now covers the screenshot-shaped five-row gap,
unknown future metadata, wrong and missing IDs, an older answer followed by a
new unanswered question, ordinary missing answers, bounded-window exhaustion,
typed-user staleness, first-action success, dispatch replay, and trust-marker
replay. The root and plugin guard copies remain byte-identical and parse under
Bash 3.2-compatible syntax.

### Lesson formalized as Provisional Guard

Hook code must join transcript events by tool-use ID, never by neighboring row
position or a list of metadata row types. The release gate replays the
interleaved confirmation shape whenever guarded transcript parsing changes.

## INC-2026-07-09 — Startup and closure ceremonies existed in prose but not at every runtime boundary

### What happened

In a plugin advisory session, the user selected "Stop here for now" from an
`AskUserQuestion` choice. Strategic Partner replied with a useful recap but did
not run the closure walk, capture `/insights`, write a handoff file, or show a
continuation prompt. The Stop hook accepted the response, so the session could
end without its durable state.

The same investigation found a startup-side version of the bug. Typed plugin
commands and resident-advisor sessions ran the startup floor, while a
natural-language activation through the Skill tool only armed the session. No
runtime check proved that any path had rendered a project recenter and ended the
orientation with `AskUserQuestion`.

### Why it broke

The plugin had strong written ceremonies but no lifecycle absence detector.
Its Stop rules checked malformed content only after a matching surface appeared;
they did not reject a ceremony that never started. Entry routing also treated
the three supported activation paths differently. Two instruction conflicts
made recovery less reliable: the skill auto-selected continuation whenever
`.handoffs/` contained files, while the startup checklist required an explicit
handoff argument, and the plugin checklist still tried to resolve standalone
command links and run standalone setup.

### Fix implemented

- Direct slash commands use `UserPromptExpansion`; model-invoked Skill activation
  uses `PreToolUse`; resident startup uses official `SessionStart.agent_type`,
  with the older prompt and settings paths retained as compatibility fallbacks.
- Every activation creates startup-pending state and reaches the same cached
  floor. Stop clears that state only after the floor, visible recenter, and final
  orientation question are present.
- Clear session-end intent, including an `AskUserQuestion` answer carrier,
  requires the full closure status, a same-turn handoff write, an insights result
  or explicit fallback, and the plugin continuation fence.
- Either missing ceremony returns one structured Stop block. A corrective turn
  with `stop_hook_active=true` is logged but allowed, preventing hook loops.
- Plugin startup and handoff references now use explicit-path continuation and
  plugin-native install mechanics. The standalone skill remains unchanged.

### Verification

The focused bash 3.2 harness covers typed, natural-language, and resident entry;
complete and incomplete startup; the screenshot-shaped recap-only closeout;
valid closure; explicit override; stale stop intent; malformed input; and the
no-loop path. The existing source guard regression suite and Claude Code's
strict plugin validator also pass.

### 2026-07-13 correction

The closure half of this fix remains valid, but the startup half overreached.
A real cold-start session produced the correct project-first orientation and
then received repeated Stop corrections solely because it did not end with
`AskUserQuestion`. A later read-only orientation was delayed further when a
floor signal triggered optional routing maintenance before the useful answer.

Startup evidence is now a log-only quality signal: the first Stop evaluation
records any missing floor, recenter, or named-handoff evidence, clears the
startup marker, and allows the response to finish. Orientation asks only when
the user owns a concrete decision. Closure remains the durable boundary: clear
session-end intent with missing continuation artifacts may still receive one
corrective block. Loop safety no longer depends on `stop_hook_active` for
startup because startup never blocks.

### Lesson

A written ceremony is not a reliable boundary until every supported entry path
converges on it. Runtime blocking belongs only where absence can lose durable
state or bypass consent; response-shape quality at startup should be observed
and tested without trapping Stop.

## INC-2026-03-30 — Hook command relies on `${CLAUDE_SKILL_DIR}` (v5.4.0 → v5.4.1)

### What happened

v5.4.0 shipped on 2026-03-30 with a new PreToolUse hook (`hooks/guard-impl.sh`) intended to enforce SP's role boundary by blocking source-code edits while allowing writes to a specific set of paths (`.prompts/`, `.handoffs/`, `.scripts/`, `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `SKILL.md`, `.claude/`, `.gitignore`). Three design choices in that release became the failure surface:

- The hook command in `SKILL.md` frontmatter referenced `${CLAUDE_SKILL_DIR}` for path resolution to `guard-impl.sh`.
- `guard-impl.sh` itself carried a `${CLAUDE_SKILL_DIR}` fallback in case the variable was not expanded by the harness at command-string time.
- The hook read the current tool name from a `CLAUDE_TOOL_NAME` environment variable and used a permissive matcher pattern (`""`) that fired on every PreToolUse event.

All three decisions assumed Claude Code populated the named variables and routed every tool call through the matcher. None of those assumptions held.

### Why it broke

`CLAUDE_SKILL_DIR` is not set by Claude Code. It expanded to the empty string, so the hook command failed on any install path that wasn't the default skillshare layout. Users on git clones or alternate directory configurations hit the failure on their next session — the hook errored before it could allow anything through, and exit code 2 from a PreToolUse hook blocks the tool call. Because the matcher fired on every tool, the block was effectively total: Read, Glob, Grep, Skill, and meta operations all paid the cost.

`CLAUDE_TOOL_NAME` had the same character — a phantom variable. Claude Code passes `tool_name` via the stdin JSON payload to the hook, not via the environment. With no tool name, the hook couldn't distinguish guarded from unguarded calls and treated all tool invocations identically.

The permissive matcher compounded both problems: even if path resolution had worked, the hook would still have fired on read-only and meta tools where the guard had no business running. Every session paid the hook cost on every tool call.

### Fix shipped

v5.4.1 shipped on 2026-03-31, one day after v5.4.0, with three changes:

1. **Inlined the guard logic into `SKILL.md` frontmatter.** The hook no longer depends on resolving an external `hooks/guard-impl.sh` path — the full guard is self-contained in the frontmatter and works on any install path (skillshare default, git clone, alternate directory layouts).
2. **Switched tool-name extraction from environment variable to stdin JSON.** The hook now parses `tool_name` from the stdin JSON payload, which is the documented Claude Code mechanism for passing tool context to hooks.
3. **Narrowed the matcher to guarded tools only.** The matcher pattern changed from `""` to `Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__plugin_serena_serena__`, so the hook fires only on the tools the guard actually governs. Read, Glob, Grep, Skill, and other non-guarded tools no longer pay the cost.

### Lesson formalized as Provisional Guard

The lesson is captured in `claudedocs/provisional-guards.md` as: *Don't use `${CLAUDE_*}` env vars in hook commands.* The guard names the affirmative alternative — inline the values, use deterministic path resolution, or grep `CHANGELOG.md` for prior incidents with the variable name before relying on it — and lists `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_TOOL_NAME}`, and any other unverified `CLAUDE_*` variable as in scope.

### Related codification

Several months after the incident, during the v5.9.0 release-review cycle (2026-04-21), two release-runbook items were added to CLAUDE.md's `### 2a. Hook Verification` step to catch this class of bug at verification time rather than after ship:

- **§2a item 4 — runtime-input fuzzing** for hooks parsing JSON or env vars: vary whitespace, quoting, missing optional fields, and non-JSON input through the reference script and confirm graceful handling rather than abort-on-error. The author's own test set represents what the author thought about; fuzzing represents what the runtime will actually send.
- **§2a item 5 — CHANGELOG cross-reference** for `${CLAUDE_*}` env vars and path-resolution patterns: before endorsing any hook command that uses one, grep `CHANGELOG.md` for that variable or pattern. Prior release notes are authoritative on what doesn't work in this harness, and a historical entry is the fastest way to avoid re-introducing the same bug.

These checks are preventive; the lesson came from this incident plus a small number of subsequent near-misses with related variables. Together with the Provisional Guard above, they form the current mitigation surface for this failure mode.

## INC-2026-05-01-A — v5.15.0 fan-out brief missed the 8-group closure floor

### What happened

SP's v5.15.0 Phase 3 fan-out brief at `.prompts/v5150-structural-fix/phase3-fanout.md` — the brief that decomposed the locked v5.15.0 design into atomic executor commits — did not include the 8-group closure floor as a deliverable. The locked design at `.prompts/v5150-structural-fix/design-ab.md` (line 139+) explicitly specified the closure floor as a Phase 3 component. The fan-out brief covered other Phase 3 work (handoff doc backlog mention, identity-reset rule, startup-checklist refactor) but treated the closure floor as already-covered when it was not.

Six executor commits landed (`27680d6`, `88e3a60`, `f7deb35`, `1fb570a`, `4a9c979`, `06afe09`) before the user caught the gap mid-session: "I remember we had two floors, not only one. Is this just the start-up floor and the closure one? Are we going to do it, or do we have a resolution that we're not going to do it?"

### Why it broke

The brief author (SP, in advisory mode) worked from the `decision_log` Phase 3 task summary list — a rolled-up view that listed smaller items individually but did not repeat the closure floor as a discrete sub-task. The summary was chronologically downstream of the locked design and had drifted in coverage.

The structural shape of the failure: when a brief derives from a multi-source design lock (a `.prompts/[milestone]/design-*.md` file iterated across multiple Codex review rounds, plus a `decision_log` summary that aggregates the design's tasks, plus the brief author's working memory of the design conversation), each downstream representation is lossy. The summary captured the smaller items because they were named individually in conversation; the closure floor was treated as a single canonical item in the locked design and got compressed into "the closure work" — present in name, absent in fan-out detail.

This is a class of failure where the convenience of a derived summary (faster to scan than re-reading 700 lines of locked design) trades against the completeness of the source-of-truth.

### Fix shipped

SP drafted a second brief at `.prompts/v5150-structural-fix/phase3-closure-floor.md` (~700 lines, 7 components) covering the missed work: 8-group closure floor body, backlog hygiene as first-class, handoff write protocol refinements, Post-Handoff Verification, optional SessionEnd hook, new `references/closure-floor.md` reference doc, and visual prescription via the Closure Walk Status table.

The closure-floor brief went through two Codex Mode A review rounds: round 1 returned CONDITIONAL GO with six substantive conditions (full skill rediscovery in Group 3, Serena verify-activate-fallback chain instead of permissive skip, grouped backlog summary + single AUQ pattern, runtime backstop scope correction, visual consistency prescription, durable SessionEnd test marker). SP applied 10 atomic edits resolving all six. Round 2 returned CONDITIONAL GO with three surgical fixes (MCP-error retry chain, stale `/tmp` reference cleanup, durable artifact for the v5.16 Stop rule 6 deferral). SP applied all three.

The brief shipped to a background Opus 4.7 executor on 2026-05-01 and produced six atomic commits landing the closure-floor work.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Brief authors must re-read locked design files at brief-author time, not derived summaries.* Scope: SP-authored executor briefs that aggregate multiple components from a multi-iteration locked design (small mechanical briefs are out of scope). Review: 2026-07-30.

## INC-2026-05-01-B — v5.15.0 closure-floor brief deferred Stop rule 6 with no surface artifact

### What happened

The v5.15.0 closure-floor brief (`.prompts/v5150-structural-fix/phase3-closure-floor.md`) deferred the closure-walk-completeness Stop rule (Stop rule 6) to v5.16.0. The deferral was documented in two places: Principle 5's rewrite within the brief, and Component 7's commit message. Both locations are findable, but only by reading the original source artifacts after the fact.

Codex Mode A re-review (round 2) flagged the absence of a durable surface for the deferral: "the v5.16 deferral lives only in the brief's commit message — findable if you know to look, but not surfaced automatically when v5.16 work begins."

When the v5.16.0 milestone opened, SP's normal scans (`/strategic-partner:backlog`, startup orientation, closure-floor Group 7a backlog hygiene) would not see the deferred Stop rule 6 — it would surface only if someone happened to grep commit history or re-read the closed brief.

### Why it broke

Commit messages and brief context are write-once retrieval-poor surfaces. They are findable via `git log -S` or grep across `.prompts/`, but neither path is part of SP's normal session-start orientation flow. The structural pattern: deferral within an executed brief assumes the next milestone's planner will re-read the prior brief. That assumption is false in practice — milestones open from the new brief, not from re-reading completed ones.

The bug class: any explicit deferral within a release that lacks a durable artifact in a routinely-scanned location (`.backlog/`, a reference doc, project memory) becomes invisible to SP within one milestone cycle.

### Fix shipped

SP created `.backlog/closure-walk-completeness-stop-rule.md` capturing the v5.16 Stop rule 6 deferral as a durable artifact. The file documents the full design approach (sample real transcripts → identify format variations → design detection patterns → empirical validation → implementation), references back to v5.15.0 brief Principle 5, Component 7's commit message, and the Codex re-review output, and carries an explicit `trigger:` field so `/strategic-partner:backlog` lists it during normal scans.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Deferred work needs durable artifacts (backlog item or reference doc), not just commit messages.* Scope: any explicit deferral within a release. Acceptable durable artifacts: a `.backlog/[item].md` file with explicit `trigger:` field, or a dedicated section in a reference doc. Review: 2026-07-30.

## INC-2026-05-01-C — Closure-floor brief Component 1 prose vs verification grep mismatch

### What happened

The v5.15.0 closure-floor brief's Component 1 description carried two conflicting specifications for the same structural element. The prose said "the 8-group walk is Steps 1-8" — implying group headings should carry the format `### Step N — Group description`. The verification grep `^### Group [1-8] —` required the opposite: headings must NOT include any "Step" prefix.

Two specifications in the same brief disagreed on the format of the same headings.

### Why it broke

The prose and the verification command were written in different drafting passes. The prose described the conceptual structure ("Steps 1-8" reads naturally as a description of an ordered walk), while the verification command was tightened later to anchor against the actual heading format the executor would produce. Neither pass updated the other.

The bug class: any brief that contains BOTH prose describing a structural element AND verification grep/regex patterns checking for the same element risks divergence if the two are not authored or proofread in lockstep.

### Fix shipped

The closure-floor executor agent went with the verification grep's anchor (`### Group N —`) since the verification check was the load-bearing specification at execution time. Semantic intent ("Step 1, Step 2, ...") was preserved by Component 3 and Component 4 carrying the "Step" prefix in body content (Steps 9-13 covered handoff write protocol; Step 14 covered Post-Handoff Verification), while the eight closure groups themselves used the `Group N —` format.

No retroactive fix to the brief was needed because the executor's call resolved cleanly. The lesson is forward-looking: future briefs must keep prose specs and verification commands in lockstep.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Brief verification commands and prose specs in the same brief must agree.* Scope: executor briefs with verification commands that reference structures described in prose deliverables. Review: 2026-07-30.

## INC-2026-05-01-D — Closure-floor Component 5 used binary outcome framing

### What happened

The v5.15.0 closure-floor brief's Component 5 (optional SessionEnd hook) specified a verification protocol that required user-keyboard work the executor agent could not drive: open a separate terminal, invoke the skill in a fresh Claude Code session, `/exit` normally, repeat.

The brief's outcome framing was binary: "any gate fails → don't ship the deliverable." It did not enumerate "test couldn't run within executor scope" as a third possible state.

When the executor ran the brief, it could not drive the multi-process orchestration. It made a defensible call — treating the situation as "documented gap with explicit scope-limit framing" — but the brief's binary framing left the call ambiguous between "test failed" and "test couldn't run."

### Why it broke

Briefs with verification steps that depend on multi-process orchestration sit in an awkward space: the executor can verify single-process behavior, but cannot drive separate terminals, fresh CC sessions, or manual lifecycle events. The brief author either (a) writes verification the agent CAN drive, (b) explicitly enumerates the user-keyboard outcome path, or (c) accepts ambiguity at execution time.

The bug class: any brief whose verification depends on user-keyboard work without explicitly enumerating the "couldn't run" outcome forces the executor to invent a third state — which produces inconsistent calls across briefs.

### Fix shipped

No retroactive fix to the brief was needed; the executor's documented gap with scope-limit framing was a defensible call. The lesson is forward-looking: future briefs with user-keyboard verification must enumerate three outcomes, not two.

The three-outcomes pattern came from the dispatch-vs-instruct split formalized in 2026-04-30 findings (issue 9): when verification requires user-keyboard work, the brief author must explicitly account for the agent's structural inability to drive certain test paths.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Briefs with user-keyboard verification must enumerate three outcomes.* Scope: executor briefs whose verification depends on multi-process orchestration the agent cannot drive. The three outcomes: (a) all gates pass → ship; (b) any gate fails → defer with documented failure mode; (c) test couldn't run within executor scope → defer with explicit scope-limit documentation. Review: 2026-07-30.

## INC-2026-05-03-A — Cross-file template token mismatch (`[STATUS_EMOJI]` vs `[STATE_EMOJI]`)

### What happened

The v5.15.0 closure-floor brief's Component 6 produced three files that share a templated token vocabulary: `assets/templates/handoff-template.md` (the template the renderer fills), `commands/handoff.md` (the renderer command itself, with an inline render section), and `references/closure-floor.md` (the canonical specification).

The handoff template used the token `[STATUS_EMOJI]`. The initial draft of `commands/handoff.md`'s inline render section used `[STATE_EMOJI]`. Same renderer slot, one-word difference. If the divergence had shipped, the renderer would not have filled the slot in one of the files (the renderer searches for `[STATUS_EMOJI]`; a template carrying `[STATE_EMOJI]` would leave a literal `[STATE_EMOJI]` placeholder visible to users).

The mismatch was caught at commit prep via a manual visual scan, not by any automated check.

### Why it broke

Authoring three template-related files in sequence requires holding the token vocabulary in working memory across all three drafts. One-word divergences (`STATUS` vs `STATE` — both legitimate English words for the same concept) are easy to introduce mid-draft and hard to spot on re-read because both readings parse as sensible English.

The bug class: any multi-file authoring session where 2+ files share templated tokens risks one-word divergences that pass spell-check, parse as sensible English, and are detectable only by literal-text comparison.

### Fix shipped

The mismatch was caught and fixed pre-commit during the closure-floor work. Both files now use `[STATUS_EMOJI]` consistently. No automated detection was added at the time — the visual scan was the only check.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Cross-file template token names must agree across all files in the same authored set.* Scope: multi-file authoring sessions where 2+ files share a templated token vocabulary (typically a template + renderer command + reference specification). Review: 2026-08-01.

## INC-2026-05-03-B — Routing matrix mtime+1h staleness check + permanent rebuild loop

### What happened

User flagged at start of the 2026-05-03 session: "SP REBUILDS the ROUTING SKILLS Map EVERY TIME! that's a waste of time and tokens."

Concrete evidence: floor sentinel reported `routing=stale`, SP dispatched an Opus 4.7 background rebuild agent per the Floor-Signal Handling protocol. The agent ran 4 minutes / 85K tokens / 11 tool uses to inventory 198 skills + 28 agents + 16 MCP servers and persist the result to Serena `skill_routing_matrix`. The prior session's handoff showed the same rebuild had fired the day before, producing near-identical inventory.

Mid-session investigation revealed the floor sentinel checked `.serena/memories/skill_routing_matrix.md` mtime against a 1-hour threshold (`g7.routing` = `fresh` if mtime within last hour, else `stale`). Any session opened more than an hour after the last build triggered a full rebuild — even when the inventory had not changed.

A second confirmation came from the BAM-MVP project: that project had no Serena `skill_routing_matrix` memory at all, so the floor marked `routing=missing` every session, dispatched a rebuild every session, and SP wrote the rebuild output to `.claude/skill-routing-matrix.md` instead. Two competing routing-matrix files (`skill-routing-matrix.md` and `sp-routing-matrix.md` with different schemas) had accumulated, the floor never checked `.claude/`, and the rebuild loop was permanent.

### Why it broke

Three layered issues:

1. **Wrong axis for staleness.** Time-since-last-rebuild is not what determines whether a routing matrix is fresh — what determines freshness is whether the skill / agent / MCP inventory itself has changed. Mtime + 1-hour threshold guarantees rebuild on any session opened more than an hour after the last one.

2. **Persistence fork in non-Serena projects.** When Serena memory was unavailable, SP wrote to `.claude/` files. The floor checked Serena only. The two locations were never aligned.

3. **Floor-vs-write disconnect.** Even when the floor and SP were both supposed to coordinate via the matrix, they read and wrote different paths. In projects where Serena memory was missing, the rebuild loop became permanent because every session reproduced the same `routing=missing` signal.

A fourth issue surfaced during fix work: the first v5.16.0 implementation (drafted by an executor agent) attempted to compute the inventory hash from `$payload` — the UserPromptSubmit JSON. Codex Step 2b adversarial review caught that `$payload` contains only the prompt envelope (cwd / session_id / model / transcript_path / prompt) — NOT the system-reminder skill list visible to agents. The hash was effectively over empty input and would never match Agent D's full-inventory hash.

### Fix shipped

v5.16.0 (commit `de4ed7a`, 2026-05-03) shipped the corrected design after five Codex Step 2b rounds:

- The floor sentinel now compares an `inventory_hash` field in the matrix footer against a recomputed hash. Both the floor and Agent D compute the hash from the same filesystem source: sorted basenames of `~/.claude/agents/*.md` plus `agent_count`, sha256-hashed and truncated to 16 hex chars.
- Skill directories and MCP server names are NOT in the hash because the floor's UserPromptSubmit hook receives only the prompt envelope — not the system-reminder skill list — and skill / MCP install paths vary across harnesses. The hash inputs must be filesystem-discoverable from one source both sides can read identically.
- Trade-off: pure skill or MCP installs without an accompanying agent change are not auto-detected by the floor; explicit refresh paths (`/strategic-partner:update`) handle those cases.
- The persistence fork is closed: the matrix builder writes to one source of truth per project (Serena memory `skill_routing_matrix` when active, else `.claude/skill-routing-matrix.md`). The legacy `.claude/sp-routing-matrix.md` companion is deprecated.
- Live verification: hash reproduces as `d6bf21db8f2df3e5`; voice lint clean; synthetic hook tests 6/6 pass; cross-file consistency holds.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Routing matrix freshness is content-based (inventory hash), not time-based.* Scope: SKILL.md frontmatter UserPromptSubmit hook Group 7; `references/floor.md` § Group 7; Agent D protocol in `references/startup-checklist.md` and `references/skill-routing-matrix.md`. Review: 2026-08-01.

## INC-2026-05-06 — SP endorsed SP-flavored framing in user CLAUDE.md as a strength

### What happened

During a /strategic-partner advisory session on 2026-05-06, SP was asked to rate the BAM-MVP project's `CLAUDE.md` (at `/Users/OldJimmy/Developer/Claude-CoWork/Padel-Related/BAM-MVP/CLAUDE.md`). The file opens with an H1 heading `# Strategic Partner Mode — ALWAYS ACTIVE`, followed by an `## Operating Rules` block with eight numbered items duplicating SP's own behavioral defaults — "AskUserQuestion is your primary tool", "Push back and be blunt", "Diagrams first", "Decision archaeology", "Scope radar", and similar — and a `## Response Pattern` flowchart prescribing SP-style turn discipline.

SP rated this section "SP-mode framing strength: 9/10" and called the framing "load-bearing" and "excellent." A yellow-flag hedge was added — "Possible duplication with global SP rules — worth deciding" — but the framing was treated as a feature worth preserving rather than as a policy violation.

The user reminded SP: there is an explicit prior agreement that SP-related instructions never get pushed into user project files. SP is a skill; its behavioral defaults apply automatically when SP is invoked. Duplicating those defaults in a user project's `CLAUDE.md` is the violation pattern, not a strength.

### Why it broke

Three stacked failures, none caught by SP's own surfaces:

1. **No mechanical detection.** The v6.0 scanner ran 16 rules (S1-S8 + B1-B8) against the BAM file and produced 12 findings. None flagged the SP-as-pillar heading, the operating-rules block, or the response-pattern flowchart. The scanner's voice-discipline rule applied to scanner OUTPUT only — "never push SP-flavored conventions onto a project" — but no rule scanned the input file for the same pattern. The policy existed in advisory text; it did not exist in scanner code.

2. **No codified policy in SP's own rules.** SP's `CLAUDE.md` had voice and process guards (Provisional Guards covering hook env vars, brief authoring, deferred-work artifacts, template tokens, routing-matrix freshness) but no guard covering "user project files don't get SP-flavored framing." When SP encountered the BAM file's framing, there was nothing in the loaded context anchoring "this is a violation" — only the implicit advisory-text rule that SP did not retrieve.

3. **Sycophantic anchoring on what was there.** SP found the framing well-organized, internally coherent, and aligned with SP-style behavior — and rated it accordingly. The yellow-flag hedge framed the duplication as "worth deciding" rather than as "this should not be here." The session evaluated what was, not whether it should be.

### Resolution

v6.1.0 (this release) ships three coordinated changes:

- **Scanner rule S9 — SP-flavored framing.** Detects three signal classes in any context file the scanner runs against: a heading containing "Strategic Partner" co-occurring with a pillar-framing marker (Mode / ALWAYS ACTIVE), top-of-file "ALWAYS ACTIVE" + override-framing within the first 50 lines, and ≥3 distinct SP-pattern phrases (the operating-rules duplication signal). Any signal fires the rule once per file at warn severity, with a remove-or-scope suggestion in the standard scanner template.
- **Provisional Guard in SP's `CLAUDE.md`.** Codifies the policy explicitly: when SP evaluates / rates / drafts / audits a user's context file, SP-flavored framing is a violation, not a strength. Run the scanner; flag and recommend removal or scoping to a project-named overlay.
- **This INCIDENTS.md entry.** Catalogs the failure mode, root causes, and resolution path so the archaeology is searchable from the project's incident archive in future sessions.

Additionally, a local auto-memory entry `feedback_no_sp_framing_in_user_files` was written in the SP project's machine-local memory store. This anchors human-eye discipline for the SP author across future sessions but is **NOT part of the public release** — it lives at `~/.claude/projects/<encoded-project-dir>/memory/` and ships only with the SP author's local Claude Code installation.

### Prevention

The detection lives in three layers, in order of strength:

1. **Mechanical (scanner rule S9)** — runs as part of `/strategic-partner:context-file-scan` against any user project file. Cannot be skipped by sycophantic drift; produces a structured finding with a copy-paste suggestion.
2. **Codified (Provisional Guard)** — present in `claudedocs/provisional-guards.md`, with a short pointer stub in `CLAUDE.md` § Provisional Guards.
3. **Anchored (local feedback memory, SP author's machine only)** — surfaced through SP's memory recall at session start, alongside other voice and process feedback. Local to the author's Claude Code installation; not part of the public release.

The mechanical layer is the load-bearing one. Layers 2 and 3 anchor SP's reasoning when the scanner has not been run; layer 1 catches the pattern deterministically when it has.

### Context

A separate forensic report at `/Users/OldJimmy/Developer/Claude-CoWork/Padel-Related/BAM-MVP/.handoffs/sp-claudemd-policy-feedback-0506.md` (241 lines, authored 2026-05-06 13:12 by a prior session) catalogs 13 SP feature gaps where SP-anchored human-eye discipline failed in advisory work and recommends converting each to deterministic enforcement. This v6.1.0 release adds a 14th detection — gap #14 — that fits the same pattern: convert SP-anchored human-eye discipline (which failed in this session) to scanner-anchored mechanical detection (S9). Future archaeology connecting this incident to the broader inventory can start from that report.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *User project files don't get SP-flavored framing.* Scope: SP advisory turns evaluating, rating, drafting, or auditing a user's `CLAUDE.md` / `AGENTS.md` / `GEMINI.md`, plus the scanner rule S9 in `.scripts/context-file-scan/rules/structural.sh`. Review: 2026-08-06.

## INC-2026-07-13-B — Empty memory reported healthy and routing maintenance gated read-only startup

### What happened

A fresh disposable validation session proved Serena was connected to the exact
repository with the `claude-code` context and quiet dashboard startup. The first
useful Strategic Partner orientation still took almost four minutes.

The floor receipt contained the detailed truth:

- `g3.serena_memories=present count=0`
- `g3.project_overview=missing`
- `g3.decision_log=missing`
- `g7.routing=missing`

Its compact line nevertheless reported `memory=ok`. Claude then read live Serena,
correctly learned that onboarding had never run, and treated the missing routing
matrix as a mandatory startup prerequisite. It invoked a `general-purpose` Agent
before asking the dispatch question. The brief called the work read-only while also
instructing the worker to write Serena memory or a fallback project file. The
existing dispatch guard correctly blocked the call. Claude performed unrelated
hygiene checks and only then asked the exact confirmation question.

### Why it broke

Four contracts disagreed:

1. The floor summary checked only whether the `g3.serena_memories=present` prefix
   existed. Directory existence therefore became health even when the count was
   zero and both required memories were missing.
2. Startup instructions treated `routing=missing` as automatic dispatch authority,
   while the guard correctly requires direct, exact confirmation before every Agent.
3. The routing worker was described as read-only but had write-capable instructions.
4. Routing construction was simultaneously described as mandatory Agent D work and
   as work that should never be delegated, causing hesitation and mode drift.

The guard was not defective. It prevented an unauthorized project write.

### Fix shipped

- Both floor scripts now report `memory=ok` only when the memory count is greater
  than zero and `project_overview` plus `decision_log` are present.
- Startup gaps are log-only and clear their pending marker on the first Stop pass.
  Closure remains the only lifecycle ceremony allowed to block once.
- Routing maintenance is demand-driven. Orientation uses visible capabilities or
  `bare: true` and never waits for a matrix rebuild.
- Read-only intent forbids routing writes, onboarding, fallback files, and Agent
  dispatch. A later material routing need uses one documented background
  `general-purpose` / Opus / `acceptEdits` contract after exact confirmation.
- Regression coverage exercises empty, partial, and healthy memory states, repeated
  Stop evaluation, mirrored routing instructions, and unchanged dispatch guards.

### Lesson formalized as Provisional Guard

Captured in `claudedocs/provisional-guards.md` as: *Floor signals describe state;
they never grant write or dispatch authority.* Review: 2026-10-13.
