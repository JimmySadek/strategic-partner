---
paths: ["SKILL.md", "hooks/**", "references/**", "commands/**", "tests/**"]
---

# Source-Editing Behavioral Guardrails

These rules apply whenever Claude is editing Strategic Partner source — `SKILL.md`,
hooks, reference docs, commands, or tests. They load through path-scoping: absent
when SP is in advisory mode, present when source content is actually changing.

Five principles, each with a one-sentence statement, the anti-pattern that
typically appears without the rule, the corrected approach, and a worked
example drawn from SP's own domain.

═══════════════════════════════════════════════════════════════════

## 1. Think Before Coding

**Principle:** Surface assumptions. Surface confusion. Reject sycophancy as a
dark pattern.

### What this means

- State assumptions explicitly. If uncertain, ask rather than guess.
- When multiple interpretations exist, present them. Don't pick silently.
- Push back when warranted. If a simpler approach exists, say so.
- **Reject sycophancy.** Sycophancy is a dark pattern where the model
  prioritizes user preference over accuracy. The result is distorted reality,
  weakened critical thinking, and reinforced user bias. Avoid this at all
  costs — not just "push back when warranted" but explicitly name and reject
  the dynamic.

### Anti-pattern

- Silently picking an interpretation when ambiguity exists.
- Hidden assumptions that surface only when the work is rejected.
- Confirming user direction without verification.
- Avoiding pushback to keep the user comfortable.
- Validating bad approaches because the user proposed them.

### Corrected approach

- Before editing, list assumptions explicitly. Ask if uncertain.
- When multiple valid interpretations exist, present them. Don't pick silently.
- When the user proposes something problematic, name the problem clearly.
  Honesty is the partnership.
- Push back with evidence and reasoning, not opinion.

### Worked example

**Editing context:** A reference doc updating the floor sentinel's routing
rules. User says: *"Add caching to the routing matrix lookups — the floor
checks feel slow."*

❌ **Anti-pattern (silent agreement, hidden assumptions):**

```bash
# Wraps the matrix read in a 5-minute TTL cache
ROUTING_CACHE="${TMPDIR}/sp-routing-cache"
if [ -f "$ROUTING_CACHE" ] && [ "$(find "$ROUTING_CACHE" -mmin -5)" ]; then
  cat "$ROUTING_CACHE"
else
  build_routing_matrix > "$ROUTING_CACHE"
  cat "$ROUTING_CACHE"
fi
```

The author silently assumed three things: the floor is actually slow, caching
is the right fix, and a 5-minute TTL is fine. None of those are verified. The
new TTL cache also collides with the existing inventory-hash freshness
mechanism — two competing freshness layers, neither aware of the other.

✅ **Corrected approach (surface assumptions, push back):**

> Before I add caching, a few things I want to surface:
>
> 1. **Evidence.** Do we have measurements showing the matrix lookups are
>    actually slow? The floor sentinel runs in roughly 150ms per the v5.16.0
>    release notes; "feels slow" might be from another step in the chain.
> 2. **Existing mechanism.** There's already an inventory-hash freshness
>    check (a SHA-256 fingerprint of the agent inventory that decides whether
>    the cached matrix is current). Adding a TTL cache on top would create
>    two competing freshness mechanisms, and the inventory hash is the one
>    designed not to drift.
> 3. **Real bottleneck candidate.** The v5.16.0 fix targeted "rebuild every
>    session," not "lookup every turn." If lookups are slow, that's a
>    different problem than the one the inventory hash solved.
>
> What's making this feel slow on your end? If we measure it and the lookups
> really are the bottleneck, I'd lean toward extending the inventory-hash
> mechanism to cover lookups specifically — not adding a new TTL layer.

═══════════════════════════════════════════════════════════════════

## 2. Simplicity First

**Principle:** Minimum content that solves the problem. Nothing speculative.

### What this means

- No features, options, or knobs beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No defensive handling of scenarios that can't occur.
- If the diff has 200 lines and 50 would solve the problem, rewrite to 50.

### Anti-pattern

- Configuration system for a one-line decision.
- Premature abstraction "because we might need it later."
- Defensive programming against impossible scenarios.
- Adding interfaces around concrete implementations that have one caller.
- Generalizing a one-shot script into a reusable library.

### Corrected approach

- Solve today's stated problem with the minimum that works.
- If complexity is genuinely needed later, refactor when the second use case
  arrives — not before.
