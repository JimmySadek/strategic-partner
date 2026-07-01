# Changelog

## [7.3.2] - 2026-07-02

### Fixed
- **The project-rules content scanner no longer mistakes ordinary writing for a session log** — a check meant to catch dumped session notes in your project's rules file was matching on word fragments inside completely normal sentences, and a single old false alarm would block every future edit to that file, forever, no matter how small.
- **A safety check for terminal commands could be silently bypassed, and separately, over-blocked harmless commands** — a command containing quoted text could sneak past the check meant to stop accidental file changes; separately, some completely harmless commands were being blocked for no reason. Both are fixed, including for the rare case where a required helper tool isn't installed.

### Added
- **You can now see whether the "different reviewer than builder" policy is active for your project** — a status line appears every session, instead of only surfacing deep inside an actual build.

### Changed
- **The Codex review command now describes itself more precisely** — it's the reviewer-side check only; turning the policy itself on or off is a separate, one-line project-rule setting.

## [7.3.1] - 2026-06-22

### Fixed
- **Cross-model review is recognized even when it isn't spelled out exactly** — the
  cross-model build/review policy (added in 7.3.0) only switched on when a project's rules
  contained the exact line `review-policy: cross-model-go-no-go`. But many projects already
  ask for a different-model review in plainer words — "run a Codex review before pushing" —
  or keep that rule in a separate document their main rules file points to. The advisor now
  recognizes both: a review requirement named by tool (a Codex review of Claude-built work,
  or the reverse) counts, and a rules file that points to a companion rules or release
  document is followed before the advisor concludes there's no policy. The exact marker
  still works and is still the clearest way to set it — you just no longer have to know the
  magic string. Detection stays project-scoped: a global rule won't switch the policy on for
  every project unless the project opts in.

## [7.3.0] - 2026-06-22

### Added
- **Cross-model build/review as a project policy** — A project can now ask that whoever
  reviews a change be a different AI model than whoever built it (for example, Claude
  builds and Codex reviews — or the reverse). Turn it on by adding `review-policy:
  cross-model-go-no-go` to the project's rules file. The advisor notices it quietly at
  startup, asks which build/review direction to use only when implementation actually
  starts (and only offers directions whose models are installed), and records the
  GO / NO-GO verdict as advisory status — it states and logs the result, but never
  claims to block a push, release, or handoff.

## [7.2.0] - 2026-06-20

### Added
- **Your always-loaded rules files are now protected from bloat** (context-file
  stewardship) — The files Claude reads at the start of every session — `CLAUDE.md`,
  its `AGENTS.md` / `GEMINI.md` equivalents, and path-scoped `.claude/rules/*.md`
  files — tend to rot over time as session
  notes, commit logs, and folder-specific rules get pasted in, until the real rules
  are buried and every session wastes context loading the clutter. The advisor now
  guards these files: when one is edited, the change is checked first.
  Content that belongs elsewhere — a session diary, a rule that only applies to
  certain folders, a "what we shipped" log — is stopped with a plain-English reason
  and a better place to put it, while genuine project-wide rules pass straight
  through. The guard covers edits made through Claude's normal tools, plus common
  shell writes on a best-effort basis, and it fails safe — if it can't confirm an
  edit is clean, it
  refuses rather than risk letting bloat through. The drift scanner behind it also
  gained a check for session-diary dumps and now measures size by line count, not
  just characters (matching the under-200-lines guidance).

## [7.1.1] - 2026-06-17

### Fixed
- **The session wrap-up shows its work again** — at the end of a session the advisor
  walks an 8-group closure checklist (git tree clean, findings saved, backlog captured,
  and so on). It was still running and still saved into the handoff file, but had quietly
  stopped appearing in the chat — so the close looked thin even when nothing was skipped.
  The checklist now renders in chat before the handoff is written, restoring the visible
  summary of everything that was checked. The render is now an explicit, ordered step in
  the advisor's main in-session closure flow — previously it lived only in supporting files
  (a reference doc and the handoff command), not in that main flow — so it can't quietly
  fall off again.

## [7.1.0] - 2026-06-16

### Fixed
- **The advisor offers to run small tasks for you again.** On small, reversible,
  single-concern changes, the Strategic Partner now reliably asks whether to run the
  work in the same session or hand you a prompt — instead of silently defaulting to
  the prompt. A new internal checkpoint makes that offer a required step, and it now
  names the specific specialist agent so you can catch a wrong pick before confirming.
  Big, risky, or hard-to-reverse changes still go out as a full prompt, exactly as before.

## [7.0.1] - 2026-06-14

### Fixed
- **A handed-over prompt can no longer quietly launch the advisor instead of a builder** — When the advisor
  packaged work to run in a fresh session, it could occasionally put its *own* command (`/strategic-partner`)
  at the top of the copy-paste block. Pasting that started another advisor — which is blocked from writing
  code — so nothing actually got built. The advisor's rule for this is sharpened so it doesn't happen, and a
  new turn-end check flags it on the spot if it ever slips through. A normal "pick up where we left off"
  handoff still works exactly as before.

### Changed
- **Copying a prompt to your clipboard is faster** — `/strategic-partner:copy-prompt` used to take several
  steps for the common case of a single saved prompt; it's now one step. Same reliability, less waiting.

## [7.0.0] - 2026-06-14

### Added
- **SP now catches its own swallowed replies** (render-before-ask backstop) —
  Some current models can silently drop a report they were about to show —
  writing it into hidden reasoning instead of the chat — and then ask a
  question that refers to content that never appeared (a known
  Anthropic-side model bug). SP's turn-end check now detects that exact
  shape and makes SP re-print the missing content at the start of its next
  reply. Sessions on unaffected models see no change at all.
- **SP recognizes the Fable 5 model** — startup status and prompt-crafting
  defaults now detect Fable 5 sessions instead of reporting the model as
  unknown. Knowing the model also lets the existing long-window context
  advisory fire on 1M-context sessions that previously read as unknown.
- **SP now checks its own advisory posture, not just its wording** (own-conclusion check) —
  SP already had rules against flattery and for taking a clear position; those govern what SP
  says. This adds the upstream check: before a real recommendation, SP asks itself whether it
  is genuinely serving your question or just defending the answer it already landed on — and
  if it is the latter, it lowers its confidence, names the evidence that is missing, or argues
  the other side. The tell it watches for is piling on more analysis that only better-defends
  the same conclusion.

### Changed
- **SP's internal decision-making is now one plain-English gate** (the Decision
  Ownership Gate) — Previously every decision flowed through a four-stage
  internal pipeline with its own private vocabulary, a translation layer to
  keep that vocabulary out of chat, and six reference files documenting the
  stages. A full-transcript audit showed the stage files were never consulted
  at decision time. The four stages are now four plain questions inside the
  skill itself (are the facts known? who owns this decision? is it worth
  asking? how deep should the ask be?), the six reference files are deleted
  (~1,500 lines), and the translation layer is gone because there is nothing
  left to translate. Nothing changes in what users see: the asking behavior,
  the always-ask whitelist, and silent handling of decisions a canonical
  document already answers are all preserved. The same cleanup trimmed dead
  internal vocabulary from the source-editing rules file.
- **Four advisory checkpoints became one readiness gate** (the Advisory
  Readiness Gate) — The path from "user asks" to "SP packages execution" used
  to pass four separately documented structures: task discovery questions, a
  premise challenge with six triggers, a forced three-option menu, and a final
  completion gate. A full-transcript audit showed all four protect the same
  transition and none catches anything the others would miss. They are now one
  gate with three checkpoints — frame the task, surface real alternatives,
  confirm readiness — plus a new captured-thinking lens that detects HOW a
  request is stuck (defending a settled conclusion, rushing for relief,
  settling for any answer) and matches the response to the cause instead of
  the symptom. Dead ceremony is gone: two triggers that never fired once,
  scripted lines no session ever used, and an every-request evaluation mandate
  that left no trace across 53 sessions. Every check that demonstrably fired
  survives: the mandatory goal and done-state questions in fresh sessions, the
  A/B/C alternatives menu, the five readiness criteria, and the rule that
  findings carried from prior sessions are verified before SP acts on them
  (which moves into the Decision Ownership Gate — the who-owns-this-decision
  check — where unverified facts belong).
- **The advisor's decision toolkit is simpler to scan** (cognitive operations) — SP
  used to carry fourteen separately named thinking patterns, each wired as its own gate.
  A full-transcript audit found the names almost never drive the actual reasoning — they
  label it after the fact, appearing in none of 2,150 internal reasoning blocks. The
  fourteen are now organized as six paired thinking-moves (zoom in vs zoom out, hold vs
  commit, and four more) plus three standalone checks that genuinely gate a decision. The
  old pattern names live on as worked examples, so nothing is lost — the toolkit is just
  easier to scan and reason about.
- **One home for the advisory rules** (reference cleanup) — The prompt-crafting
  reference file used to repeat advisory guidance that also lives in the main skill
  (the premise challenge and the alternatives menu). Those
  duplicates are removed; the guide now covers only how to package a prompt and points
  back to the skill for the advisory rules. Less chance of the two drifting out of
  sync; nothing changes in how prompts are crafted.

## [6.14.0] - 2026-06-10

### Added
- **The advisor can now suggest a hands-off run** (goal-mode option) — after handing
  you a prompt, when the task genuinely fits Claude Code's `/goal` autonomous-run
  command (multi-step work whose finish line can be proven from the session
  transcript), the advisor adds a short chat-only suggestion with a tailored finish
  line and a safety cap. The runnable `/goal` line lives only in chat — never inside
  a saved or copyable prompt, so it can't fire by accident on paste or resume — and
  a new release-time check (the goal-tripwire lint) enforces that rule mechanically.
- **One voice rulebook** — the advisor's plain-English voice rules now live
  canonically in the main skill file, and the installable voice style is an
  explicitly-derived mirror of them. Rules that previously existed only in the style
  file were folded back in — the ban on status rows that claim ✅ while admitting the
  check didn't happen, the rule to judge your work by its effect on your goals rather
  than its resemblance to familiar patterns, guidance on when to reach for each
  formatting tool (blockquotes, backticks, numbered vs bulleted lists), and the rule
  that a reply ending at a decision point must end by asking you — so the partnership
  voice survives even if Claude Code retires output styles. A new release-time check
  (the voice-mirror lint) blocks any release where the two copies drift apart.

### Changed
- **Work you run yourself now gets a real code review on return** — when you come
  back from running a prompt in a separate session, the advisor reads the actual
  changes against the commit recorded when it handed you the prompt — not just the
  commit list and your summary — matching the rigor it already applied to
  background-agent work.

## [6.13.0] - 2026-05-31

### Added
- **Every prompt now previews what you'll get** — when the advisor hands you a
  copy-paste prompt, it adds a short plain-English "📦 What you'll get" summary
  right after it: what the work will change for you, in everyday terms rather than
  file names. The same list doubles as your checklist when the result comes back.

### Fixed
- **The safety guard can no longer be slipped past on an unreadable edit** — the
  guard that stops the advisor editing your source files now *blocks* an edit when
  it can't tell where the edit is headed (it used to let it through), and reads tool
  details more forgivingly so an oddly-formatted request can neither sneak past nor
  wrongly block an allowed write. Your memory, shell, and read-only commands are
  unaffected.
- **The first prompt in a brand-new project no longer crashes** — the step that
  clears old saved prompts now uses a command that doesn't choke on an empty or
  missing folder and doesn't trip a `rm`-blocking shell alias.
- **The advisor's startup auto-activates Serena when it can** — when Serena (the
  cross-session memory server) reports no active project at startup, the advisor now
  activates the matching project automatically — if your folder matches one it
  already knows — instead of stopping to recover by hand.

## [6.12.0] - 2026-05-31

### Changed
- **Tuned for Claude's latest model, Opus 4.8** — model labels, the model picked
  for background tasks, and effort guidance now reflect Opus 4.8 instead of 4.7;
  it recognizes when it's on 4.8 and knows 4.8's default effort is "high," so for
  deeper work it sets "xhigh" explicitly. A few "4.7" behavior notes were reworded
  as stable Opus-family traits.
- **Sub-agent correction is more robust** — if a follow-up message to a running
  helper agent can't be delivered (e.g. after a session resume), the advisor falls
  back to a fresh brief instead of stalling; and it notes that team agents share
  one workspace, so their file assignments must not overlap.
- **Voice rules name the jargon that tends to leak** — the advisor's voice guidance
  now calls out the specific internal terms that slip into release-cycle chat, with
  a pre-send check to catch them.

### Added
- **The advisor now knows about workflows** — Claude Code's new way to run many
  sub-agents in parallel in the background for big jobs (codebase-wide audits,
  large migrations, cross-checked research). A clear rule for when to reach for a
  workflow vs. a single agent vs. a fresh session, the /deep-research and /batch
  commands surfaced where they fit, and the caveat that a workflow's sub-agents
  auto-approve their own edits.

### Fixed
- **Review briefs now ask for everything, not just the serious stuff** — Opus 4.8
  follows "only flag high-severity" so faithfully it finds real problems and stays
  quiet about them; the advisor now writes review briefs to report every finding
  with a severity tag and filter afterward.
- **Verified, current notes on Claude Code's internals** — confirmed against live
  docs: the session-start check stays within Claude Code's 30-second hook limit,
  question-prompts are for choosing a direction (not plan approval), and the list
  of still-open large-context issues is refreshed. Crafted prompts now describe the
  capability an executor needs rather than assuming a tool is preloaded.

## [6.11.0] - 2026-05-22

### Added

- **Fresh installs now complete themselves in-session, no separate terminal step required** — When you invoke `/sp` on a fresh install where the one-time `./setup` step has not yet run, the advisor notices the missing setup, shows a row in the session-opening status saying so, and offers to finish setup for you with a single yes/no prompt. On yes, it runs `./setup` on your behalf and then tells you to restart Claude Code so the new commands and the voice style (the formatting profile that makes replies scannable) activate. The previous behaviour — install via `npx skills add` or `git clone`, miss the manual `./setup` step, then wonder why `/strategic-partner:*` commands do not autocomplete and the voice style does not show up under `/config` — is gone. Existing installs experience zero new noise: the offer only appears when the commands are genuinely missing.

### Fixed

- **The session-startup check now fires on fresh installs, where it was silently doing nothing** — The check used to find where the advisor lives by walking one of the registered subcommand shortcuts. On a fresh install those shortcuts do not exist yet (they are what `./setup` creates), so the check could not find itself, produced no startup state, and the advisor had no signal to react to. The check now resolves its own location directly from where its own script lives on disk, with the older shortcut-walk preserved as a fallback for installs in non-standard locations. Without this fix, the new fresh-install completion flow above had no startup signal to trigger on.

### Changed

- **The session-startup status line now carries a twelfth field, recording whether the install is fully set up** — The always-on check that reports your project's state at session entry (branch, memory, version, output style, and so on) now distinguishes "the subcommands are registered" (the state `./setup` leaves behind) from "the subcommands are not registered yet" (a fresh install). The check's internal cache stamp bumped accordingly — your next session after this update re-runs the check once to pick up the new field, then resumes normal cached behaviour. Nothing else about the check changed.

## [6.10.0] - 2026-05-19

### Added

- **The advisor's voice is now noticeably clearer, and harder to drift** — A revision of the voice profile that governs every reply. Highlights: a version stamp on the voice file so a stale installed copy can be detected; a whole-response plain-English check (every visible block must read clean to a smart non-technical reader, not just the opening); one consolidated pre-send checklist instead of three overlapping lists saying the same thing different ways; guidance on when a section heading or an emoji actually earns its place versus when it is decoration; a rule that when the advisor rates something you wrote, it judges the effect on your project, not how closely it resembles a pattern it recognizes; a plan-mode rule that the plan-approval step is the decision gate (no redundant extra confirmation stacked on top); a self-contained list of the always-ask decision points so a reader does not have to cross-reference another file to know what it covers; trimmed response templates; and an honest "what is actually enforced versus what is discipline only" section so the advisor does not imply a safety net that does not exist.
- **The advisor can now tell you when its installed voice file is out of date** — The voice profile that shapes every reply is a separate file you install once; it does not auto-update when the advisor updates. The session-startup check now records both the shipped version and your installed version of that file and reports whether your copy is current, out of date, or missing. When it is out of date or missing, session orientation shows a one-line row telling you so, and `setup` warns you (without overwriting your copy) instead of silently leaving you on an old version.
- **The advisor no longer invents a non-existent command when telling you how to turn its voice on** — When the recommended voice is not active, orientation shows how to enable it. The exact steps now live in the always-loaded layer, so the advisor states them verbatim instead of improvising and occasionally inventing a command that does not exist.
- **The advisor now catches backlog work that already shipped** — When you run the backlog command, it scans recent commit messages, changed files, diffs, and release notes for work that matches an open backlog item, and asks before marking anything done — so finished items do not silently linger in the backlog.
- **A check that prevents a known session-breaking mistake now runs automatically before hook-touching releases** — A specific kind of stray separator inside the skill's settings header can silently break every new session. A check that detects exactly that is now part of the release process for any release that changes start-up or session-end behavior.

### Changed

- **The shipped-work backlog scan now runs even for documentation-only pushes** — A documentation change can still be the thing that finishes a backlog item, so that close-out scan no longer skips documentation-only releases.
- **The session-startup check now reports eleven pieces of project state, with no gaps** — The always-on check that reports your project's state at session entry now consistently covers eleven items, adding the project-rules-file size band, the count of old-format backlog items, and the installed-voice-file freshness state. These were already being computed but were missing from the summary the advisor reads. The internal cache version was deliberately left unchanged — these additions ride along with changes already in this release.
- **The version-bump procedure now also covers the voice file when its content changed** — Because the voice file is a real shipped artifact with its own version stamp, the release checklist now treats it as a fourth file to bump whenever its content changed in that release, so a stale-copy warning fires correctly for users.
- **Install and update documentation now explains the voice file** — The README and update docs now state that `setup` installs the voice style and warns you when your installed copy is behind the shipped one, instead of describing `setup` as only a command-registration step.
- **The always-on session-startup check now lives in its own file, so a stray separator can no longer break new sessions** — Every time the advisor runs in a project, a lightweight check reports the project's state (branch, memory, version, and so on) as the session opens. That check used to sit inside the skill's settings header — the configuration block at the very top of the skill file. Because that block is read as structured settings, a single stray three-dash separator line anywhere inside it was misread as "settings end here," which silently cut the check in half and blocked every new session until it was hand-fixed. The check now lives in its own standalone script, and the settings header only points to it — so editing the check can never truncate the settings block again, and that entire class of session-breaking accident is gone. Nothing changes for users: the check runs identically and reports exactly the same information.

### Fixed