- Apply the test: would a senior engineer reading this say "this is
  overcomplicated"? If yes, simplify.

### Worked example

**Editing context:** A hook script in `hooks/lib/` controls how long the
floor sentinel allows itself to run. User says: *"Make the timeout
configurable so we can test different values."*

❌ **Anti-pattern (configuration layers for a single value):**

```bash
# Adds env var → config file → default fallback chain
SP_FLOOR_TIMEOUT="${SP_FLOOR_TIMEOUT:-}"
if [ -z "$SP_FLOOR_TIMEOUT" ] && [ -f "${HOME}/.sp/config.toml" ]; then
  SP_FLOOR_TIMEOUT=$(grep '^floor_timeout' "${HOME}/.sp/config.toml" \
                    | cut -d'=' -f2 | tr -d ' "')
fi
SP_FLOOR_TIMEOUT="${SP_FLOOR_TIMEOUT:-200}"
```

Two new layers — environment variable override and a TOML config file — for
one numeric value that has never had a second user. The complexity earns
nothing today.

✅ **Corrected approach (inline the value):**

```bash
# Floor timeout in milliseconds.
# Update inline if a new value is needed.
SP_FLOOR_TIMEOUT_MS=200
```

If a second test value is genuinely needed later, the refactor takes the same
ten minutes either way. At that point the second use case tells you what the
config interface should look like, instead of guessing now.

═══════════════════════════════════════════════════════════════════

## 3. Surgical Changes

**Principle:** Touch only what you must. Every changed line traces directly to
the user's request.

### What this means

- When fixing a bug, don't "improve" adjacent code.
- Don't refactor things that aren't broken.
- Match the file's existing style, even if you'd write it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Diff discipline: every changed line should answer "Why did this change?"
  with "Because the user asked for X."

### Anti-pattern

- Reformatting quotes, indentation, or line wrapping while fixing a bug.
- Adding comments, docstrings, or type hints that weren't requested.
- "Improving" wording in adjacent rules while editing one.
- Renaming variables for clarity in code that wasn't requested.
- Auto-applying a linter or formatter across the whole file when only one
  line was at fault.

### Corrected approach

- Diff discipline at every changed line.
- If you notice unrelated issues, surface them in the response — don't fix
  them silently.
- Match the project's existing conventions, even if they're not your
  preference.

### Worked example

**Editing context:** SKILL.md frontmatter. User says: *"Add `playwright` to
the `mcp-servers` list."*

Current state:

```yaml
mcp-servers: [serena, context7]
```

❌ **Anti-pattern (drive-by improvements):**

```diff
- mcp-servers: [serena, context7]
+ mcp-servers:
+   - "context7"  # documentation lookup
+   - "playwright"  # browser automation
+   - "serena"  # session memory and code navigation
```

The user asked for one value added. They got: list-format change (inline →
block), quotes added around values, alphabetical sort, inline comments
explaining each entry's purpose. None requested.

✅ **Corrected approach (one value added, everything else preserved):**

```diff
- mcp-servers: [serena, context7]
+ mcp-servers: [serena, context7, playwright]
```

If the surgical change reveals adjacent issues genuinely worth fixing,
surface them as separate observations:

> "Done — `playwright` added. While I was in the frontmatter, I noticed the
> `category:` field is missing a trailing newline. Want me to fix that as a
> separate change, or leave it?"

The user decides whether to expand scope. The default is no.

═══════════════════════════════════════════════════════════════════

## 4. Verification, not Specification

**Principle:** Anchor on what can be verified, not on prescribing every step.

### What this means

- Frame work as a verifiable outcome, not as imperative micro-management.
- Test-first when fixing bugs: write the test that reproduces, then make it
  pass.
- Define success criteria. The agent loops independently against criteria;
  weak criteria require constant clarification.
- Declarative outcomes scale; imperative steps don't.

### Anti-pattern

- "I'll review and improve the code" — no success criteria.
- Fixing a bug without first writing a test that reproduces it.
- "Make it faster" — no measurable target.
- Imperative step-by-step prescription that prevents the agent from finding a
  better path.

### Corrected approach

- Transform tasks into verifiable goals. For example:
  - "Add a check" → "Write tests for the failing inputs, then make them pass."
  - "Fix the floor signal bug" → "Write a test that reproduces the bug, then
    make it pass."
  - "Refactor this hook" → "Existing test suite passes before and after; no
    new behaviors emerge."
- For multi-step tasks, state the verification at each step.
- Strong success criteria let the agent loop independently. Weak criteria
  require constant clarification.

### Worked example

**Editing context:** A bug in `tests/lint-voice.sh` — the lint silently
passes when `TMPDIR` is broken or no files are scanned, instead of failing
closed. User says: *"Fix the lint so it doesn't silently pass when nothing's
scanned."*

❌ **Anti-pattern (fix without specification or verification):**

The author rewrites the lint's exit logic, infers what "silently pass" means,
and ships the change without ever exercising the failure path.

```bash
# A guess at the fix — no test demonstrates the original bug or the fix
if [ -z "$FILES_SCANNED" ]; then
  echo "WARNING: nothing scanned"
fi
```

This neither reproduces the bug (so we don't know if the change addresses
it) nor verifies the fix. And "doesn't silently pass" is ambiguous — does it
mean "warns" or "fails closed"? The author picked one without asking.

✅ **Corrected approach (specify, then verify):**

**Step 1 — surface the spec.** Before editing, ask:

> "When the lint can't scan any files, two behaviors are reasonable:
>
> 1. Emit a warning but exit 0 — the lint ran, found nothing to flag.
> 2. Exit 1 — the lint expected files and got none, treat as a release-blocker.
>
> The release process treats lint failures as blocking. Which do you want?"

User picks option 2: *"Fail closed. If we expected files and scanned zero,
that's a release-gate failure."*

**Step 2 — write the failing test.** Create a fixture that triggers the
"expected files, scanned zero" condition:

```bash
# tests/fixtures/lint-voice/empty-tmpdir.sh
TMPDIR=/nonexistent-path bash tests/lint-voice.sh
EXIT=$?
[ "$EXIT" -eq 1 ] || { echo "FAIL: expected exit 1, got $EXIT"; exit 1; }
echo "PASS"
```

**Step 3 — run the test against the existing lint.** It should fail with
`expected exit 1, got 0`. That's the original bug, reproduced.

**Step 4 — fix the lint to honor the spec.**

```bash
if [ "$expected_files" -gt 0 ] && [ "$files_scanned" -eq 0 ]; then
  echo "ERROR: expected $expected_files files but scanned zero — TMPDIR broken?"
  exit 1
fi
```

**Step 5 — re-run the test. It passes deterministically.**

The principle: **the test is the spec.** Without an explicit "what should
happen when nothing is scanned" decision, you'd be guessing what to verify
against. With the spec stated upfront, both the test AND the fix have a clear
target — and the next person reading the diff understands why the change was
made.

═══════════════════════════════════════════════════════════════════

## 5. Voice Discipline

**Principle:** Every change to SP source applies SP's voice — plain English,
deliberate visualization, functional emojis as section anchors, no
project-internal jargon without a one-line gloss on first mention. This rule
is source-edit-time enforcement, independent of whatever live-session output
style is active.

### Why

The `strategic-partner-voice` output style file is today's enforcement layer
for SP voice in live sessions. If Claude Code deprecates output styles, the
user experience disappears unless SP source already carries voice on its
own. This rule makes voice live in the source — durable independent of any
single mechanism. The release-time voice lint (`tests/lint-voice.sh`) catches
mechanical violations at pre-push; this rule catches the same patterns at
edit-time so the lint stays clean.

### What this means

- **Plain English first.** Translate jargon as it appears. Gloss internal
  terms on first mention. Standard vocabulary (HTTP, JSON, git, REST) needs
  no gloss; project-coined terms always do.
- **Visualization is required for non-trivial content.** Tables for
  comparisons (two or more items being compared along the same dimensions),
  ASCII diagrams for spatial / temporal / structural relationships,
  structured bullets for enumerable items. Wall-of-text prose for
  substantive content is the failure mode.
- **Functional emojis as section anchors.** Match emoji to section meaning
  (🎯 routing, 📥 intake, 📋 status, 🔍 analysis, ⚠️ warning, 🛡️ guardrail,
  🔧 configuration, 🏗️ architecture, 🎭 voice, ⚡ performance, 🚀 deploy).
  Status emojis (✅ ❌ ⚠️ 🟢 🔴 🟡) inside tables and checklists. Not
  decorative.
- **Bold for key terms only.** First definition of a key term, the
  recommendation in a Position line, decision points the reader scans for.
  Never whole sentences or paragraphs.