- **Old backlog items now get the upgrade offer reliably, instead of being silently skipped** — If you have backlog items saved in the pre-v6.4 format, the advisor offers a one-time, opt-in migration to the current format. That offer used to depend on the advisor remembering to run a check during start-up; in real usage it almost never fired, so projects quietly accumulated dozens of un-upgraded items. The offer is now driven by the always-on session check (the same lightweight check that already reports your project's state at session entry), so it surfaces every time the advisor runs in a project that has old-format items — not only on a remembered first scan. Nothing about the migration itself changed: same opt-in prompt (Migrate now / Preview / Skip), same one-time "skip" that turns it into a quiet one-line reminder, same script. Only the trigger became reliable. The offer covers items that have old-format frontmatter (the small settings block at the top of each item file); backlog files with no frontmatter at all remain a separate, known gap and are not implied to be handled.
- **The session-startup check now works on macOS without extra tools installed, where it could previously go silent** — The startup check finds where the skill is installed by following a shortcut the installer creates. It did this with a command flag that ships by default on Linux but not on stock macOS. On a macOS machine without that extra toolset, that step produced nothing, the check could not find itself, and it silently did nothing at all — no error, no start-up state. The check now uses a method that is available out of the box on every macOS and Linux, so it works everywhere; behaviour on machines that did have the extra tools is unchanged.
- **Two settings-header separator fixes that close a session-breaking class** — A single stray three-dash line inside the skill's settings header is misread as "settings end here" and breaks every new session. Two such occurrences — one in a recently added detection step, one its incomplete first fix — were corrected, and the underlying check was moved out of the settings header entirely so the whole class of accident can no longer recur.

## [6.9.0] - 2026-05-18

### Added

- **Scripts and terminal commands now get the same robust hand-off prompts already got** (Script Emission Protocol) — When a session needs you to run a non-trivial script or a multi-command sequence in your terminal, the advisor now writes it to a file first and hands you exactly one short line to run it (`bash <path>`), instead of a long inline one-liner or a paste-in heredoc. Long commands pasted into a terminal get newlines injected mid-command or truncated at the edge — the identical failure the prompt hand-off already solved by writing the prompt to a file before showing it. A single trivial read-only command (`git status`, a one-line `cp`) still stays inline. If a permission prompt blocks a direct write or run, the file-first hand-off is the only fallback — the advisor never falls back to a fragile longer inline form, which is exactly what reproduces the original breakage.
- **A quiet self-check flags it when that hand-off discipline is skipped** (script-write-coupling check) — if a runnable command is handed over without having been written to a file first, the advisor's end-of-turn self-check records a note about it for later review. It mirrors the existing check that does the same for prompt hand-offs. It only logs a note — it never blocks the turn or stops the command.
- **Clearer scope on the source-edit safety guard** — the guard that stops the advisor from editing source code itself governs only the advisor's own actions; a delegated executor is the intended way source changes get made and runs outside that guard by design. This is a one-sentence clarification of what was always true, not a loosening of the rule.

## [6.8.0] - 2026-05-17

### Added

- **The advisor now names who does each action** (actor-ownership voice rule) — at hand-off points where a step is assigned, the advisor states explicitly whether the advisor, you, or the executor performs it, instead of an ambiguous "I'll do this, then you do that." Natural second person is unchanged everywhere else.
- **An almost-right delegated result can be corrected with one message instead of a full re-run** (flag-gated SendMessage corrections) — when a small delegated task comes back needing a minor fix (wrong commit wording, a missed constraint, formatting drift), the advisor can send a one-line correction to the same still-warm agent rather than re-dispatching the whole brief from a cold start. Gated behind Claude Code's experimental Agent Teams switch: when the switch is off (the default), behaviour is exactly as before — no new prompts, no mention of it. Same silent-fallback posture the advisor already uses for other optional tools.

### Fixed

- **Corrected the Pre-Send voice-checklist count** — the plain-English voice checklist gained an eighth item but a sentence still referred to "seven"; the count now matches.

## [6.7.0] - 2026-05-16

### Added

- **Every emitted prompt now records *why* its skill was chosen — into the saved file, not just the chat** (routing-decision record) — Until now, the one-line note explaining the routing choice lived only in the conversation reply; it vanished when the session ended. A later audit of a project's saved prompts could not recover the decision. From now on, each prompt writes a small `routing:` block — either `skill:` + a one-line reason, or `bare: true` + a one-line reason for using no skill prefix — into the saved prompt's frontmatter (or, for prompts shown inline rather than saved, into the matching last-prompts file). A new 14th item on the Post-Craft Verification checklist (the pass/fail table SP shows before handing you any prompt) fails the prompt if that block is missing or has no reason. Historical prompts are not retrofitted.

### Changed

- **Routing guidance now reflects what three projects of evidence actually showed** — A 220-prompt audit across three projects found the representative default is the bare prompt with no skill prefix (~82%), and that where skills are used the routing is diverse and appropriate — not a generic-skill bias. This corrects the earlier "always reach for `/sc:implement`" framing. The same evidence refuted two proposed additions (a deterministic routing-score engine and a design/visual-QA tiebreaker); the tiebreaker's supporting data turned out to be a measurement artifact. Only the auditability gap survived, which is what the routing-decision record above addresses.

## [6.6.1] - 2026-05-13

### Fixed

- **The startup briefing example now matches the verification rule it documents** — v6.6.0 added a three-class verification rule for the rows in startup briefings (the advisor reads what the startup check returned, OR fires a structured-choice menu when something is missing, OR calls a tool to inspect what's there). But the example shown right above the rule was a single bundled row — `Conventions, memory, routing | ✅ Clean | Normal startup` — with no detail on what was actually checked. The advisor learns the response shape from the visible example more than from the prose rule, so fresh-session briefings kept producing the bundled summary instead of the per-row, fully-enumerated shape the rule intended. After this patch, the example shows separate rows for project rules, the project's cross-session memory (with the actual memory names listed inline), the skill-routing matrix freshness check, and the git tree. Each row demonstrates its own verification path, so the advisor has a clear pattern to copy.

### Under the hood

The patch only changes the example. The verification rule itself stays as v6.6.0 wrote it — same three classes, same honesty constraint that bans ✅ alongside an "I didn't actually check" admission in the same row, same closing-menu requirement when something is missing. No new rules shipped.

## [6.6.0] - 2026-05-13

### Fixed

- **Startup briefings no longer claim verified status without running the verification** — Before this release, when you started a Strategic Partner session the advisor could render a status row like `Serena memory ✅ reachable / Haven't checked what exists for this specific project yet` — a green checkmark in the Status column alongside an in-row admission that the actual check (looking up which memories exist for the project) didn't run. The orientation read as internally contradictory. After this release, status rows reflect actual verification: ⏳ checking… while a check is in flight, ❓ not verified if the deeper check is skipped, and ✅ only when verification actually ran. Sits alongside v6.5.0 (which fixed the startup briefing closing with a prose line instead of a clickable menu).

### Added

- **Three verification classes for the rows in startup briefings** (the Verification protocol) — Each row in the startup briefing now belongs to one of three classes. Class A is verified by the startup hook directly (version, git, output style — the hook ran the check and the row reflects the result). Class B requires the advisor to ask the user via the structured-choice menu (when memory or routing or project rules are missing, the advisor surfaces the gap AND fires the menu asking what to do next). Class C requires the advisor to call a tool from the model side (when memory is present, the advisor reads the relevant memories to surface what's there). The class governs which verification path runs.

- **An honesty constraint on status rows** — A row may render ⏳ checking… while its verification is in flight, or ❓ not verified if the deeper check is skipped. It may NEVER render ✅ alongside an in-row admission that the verification didn't happen. The rule reads simply but eliminates the family of contradictory rows that motivated this release.

- **A release-time check for contradictory status rows** — The release-gate lint (the maintainer-side scanner that walks the CHANGELOG, README, recommended Output Style, and subcommand descriptions before every release) now catches the ✅-plus-admission shape mechanically. Patterns it flags include `✅ reachable / haven't checked`, `✅ fresh / didn't verify`, `✅ fresh / didn't actually verify`, and `✅ X / X is unknown`. Fail-closed: the lint exits non-zero on detection, blocking the release until the contradictory row is rewritten.

- **Regression fixture extended with verification-before-claim cases** — The fixture from v6.5.0 gains three new case groups: positive cases showing deferred ⏳ rendering while a tool call is in flight, negative cases showing the contradictory-row pattern from the user screenshot, and a negative case showing a missing-memory signal surfaced without the closing structured-choice menu.

- **Dryness Ban List pattern 9 in the recommended Output Style** — Contradictory status rows added as the ninth pattern in the list of dry, jargon-laden, memo-flavored response shapes the advisor avoids.

### Changed

- **Pre-existing verbose sections trimmed to honor the net-negative line target** — The four Response Template worked examples (Decision, Status, Analysis, Discovery) each dropped one trailing recap sentence that restated what the worked example already showed. The Formatting Playbook's Sparse-vs-Rich anchor demo was compressed from two parallel 15-line code blocks to one annotated comparison; the teaching point lands cleanly without the duplicate content.

### Behavioral files net change

- `SKILL.md`: 2472 → 2472 lines (no change)
- `output-styles/strategic-partner-voice.md`: 874 → 847 lines (-27)
- **Total behavioral files: 3346 → 3319 lines (-27 — target was ≤ 0)**

The structural fix adds the Verification protocol (three verification classes plus the honesty constraint plus a closing-menu carve-out for missing-memory/missing-routing/missing-rules signals) and the Dryness Ban List entry to the Output Style, plus the contradictory-row pattern in the release-time voice lint and the regression fixture extension. Offsetting trim came from cutting four redundant trailing-recap sentences after the Response Template worked examples and consolidating the duplicate Sparse-vs-Rich code blocks in the Formatting Playbook into one annotated comparison.

## [6.5.0] - 2026-05-13

### Fixed

- **Startup briefings now always end with a clickable menu instead of a bare prose line** — Before this release, when you started a Strategic Partner session the advisor could close its briefing with something like "Ready when you are." or "Let me know what you'd like to focus on." — leaving you to type a freeform direction when a clear pick-list would have been faster. After this release, the closing menu (the structured choice the advisor presents you with) reliably fires at session start, every time. The fix is structural rather than a patch on top: startup briefings now have their own dedicated response shape, with their own dedicated template, and the closing question is treated as protocol-mandated (it can never be silently absorbed into prose). Diagnosed via in-session root-cause analysis, validated by cross-model adversarial review (Codex GPT-5.5, xhigh reasoning effort).

### Added

- **A dedicated response shape for startup and session-entry "where do we stand" check-ins** — When the advisor is doing a startup briefing or a "where do we stand" check at session entry, the response now follows a shape built specifically for that moment (called the Orientation envelope internally). The selector routes startup responses through this shape first, ahead of the regular conversational default. The shape's template requires the closing menu in its worked example, so the advisor copies that closing pattern when it composes the response.

- **Startup closing questions are now on the always-fire list** — The advisor's closing menu during startup is now in the small set of questions the advisor cannot skip — joining the "ready to move from thinking to building?" gate, the "you said 'just do it' — confirming?" gate, and the "external-review verdict is in — what's next?" gate. In plain terms: when you start a session, the advisor always presents the next-step menu. It can't quietly choose for you.

### Changed

- **Six scattered rules that licensed prose-closing were collapsed into one** — Before, the same rule ("don't wrap a non-question in the structured-choice tool") was repeated across both the main rules file and the voice file in slightly different phrasings. Together they were enough to license skipping the structured choice at startup (because the startup moment doesn't literally contain a `?` in prose). After, one place owns the rule and explicitly names the always-fire exceptions; the other places reference it or were removed.

- **The Status response template's worked example now ends in a clickable menu** — When the advisor is giving a status briefing and the next step is a real decision, the closing line is now the structured-choice menu instead of a prose "What's next" plan. The advisor copies what the template demonstrates, so this propagates to live status briefings.

- **A duplicate status-briefing pattern was removed from the main rules file** — The Done/Active/Next table that lived in two places (rules file and voice file) is now in one place only. The voice file owns the canonical shape; the rules file points to it.

- **Adjacent prose compressed without touching visual elements** — The Plain-English Whole-Response Gate, Voice Discipline intro, and Anti-Sycophancy Symmetric failure mode were each rewritten with one fewer paragraph but no change to content. Emoji anchors, ASCII flows, before/after code blocks, side-by-side comparison tables, structured bullets, and bolding patterns are all preserved.

### Behavioral files net change

- `SKILL.md`: 2460 → 2472 lines (+12)
- `output-styles/strategic-partner-voice.md`: 852 → 874 lines (+22)
- **Total behavioral files: 3312 → 3346 lines (+34)**

The structural fix genuinely adds ~35 lines of new content (a new response-shape step in the selector, a new row in the response-shape table, a new always-fire entry in the bypass list, a new response template, and a carve-out paragraph). Per user direction, visual elements (emoji anchors, ASCII flows, comparison tables, code-block before/after examples, structured bullets, bolding patterns) were preserved at full visual weight rather than over-trimmed to hit a net-negative line target. The structural fix earns its keep by collapsing six redundant prose-closing rules into one canonical owner — so there are fewer competing closure cues for the advisor to follow. Net effect: line count grew, but the rule conflict dropped and the structural fix lands. The full release diff (including `README.md` and `CHANGELOG.md`) is larger but doesn't affect runtime behavior.

## [6.4.0] - 2026-05-13

### Added

- **Backlog items now move through a named lifecycle instead of an ad-hoc taxonomy** — Strategic Partner's backlog and findings cycle is rebuilt around five named states with explicit transitions. Items start as 📥 inbox (a fresh capture you haven't thought through yet), become 🔍 clarified once they're scoped, sit ⏳ parked while waiting on a trigger, become 🔄 active when work starts, and close to ✅ closed with one of four reasons (completed, not-planned, duplicate, superseded). Each transition names a decision-maker, so the cycle is no longer "SP decides" by judgment — it's a small state machine you can audit. The full reference lives at `references/backlog-cycle.md`.

- **Existing backlog items auto-upgrade to the new schema on first run after install** — when you start Strategic Partner for the first time after upgrading to v6.4, the advisor scans your project's backlog and offers a one-time prompt: Migrate now, Preview, or Skip. The migration script renames files under the new verb-prefix convention (fix-, add-, improve-, investigate-, migrate-, redesign-), upgrades frontmatter (`status:` becomes `state:`, `type:` / `priority:` / `severity:` fold into a `labels:` list, `added:` becomes `opened:`), and converts trigger prose into a structured triggers list. It runs safety preflights first — a dirty-tree check and a pre-migration backup under `.handoffs/pre-migration-backup-YYYYMMDD-HHMMSS/`. When `.backlog/` is tracked by git, the migration also lands as a single atomic commit you can revert with one command. When `.backlog/` is gitignored — the typical case, since most projects treat backlog items as local working state — rollback uses the backup directory rather than git: copy files from the backup back into `.backlog/` to undo. Either way, the backup is the universal rollback path. If you pick Skip, the advisor reads your old-schema items in a degraded mode (no trigger evaluation) and shows a banner at orientation bottom until you migrate manually. The script is idempotent — re-runs after a successful migration are no-ops.

- **Triggers are now typed instead of prose** — every parked item names its triggers with one of three types: **mechanical** (a shell expression like `[ $(wc -l < SKILL.md) -gt 1500 ]` that the advisor runs directly), **event** (something observable in findings, recent handoffs, or the current session), or **temporal** (a version or cadence comparison). Composite triggers default to OR semantics (`triggers_logic: any`); rare items that genuinely need AND semantics set `triggers_logic: all`. The result: "trigger met" is a yes/no question, not a read.

- **Voice discipline rule for source edits** — the source-editing guardrails in `.claude/rules/source-editing.md` gain a new principle (Voice Discipline) that codifies plain-English voice, deliberate visualization (tables, ASCII, structured bullets), functional emoji anchors at substantive sections, and gloss-on-first-mention for any project-internal vocabulary. The rule applies at edit time, complementing the release-time voice lint and the live-session voice rules in the strategic-partner-voice output style. Why: if Claude Code deprecates output styles later, the voice still lives in the source itself.

- **Findings disposition rule documented for follow-up implementation** — the new lifecycle spec (`references/backlog-cycle.md` § Findings disposition) defines an auto-archive rule: a finding that survives 3 consecutive triage events without being promoted to `.backlog/` gets moved to `.handoffs/findings-archive/` with an appended note. The rule is captured in the spec for v6.4; the runtime tracking that counts per-finding triage survival is scheduled for a follow-up release (the rule is informational in v6.4 — users can apply it manually if a findings file feels stale, and the spec gives the advisor a hook to surface stale findings at triage time).

### Changed

- **Triage now fires on a known cadence instead of opportunistically** — two events drive backlog triage. The advisor walks the inbox automatically before every minor or major release (catching parked items whose triggers fired and inbox findings worth promoting), and the same walk runs on-demand any time you invoke `/strategic-partner:backlog`. Per-session lightweight scans are not part of the cadence — they added noise without earning their keep for a single-user-ish project.

- **Filenames now carry intent at-a-glance via verb prefixes** — every active backlog item is named with one of six lowercase verb prefixes: `fix-` (defects), `add-` (new capabilities), `improve-` (refinements), `investigate-` (open questions), `migrate-` (moving between approaches), `redesign-` (rare deep rewrites). No date stamps, no version stamps, no type tags in filenames — that metadata lives in frontmatter. For items spanning multiple verbs, a precedence ladder picks the primary intent (fix > migrate > add > improve > investigate > redesign) and secondary intents go into the `labels:` field.

- **The `/strategic-partner:backlog` subcommand groups items by lifecycle state** — items render under their state's functional emoji anchor (📥 inbox, 🔍 clarified, ⏳ parked, 🔄 active), with closed items deferred to the archive. The triage menu now offers five actions: discard (for inbox findings), promote to clarified, promote to active, set a trigger and park, or close with one of the four reasons. The subcommand walks both the lightweight findings file (`.handoffs/findings-MMDD.md`) and substantive items (`.backlog/*.md`) as one logical inbox — they are two storage shapes serving the same lifecycle stage.

- **`.claude/rules/source-editing.md` Principle 5 emoji list adds 📥 intake** — the canonical functional-emoji anchor list used by the voice rules now includes 📥 between 🎯 routing and 📋 status, giving the new inbox state a documented home.

- **Strategic Partner's own internal backlog items migrated in place to the new schema** — Strategic Partner's `.backlog/` directory is gitignored (the items are SP-internal working state, not shipped artifacts), so the migration shows up in this release's git history as a marker commit (`migrate(backlog): rewrite 20 items under new schema`) rather than a tracked diff. The 20 items were renamed under the new verb-prefix convention and rewritten under the v6.4 schema on disk; users who clone or update SP will not see any `.backlog/` content in git, but their OWN backlogs are migrated by the auto-migration mechanism described above. Two SP-internal items were reclassified per the design spec's manual-migration intelligence — `routing-quality-improvement` (was `type: feature`, really an enhancement) became `improve-routing-quality`, and `codex-feedback-improvements` became `improve-codex-feedback-patterns`. The two partial-state items carry meaningful `progress:` summaries naming exactly what shipped and what remains.

## [6.3.4] - 2026-05-11

### Added

- **Hard structural constraints on README maintenance** (release process update) — `CLAUDE.md` § 4 now sets a 300-line README ceiling, caps "What's new" at the current release only, caps technical "Under the hood" detail at 5 bullets, and requires plain-English descriptions for SP-internal vocabulary on first mention. The Codex pre-release review brief must now include the line ceiling, a forcing question ("Would you install this after reading?"), and a request for the top 5 ranked structural cuts. If Codex returns "would not install," the release is blocked until the README is fixed. Prevents the soft drift that allowed the README to grow to 446 lines without each individual review catching it.

- **New `ARCHITECTURE.md`** — maintainer-facing reference for the full file layout, behavioral gates, memory architecture, cognitive patterns, closure walk, cross-model review modes, context handoff, provider formatting, 1M context advisory, release-time lint layers, release process highlights, and pointer to Provisional Guards in `CLAUDE.md`. Receives content that previously lived inside README's "Under the hood" and "Full file tree" sections.

### Changed

- **README rewritten from 446 to 265 lines** (structural rewrite per Codex audit) — Stale version-history wall replaced with a one-line "What's new" naming the current release only. Maintainer-facing file tree and technical detail moved to the new `ARCHITECTURE.md`. 18 SP-internal terms replaced with plain-English phrases — for example, "structured question prompts" (formerly `AUQ`), "pre-build decision checklist" (formerly `Advisory Completion Gate`), "the safety guard that blocks accidental source edits" (formerly `PreToolUse hook`). Opening pitch and two-sessions diagram preserved verbatim; "key difference" table preserved with vocabulary fixes. Codex install-or-skip judgment moved from "would not install" pre-rewrite to expected "yes" post-rewrite.

## [6.3.3] - 2026-05-11

### Changed

- **Closure-walk status names now read in plain English** — at session-end, Strategic Partner runs a verification checklist across project state (the "closure walk") and renders a status table summarizing what got checked, what got handled automatically, and what needs your input. Previously, that table surfaced internal state-machine names like `RESOLVED`, `RESOLVED-AUTO`, `SKIPPED-AUTO`, and `DIRTY` — terms that read clearly to the advisor but confused non-technical readers. The rendering layer now translates each state to a short plain-English phrase with a status emoji: ✅ Checked, all clean / ✅ Already handled / 🟡 Needs your input / ⏭️ Skipped (you declined) / ➖ Doesn't apply this session / 🚨 Uncommitted source changes. The internal state-machine logic that drives the walk is unchanged — only the user-facing rendering translates. The summary line at session-end also reads in plain English now ("3 of 8 checked, 2 handled automatically, 1 needs your input" rather than the previous state-name shorthand).

## [6.3.2] - 2026-05-11

### Changed

- **Strategic Partner now writes to its memory at smarter moments, not just at session-end** — the advisor follows a new two-rhythm rule for writing to Serena (its cross-session memory store). Factual corrections — file paths, version numbers, new conventions just agreed on — write immediately as routine hygiene with a brief mention in chat. Substantive decisions accumulate during a stretch of advisory work, then write as one coherent block when that stretch ends — when the advisor confirms the path forward and moves on to packaging or to a new topic. The single block keeps the story of "what got decided and why" together as one readable entry; one write per decision would scatter the same narrative across many tiny entries. The session-end closure checklist remains the catch-all, so anything missed during the session still lands before the session closes.

### Fixed

- **Internal premise corrected: the source-edit guard never blocked memory writes** — past internal framing implied that Strategic Partner's source-editing safeguard (the rule that stops the advisor from editing project source files directly) was also blocking writes to its memory store. It was not — memory writes were always available. The historical pattern of substantive decisions ending up in the handoff but never the cross-session record was always a behavioral gap, not a structural one, so fixing it took a behavioral rule (above), not a code change to the guard.

## [6.3.1] - 2026-05-11

### Added

- **Strategic Partner now stops at every decision instead of bundling them** — the recommended Output Style picks up a new section called Ask-Don't-Drift Discipline that codifies five behavior rules. First, any decision the user needs to make appears as a structured choice (the `AskUserQuestion` tool that presents a small number of labeled options), not as a question buried in prose. Second, when a path has multiple steps the user might want to redirect at, the advisor pauses after each step instead of sweeping through all of them in one response. Third, even brief check-ins like "does that work for you?" go through the structured-choice tool — not just substantive recommendations. Fourth, when a turn describes a transition where a decision is owed, that turn must end with a structured choice — silently absorbing the decision into a status sweep is the same protocol violation as burying the question in prose. Fifth, before dispatching to a sub-agent, the advisor consults the routing matrix (a reference that maps task shapes to specialist agents), states which agent it picked and why, and surfaces that choice as part of the dispatch confirmation so you can catch a wrong agent before it runs.

- **You now see which sub-agent SP is about to dispatch, and why, before it fires** — when the advisor is about to hand work off to a specialist sub-agent, the response includes a `Routing:` line naming the chosen specialist and the matrix row or rationale that justified the pick. The first specialist dispatch in a session is gated by a confirmation question whose option label names the specialist (for example, "Dispatch now — frontend-architect" instead of generic "Dispatch now"), so a wrong pick gets caught at the confirmation step rather than after the agent returns with the wrong kind of work. The rule also narrows the "fall back to general-purpose" carve-out: when any specialist plausibly fits, the advisor names the candidates considered, why each was rejected, and asks the user rather than defaulting silently.

### Changed

- **The Output Style's validation checklist gained three new voice items** covering the new rules: `AskUserQuestion` for any user-facing decision (no questions in prose); transitions owing decisions end with the structured-choice tool, not a status sweep; and pre-dispatch responses include the routing line plus the chosen agent in the confirmation option label.

## [6.3.0] - 2026-05-09

### Added

- **Output Style is now a permanent row in your session orientation** — every fresh `/strategic-partner` session shows whether the recommended Strategic Partner Voice is active. When it is not, you see a two-line activation hint right in orientation: open `/config` and switch the Output Style, or set `outputStyle: strategic-partner-voice` in your user settings file. No questions, no nag — the row is informational and respects users who have explicitly chosen a different style. If the persisted settings disagree with the runtime style your session is actually using (rare, usually means you edited the file mid-session), the row also notes the mismatch so you can restart the session to reconcile.

### Changed

- **Output Style detection moves into the session-entry snapshot** (the one-time snapshot that already gathers project conventions, persistent memory, git state, and version freshness on session start). SP no longer runs a separate detection step at startup; the duplicated procedure in the internal startup checklist is replaced with a pointer to the snapshot. Sessions running an older snapshot during the transition fall back gracefully to a direct settings-file read; the fallback can be removed in 1-2 release cycles past v6.3.

## [6.2.1] - 2026-05-07

### Fixed

- **Startup orientation now correctly identifies the active Output Style** even when other plugins inject "you are in X mode" guidance via SessionStart hooks. Strategic Partner used to read that injected text and report it as the active style — telling users to switch to a setting they'd already chosen. Orientation now reads the settings files directly (with the runtime `# Output Style:` header as the authority), and surfaces any disagreement between settings and runtime rather than silently picking one.

### Note

- v6.2.1 also includes the **Strategic Partner Voice** Output Style work originally tagged as v6.2.0 (which was not published as a GitHub Release). See the v6.2.0 entry below for what shipped in that commit. Users upgrading from v6.1.x to v6.2.1 receive both the Output Style and this orientation fix.

## [6.2.0] - 2026-05-07

### Added
- **A new way to keep advisor responses readable and structured** (strategic-partner-voice Output Style) — Strategic Partner now ships an installable Output Style that activates a super-structured assistant persona for non-technical readers. The style applies plain-English language, deliberate visual formatting (functional emoji anchors, tables, ASCII diagrams), and anti-sycophancy rules at the model-instruction level — before responses are generated rather than after. The setup script now copies the style file to `~/.claude/output-styles/` on install (does not overwrite existing user copies). Activate via `/config` → Output Style → "Strategic Partner Voice", or set `outputStyle: strategic-partner-voice` in `~/.claude/settings.json`. Takes effect on next session start. On startup, SP also detects the active Output Style and surfaces a soft recommendation if it is not `strategic-partner-voice` — no enforcement, just a note pointing at the recommended setup so users know the option exists.

## [6.1.0] - 2026-05-06

### Added

- **Scanner now flags SP-flavored framing in your project file** — When you run `/strategic-partner:context-file-scan` against your project's `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`, the scanner now detects sections that declare Strategic Partner as an always-active project pillar (top-of-file headings framing SP as a behavioral mode), or operating-rules blocks duplicating SP's own interaction-discipline defaults. The new check fires once per file at warn severity with a copy-paste suggestion to remove the section or scope it to a project-named overlay. Strategic Partner is a skill — its behavioral defaults apply automatically whenever it is invoked, so they do not belong in your project's context file.

### Changed

- **The project's own rules now codify the same policy as a guard.** SP's `CLAUDE.md` gains a Provisional Guard naming SP-flavored framing in user project files as a policy violation rather than a strength. Closes a gap exposed during a v6.0.1 advisory session where SP rated such framing 9/10 as a feature instead of catching the duplication. The full archaeology lives in the project's incident archive.

### Notes

- The pre-push adversarial review (the cross-model second-pass that runs before any release push) returned a conditional approval on v6.1.0 with eight significant findings, three minor, and no blockers. A follow-up commit on top of the v6.1.0 release tag addresses three of the fixes: a false-positive case in the new SP-framing scanner check is tightened, an incident-archive note that overclaimed what the release ships is reworded, and a stale "16 patterns" count in the README is bumped to 17. The fourth observation — undefined internal vocabulary surfacing in advisory chat during the release session — is filed in the project backlog as continued evidence for the runtime voice-discipline enforcement work.

- A second pre-push review pass — re-run on top of the previous follow-up commit — returned conditional approval with three more significant findings, two minor, and no blockers. This second follow-up addresses two of them: the new scanner check is narrowed further so a generic "Mode" heading no longer counts on its own as evidence of SP-as-pillar framing (the remaining co-occurrence tokens still catch real SP-flavored framing), and the README banner is rephrased so the updated 17-pattern count is no longer presented as a v6.0.0 fact. Undefined internal vocabulary that surfaced again during this second pass is appended to the same project backlog item that captured the earlier pass's voice slips. The runtime per-turn voice-discipline enforcement still parked in that backlog item — a check that would scan each outgoing chat turn before you see it — is the canonical fix and remains scoped to a future minor release. v6.1.0 ships with voice quality as a documented known issue.

## [6.0.1] - 2026-05-06

### Fixed

- **CHANGELOG v6.0.0 quiet-mode-scan description corrected** — the prior wording implied the quiet-mode scan auto-detects and scans your project's `CLAUDE.md`. It does not. The quiet-mode scan only scans SP's own `CLAUDE.md`; project-file scans require explicit `/strategic-partner:context-file-scan` invocation. The CHANGELOG text now matches the implementation.

### Added

- **Premise Challenge trigger #6 — context-file scan first.** When you ask SP to improve `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` or "our rules," SP now surfaces `/strategic-partner:context-file-scan` as Step 1 before any other routing. Closes a failure mode where the scanner shipped in v6.0 but SP failed to surface its own feature without three explicit user reminders.

- **Floor sentinel size bands.** Orientation now shows a band-appropriate flag when your project's `CLAUDE.md` is large. Bands match the scanner's S1 thresholds: under-soft (silent), soft-warn (💡), warn (⚠️), surface-loudly (🚨 + scanner suggestion). One source of truth across SP — the floor and the scanner agree on what counts as "large."

- **v6.0 Context-File Policy section in SKILL.md.** Short scannable summary of the Hybrid Pattern, the 16 rules, the size bands, and the canonical example (SP's own `CLAUDE.md`). Brings the policy from `commands/context-file-scan.md` (where the scanner reads it) into the SP's main behavioral surface (where SP reads it).

### Note

- **Scope of this release** — three specific scanner-discoverability issues are addressed: SP now suggests the scanner when you ask to improve your context file; orientation now shows a size warning that mirrors the scanner's policy; and `SKILL.md` surfaces the scanner more prominently in routing decisions. Other improvements suggested during field testing — additional discoverability nudges and stricter plan-authoring practices — are tracked in the project backlog and will land in later releases.

- **Known issue: voice discipline during release work** — SP's communication during release planning and execution occasionally slips into internal vocabulary (rule numbers, raw line references, undefined acronyms). The mechanical voice lint (`tests/lint-voice.sh`) catches several patterns in release artifacts; runtime per-turn enforcement of voice rules in live chat remains parked work in the backlog (`.backlog/in-chat-voice-runtime-enforcement.md`), prioritized for the next release that includes a Stop-hook update. The released artifacts in v6.0.1 (CHANGELOG, README, code) are clean; the issue is specific to advisory chat during release sessions.

## [6.0.0] - 2026-05-05

### Added

- **Detect drift in your project's `CLAUDE.md`, `AGENTS.md`, or `GEMINI.md`** with the new `/strategic-partner:context-file-scan` command. The scanner reads your project's rules file, follows pointers to a companion rules file when one exists (this "hybrid pattern" keeps the main file small while the full content loads only when needed), and flags 16 patterns of drift across two categories. **Structural problems**: oversized file, sections that belong in a separate doc (decision logs, architecture notes), stale path references to deleted files, expired Provisional Guards, inline shell blocks better off as scripts, re-asserted skill rules. **Behavioral problems**: missing source-editing rules in projects that produce code, broken hybrid pattern (stub without companion or vice versa), rules without examples, rules a linter or CI gate could enforce instead, duplicated rules, drift from the four behavioral principles (described in the next bullet).

  Two output modes: an interactive walkthrough that proposes one fix per finding, or a single markdown report for offline review. Run `/strategic-partner:context-file-scan` to start.

- **The four behavioral principles ship publicly**, with attribution to Andrej Karpathy's source corpus. The principles — Think Before Coding, Simplicity First, Surgical Changes, and Verification not Specification — apply whenever Claude is editing source files in a project that adopts the pattern. Worked examples live in a path-scoped rules file (a separate doc that only loads when source files are actually being edited), so the rules don't cost tokens during advisory or planning work.

- **Quiet-mode scan at session start** — when you open a fresh SP session, the orientation includes a one-line summary if SP's own `CLAUDE.md` shows policy drift. This catches drift in the SP install itself; it does not silently scan your project's `CLAUDE.md`. To scan your project's rules file, run `/strategic-partner:context-file-scan` (the scanner auto-detects `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` in your CWD). Suppressed when SP's own file is clean and during continuation sessions where a handoff path is already focused. (Note: v6.0.0 originally implied auto-detection-in-CWD for the quiet-mode scan; that wording was incorrect and was clarified in v6.0.1.)

- **A release-gate mode** (`--release-gate` flag) for CI pipelines and pre-push checks. Returns a non-zero exit code if any warn-or-higher finding lacks a documented exception in your project's `.scanner-exceptions.json` (an opt-in file you maintain per project, one entry per finding you've decided to accept). Useful for teams that want their rules file to converge on the policy without breaking on every legitimate edge case.

### Changed

- **Smaller install footprint** — the SP install no longer includes the internal test suite (~115 files of test scripts, fixtures, and lint configuration). Users who installed via `npx skills add` or `git clone` will see those files removed on their next update. The test suite remains in active development as part of SP's own quality story; it just doesn't ship to every user. Roughly 10% byte reduction and 66% file-count reduction in the install footprint.

### Note

- **First public release with the scanner.** v5.17.0 and v5.18.0 were internal-only releases that prepared the policy SP now uses on its own files; v6.0 makes both the policy and the scanner available to anyone using Strategic Partner.

## [5.18.0] - 2026-05-05

### Added
- **A new section in SP's project-rules file describing how Claude should approach editing SP source** (migration #1.5, internal). The new "Behavioral Guardrails" section in `CLAUDE.md` names four principles in four lines — think before coding, prefer simplicity, make surgical changes, anchor on verifiable outcomes — and points to a separate file with the full content. Same hybrid pattern SP will recommend to other projects when the broader policy ships publicly.

- **A new path-scoped rules file at `.claude/rules/source-editing.md`** holds the full behavioral content. It loads only when Claude is editing SP source files (the skill definition, hooks, references, commands, or tests) — so the rules apply where they matter without costing tokens during release runbook work or advisory turns. Each principle includes an anti-pattern, a corrected approach, and a worked example drawn from SP's own domain (caching the routing matrix; making the floor sentinel's timeout configurable; adding a value to a list in YAML frontmatter; fixing a silent-pass bug in the voice lint).

### Changed
- **CLAUDE.md visual style aligned with the policy.** Each top-level section now leads with a functional emoji (🎯 Project Facts, 📍 Where to Look, 🧠 Behavioral Guardrails, ⚙️ Release Process, 🚧 Provisional Guards) and major sections are separated by `═══` rules. Emojis are scanning anchors, not decoration; separators give visual rhythm so major sections aren't easily missed. Same visual pattern SP will recommend to other projects when the broader policy ships publicly.

- **`.gitignore` carve-out so the new rules file actually ships.** `.claude/` was wholesale gitignored for session state (local settings, worktrees). The new rules file lives under `.claude/rules/` and needs to ship with the skill, so `.gitignore` switches to ignoring `.claude/*` with an explicit exception for `.claude/rules/`. Session state stays local; project rules ship.

### Note
- **The four behavioral principles come from a draft policy that's been in development since April 28** — a unified policy on how project-rules files should be sized, layered, and refreshed over time. v5.17.0 applied the structural half of that policy to SP itself (file shape, layer routing, lifecycle for incident-born rules). This release applies the behavioral half (how Claude should approach editing SP source). The full policy document with external attribution lands publicly in v6.0.0 alongside the scanner command that detects similar drift in other projects' rules files.

- **No GitHub Release for v5.18.0** — internal release. The eight commits from v5.17.0 also push as part of this bundle. The user-facing release that includes the scanner command lands as v6.0.0 once the scanner is built.

## [5.17.0] - 2026-05-04

### Changed
- **SP's own project-rules file got reshaped to match SP's draft policy on rules-files** (migration #1, internal). SP has been drafting a policy on how project-rules files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) should be sized, sectioned, and trimmed over time. This release applies that policy to SP's own `CLAUDE.md` as the first of three to five projects that have to migrate before the policy ships publicly. The file now opens with a small "Project Facts" section (four non-default conventions like commit style and macOS bash compatibility), a polished "Where to Look" pointer table, the unchanged release runbook, and a tighter rules section at the bottom.

- **Bug-driven rules now sit in a 4-line shape pointing at the underlying incident write-ups.** Each Provisional Guard (the entries that record a rule SP added in response to a past incident) used to carry a multi-paragraph narrative explaining the original bug inline. Those narratives have moved to `claudedocs/INCIDENTS.md` — searchable, indexed, one entry per incident. The guards themselves keep only the rule, its affirmative alternative, the scope, the pointer to the incident write-up, and the review date. Same rules, less reading at session start.

### Added
- **Six new incident write-ups in `claudedocs/INCIDENTS.md`** — one for every Provisional Guard whose narrative just moved out of `CLAUDE.md`. Each entry follows the existing format: What happened / Why it broke / Fix shipped / Lesson formalized.

- **The release-time quality check now supports an explicit skip-list for old conversation transcripts** (a `.lint-allowlist` file at the repo root). Each non-comment line names a single transcript filename to exempt. Three transcripts from the v5.16.0 and v5.17.0 advisory sessions are added to the skip-list as a one-time bootstrap — those transcripts captured authoring drift that never reached any published file (CHANGELOG, README, CLAUDE.md, INCIDENTS.md are all clean). Future sessions are still scanned in full; the mechanism exists so old sessions do not block an otherwise-clean release.

### Note
- **The reshaped `CLAUDE.md` lands at 405 lines / ~21.5K characters — healthy for a single-topic release runbook, not a length problem.** The draft policy explicitly endorses release-runbook files at this size when their content earns its space; this release confirms that's the realistic floor for SP's own runbook after every reasonable compression pass.

- **The rules-file policy itself stays unpublished for now.** It ships publicly when the matching auto-scan command exists and the policy gets referenced from SP's onboarding for new projects. Three more project migrations after this one will prompt a first-pass review of the policy itself.

- **The three allowlisted transcripts are documented in the `.lint-allowlist` file itself** with rationale comments. The allowlist is intended for deliberate, documented exemptions only — every entry should name the reason it's there and reference whatever follow-up work (if any) closes the underlying gap.

## [5.16.0] - 2026-05-03

### Fixed
- **The routing matrix no longer rebuilds every session.** Previously, a fresh SP session opened more than an hour after the last build triggered a full rebuild, burning ~4 minutes and ~85K tokens to inventory the same skills, agents, and MCP servers as before. The startup floor check now compares a compact fingerprint of the agent inventory (a sha256 over the sorted filenames in `~/.claude/agents/`) against a fingerprint stored in the cached matrix. If they match, the cached matrix is reused with no rebuild. If they differ, only then does a rebuild run — because something actually changed. The freshness check itself runs in ~150ms per invocation, well under the 200ms budget for the startup floor, and uses zero LLM tokens when nothing changed. The fingerprint covers agents only (not skills or MCP servers) because the startup hook can read `~/.claude/agents/` from the same filesystem location the rebuild does — that's the only inventory source where the two sides are guaranteed to compute identical hashes. Pure skill or MCP installs without an accompanying agent change are not auto-detected by the floor; an explicit refresh via `/strategic-partner:update` handles those cases.

- **A permanent rebuild loop in projects without Serena memory is now closed.** Previously, the floor only checked the Serena memory location, while the SP wrote the matrix to `.claude/` files when Serena was absent — so the floor saw "missing" every session and dispatched a rebuild every session. The floor now falls through Serena → `.claude/skill-routing-matrix.md` → missing, and the SP writes to one canonical location based on whether Serena is active. (User-flagged via the BAM-MVP project, where Serena memory was absent and two competing matrix files had accumulated.)

### Added
- **`inventory_hash` field in the routing matrix footer.** Each rebuilt matrix now records a 16-character sha256 fingerprint of the agent inventory alongside the existing `routing_status`, `scan_timestamp`, `errors`, and `counts` fields. The startup floor reads this field on the next session start to decide whether the cached matrix is current. The fingerprint covers sorted `~/.claude/agents/` filenames plus the agent count so the floor — which has no access to the in-conversation skill list — can recompute the same hash that the matrix builder wrote.

- **A new Provisional Guard in CLAUDE.md** — routing-matrix freshness must be content-based, not time-based. Codifies the inventory-hash decision so future floor work doesn't regress to mtime + time-window heuristics, and pins the hash inputs to filesystem sources both the floor and the matrix builder can see.

### Changed
- **Single canonical routing-matrix file when Serena is absent.** The matrix builder now writes to one source of truth per project: Serena memory `skill_routing_matrix` when Serena is active, else `.claude/skill-routing-matrix.md`. The legacy `.claude/sp-routing-matrix.md` companion is deprecated and no longer created. Existing legacy files in user projects remain on disk until natural rebuild via the canonical name.

## [5.15.2] - 2026-05-03

### Fixed
- **Voice lint now fails closed when it can't actually scan files** (`tests/lint-voice.sh` hardening) — Previously, an empty file collection (e.g., when `TMPDIR` is broken or expected directories go missing) would silently report "all clean" and exit 0. The release-time gate now aborts with exit 1 when expected files exist but zero were scanned. Header comment also updated to document the 7 mechanical patterns now in `hooks/lib/validators.sh`. Closes a hidden release-gate failure mode.

- **Codex CLI dispatch policy hardened end-to-end in `commands/codex-feedback.md`** — Locks in five policies covering every known misconfiguration class for SP-dispatched Codex reviews: (1) **mode-aware sandbox** — Mode A (decision review) uses `--sandbox read-only` for tightest analysis; Mode B (evidence audit) uses `--sandbox workspace-write` because read-only blocks `/tmp` writes that bash heredocs require; (2) **stdin closed via `< /dev/null`** to prevent 30+ min hangs in Codex CLI 0.124+; (3) **never override the model** via `-m`/`--model`/`-c model=*` — user's `~/.codex/config.toml` `model` setting wins (recommend `gpt-5.5` or latest, never `o4-mini` or older); (4) **never override reasoning effort** via `-c model_reasoning_effort=*` — user's config wins (recommend `high` minimum, `xhigh` for complex audits, never medium/low); (5) **generous timeout floors** — bumped to 480s/900s/1500s/2400s for small/moderate/large/full-repo audits, prefer over-allocating to wasting already-spent tokens on a timeout. Spec also documents required `~/.codex/config.toml` settings, `--add-dir` for audits that need transcripts outside the project dir, and minimum Codex CLI version 0.128.0+.

### Added
- **Placeholder-string check in voice lint** — Catches committed user-facing prose containing `[Populated at...]`, `[TODO]`, `[PENDING]`, `[FIXME]`, or `[XXX]` markers across `CHANGELOG.md`, `README.md`, and `commands/*.md`. Prevents incomplete drafts from shipping. Mechanical violation (release-blocking).
- **Cross-file token consistency Provisional Guard** in `CLAUDE.md` — Documents the rule that when authoring multi-file template sets (template + renderer + reference), all files must use IDENTICAL token names. Codifies the v5.15.0 closure-floor lesson where `[STATUS_EMOJI]` and `[STATE_EMOJI]` diverged across three files.

## [5.15.1] - 2026-05-01

### Fixed
- **Close-routine now properly tracks every loose end at session-end.** Previously the close-routine's parked-folder check just gave a count ("27 items total"). It now breaks down by status — how many are ready to act on (their wait condition fired), how many haven't moved in over 30 days, how many are recent, and how many are technically done but still showing as parked. The findings check also now lists what happened to every captured note, not just whether new ones got captured today.

- **Close-routine now closes finished items.** When work in this session finishes a parked item, the close-routine catches it and proposes archiving. Previously items piled up as "parked" even after the work was done.

### Changed
- **Close-routine status table now shows backlog, prompts, and scripts as independent rows.** The combined parked-folder check used to render as a single row in the table; if any of the three sub-checks was skipped, you couldn't tell. Now backlog hygiene, pending prompts, and pending scripts each get their own row.

- **Voice rules document now includes a checklist and worked examples.** The pre-send check now has an explicit list of patterns to scan for (Greek labels, bare letter options without named context, file paths in user prose, internal vocabulary without gloss). And a positive-examples section demonstrates what readable / clearly visual SP communication looks like in practice.

### Added
- **A short paragraph in the canonical close-routine documentation** names the noticed → tracked → done lifecycle as the SP's mental model for findings, backlog, and retired work. Concrete enough to anchor future protocol decisions.

- **Two new Provisional Guards in CLAUDE.md.** First: when an executor brief has both prose specs and verification grep patterns describing the same structural element, the two must use identical patterns. Second: when a brief's verification depends on user-keyboard work, the brief must enumerate three outcomes (pass / fail / couldn't-run-in-scope), not two.

## [5.15.0] - 2026-05-01

### Fixed

- **Update notifications work reliably on fresh sessions** (UserPromptSubmit floor sentinel — Group 6 GitHub release lookup) — The hook that checks GitHub for new SP releases was failing in two ways. First, a 2-second timeout: on a cold session (DNS not yet warm, TLS handshake fresh), the response consistently missed the window. Loosened to 8 seconds and dropped a redundant outer shell timeout. Second, the grep that pulled the version out of GitHub's response required no whitespace after the colon, but GitHub's pretty-printed JSON has a space (`"tag_name": "v5.14.0"`) — so even when curl succeeded, the version was never extracted. Pattern is now whitespace-tolerant. Fresh sessions now see real version status (`current` / `behind` / actual version string) instead of a silent "unreachable".

- **Rhythm enforcer no longer flags SP describing its own rule patterns** (Stop rhythm enforcer — rule 4 fence-write-coupling) — When SP walked through what its own hooks check (e.g., explaining "rule 4 catches `══ START 🟢 COPY ══` fences emitted without a handoff write"), the rule was triggering on the inline-code mention of the fence pattern in SP's prose, not on actual fence emission. The fence detection now strips inline code (single-backtick spans) before matching — same treatment the tool-availability rule already applied. False positive eliminated.

- **Update notifications now correctly handle unreachable releases on the SP body version-check** (`references/startup-checklist.md`) — The version check that fires during SP orientation had the same bugs the floor sentinel's Group 6 fix patched: a regex that didn't tolerate whitespace in GitHub's pretty-printed JSON, and an if/else that fell through to a misleading "UP_TO_DATE" when the regex returned empty. Now whitespace-tolerant, and explicitly emits "UNABLE_TO_CHECK" when GitHub is unreachable instead of falsely declaring the SP up to date.

- **Hooks no longer silently degrade on stock macOS** (SKILL.md frontmatter — UserPromptSubmit floor sentinel + Stop hook) — `timeout` is a GNU coreutils utility not present on macOS by default. Hook calls to `timeout 1 git ...` and `timeout 1 tail ...` were silently failing on stock macOS, causing the floor's git-state check to report `g5.status=clean` even with a dirty working tree. Now uses portable detection (`gtimeout` from Homebrew coreutils first, then `timeout` for Linux, then no-bound fallback if neither is available). Floor remains functional on stock macOS — bounded when the utility is present, unbounded but functional when it isn't.

- **Voice lint no longer false-fires on quoted lint-pattern descriptions** (`tests/lint-voice.sh` tool-availability rule) — When the lint scanned text containing italic-quoted or plain-quoted spans of the lint's own patterns (e.g., a CLAUDE.md section explaining "the voice lint catches *I can run* and *I have access to* patterns"), the rule was triggering on the quoted spans rather than on actual first-person tool-availability claims. Now strips italic-quoted and plain-quoted spans before matching.

- **Voice lint suppresses harmless integer-expression warnings** (in `tests/lint-voice.sh`) — A multi-line guard that compared file count to a threshold could produce shell warnings when the count was an empty string (split-empty edge case). Counts are now defaulted to zero before comparison; warnings eliminated; lint behavior unchanged.

### Added

- **Session facts now arrive automatically at session entry and on subcommand transitions** (UserPromptSubmit floor sentinel) — When you start a session or invoke an SP subcommand, a hook gathers a snapshot of the things SP needs to know to advise you well: which model is running, whether your project has a CLAUDE.md and any rule files, what's in your Serena memories, how many findings and parked backlog items exist, current git state, and whether the SP is up to date. The summary is injected into SP's context as a single line, so SP can't miss it. The hook deduplicates within a session — once SP has the snapshot for a given context (session, project, subcommand mode), repeat prompts skip the gather to avoid noise. This replaces the previous documentation-only approach where SP had to remember to check on its own. Mechanically enforces the startup floor that prose alone has been failing to ensure.

- **Per-turn rhythm enforcer** (Stop rhythm enforcer) — At the end of every assistant turn, a hook scans the response for four common drift patterns: questions buried in prose (instead of using the Ask-User-Question tool), missing identity-reset announcements after returning from a dispatched agent, first-person tool-availability claims without an actual tool call, and execution fences emitted without the expected handoff file write. When SP slips, the violation gets carried into the next turn's context as a one-line note — and SP self-corrects on the next prompt. Five rounds of adversarial review with Codex GPT-5.5 converged on this design.

- **The strategic partner now catches itself when it sees a problem and silently moves on** (Stop rhythm enforcer — new rule 5 floor-signal-acknowledgment) — When the startup floor reports any non-clean signal (project conventions missing, Serena memories missing, git tree dirty, version behind, routing matrix missing or stale), the model must either dispatch a remediation agent or explicitly acknowledge the signal in its response. Silent ignores are now logged and surfaced on the next turn — same shape as the existing rule 2 (identity-reset announcement after dispatch returns).

- **Documentation for what to do with each non-clean startup-floor signal** (SKILL.md Floor-Signal Handling section, plus new `references/floor-signal-handling.md`) — Clear guidance per signal field on whether the model auto-dispatches a remediation agent (e.g., routing matrix gets a background Opus 4.7 agent immediately), gates on user confirmation first (e.g., Serena onboarding for missing memory is heavier and asks first), or just acknowledges in orientation (e.g., dirty git state). Default model for any auto-remediation is Opus 4.7 — these are load-bearing decisions that propagate to every downstream session.

- **Standalone reference for the startup-floor protocol** (`references/floor.md`) — The full spec for what the seven floor groups check, the SP-FLOOR-COMPLETE summary line format, and the carve-out rules for lightweight subcommands now lives in its own reference file. Keeps the broader startup-orientation protocol (mode detection, agent fire-and-verify) separate from the per-prompt floor walk.

- **Closure floor — eight procedural groups walked at session end** (`commands/handoff.md` body, with new `references/closure-floor.md`) — When you invoke `/strategic-partner:handoff` (or signal session end), the SP now walks eight verification groups before writing the handoff file: staleness check on Serena memories, architecture drift scan, routing matrix verification, persistent memory ledger, project conventions ledger, working memory ledger (findings), workspace ledger (with active backlog management), and working tree closure. Each group runs a verification command, marks one of six states, and either takes hygiene actions automatically or asks you only when there's a genuine call to make. Silent skips are no longer possible.

- **Backlog hygiene as a first-class step in the closure walk** (Group 7a in `commands/handoff.md`) — The closure walk scans your `.backlog/` items, surfaces ones whose triggers have fired against current project state, asks about stale items (more than 30 days, no movement) via grouped summary + opt-in per-item review, and promotes unresolved findings from the session that have clear "park this" intent. Bulk-appending to backlog without surfacing what's filed is now an explicit anti-pattern.

- **Visual prescription for the closure walk** (`assets/templates/handoff-template.md` Closure Walk Status section + `commands/handoff.md` inline render + `references/closure-floor.md` Visual Output Specification) — Both the inline closure walk output and the persisted handoff file now render an 8-row Closure Walk Status table with row-anchor emojis (🧠/🏗️/🗺️/💾/📝/📋/📦/🔀) and state emojis (✅/🔄/🟡/⏸️/⏭️/🚨). Matches the init-mode orientation style users already expect. Visual consistency between init and closure orientation is now structurally prescribed.

- **Post-Handoff Verification gates the handoff close** (`commands/handoff.md` terminal step) — Four lightweight checks confirm the continuation prompt is present and intact, the SP invocation is in it, the findings file is surfaced, and `.gitignore` covers the four session-work directories. Catches silent gaps in the handoff contract before the session ends.

- **Backlog stewardship documented in handoff command + reference** — Both the `/strategic-partner:handoff` subcommand and `references/context-handoff.md` now describe the relationship between session findings (lightweight, automatic, session-scoped) and curated backlog items (project-scoped, with structured frontmatter and triggers). Findings carry forward to the next session by default; the handoff bridges them via per-item promotion AskUserQuestions only when scope is unclear.

- **Cross-references between subcommands** — Each of the seven SP subcommands (backlog, codex-feedback, copy-prompt, handoff, help, status, update) now points to related ones in a "See Also" section. Helps users discover the right tool for adjacent needs without running help every time.

- **Deferred Floor Signals section in handoff template** (`assets/templates/handoff-template.md`) — Startup-floor signals that were acknowledged during the session but not addressed (e.g., "version=behind, release ceremony scheduled for tomorrow") now carry forward as continuation context.

- **Identity-reset announcement is now a shared validator function** (`hooks/lib/validators.sh`) — The check that catches missing "Back in advisory mode" or "Dispatch complete" phrases after agent returns is now a shared library function used by the release-time transcript lint. The Stop hook (rule 2) keeps its inline implementation in v5.15.0 to avoid hook-frontmatter sourcing complexity; both detect the same patterns. Future release may converge them onto the shared library.

- **Release-time voice lint** (`tests/lint-voice.sh`, plus `tests/fixtures/v5.15.0/voice-lint/` and `tests/fixtures/v5.15.0/voice-transcript/`) — Mechanical scanner that catches the six jargon-loaded patterns (raw line refs, "Layer N" without gloss, "Direction N", "deliverable N", function-call notation in prose, incident IDs) in user-facing artifacts (CHANGELOG, README, commands/). Scope expanded to also scan SP's chat output in JSONL transcripts and the Codex pre-release review brief. Mechanical violations block release; warnings inform. Skip-block markers (`<!-- voice-lint:skip-start -->` / `<!-- voice-lint:skip-end -->`) bracket sections that legitimately use internal vocabulary (file trees, architecture details).

- **GitHub Release publishing script** (`.scripts/release-publish.sh`) — Wraps the `gh release create` invocation that previously lived inline in CLAUDE.md release ceremony Step 7. Pre-flight checks confirm `gh` is installed and authenticated, the tag exists locally, and CHANGELOG.md is in the current directory. Extracts the matching CHANGELOG entry as release notes automatically.

- **Past-incident archaeology consolidated** (`claudedocs/INCIDENTS.md`) — New file capturing detailed write-ups of past hook bugs and process incidents (currently covering the v5.4.0 → v5.4.1 `${CLAUDE_SKILL_DIR}` hook archaeology). Referenced from the Provisional Guards in CLAUDE.md so the rules and their evidence stay connected.

### Changed

- **Two new hook integrations alongside the existing source-edit guard** (SKILL.md frontmatter) — The strategic-partner skill now ships three hooks that work together: the existing PreToolUse guard that blocks SP from editing source files, plus the two new hooks above. Hook commands resolve their own install path via the stable command symlinks Claude Code creates at `~/.claude/commands/strategic-partner/`, with no dependency on environment variables that aren't reliably set in hook execution contexts.

- **CLAUDE.md project-rules file restructured to policy v1** (Where to Look + Provisional Guards + script extraction) — Top-level "Where to Look" table maps recurring questions to their source-of-truth files. New Provisional Guards section captures bug-driven rules with explicit source incident, scope, and 90-day review date (currently 4 guards: env-var hook hazard from the v5.4.1 incident, brief-author-must-re-read-locked-design lesson from today's closure-floor work, deferred-work-needs-durable-artifacts lesson from today's Codex re-review, and the existing voice-rule scope). Inline shell scripts extracted to `.scripts/release-publish.sh` for maintainability.

- **Voice rules generalized to user-facing scope** (CLAUDE.md § User-Facing Voice Rules) — Voice rules now apply to all user-facing artifacts (CHANGELOG entries, README user-facing prose, subcommand descriptions in `commands/`), not only CHANGELOG. Plain-English lead, define-before-use for project-internal vocabulary, no raw line refs, headline first. The release-time voice lint mechanically catches violations on the artifacts; the rule reads to a smart non-developer.

- **Layered-architecture references rewritten in plain English** (CHANGELOG and README) — Past CHANGELOG and README entries that referred to numbered enforcement layers without describing what each layer actually does have been rewritten to lead with the plain-English description. The numbered layer is parenthetical, not the headline.

- **Hooks integration reference aligned with 2026-04-30 audit findings** (`references/hooks-integration.md`) — Updated to reflect the empirical findings from the 2026-04-30 hook audit: PreToolUse, PostToolUse, UserPromptSubmit, and Stop fire reliably from skill frontmatter on Claude Code 2.1.123; matcher syntax must be literal tool name (not regex `.*` or pipe-alternation) for new registrations; hooks register on skill invocation, not file mtime; settings.json hot-swap is broken on this version.

- **Transcript-lint output shape change** (in `tests/lint-transcripts.sh`) — Output line changed from `across N file(s)` to `across N of M file(s)` to surface how many of the eligible files contained findings vs how many were scanned. Backward incompatibility with prior parsers is intentional — the new shape carries strictly more information. Downstream consumers should update to read both numbers.

### Not Shipped

- **SessionEnd evidence-capture hook** — The locked v5.15.0 design named SessionEnd as an optional last-gasp evidence capture (forensic snapshot to a durable file on session termination). Empirical verification of SessionEnd from skill frontmatter could not be completed within executor scope (the verification protocol requires multi-process orchestration: open separate terminal, invoke skill in fresh CC session, exit via `/exit`, repeat). Conservative default applied: SessionEnd hook NOT added to SKILL.md. Gap documented in `references/closure-floor.md` § "Why we do not ship a SessionEnd hook (as of v5.15.0)" with the manual protocol you can run to verify and ship in v5.16.0+. The handoff body's 8-group closure floor remains the canonical closure path; SessionEnd was always non-load-bearing.

- **Stop rule 6 (closure-walk-completeness)** — Originally scoped as an optional v5.15.0 component. Deferred to v5.16.0 because detection patterns require real `/handoff` transcripts in the new closure-floor format to inform robust pattern matching (none exist yet). Re-engagement triggered once ≥5 real handoff transcripts in the new format exist for empirical pattern matching.

- **Voice-quality compliance claim for SP chat** — v5.15.0 ships voice-related features (release-time voice lint extended to scan transcripts, identity-reset shared validator, dryness ban list documented in v5.14.0+) but does NOT claim that SP's chat across all sessions is jargon-free. Historical transcript lint runs find ~143 baseline voice violations in older sessions that predate v5.15.0 enforcement; new behavioral compliance is gradual, not an instant cutover. The features improve the situation; they don't certify it as solved.

## [5.14.0] - 2026-04-29

### Added

- **Typed Response Envelopes** — four-envelope response taxonomy (Conversational, Analytical, Packaged Prompt, Closure) maps response shape to appropriate formatting and visual density. Fence discriminator and Insight-block suppression rules included. Different envelopes get different formatting: low density for conversational acks, medium-high for analytical advisory turns, maximum for executor briefs, medium-high for closure handoffs.
- **Closure Evidence Ledger** — six-state ledger (RESOLVED / RESOLVED-AUTO / DECISION / SKIPPED-USER / SKIPPED-AUTO / DIRTY) replaces the prior 8-row Visual Closure Checklist. AUQ fires only on DECISION rows. Reconciles the SKILL.md hygiene-vs-decision boundary at category-vs-operation level.
- **Premise Challenge trigger #5** — fires when SP is acting on a derivative finding from a previous session (auto-fires on findings/backlog reads). Walk-through Scope Discipline subsection added separately.
- **V1–V7 regression fixtures + release-time transcript checker** — `tests/fixtures/v5.14.0/V1-V7-*.md` covering structural rule violations and friend-perspective jargon failures; `tests/lint-transcripts.sh` enforces AUQ-must-be-AUQ, tool-availability claims, and fence-write coupling rules against post-tag JSONL transcripts and SP-internal handoffs. RUNBOOK extended with manual-review procedure for fixture grading.
- **Voice-fix pass** — Define-Before-Use extended to all v5.14.0 SP-internal vocabulary (envelope names, ledger states, trigger numbers, the layered enforcement architecture); Plain-English Default rule renamed to Plain-English Whole-Response Gate with a concrete pre-send re-read mechanism named explicitly; eight-item dryness ban list added (covering jargon-laden tables, numbered-work-item framing in advisory chat, AUQ-as-ceremonial-padding, code-style spec framing in conversation, friend-perspective failures from V7 fixture, and more); warm partner tone made REQUIRED (folded into the existing rule, not a separate target); Anti-Sycophancy Protocol gains contrarian-theater symmetric failure mode; envelope-appropriate visual density principle named explicitly.

### Changed

- **CLAUDE.md release Step 2a** — hook verification expanded with matcher-scope tests, guard logic verification, runtime-input fuzzing, CHANGELOG cross-reference for env-var patterns, and the release-time transcript-checker backstop. Scoped to the source-edit guard (which predates v5.14.0) and the release-time transcript checker only — runtime enforcement was deferred.

### Fixed

- **`tests/lint-transcripts.sh:333` cwd encoding** — script was doing `tr '/' '-'` only; harness encoding also requires `tr '.' '-'`. Lint was silently scanning a non-existent path and finding zero transcripts. Fix mirrors the SKILL.md startup checklist's encoding pattern.

### Known Limitations (queued for v5.14.1)

- **Release-time lint over-flags meta-discussion** — `tests/lint-transcripts.sh` TOOL-CLAIM rule matches first-person tool-availability substrings inside transcript lines that *quote the lint's own patterns* or discuss its findings, rather than making live first-person tool-availability claims. Two known false positives surfaced in v5.14.0 development sessions during release verification. Fix queued for v5.14.1: add backtick-context awareness or sentence-context scoping to the TOOL-CLAIM matcher.
- **`tests/lint-transcripts.sh:597` integer expression warning** — script emits `0: integer expression expected` warnings during transcript scanning. Output is noisy but violation counts remain correct. Fix queued for v5.14.1.

### Deferred to v5.15.0

- **Runtime enforcement layer** (Stop hook + PostToolUse tracker) — prototyped during v5.14.0 development but pulled before release after a read-only mining of 105 JSONL transcripts (314 stop-hook-summary records inspected) found zero observable firings of the validator. Production observability was insufficient to verify the < 2% false-positive target the design called for. The source-edit guard (existing) and the release-time transcript checker are the only enforcement layers in v5.14.0. Runtime SP behavior is unchanged versus v5.13.0 except for the Theme A/C/D additions and the voice-fix improvements documented above. Runtime enforcement returns in v5.15.0+ once observability is in place.

## [5.13.0] - 2026-04-28

### Added

- **Plain-English Default section** (`SKILL.md`) — three subsections keeping SP's *voice* user-facing alongside Output Style's label translation. **Plain-English Opening Gate**: first 1–2 sentences of every response must be parseable by a non-technical reader; **Define-Before-Use**: project IDs (B-040, P1-002, §17, etc.) glossed on first mention, identifier as handle thereafter; **Housekeeping vs User Status**: SP-internal bookkeeping (memory writes, decision-log appends) no longer surfaces as user output.
- **Multi-Step Workflow Decomposition rule** (`SKILL.md` Core Advisory Loop) — when a path contains multiple discrete deliverables or transitions (write artifact → test → dispatch), pause and ask between each. Don't bundle "do task → return → next step → next step" into one response.
- **Token Efficiency Override** (`SKILL.md` Plain-English Default) — global `MODE_Token_Efficiency.md` style does NOT apply to SP user-facing prose unless explicitly invoked (`--uc`, `--ultracompressed`, or >75% context). Carves SP voice out of the global compression bias regardless of in-context examples.
- **Comprehension fixtures** (`tests/fixtures/v5.13.0/`) — five new fixtures (C1-C5) testing voice quality via reader-perspective Y/N criteria, complementing the existing label-pattern fixtures (F1-F5). C1: Plain-English Opening + glossing. C2: Housekeeping vs User Status. C3: Position + Greek + Visual Aids. C4: Multi-Step Workflow Decomposition. C5: Partner Profile General User Default. New `tests/RUNBOOK.md` section explains in-role grading procedure (reviewer reads SP's response as a non-technical user, answers Y/N criteria).

### Changed

- **Position First reframe** (`SKILL.md`) — Position line capped at one plain sentence readable in isolation. Rationale, trade-offs, and supporting detail go on subsequent lines, not crammed into the Position line itself.
- **Greek option labels banned** (`SKILL.md` Plain-English Default) — A/B/C only. The justification given for Greek labels (avoiding ordering implication) does not survive contact with users who don't read math; A/B/C is universally readable.
- **Visual aids default** (`SKILL.md` Communication and Consent) — replace previous "2-3 symbols max" rule with ASCII diagrams / tables / structured bullets as default for non-trivial responses (2+ options, flows, comparisons, status summaries). Emoji used as functional anchors (status, scanability), not decoration; no artificial symbol-count cap. Visual aids NOT used for trivial answers.
- **Bolding guidance** (`SKILL.md` Communication and Consent) — bolding is encouraged for key terms on first definition, the recommendation in a Position line, and decision points the user should focus on; not for whole sentences or whole paragraphs.
- **Partner-profile default** (`references/partner-protocols.md`) — default profile is now **General user / Product-minded user** (was: Engineer). Engineer/PM/Founder remain as profiles detected from user signals; the default — until signals emerge — leads with outcomes in plain English. Activation header and Profile Detection table updated to match.

## [5.12.0] - 2026-04-27

### Added
- **AUQ Materiality Gate** — SP now decides whether to surface a decision as an AskUserQuestion based on (a) whether it's your call and (b) whether it's actually material — meaning irreversible, high-cost, genuinely ambiguous, or explicitly flagged. Decisions resolved by canonical artifacts (CLAUDE.md rules, Serena memories, `.claude/rules/`) or owned by SP/executor terminate silently. AUQs fire at real partnership moments, not for SP-internal mechanics.
- **Attention Steward (Asking Pattern stage)** — A depth-modulation layer that tunes AUQ framing (must-ask vs. likely-ask vs. could-skip) based on signal strength. The right level of partnership friction for the situation.
- **Protocol-mandated AUQ whitelist** — 3 entries always emit AUQs regardless of gate outcome: Advisory Completion Gate, user-override checkpoint, and Codex review verdict synthesis. Whitelist extension requires version bump + CHANGELOG + regression fixture + Codex approval — preventing it from becoming a silent bypass.
- **Calendar-native routing prior** — When CLAUDE.md declares `project_type: calendar-native`, SP biases calendar-shaped decisions toward user-channel partnership AUQs (likely-ask depth) by default. The prior is overridden by user-authored standing rules in CLAUDE.md, Serena memories, or `.claude/rules/`.
- **F1-F5 regression fixtures** (`tests/fixtures/v5.12.0/`) — Five reproducible scenarios exercising each pipeline stage with PASS criteria. Includes `tests/RUNBOOK.md` for reviewer-driven manual validation.
- **Output Style mandate** (`references/pipeline/user-output-style.md`) — Canonical translation layer mapping internal pipeline vocabulary (Bootstrap/Router/Egress, channel names, materiality signal names, criteria labels) to plain English. Internal labels remain in SP's reasoning chains; user-visible output stays plain English.

### Changed
- **Premise Challenge format** — Trigger evaluation discipline preserved (still evaluates all 4 conditions internally on every task), but user-facing output uses plain prose ("You're starting with Redis — let me check the goal first") instead of `Triggers: #N fired` numbering.
- **Silent-log discipline** — When the SP resolves a decision without an AUQ, it no longer narrates the classification path in user-facing prose. Internal logging continues; user-facing surface stays focused on the substance.
- **Codex CLI references** — Updated from GPT-5.4 to GPT-5.5 following the 2026-04-23 release. README first-time-user flow patches applied per Codex review (`d733f40`).

### Fixed
- **SKILL.md pipeline heading** — Now matches the 4-stage diagram: `Bootstrap → Router → Egress → Asking Pattern`.
- **Pipeline frontmatter scope** (`references/pipeline/router.md`, `egress.md`) — Updated from "v5.12.0 minimal vertical slice (Brief 1)" to reflect the complete v5.12.0 specification.
- **`tests/RUNBOOK.md` init-prompt navigation** — Clarification that fresh SP orientation presents project-specific AUQs; reviewers should select "Type something" / freeform input to paste fixture transcripts cleanly.

## [5.11.0] - 2026-04-23

### Fixed
- **PreToolUse hook allow-list now matches relative paths** (hooks/guard-impl.sh + SKILL.md frontmatter inlined copy) — previously the case patterns required an absolute-path prefix (`*/.handoffs/*`), which blocked Write/Edit tool calls using relative paths against otherwise-allow-listed directories. The Fenced Prompt Emission Protocol (9c65b47) instructs writes to `.handoffs/last-prompts/[N].md` (relative) — the hook now correctly permits those. Added bare-form and relative-form patterns per allow-list entry. Bash and Serena guards were already correct; only Guard 1 needed the fix.
- **setup script now prunes stale symlinks** — previously setup only
  added missing symlinks but never removed orphaned ones. A stale
  `sync-skills.md` symlink (dating from pre-v5.2.1 removal of
  sync-skills) masked the self-repair count check and delayed
  discovery that `/strategic-partner:copy-prompt` had no registered
  symlink. Setup now prints `🧹 Removed stale symlink: {name}` when
  pruning.

### Added
- **/strategic-partner:copy-prompt subcommand** — copies a recently emitted fenced prompt to the OS clipboard, eliminating mouse-select friction on SP's primary handoff mechanism. Single-prompt direct copy; multi-prompt AskUserQuestion picker. Cross-OS clipboard via `pbcopy` / `xclip` / `xsel` / `clip.exe`.
- **Fenced Prompt Emission Protocol** (SKILL.md) — SP now writes each fenced prompt to `.handoffs/last-prompts/[N].md` at emission time so `copy-prompt` can retrieve them. Wipe-and-rewrite per response; no history.
- **Subcommand-Adding Briefs checklist** (references/prompt-crafting-guide.md)
  — new mandatory checklist for feature briefs that add subcommands:
  must include setup invocation, symlink verification, restart
  requirement note, and end-to-end invocation test as acceptance
  gates. Closes a process gap discovered during copy-prompt delivery.
- **Notify on Backgrounded Completion** (SKILL.md rule) — SP now fires a
  single PushNotification when any agent dispatched with
  `run_in_background: true` completes. Leads with verdict / headline
  finding (≤200 chars). Eliminates the walk-away dead zone during
  Codex reviews and other long-running dispatches. Fast Lane
  (foreground) dispatches explicitly do not notify.
- **README note on new subcommand discovery** — documents that users must restart their Claude Code session after running `./setup` (or `/strategic-partner:update`) to pick up new subcommands introduced by the release. Prevents confusion when upgrading to a version that adds commands like `/strategic-partner:copy-prompt`.

### Changed
- **Release process: mandatory Codex pre-release review** (CLAUDE.md Step 2b, commit 8829bb5) — codified as a gate equivalent to hook verification. Every non-docs-only push must pass `/strategic-partner:codex-feedback` Evidence Audit (Mode B) with the three mandatory questions (diff-matches-CHANGELOG, no-regressions-vs-prior-version, release-worthiness-per-user-segment) before the version bump is applied. Previously documented as optional dual-review guidance; now treated as mandatory release step.
- **Notify on Backgrounded Completion rule tightened** (SKILL.md) — replaced loose "≤200 chars" guidance with 4 explicit templates (`[<project>] SP — <event>: <detail>` shape), a 40–100 char target range, project-name derivation via `basename "$(git rev-parse --show-toplevel)"`, and an anti-pattern showing the failure mode (verbose comma-separated summary). Addresses user feedback that notifications were "messy and verbose" in real-world use.
- **Startup hygiene rules elevated to SKILL.md** — the no-echo-chain
  rule for git state commands (and similar compound commands) now lives
  in SKILL.md body with a concrete anti-example, not just
  `references/startup-checklist.md`. Reduces recurrence of the drift
  pattern where startup-checklist.md's rule was violated because the
  reference wasn't always loaded before orientation commands ran.
- **Serena memory reads clarified as on-demand default**
  (`references/startup-checklist.md`) — spec now documents deferred-
  read-on-demand as the approved default, with explicit always-read
  exceptions for `project_overview` and the most recent
  `decision_log` entries. Matches healthy session behavior and
  preserves token economy for long sessions.
- **Notify rule refined with "action, not process" principle** (SKILL.md) — new guidance at the top of the Message format templates block: lead with what the user needs to do, not what the tool did. Partial/timed-out dispatches report the effective outcome (e.g. "CONDITIONAL GO, 3 findings") rather than the process failure ("timed out at synthesis"). Includes a real anti-example from v5.11.0 prep.
- **commands/codex-feedback.md aligned with new Notify templates** — replaced the legacy "Codex review complete: {verdict} — {findings}" format with SKILL.md template #2 and resolved the foreground/background contradiction (was both; now consistently `run_in_background: true, mode: "acceptEdits"`).
- **SKILL.md Notify rule Step 3b no longer duplicates examples** — inline legacy examples removed in favor of a pointer to the authoritative "Message format (templates)" block in the same section.
- **copy-prompt now detects WSL and routes to clip.exe** (commands/copy-prompt.md) — WSL was previously treated as generic Linux (uname -s = Linux) and fell through to xclip/xsel, which are often absent on WSL. New detection: if `uname -r` contains `microsoft` or `WSL` (case-insensitive), use `clip.exe` via WSL interop.

## [5.10.0] - 2026-04-23

### Added
- **Fail-loud detection for native Windows Git Bash in `setup`** — On `$OSTYPE` matching `msys|cygwin|MINGW`, setup exits 2 with an experimental warning and WSL recommendation unless `SP_ALLOW_NATIVE_WINDOWS=1` is set. **Behavior change for existing Windows Git Bash users**: set `SP_ALLOW_NATIVE_WINDOWS=1` when running `bash setup` to acknowledge the experimental posture. Prevents silent degradation (symlinks → copies, broken install-dir resolution) on native Windows installs. WSL2 is the recommended Windows path.
- **Supported platforms matrix in README** — Clarifies macOS/Linux/WSL as fully supported; native Windows (Git Bash / MSYS2 / Cygwin) as experimental/best-effort; native cmd/PowerShell as unsupported.

### Fixed
- **H-3: Hook path normalization (conditional)** — Inline PreToolUse hook in SKILL.md frontmatter and `hooks/guard-impl.sh` normalize backslashes to forward-slashes ONLY for Windows-origin paths (drive-letter `C:\...` or UNC `\\...`). Unix paths, including those with literal backslashes in filenames, pass through unchanged. Preserves v5.9.0 semantics for Unix filenames; defensive against Windows `file_path` formats.
- **M-1: Python interpreter probe in `setup`** — Setup probes `python3` → `python` (with Python 3 version check) → `py -3` and uses the first that resolves. Allows `audit-permissions` to run on default Windows Python installations without requiring a `python3` alias.

### Changed
- **CLAUDE.md Step 2a hook verification extended** — Added items 4 (runtime-input fuzzing for hooks parsing JSON / env vars) and 5 (CHANGELOG cross-reference for `${CLAUDE_*}` env vars and path-resolution patterns) to the pre-release hook verification checklist. Codifies two preventive-action lessons from the v5.9.0 release review cycle. Originally landed as docs-only commit `8771c89` between v5.9.0 and this release.

### Context
Phase 1 of the Windows compatibility work from the 2026-04-22 cross-OS audit (`.handoffs/os-compatibility-audit-0422.md`, gitignored). Decision D (WSL-first + cheap hardening + fail-loud native detection) was selected via three-way synthesis (user + SP + Codex Decision Review on 2026-04-23). Pre-release Codex Evidence Audit + release-worthiness judgment returned CONDITIONAL GO on first pass; fixes applied (commits `a7b055b`, `b754636`); re-audit returned RELEASE-WORTHY + CONDITIONAL GO with conditions reduced to standard release-bump steps.

Deferred pending native-Windows demand evidence: H-1 (setup symlinks → file copies on Git Bash), H-2 (readlink -f cascade), GHA windows-latest CI matrix. Follow-up captured: `.backlog/hook-parser-fail-closed.md` — pre-existing fail-open behavior of the hook tool_name parser on pathological-whitespace JSON (not a regression from this release).

## [5.9.0] - 2026-04-21

### Removed
- **SessionStart hook from SKILL.md frontmatter** — Investigated and removed. The intent was to set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` adaptively based on detected model. Anthropic's hooks documentation (https://code.claude.com/docs/en/hooks) states skill-frontmatter hooks "are scoped to the component's lifecycle and only run when that component is active" — and SessionStart fires at Claude Code session start, before any skill activates. Empirical test confirmed the hook never fires: a trace-log line added to the hook, a fresh session invoked, and `/tmp/sp-hook-trace.log` never appeared. The architecture is incompatible with the event, not a bug that can be patched.
- **Standalone `hooks/session-start.sh`** — Deleted. Was reference documentation for the now-removed inline hook; serves no purpose without it.

### Fixed
- **False precedent claim in `references/hooks-integration.md`** — The documentation previously stated that "gstack and other well-established skills use the same pattern" for SKILL.md frontmatter hooks. Empirically false: an audit of installed skills at `~/.claude/skills/` found that only strategic-partner had a `SessionStart:` block in SKILL.md frontmatter. gstack, the cited precedent, has no `hooks:` section at all. Rewritten to document the architectural incompatibility correctly, citing Anthropic's hooks documentation.
- **Stale adaptive-PCT claims in `references/context-handoff.md` and `references/startup-checklist.md`** — Both files previously described SP as setting `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` adaptively. Rewritten to reflect the correct reality: autocompact threshold configuration is entirely user-owned; the SP's role is informational only.
- **PreCompact section in `references/hooks-integration.md`** — Previously coupled to the (removed) SessionStart section with "how they cooperate" language. Rewritten as a standalone description of a user-owned hook users may optionally configure in their own `settings.json`. No user-facing shell commands or configuration walkthroughs.

### Added
- **Context Advisory for 1M-context sessions** — `startup-checklist.md` Step 5 orientation now surfaces a one-time informational note on 1M-context sessions (Opus 4.7): autocompact defaults to ~95% (~950K), upstream Anthropic 1M autocompact bugs (#34332, #42375, #43989, #50204) cause inconsistent behavior above ~256K, and users can consider wrapping up or triggering handoff around that threshold for reliable retrieval. Pure advisory — no settings changed, no commands recommended.
- **Closure Checklist (SKILL.md § Continuity Stewardship)** — New 8-row pass/fail table the SP displays before writing any handoff, verifying every persistence layer: Serena memories, CLAUDE.md proposals, session findings, backlog promotions, `.prompts/`, `.scripts/`, git state, `.handoffs/` file. Items marked "action needed" get addressed via `AskUserQuestion` before the handoff is finalized. Makes closure completeness auditable.
- **Auto-dispatch on session-end signals (SKILL.md § Context Handoff)** — New paragraph formalizing that when the SP detects session-end signals (explicit wrap-up keywords, periodic-awareness signals, or `/strategic-partner:handoff` invocation), it proactively runs the Closure Checklist → addresses gaps via `AskUserQuestion` → invokes the handoff protocol → runs Post-Handoff Verification. The SP does not wait for a separate user request after a session-end signal fires. User can decline any individual item, but the flow is auto-dispatched.
- **Post-Handoff Verification (SKILL.md § Context Handoff)** — New subsection with grep-based verification commands run after the handoff file is written: confirms the continuation prompt format is present, the `/strategic-partner` invocation is included, findings file exists (or absence was explicitly acknowledged), and all four session-work dirs are in `.gitignore`. If any check fails, surfaces the gap via `AskUserQuestion`.

### Context

This release consolidates v5.7.0 (intentionally skipped), v5.8.0 (Claude 4.x compatibility refresh, reusable prompt block library, model-aware generation — see v5.8.0 entry below), and v5.9.0 (SessionStart investigation + strip + closure hardening) into a single public release. The latest prior public release was v5.6.0 (2026-04-07); users updating from v5.6.0 receive the full delta.

The SessionStart investigation was adversarially reviewed via the `/strategic-partner:codex-feedback` subcommand (GPT-5.4 at xhigh effort) in two focused passes. The Part A review covered the v5.7/v5.8 committed work (Opus 4.7 refresh, block library, target-model detection). The Part B review covered this v5.9.0 uncommitted work (strip + advisory + closure hardening). The strip + advisory decision was informed by authoritative sources: Anthropic's hooks and env-vars documentation, verified lifecycle constraints, empirical testing of the hook, and the user's explicit UX preference that user-facing SP docs contain no shell commands or settings walkthroughs.

### Known limitations documented in release

- Anthropic's open 1M autocompact bugs (#34332, #42375, #43989, #50204) remain outside SP's control — the release documents them as context, not workarounds
- The `setup` script does not currently prune orphan command symlinks; the self-repair check detects mismatches but relies on `setup` to converge (pre-existing limitation, tracked for future release)
- Context-window detection for Opus 4.6 / Sonnet 4.6 is plan-dependent (200K default, 1M on Max/Team/Enterprise) — not applicable to current shipping SP paths since SP's advisory surface is 1M-only

## [5.8.0] - 2026-04-20

### Added
- **Reusable Prompt Block Library** — 7 Anthropic-authored XML blocks (`<investigate_before_answering>`, `<avoid_over_engineering>`, `<subagent_usage>`, `<use_parallel_tool_calls>`, `<conservative_actions>`, `<scope_explicit>`, `<context_awareness>`) codified in `references/prompt-crafting-guide.md`. Each block has a trigger condition and target-model note.
- **Template default blocks** — `assets/templates/prompt-template.md` now includes `<investigate_before_answering>` and `<avoid_over_engineering>` by default so every crafted prompt inherits hallucination prevention and scope discipline.
- **Model-aware block selection** — SP detects the currently active Claude model at startup and picks blocks + effort recommendations per target model (Opus 4.7 / Sonnet 4.6 / Haiku 4.5). Target can be overridden per prompt.
- **Opus 4.7 patterns subsection** — `references/provider-guides/anthropic.md` now documents Opus 4.7-specific patterns with pointers to relevant blocks.
- **13th Post-Craft Verification check** — "Relevant blocks included for target model/task." Ensures block coverage alongside existing quality gates.
- **Haiku 4.5 model ID** — `claude-haiku-4-5-20251001` now documented in the routing matrix.
- **Visible Post-Craft Checklist directive** — The checklist must be shown as a pass/fail table before the fence block, not inlined as invisible reasoning (Opus 4.7's "reasons more, tools less" tendency created audit risk). Fixed placement: checklist → 🎯 Routing blockquote → fenced prompt(s).
- **Mandatory git verification after dispatch** — `git log --oneline -3` and `git diff HEAD~1` are now explicitly mandatory Bash calls, not optional or inferred from commit messages.
- **`/context` sanity check note** — Startup flags known autocompact-on-1M-context bugs (anthropics/claude-code#34332, #18843, #27189) and recommends `/context` verification on Opus 4.7 sessions.

### Changed
- **Opus 4.6 → Opus 4.7 references** — Updated across `references/orchestration-playbook.md`, `references/prompt-crafting-guide.md`, `references/provider-guides/anthropic.md`, `assets/templates/prompt-template.md`, and `SKILL.md`. Sonnet 4.6 references preserved (still current GA).
- **Removed obsolete `/effort high` startup recommendation** — `/effort xhigh` is now Claude Code's default on Opus 4.7 plans, and Sonnet 4.6 defaults to `high` at the API level. Explicit recommendation was redundant.
- **Relabeled "Claude 3.x workarounds" → "pre-4.x holdovers"** — Anti-sycophancy rule is still relevant (more so on 4.7's direct tone); only the version label was outdated.
- **Renamed "Self-check verification blocks" → "Executor verification contract"** — Reflects what `<verification>` actually is (testable commands for the executor), not model self-reflection scaffolding.

### Demoted (not removed)
- **`<orchestration>` tag — mandatory → conditional** — Required only when subtasks are clearly independent, user explicitly requested multi-agent decomposition, or latency-hiding is primary goal. Opus 4.7's "fewer subagents by default" and "more literal instruction following" invalidated the always-on mandate.
- **Parallelization check — hard gate → thinking tool** — The 4-question check stays as a design-time thinking aid, but prompts no longer FAIL solely for lacking an `<orchestration>` section.

### Fixed
- **Orchestration-playbook consistency** — `references/orchestration-playbook.md` still described the parallelization check as "🔴 mandatory" after the v5.8.0 demotion. Now aligned with the thinking-tool framing and conditional `<orchestration>` criteria used in `prompt-crafting-guide.md` and the Anthropic provider guide.
- **Block-placement guidance** — `references/prompt-crafting-guide.md` "How to use this library" incorrectly pointed block authors to a nonexistent `<task>` section. Updated to match `<instructions>` (the actual template section) with BEFORE-instructions placement.
- **Visible-checklist placement rule** — Resolved contradiction between SKILL.md's "visible pass/fail table in the response" mandate and the crafting guide's "nothing outside the fences" rule. Explicit pre-fence order is now specified in both files: checklist table → 🎯 Routing blockquote → fenced prompt(s).

### Context
This release was produced via full audit (24 findings in `.handoffs/opus47-audit-0420.md`) + three-way synthesis (SP + Codex GPT-5.4 adversarial review + Anthropic primary-source research) in response to the Claude Opus 4.7 release on 2026-04-16.

The v5.7.0 tag was skipped intentionally — mid-audit the user correctly flagged that SP's crafting guide had drifted from Anthropic's published 4.x prompting guidance; expanding scope to address that gap produced v5.8.0. A final Codex adversarial review before tagging caught three internal inconsistencies that were fixed in the same release window (see Fixed section).

Kept intact: all identity gates (Position mandate, AskUserQuestion protocol, Premise Challenge, Advisory Completion Gate, cognitive patterns) and belt-and-suspenders rules (explicit model+mode on agent spawns). These are SP's product, not model compensation.

## [5.6.0] - 2026-04-08

### Added
- **Backlog stewardship** — two-layer system: lightweight session findings (.handoffs/findings-*.md) with automatic capture, and curated backlog (.backlog/*.md) with trigger-based surfacing at startup
- **Backlog subcommand** — `/strategic-partner:backlog` for reviewing parked items with type-grouped display and trigger evaluation
- **Bug awareness in backlog** — backlog items support `type: bug` with severity field and bug summary line in display

### Changed
- **Auto-capture redesign** — replaced language-detection heuristic with unconditional capture-first, triage-at-boundaries approach (Codex-recommended)
- **XML structural tags** — reference loading uses `<reference_files>`, `<gate>`, and `<load_reference>` tags for machine-parseability
- **Checkpoint 1 reconciled** — direct requests trigger "craft prompt"; feedback-shaped input routes to Immediate Reframe Rule

### Fixed
- **Inline XML prompts** — Anthropic-format prompts wrapped in backtick code fence to prevent Claude Code's markdown renderer from stripping XML tags
- **Codex CLI hangs** — `codex exec` now disables MCP servers (`-c 'mcp_servers={}'`) to prevent startup stalls
- **Cross-reference consistency** — 5 gaps resolved via Codex pre-release audit: allowed-paths prose, subcommand table, findings-to-backlog directive, wrapper terminology, Checkpoint 1 tension
- **Stale cadence reference** — removed "every 5th exchange" from context-handoff.md
- **Fence marker verification** — Post-Craft check #10 now catches missing 🟢/🛑 markers

## [5.5.0] - 2026-04-01

### Added
- **Permission audit** — `setup --audit-permissions` checks `~/.claude/settings.json` for SP-required permissions (3 mandatory, 9 recommended, defaultMode), detects redundancies, recommends deny entries based on tech stack scanning, and offers to apply with backup. Supports `--dry-run` and `--verbose` flags
- **Quick permission check** — setup now checks for Serena and Context7 permissions after command registration, with a one-line 💡 hint if missing

### Changed
- **Emoji severity hierarchy** — standardized three-tier system across all SP files: ❌ (error/failure), ⚠️ (warning/degraded), 💡 (suggestion/informational)
- **[✅ SAFE]/[⚠️ RISK] labels** — recommendation labels now include emoji for visual consistency. Updated in definitions, examples, and all prose references
- **WebFetch(*)/WebSearch(*) documentation** — updated to starred form in orchestration-playbook and README for audit consistency

### Fixed
- **skillshare → skills CLI** — replaced all `skillshare` references with Vercel `skills` CLI. Removed broken `npx skillshare install` from README
- **Stale hook reference** — SKILL.md guidance corrected to "inlined in SKILL.md frontmatter"
- **Hook verification in release process** — CLAUDE.md gains Step 2a for testing matcher scope and guard logic before release
- **Docs-only push exception** — CLAUDE.md release process allows docs-only pushes to skip version bump and GitHub Release

## [5.4.1] - 2026-03-31

### Fixed
- **Hook fires on every tool call** — matcher `""` changed to targeted `Edit|Write|MultiEdit|NotebookEdit|Bash|mcp__plugin_serena_serena__`. Hook no longer executes on Read, Glob, Grep, Skill, and other non-guarded tools.
- **Hook errors on non-default install paths** — guard logic inlined directly in SKILL.md frontmatter. Eliminates dependency on external `hooks/guard-impl.sh` path resolution. Works on any install path (skillshare default, git clone, alternate directories). `CLAUDE_SKILL_DIR` was not a real Claude Code variable; fallback path was fragile for distributed users.

## [5.4.0] - 2026-03-30

### Added
- **PreToolUse structural enforcement** — `hooks/guard-impl.sh` blocks Edit, Write, MultiEdit, and Bash file mutations on source files via harness-enforced exit code 2. Allowed paths: `.prompts/`, `.handoffs/`, `.scripts/`, `CLAUDE.md`, `CHANGELOG.md`, `README.md`, `SKILL.md`, `.claude/`, `.gitignore`
- **Immediate Reframe Rule** — when user provides implementation-shaped feedback, SP's first response is to craft a prompt or ask a clarifying question, not investigate the code
- **Guard 3 (Serena writes)** — blocks Serena code-editing tools (`replace_content`, `replace_symbol_body`, etc.) on source files while preserving full memory layer access
- **Debug mode** — set `SP_HOOK_DEBUG=1` to log hook decisions to `/tmp/sp-hook-debug.log`

### Changed
- **Override rewritten** — "implement yourself" → "dispatch to executor"; resolves the fundamental contradiction between "never implement" and "just do it yourself on small tasks"
- **Checkpoint expansion** — Checkpoint 1 (REQUEST) now catches implicit implementation triggers (bug reports, visual complaints, "looks wrong")

### Fixed
- **Hook tool name extraction** — was reading `CLAUDE_TOOL_NAME` env var (not set by Claude Code); now parses `tool_name` from stdin JSON payload
- **Hook path resolution** — `${CLAUDE_SKILL_DIR}` fallback added for environments where the variable isn't expanded

### Removed
- **"Trivial — Just run [X] directly" branch** — was the biggest identity escape hatch; all tasks now go through prompt crafting or agent dispatch
- **Self-waiver in prompt-crafting-guide** — "proceed directly" option replaced with prompt-only paths

## [5.3.0] - 2026-03-30

### Changed
- **Advisory identity restored as dominant force** — SKILL.md restructured from 1,139 lines to 762 lines with advisory-first section ordering; first 4 sections (38%) are purely advisory with no delivery mechanics
- **"Your default is advisory-only" → "You are not allowed to implement"** — boundary language changed from defeasible preference to present-tense prohibition
- **Primary deliverable redefined** — from "prompt crafting" to "decision-ready advisory brief"; prompts are secondary packaging
- **Cognitive patterns wired to decision points** — 14 patterns now have mandatory triggers and actions at specific decision points (was a decorative reference table); Reversibility Spectrum removed (duplicated One-Way Doors)
- **Fast Lane extracted to reference file** — mechanics moved to `references/fast-lane.md`; core SKILL.md keeps a 17-line stub that emphasizes "Dispatch, Not Identity"

### Added
- **Advisory Completion Gate** — hard gate with 5-point checklist (problem framed, alternatives explored, trade-offs surfaced, user confirmed, done defined) that must pass before ANY prompt, dispatch, or script is crafted
- **Advisory Reset After User Execution** — explicit identity recovery when user returns from implementation: "Back in advisory mode. I am reviewing the result, not continuing the build."
- **Post-Dispatch Identity Recovery** — explicit snap-back after Fast Lane agent returns: "Dispatch complete. I am back in strategic-partner mode."
- **Mission statement** — "Your mission is to slow the process down just enough to get it right"
- **`references/fast-lane.md`** — new reference file containing simplicity scoring, consent flows, dispatch protocol, and agent definition guidance
- **Advisory loop diagram** — Think → Challenge → Recommend → [Gate] → Package → Execute → Reset → Think

### Fixed
- **"brainstorm" appeared 0 times** in v5.2.1 SKILL.md — now appears 6 times with advisory vocabulary throughout
- **Implementation creep** — users reported SP jumping from brainstorming to prompt crafting mid-conversation and directly editing source code; the 3 new gates structurally prevent both failure modes
- **Persistence Router** — restored full 3-column table with Why column and specific Serena memory names
- **Anti-sycophancy gap** — restored missing banned phrase "I can see why you'd think that"

### Removed
- **~415 lines of implementation mechanics** from core SKILL.md (relocated to reference files or removed as dead code)
- **Reversibility Spectrum** cognitive pattern (duplicated One-Way Doors)
- **Partner Adaptation** subsection (soft/dead — no enforcement mechanism)
- **Non-enforceable cadence triggers** ("after EVERY exchange", "after every 5th exchange")

## [5.2.1] - 2026-03-30

### Fixed
- **AskUserQuestion compliance** — fixed self-contradicting prose question examples in Ask-Before-Act section, extended Response Completion Gate to cover mid-response questions, added open-ended AUQ pattern for clarification questions, added "user save request" persistence trigger for backlog/note/park directives
- **Version check reliability** — replaced background Agent E (WebFetch, intermittently blocked by sandbox permissions) with inline curl check that always works

### Removed
- **Agent E (background version check)** — replaced by inline curl in Step 1.5; agent overhead added fragility with no benefit for a single API call
- **`/strategic-partner:sync-skills` subcommand** — redundant after dynamic routing architecture replaced the static skill matrix

## [5.2.0] - 2026-03-30

### Changed
- **Dynamic routing architecture** — removed ~200 lines of hardcoded author-local skill mappings from routing matrix; replaced with dynamic discovery protocol that builds from each user's actual installed skills and agents at startup
- **Two-step consent model** — Fast Lane now uses Solution Ambiguity Gate: when Q1/Q2/Q3 indicate open solutions, SP presents solution options before delivery options; when solution is unambiguous, mandatory Position statement shows WHAT before asking HOW
- **Agent D return format** — now includes errors array and routing_status field for transparent partial-failure handling; orientation uses user-friendly language instead of "base + delta" jargon
- **Continuation re-confirmation** — when dispatch is planned in a continuation session, Q1 is re-confirmed via AskUserQuestion (handoff provides context, not consent)

### Added
- **Post-dispatch acceptance gate** — mandatory AskUserQuestion after both user-run and agent-run prompts before proposing next task
- **Solution Ambiguity Gate** — uses existing simplicity scoring Q1/Q2/Q3 to determine one-step vs two-step consent, proportional to solution openness
- **Fallback chain** for routing — Serena cached matrix → system context + task categories → built-in agents only

### Fixed
- **Orientation clarity** — removed internal "base/delta" jargon; environment summary now shows actionable status (built/cached/fallback)
- **Agent detection** — partial scan failures now reported with specific error context instead of silently returning 0

## [5.1.0] - 2026-03-29

### Added
- **`/strategic-partner:codex-feedback` subcommand** — Cross-model adversarial review via Codex CLI (GPT-5.4). Two modes: Decision Review (attack assumptions on a curated brief) and Evidence Audit (repo-aware claim verification with file:line citations). Includes trigger gate, anti-injection rule, three-way synthesis (User | SP | Codex), and 6-scenario failure handling
- **Codex CLI detection** — silent inline check at startup (Step 1.5); feature surfaces only when Codex is installed, never mentioned in orientation

### Fixed
- **Implementation Boundary renamed** — "Firewall" → "Boundary" for honest framing; boundary allows documented single-use override
- **AskUserQuestion contradiction resolved** — fresh sessions MUST use AskUserQuestion for Q1/Q4; continuation sessions verify from handoff
- **Auditable artifact markers** — mandatory grep-able format markers (`**Triggers:**`, `**Position:**`, `**Simplicity:**`) make protocol compliance verifiable in session transcripts
- **Mandatory simplicity scoring gate** — score marker required BEFORE presenting delivery options; delivery gate enforced by threshold (score ≤2/5 blocks dispatch)
- **Stop hook documentation cleaned** — removed false safety claims; replaced with "no automated backstop" in handoff reference
- **NOT-in-scope full specification** — definition, when-required rules, good/bad examples, identification guide added to prompt-crafting-guide.md

### Changed
- **README rewritten** — driven by cross-model evidence audit (Codex CLI / GPT-5.4); added executive summary, "Who is this for" section, accessible context dilution framing, all v5.0.0 features represented, file tree and subcommands updated for 6 commands

## [5.0.0] - 2026-03-29

### Changed (Breaking)
- **Delivery model restructured** — Agent C (dashboard fix, gitignore check, command symlinks), Step 1.5 (permission pre-flight), and `.claude/settings.json` hooks all replaced by an idempotent `setup` script following gstack's proven pattern
- **Memory Architecture restored** — unified 4-layer stewardship (CLAUDE.md, .claude/rules/, auto-memory, Serena) replaces the 2-layer system (Serena + CLAUDE.md only) that regressed during v3.4.0-v4.0.0

### Added
- **`setup` script** — idempotent bash script for command registration; runs on install and after every update; self-locating, portable across macOS/Linux
- **Count-based self-repair** — startup checks command count vs symlink count; auto-runs setup if mismatch detected (covers first install, updates, and removed commands)
- **Persistence Router** — decision table routing information to the correct layer (CLAUDE.md for rules, .claude/rules/ for path-scoped rules, auto-memory for user prefs, Serena for project knowledge)
- **Memory health checks** — startup verifies auto-memory enabled, .claude/rules/ scanned, CLAUDE.md size checked
- **.claude/rules/ protocol** — path-scoped rules with `paths:` frontmatter, migration guidance from bloated CLAUDE.md
- **Auto-memory awareness** — hands-off protocol; verify enabled, understand types, route correctly
- **Premise challenge triggers** — 4 trigger conditions on every task request; forced evaluation
- **Forced alternatives** — 3-path presentation (Minimal/Recommended/Lateral) before routing
- **NOT-in-scope sections** — explicit exclusions in multi-file prompts
- **[✅ SAFE]/[⚠️ RISK] labels** — confidence signals on non-trivial recommendations
- **Position-first rule** — state position before presenting options
- **Decision log enforcement** — auto-log after every confirmed AskUserQuestion

### Removed
- **Agent C** — replaced by `setup` script (install-time) + self-repair (startup)
- **Step 1.5 permission pre-flight** — no longer needed without Agent C
- **`.claude/settings.json` hooks** — Stop hook fires every turn, wrong mechanism for session-end detection
- **`hooks/check-handoff.sh`** — script deleted; behavioral protocol handles session-end detection

### Fixed
- **Graceful degradation** — removed vague "auto-memory files for persistence" promise; replaced with honest description of what each layer can/cannot replace
- **Stale Stop hook reference** — removed from handoff section after hook deletion

## [4.8.1] - 2026-03-26

### Fixed
- **Pre-Craft Discovery Protocol** — 4 mandatory questions (goal, prior work, constraints, definition of done) before routing to a skill; closes "asking the right questions" promise gap
- **Decision Log Protocol** — structured `decision_log` Serena memory format with entry schema, when-to-log/read rules, and archive strategy; closes "tracking decisions across sessions" promise gap
- **Prompt crafting pipeline updated** — Discovery Protocol added as Step 0 before Routing Decision Tree

## [4.8.0] - 2026-03-26

### Added
- **Anti-sycophancy protocol** — Communication Style expanded with 8 banned phrases, direct replacement alternatives table, 5 pushback patterns, position mandate, and partner adaptation rules
- **Cognitive patterns library** — new reference file (`references/cognitive-patterns.md`) with 15 named thinking heuristics across 4 categories: Decision Classification, Architecture Thinking, Strategic Thinking, Advisory-Specific
- **Two-level README review gate** — release process now distinguishes factual accuracy checks (every release) from first-time user tests (every 3rd minor or new user-facing features)

### Changed
- **README restructured** — information flow redesigned for first-time users (Problem → How → Show Me → Quick Start); core insight moved from buried in the middle to near the top; two-session model explained once instead of four times; file tree collapsed to `<details>` block; 268 lines, down from 382

## [4.7.0] - 2026-03-26

### Added
- **Permission pre-flight** — new startup step (1.5) detects missing permissions (`WebFetch *`, `Bash(ln -s *)`, `Bash(mkdir -p *)`) and proposes adding them via AskUserQuestion; one-time fix that persists across all sessions
- **Session-end mandatory handoff** — SP detects session-end signals ("done", "wrapping up", etc.) and triggers the full handoff protocol instead of summarizing and exiting; Stop hook serves as backstop

### Fixed
- **Agent C mode mismatch** — changed from `mode: "auto"` to `mode: "acceptEdits"`; uses Edit/Write for file modifications, Bash only for symlinks (covered by pre-flight permissions)
- **Agent E tool selection** — explicitly uses WebFetch for HTTP requests instead of Bash/curl; covered by pre-flight WebFetch permission
- **Orchestration playbook mode guidance** — mode decision tree now distinguishes read-only agents (`auto`) from config-writing agents (`acceptEdits`)

## [4.6.0] - 2026-03-26

### Added
- **Simplicity scoring model** — Fast Lane now uses a 5-question negative-test assessment instead of rigid file-count criteria; file count becomes a signal, not a gate
- **Agent definition file awareness** — SP checks for `.claude/agents/` definitions before dispatch, recommends creating them for recurring patterns; comparison table added to orchestration playbook
- **Provider-specific prompt format guides** — dedicated guides for Claude (XML), OpenAI (GPT-5.4), and Gemini (Markdown) extracted to `references/provider-guides/`
- **Copy-safe formatting rules** — inline prompts use XML + plain text only to survive markdown rendering on copy-paste
- **Delivery routing in pre-craft** — format selection and delivery routing integrated as mandatory pre-craft steps

### Changed
- **Fast Lane criteria** — replaced "≤2 files, single deliverable, mechanical, unambiguous, reversible" with simplicity scoring (5/5 = dispatch, ≤2/5 = full prompt)
- **Prompt-crafting guide refactored** — provider-specific format details extracted to dedicated guides, reducing main guide ~160 lines

### Fixed
- **README file tree** — added `references/provider-guides/` directory
- **README "What this is not"** — corrected "doesn't spawn agents" claim (Fast Lane dispatches agents)

## [4.5.0] - 2026-03-24

### Added
- **Fast Lane protocol** — three-lane delivery model for implementation prompts: small, mechanical tasks (≤2 files, single deliverable, unambiguous) can be dispatched to a sub-agent directly instead of requiring a copy-paste cycle to a new session
- **Delivery Decision step** in prompt-crafting-guide — gates whether a crafted prompt goes to agent dispatch, ══ fences, or direct user action
- **Post-Dispatch Review** — verification protocol for agent-dispatched tasks (git log, diff review, lesson extraction) with failure handling
- **"Fast lane for small tasks"** subsection in README explaining the three-lane model

### Fixed
- **Implementation Firewall** — "Two checkpoints" corrected to "Three checkpoints" (Checkpoint 3 existed but count was never updated)

### Changed
- **Implementation Firewall flow diagram** — now shows three lanes (LARGE → manual session, SMALL → agent dispatch, TRIVIAL → direct action) instead of single path
- **"No exception" text** — updated from absolute prohibition to reference the Fast Lane for qualifying tasks

## [4.4.1] - 2026-03-24

### Fixed
- **Hardcoded Serena config path** — replaced `~/.serena/serena_config.yml` with dynamic discovery chain (get_current_config → ~/.serena/ → ~/.config/serena/) in SKILL.md, startup-checklist, and orchestration-playbook
- **Hardcoded skill directory paths** — commands/handoff.md, sync-skills.md, and update.md now use `{skill-dir}` notation instead of `~/.claude/skills/strategic-partner/`
- **Hardcoded hooks config path** — hooks-integration.md updated from legacy `~/.claude/hooks.json` to `~/.claude/settings.json` with `$CLAUDE_CONFIG_DIR` fallback
- **Hardcoded companion script path** — uses `$SKILLSHARE_SCRIPTS_DIR` env var with fallback
- **README manual install** — now shows multiple location options instead of single hardcoded path

### Changed
- **Serena unavailable → firm recommendation** — graceful degradation no longer silently "notes in orientation"; now displays a firm, one-time recommendation explaining concrete capability losses (cross-session memory, semantic navigation, codebase structure model) with install link
- **Agent C dashboard check** — now uses Serena config discovery chain and reports `serena_not_detected` status when no config found

## [4.4.0] - 2026-03-24

### Added
- **Version check agent (Agent E)** — background startup check fetches latest GitHub release; shows one-liner in orientation if outdated
- **`/strategic-partner:update` subcommand** — checks version, shows changelog, detects install method (skillshare or git), runs update with confirmation
- **Commands distribution** — subcommand files now bundled in `commands/` directory and auto-linked to `~/.claude/commands/` via Agent C on first run
- **GitHub Releases step** — added step 7 to release process in CLAUDE.md; required for version-check system
- **`repo:` frontmatter field** — SKILL.md now declares the GitHub repo for version checks
- **"Staying updated" section in README** — documents automatic checks, update command, and GitHub Watch

### Changed
- **Agent C expanded** — now performs 3 checks: dashboard fix, gitignore, and commands symlink verification
- **Self-delegation list updated** — version check and commands check added to "always delegate" tier
- **Startup checklist** — Steps 2, 4, and 5 updated for Agent E integration

## [4.3.2] - 2026-03-24

### Added
- **Pattern E: Diagnostic Audit** — orchestration playbook now includes a formal audit protocol with 5-step intent-check gate (Chesterton's Fence principle) preventing ~30% false positive rate at Important+ severity

### Fixed
- **Cross-reference step number** — context-handoff.md referenced "Step 3" for env var setup; corrected to "Step 1"
- **Stale checklist count** — prompt-crafting-guide anti-patterns referenced "8-item checklist"; corrected to 9-item (format selection added in v4.2.0)
- **README loading description** — added "at startup" to reference file loading description (previously excluded startup-checklist from on-demand list)
- **/insights fallback alignment** — SKILL.md "no exceptions" softened to include manual fallback when /insights unavailable, aligning with existing template guidance

### Changed
- **Mode cross-reference** — skill-routing-matrix agent table now links to orchestration playbook's Agent Permission Modes section

## [4.3.1] - 2026-03-24

### Added
- **Failing prompt example** — prompt-crafting guide now includes Example 3 showing common mistakes with a failures table mapping each issue to the post-craft verification checklist
- **Rollback strategy section** — prompt template now includes a commented-out `<rollback>` section for changes that could regress existing behavior
- **Hybrid profile examples** — partner-protocols now includes a table of hybrid user profiles (Engineer-PM, Technical Founder, PM who codes)

### Fixed
- **README "Why two sessions?" deduplication** — collapsed redundant conclusion paragraphs into a single sentence; intro + table + one-liner now covers the argument without repetition
- **CHANGELOG "Checkpoint 3" phrasing** — renamed to "user override" for clarity without needing to read SKILL.md
- **README stale line count** — second reference to SKILL.md line count updated from ~440 to ~540

### Changed
- **Internal pattern separation** — orchestration playbook Patterns A-D now have an explicit "Internal patterns only" callout preventing confusion with Patterns 1-4 used in crafted prompts

## [4.3.0] - 2026-03-24

### Added
- **Agent permission mode guidance** — new "Agent Permission Modes" section in orchestration playbook with mode reference table, background agent warning, and decision tree for mode selection
- **Mode parameter on all agent patterns** — Patterns 1-4 (implementation) and Patterns A-D (self-delegation) now specify mode alongside model
- **Troubleshooting: sub-agent permission failures** — README now covers the scenario where background agents fail silently due to missing mode parameter

### Changed
- **Post-craft verification expanded** — item 5 now requires both explicit model AND mode on every agent spawn
- **Anti-patterns expanded** — both orchestration playbook and prompt-crafting guide now flag missing mode specification

## [4.2.0] - 2026-03-23

### Added
- **GPT-5.4 format support** — prompt-crafting guide now supports three target formats (Claude XML, GPT-5.4, Gemini) with a 3-target format decision tree
- **Agent failure and timeout handling** — orchestration playbook now covers failure modes, retry logic, and fallback paths for spawned agents
- **Serena memory updates field** — handoff template now includes a dedicated section for tracking which Serena memories need updating

### Fixed
- **Explicit routing matrix file paths** — prompt-crafting and orchestration guides now reference skill-routing-matrix.md by exact path
- **Environment-specific skill counts removed** — routing matrix and README no longer hardcode skill counts that vary by installation
- **Precision variance note** — companion-script-spec heuristics KB estimates now document ±20% variance
- **Local audit path removed** — implementation-decisions.md no longer references a local-only file path

### Changed
- **README adaptation claim softened** — removed unverifiable behavioral claims
- **README troubleshooting section added** — covers Serena, skills, hooks, and executor failure scenarios
- **SKILL.md line count updated** — README file tree description updated from ~440 to ~540 lines

## [4.1.0] - 2026-03-23

### Changed
- **Context management: removed strategic compact tier** — the SP no longer suggests `/compact`; context pressure is now managed exclusively via structured handoffs. Two-tier thresholds (🟢 0-60% normal, 🟡 60-70% monitor, 🔴 70%+ handoff) replace the previous three-tier system. Rationale: compaction produces lossy summaries that contradict the fresh-session philosophy
- **Routing matrix expanded from ~30 to ~87 entries** — 11 new categories added (Project Lifecycle, UI/Frontend, Workflow & Process, Git & DevOps, Content & Publishing, Configuration & Meta, Behavioral Modes, Recurring & Scheduled Tasks, Personal Automation). Base coverage increased from ~37% to ~95%
- **Agent subagent_types visually distinguished** — all Agent entries now prefixed with ⚙️ to prevent confusion with slash commands

### Fixed
- **Hook config examples labeled as signal stubs** — SessionStart and Stop hook configs now clearly marked as intentional signal stubs, not broken/incomplete hooks
- **Companion-script thresholds documented** — explicit 5% guard band delta between companion script and SP self-assessment thresholds now documented
- **PreCompact framing** — reframed as "system compacts regardless, SP's job is done" across all reference files

### Added
- **F6 reversal annotation** — v4.0-implementation-decisions.md F6 section annotated to note the compact tier was later removed
- **Gitignore entries** — `.handoffs/`, `.prompts/`, `.scripts/` added to .gitignore
- **README review step in release process** — project CLAUDE.md now mandates README content review during version bumps

## [4.0.1] - 2026-03-23

### Fixed
- **Saved-prompt launcher format** — added `══` fenced prompt launcher for saved `.prompts/` files, matching the inline prompt display convention
- **Implementation firewall user override** — one-time user override ("just do it") with mandatory reset to advisory mode after the single action completes
- **Handoff continuation prompt display** — enforced fenced display rules in SKILL.md core so they survive context pressure (not just in reference files)
- **Ask-before-act two-tier model** — hygiene ops (git, gitignore) execute autonomously, decision ops (Serena, CLAUDE.md, handoffs) always ask first
- **Bash echo-separator ban** — chaining commands with `echo "---"` separators triggers Claude Code's "quoted characters in flag names" safety warning; elevated to global "You always" rule requiring separate parallel Bash calls

### Added
- **Project CLAUDE.md** — release process definition ensuring version bump, changelog entry, and git tag on every push to remote

## [4.0.0] - 2026-03-16

### Post-Release Fixes (same day)

- **Routing matrix build step restored to startup** — v3.5.3 had an explicit startup checklist item ("Skill + MCP inventory → routing matrix built → stored in Serena") that was lost during the v4.0 restructure. Added Step 5.5 to `startup-checklist.md` with full delta-update procedure: load base matrix → scan system context skills → build delta entries for new skills → merge with custom agents → store in Serena
- **Hardcoded skill names removed from routing instructions** — `(e.g., /gsd:quick)` and `(e.g., /gsd:debug)` replaced with `(from routing matrix)` / `(look up in routing matrix)` placeholders in SKILL.md heuristics table and prompt-crafting-guide.md decision tree. Restores the v3.5.2 fix that prevented anchoring bias. Concrete skill names remain only in the curated base matrix (their correct location)
- **Anti-pattern warnings rewritten** — removed specific skill names from "don't do this" warnings in prompt-crafting-guide.md to avoid negation-by-example reinforcement
- **Core SP behaviors restored after over-trimming** — Self-Delegation Principle, 10-point prompt quality list, ══ fence format, Ask-Before-Act examples, Communication Style details, and Post-Prompt report-back steps restored to SKILL.md core after gap analysis showed they were removed during initial lean hub restructure

### Critical Fixes

- **F1: Context monitoring env var baseline** — set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70` at startup to lower auto-compaction trigger from ~95% to 70%, giving the PreCompact hook a reliable system signal instead of unreliable self-assessment
- **F4: Mandatory parallelization check** — 4-question checklist required before writing any prompt; if Q1-3 answer YES and prompt lacks `<orchestration>`, the prompt fails the quality gate
- **F4: Routing decision tree** — replaced flat matrix lookup with structured scope + complexity tree that must be walked before selecting a skill
- **F4: Post-craft self-verification** — 8-item mandatory checklist after writing any prompt; all items must pass before presenting
- **F9: Fire-and-verify pattern** — replaced silent fire-and-forget agents with fire-and-verify; Agent C (dashboard fix + gitignore check) verified before orientation; gitignore failure triggers immediate user warning (security concern)

### High Improvements

- **F2: Progressive session naming** — lifecycle from `sp-init-MMDD` to `sp-[topic]-MMDD` to `sp-[refined]-MMDD`; treated as identity management (no ask-before-act)
- **F3: Hooks integration** — new `references/hooks-integration.md` with phased rollout: Phase 1 (SessionStart, PreCompact, Stop), Phase 2 (SubagentStart/Stop, PostToolUse, UserPromptSubmit), Phase 3 (ConfigChange, PostToolUseFailure, custom hooks)
- **F5: Effort/color identity** — `/effort high` + `/color red` set unconditionally at startup Step 1 for full reasoning power and visual advisory identity
- **F6: /compact guardrailed protocol** — replaced absolute `/compact` ban with guardrailed protocol; bare `/compact` still prohibited; strategic compaction with mandatory focus instructions allowed at 65-72% context via AskUserQuestion

### Medium Enhancements

- **F7: Custom agent discovery** — startup scans `.claude/agents/` and `~/.claude/agents/` for user-defined agents to include in routing matrix
- **F7: Worktree isolation** — new section in orchestration-playbook.md for recommending `isolation: worktree` on risky implementations
- **F8: /insights integration** — run `/insights` before every handoff; dedicated section added to handoff template capturing project areas, patterns, friction points
- **F10: Curated base matrix** — skill-routing-matrix.md ships ~30 pre-mapped skills across 7 categories; delta-update procedure builds entries only for NEW/unknown skills (~80% startup cost reduction)
- **F11: Lean hub architecture** — SKILL.md restructured from ~700 lines to ~440 lines (41% reduction); procedural content moved to lazy-loaded reference files while retaining all core behaviors (Serena edge cases, Git Custody, Self-Delegation, prompt quality list) inline

### Low Additions

- **F12: /fork and /btw awareness** — documented as available native features in partner-protocols.md (mention only, no formal protocols)
- **F1: Companion script spec** — new `references/companion-script-spec.md` with full Python monitor architecture for power users wanting external context tracking

### Added

- `references/hooks-integration.md` — comprehensive hooks strategy with JSON configs and phased rollout
- `references/companion-script-spec.md` — Python context monitor architecture specification
- `docs/v4.0-implementation-decisions.md` — full decision log for all 12 audit findings
- Curated base routing matrix with ~30 pre-mapped skills in `skill-routing-matrix.md`
- Parallelization heuristics with concrete examples (when to parallelize vs when not) in `orchestration-playbook.md`
- Model selection cost-effectiveness guidance (Opus for coordinators/synthesis, Sonnet for parallel workers)

### Changed

- SKILL.md restructured as lean hub (~440 lines) with core behaviors inline and reference dispatch table
- Version bumped from 3.5.3 to 4.0.0
- Context handoff thresholds updated: 50-65% no action, 65-72% strategic compact, 72%+ full handoff
- Fire-and-forget agents replaced with fire-and-verify pattern throughout
- `/compact` ban replaced with guardrailed protocol (focus instructions mandatory)
- Startup sequence expanded: identity commands (Step 1), progressive naming (Step 2), env var (Step 3), fire-and-verify agents (Step 4), state reading (Step 5), verification gate (Step 6), orientation (Step 7)
- Reference files table expanded from 6 to 8 entries (hooks-integration.md, companion-script-spec.md)
- Handoff template updated with `/insights Analysis` section
- Prompt crafting guide: routing decision tree, parallelization check, and post-craft verification are now mandatory gates (not optional guidance)
- Orchestration playbook: added worktree isolation, concrete parallelization examples, anti-examples

### Removed

- Absolute `/compact` ban (replaced with guardrailed protocol)
- Fire-and-forget agent pattern (replaced with fire-and-verify)
- Context self-assessment as sole monitoring mechanism (supplemented with env var + hooks)

## [3.5.3] - 2026-03-05

### Added
- **Version badge in README.md** — shields.io badge linking to CHANGELOG for instant version visibility on GitHub
- **Git tags for release history** — first tagged release (`v3.5.3`); prior versions remain file-based only

### Fixed
- **Split-brain in post-prompt protocol** — `prompt-crafting-guide.md` had a condensed "verify > review > assess > plan next" summary that omitted the full 5-step report-back checklist from SKILL.md. Expanded to include all 5 steps (Verify, Review, Assess, Extract, Then propose next) so both files carry identical protocol detail

## [3.5.2] - 2026-03-05

### Added
- **Post-Prompt Protocol: Wait for Report Back** — mandatory behavioral section in SKILL.md enforcing the partnership loop. After delivering a fenced prompt, the SP must STOP and wait for the user to report back before offering next steps. Includes ASCII flow diagram, report-back review checklist, and explicit anti-pattern callout
- **Routing rationale line (`> 🎯 Routing:`)** — mandatory one-liner BEFORE every fenced prompt explaining why the chosen skill was selected (or why no skill was needed). Educates the user on SP routing decisions so they learn to anticipate which tools fit which tasks
- Routing rationale added to all 3 prompt format templates (inline, launcher, script) in both SKILL.md and prompt-crafting-guide.md — using generic placeholders, not hardcoded skill names
- New rule in fence format rules: routing rationale is mandatory before fences
- Two new anti-patterns in prompt-crafting-guide.md: "Missing routing rationale" and "Premature what's next?"
- **Fire-and-forget block in BOTH Step 2a and Step 2b** — Serena dashboard fix and .gitignore auto-add now explicitly listed in both continuation AND initialization PARALLEL blocks. Previously only referenced in the internal checklist, causing the dashboard fix to be missed in continuation mode

### Fixed
- **Partnership loop broken** — SP was presenting prompts then immediately offering "What's next?" menus instead of waiting for user to execute and report back. Root cause: no explicit stop instruction after prompt delivery. The Post-Prompt Protocol now enforces the wait
- **Dashboard fix skipped in continuation mode** — `web_dashboard_open_on_launch` auto-fix was only implicitly referenced via the internal startup checklist, not woven into the Step 2a/2b PARALLEL blocks. Now explicit in both modes
- **Hardcoded skill names in routing rationale examples** — removed `/sc:implement`, `/feature-dev`, `/gsd:quick` from template examples to prevent anchoring bias. Rationale examples now use `[skill-from-routing-matrix]` placeholder, forcing the model to consult the actual routing matrix every time

## [3.5.1] - 2026-03-05

### Added
- **Summary flows at top of all 6 reference files** — single-line ASCII arrow chains for instant orientation before diving into detail
- **❌ anti-pattern prefixes** in prompt-crafting-guide (17 items) and orchestration-playbook (11 items) for instant visual "don't do this" signal
- **`---` dividers between spawn patterns** in orchestration-playbook for cleaner visual separation
- **Git custody verification flow** — replaced prose list with branching ASCII diagram in SKILL.md
- **Version bump decision tree** in partner-protocols using `├─ Yes / └─ No` pattern
- **`startup-checklist.md`** added to SKILL.md Reference Files table (was orphaned)
- **Pending Scripts section** added to handoff-template.md (was missing, causing script references to be lost during handoffs)

### Fixed
- **`.gitignore` handling contradiction** — handoff subcommand said "ask before modifying" while context-handoff.md and SKILL.md said "auto-add silently". Aligned all files to auto-add (enforced guardrail, not discretionary)
- **Stale "Step 0" and "Step 1.5" references** in status.md and sync-skills.md — these steps were removed in v3.3.0 but references survived. Now removed
- **Prompt quality requirements numbering** — reference guide order now matches SKILL.md canonical order (model spec is #6 in both)
- **Anti-pattern format divergence** — orchestration-playbook now uses bold labels matching prompt-crafting-guide style

## [3.5.0] - 2026-03-05

### Added
- **Subagent delegation for context preservation** — SP delegates mechanical scanning to Explore agents during startup, keeping main context free for strategic reasoning
- **Parallel startup patterns** — initialization and continuation modes both spawn background agents for staleness checks and docs scanning
- **Fire-and-forget operations** — Serena dashboard fix and .gitignore auto-add run without waiting for results
- **Pre-prompt file delegation** — agent reads 3+ files and returns structured summary before SP crafts prompt
- **Self-Delegation Principle section** — explicit rules for what to delegate vs keep in main context
- **Delegation Decision Rules** — 4-question decision tree for routing work to agents vs doing it directly
- **Agent prompt templates** in orchestration-playbook (Patterns A/B/C/D) for consistent agent spawning

### Changed
- Startup sequence now spawns parallel agents alongside main SP work
- Orchestration playbook expanded with advisor-specific delegation patterns (distinct from implementation patterns)

## [3.4.0] - 2026-03-05

### Added
- **Graceful degradation section** — explicit fallback behavior for Serena unavailable, user declining separate sessions, and minimal skill inventory
- **Runtime routing matrix** — matrix is now built at startup from system context, stored in Serena memory, and diffed on subsequent sessions
- **Context measurement caveat** — documented that self-assessed context % can be off by 5–10%, recommending early handoff bias
- **Skill validation instruction** — prompt crafting now requires verifying skills exist in system context before recommending them
- **`references/partner-protocols.md`** — new reference file for version bump ownership and partner adaptation protocols
- **Expanded description triggers** — frontmatter now includes natural-language phrases ("plan my project", "advise on architecture", etc.)

### Changed
- **Routing matrix portability overhaul** — replaced 26-entry hardcoded inline matrix with universal layer (Agent subtypes + model heuristics + MCP rules + composition patterns)
- **`references/skill-routing-matrix.md`** rewritten as template/example format with auto-generation procedure; removed all hardcoded skill entries and project-local (`jimmy:*`) entries
- **Power Combinations** rewritten as abstract composition patterns ("Explore → Design → Build → Review") instead of hardcoded skill chains; SP fills in concrete skills at runtime
- **`/strategic-partner:sync-skills`** now rebuilds Serena routing matrix from system context and shows diff against previous matrix (was: scan-and-flag)
- **Version Bump Ownership** (Responsibility §7) compressed to 3-line summary + pointer to reference file (was: 15 lines inline)
- **Partner Adaptation** compressed to 3-line summary + pointer to reference file (was: 10 lines + table inline)
- **Reference Files table** updated with new `partner-protocols.md` entry and revised `skill-routing-matrix.md` description
- **Startup checklist** updated with routing matrix build step

### Removed
- 60+ hardcoded skill entries from `skill-routing-matrix.md`
- Project-local skill section (`jimmy:*` entries)
- "Last synced" tracking in routing matrix (no longer relevant — matrix is auto-built)
- Hardcoded skill names in Power Combinations section

## [3.3.0] - 2026-03-05

### Added
- **Git state capture at startup** — branch, uncommitted changes, ahead/behind captured before orientation
- **Post-implementation commit verification** — SP verifies commits landed after user reports back from implementation sessions
- **Partner adaptation** — Engineer/PM/Exec profile detection with concrete adaptation guidance per audience
- **Response structure standard** — status briefings, analysis templates, diagram format selection, symbol discipline
- **Git state in handoff template** — branch, status, ahead/behind, last commit now preserved across sessions
- **Target branch requirement** — implementation prompts now specify the branch in `<context>` section

### Changed
- **Hybrid rewrite** — merged old version's lean body structure with v3.2.0's genuinely valuable features
- SKILL.md body reduced from 708 → 517 lines (-27%) while retaining all capabilities
- Inline skill routing matrix restored (26 core tasks + MCP routing always in context, no startup file loading)
- Startup simplified from 6 steps to 2 steps + git state capture
- Removed ecosystem registry bootstrap (system context already provides full inventory)
- Removed Step 0 upgrade detection (unnecessary startup complexity)
- Removed Six Pillars conceptual framework (behaviors preserved without the naming layer)
- Merged `mcp-routing-matrix.md` into `skill-routing-matrix.md` (one file, not two)
- Simplified `startup-checklist.md` to supplementary detail only (body IS the checklist now)
- Ask-before-act examples restored inline (moved back from ref file for always-available access)
- Reference files now loaded on-demand only (zero ref files loaded at startup vs 2 before)
- Estimated context savings: ~2,900 tokens per session (~1.5% of context window)

### Removed
- `references/mcp-routing-matrix.md` — merged into skill-routing-matrix.md
- Ecosystem registry Serena memory pattern — replaced with direct system context reading
- Count-based diff at startup — removed with ecosystem registry

## [3.2.0] - 2026-03-04

### Added
- **Tiered context handoff** — three escalation levels (67% gentle, 72% strong, 77% urgent) replace the old 70/75/85 thresholds that rarely triggered in practice
- **Script generation** — SP now generates runnable `.scripts/*.sh` for deterministic terminal tasks (config edits, installs, setup) alongside `.prompts/` for AI-judgment tasks
- **Deliverable type routing** — decision tree in prompt-crafting-guide to route between scripts, prompts, or both based on task characteristics
- **Script quality standards** — `set -euo pipefail`, pre-flight checks, progress output, idempotent operations
- **RUN-IN-TERMINAL display block** — parallel to the existing COPY-INTO-NEW-SESSION launcher format

### Changed
- Context check cadence tightened from "every 3rd exchange" to "every 2nd exchange after 60%"
- 67% tier is now **visible** to user (inline note) — old 70% "soft trigger" was invisible (internal prep only)
- 77% tier executes handoff immediately — no permission needed, only topic-slug confirmation
- Implementation Firewall now allows `.scripts/` alongside `.handoffs/` and `.prompts/`
- Handoff split-writes now capture pending scripts in addition to prompts
- Continuation prompt template includes "Pending Scripts" section

### Fixed
- Threshold discrepancy between handoff subcommand (60/75/85) and SKILL.md (70/75/85) — unified to 67/72/77
- Stale 70% reference in orchestration-playbook.md

## [3.1.0] - 2026-03-03

### Added
- Initial published release
- Full advisor persona with implementation firewall
- Engagement protocol with mandatory AskUserQuestion
- Seven responsibilities (strategic oversight, CLAUDE.md ownership, Serena memory management, git custody, prompt crafting, context handoff, version bump)
- Six pillars (Claude Code mastery, proactive intelligence, ecosystem awareness, prompt engine, orchestration playbook, continuous improvement)
- Four subcommands (help, sync-skills, handoff, status)
- Reference files: skill-routing-matrix, mcp-routing-matrix, context-handoff, orchestration-playbook, prompt-crafting-guide, startup-checklist
- Cross-agent compatibility (Claude Code, Cursor, Gemini CLI, Windsurf, Codex)