- **No project-internal jargon without first-mention gloss.** Every coined
  term, every multi-letter project acronym, every version-stamped reference
  gets a plain-English description on first use in the new content.
- **Name the actor at action-ownership points.** Wherever a sentence assigns
  who performs an action — next steps, hand-offs, "who does what" — name the
  actor explicitly: SP, the user, the executor (or the specific agent). Do
  not use "I" / "you" / "me" for action ownership there. Natural second
  person is fine everywhere else; this is targeted, not a blanket ban on
  "you".

### Anti-pattern

- Dense paragraphs explaining mechanics that would read more clearly as a
  table or ASCII diagram.
- Project-internal vocabulary (terms like Closure
  Floor, captured-thinking state names, Layer N) dropped without gloss.
- Substantive multi-section content authored with no functional emoji
  anchors at the section headings.
- Bold sprayed across whole sentences for general emphasis rather than
  anchoring a single key term.
- Code-style spec framing (Constraints / Inputs / Outputs / Returns) used
  in advisory or explanatory prose, where structured bullets or a table
  would read better.
- Action-ownership sentences using "I" / "you" / "me" — next steps,
  hand-offs, "who does what" phrased so the reader can't tell who performs
  the action.

### Corrected approach

- Before writing, plan visual structure. Where does a table fit? Where
  does an ASCII diagram carry flow? Where do structured bullets enumerate?
  Where does prose serve best?
- Gloss every project-coined term on its first mention; use the term as a
  handle thereafter in the same block.
- Anchor each substantive section with a functional emoji matched to
  section meaning.
- Bold sparingly. Anchor a key term, a recommendation, a decision point —
  not surrounding sentences.
- Read the edit as a smart non-developer would. If they would stop on any
  block, simplify the language, gloss the term, or restructure before
  shipping.
- At action-ownership points, name SP / the user / the executor (or the
  specific agent) instead of "I" / "you" / "me". Natural second person
  stays fine for empathic asides and unmistakable context.

### Worked example

**Editing context:** A reference doc adds a new section explaining the
`/strategic-partner:copy-prompt` subcommand — what it does, when to use it,
how it works under the hood. User says: *"Document the copy-prompt
subcommand."*

❌ **Anti-pattern (dense prose, no visualization, jargon dropped):**

> The copy-prompt subcommand reads from `.handoffs/last-prompts/`, wiped and
> rewritten on every fenced emission per the Fenced Prompt Emission Protocol
> in SKILL.md. The subcommand pipes the contents of `1.md` (or `2.md` if
> argument is `2`) through `pbcopy`, bypassing the mouse-select fragility
> inherent to terminal UI rendering of fenced markdown blocks.

A reader who doesn't already know what fenced emission is, what the protocol
does, or why mouse-select is fragile cannot follow this. No section anchor,
no visualization, five pieces of project-internal vocabulary dropped without
gloss.

✅ **Corrected approach (anchored, visualized, glossed):**

> ### 📋 What `/strategic-partner:copy-prompt` does
>
> When SP shows you a prompt inside the green/red bordered block (between
> `═══` markers), the contents are also written to disk so you can copy
> them reliably — without depending on terminal mouse-select, which often
> drops characters or wraps lines unexpectedly.
>
> The subcommand copies that saved version to your OS clipboard:
>
> ```
> SP emits fenced prompt → contents saved to disk
>                                ↓
>             /strategic-partner:copy-prompt
>                                ↓
>                contents → OS clipboard
> ```
>
> **Argument behavior:**
>
> | Argument | What happens |
> |---|---|
> | (no argument) | Copies the first / only saved prompt |
> | `2` | Copies the second saved prompt, if a response emitted multiple fences |
>
> The save location is wiped and rewritten on every response that emits
> fences, so the subcommand always reads the most recent emission — there
> is no history.

The corrected version anchors with 📋, uses an ASCII diagram for the flow,
a table for the argument behavior, and glosses every internal term inline.
A reader unfamiliar with SP's internals can follow it.

### Note on this file's own structure

The four older principles in this file (## 1 through ## 4) use plain section
headings without emoji anchors. Per Principle 3 (Surgical Changes), this
fifth principle does not retrofit those headings. The voice policy applies
to new substantive content authored from this point forward, not to
backfilling existing structure for consistency's sake. When older content
gets substantively rewritten in a future change, the policy applies to that
rewrite.
