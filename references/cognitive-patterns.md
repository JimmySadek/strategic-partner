# Cognitive Patterns — Advisory Thinking Tools

Reference file for the strategic-partner advisor. Named heuristics for
architectural decisions, trade-off analysis, and strategic thinking.
Load when facing non-obvious decisions or crafting high-stakes prompts.

---

## Decision Classification

### 1. One-Way / Two-Way Doors (Bezos)
**When to apply**: Any decision point in architecture, technology choice, or process change.
- **One-way door**: Irreversible or very costly to reverse. Slow down. Gather more data.
  Get multiple perspectives. This warrants a full prompt with design phase.
  Examples: database choice, public API contract, authentication architecture.
- **Two-way door**: Easily reversible. Decide fast, iterate. This is a Fast Lane candidate.
  Examples: internal naming conventions, folder structure, UI component choice.
**Anti-pattern**: Treating two-way doors as one-way (analysis paralysis).
**Anti-pattern**: Treating one-way doors as two-way (moving fast on irreversible choices).

### 2. Inversion Reflex (Munger)
**When to apply**: Stuck on "how do we make X work?" — flip it.
- Ask: "How would we guarantee X fails?" Then avoid those conditions.
- Ask: "What would make this project a disaster?" Then check if any of those conditions exist.
**Use in prompts**: Add an "inversion check" section to architecture prompts:
"Before implementing, list 3 ways this design could fail catastrophically."

### 3. Focus as Subtraction (Jobs)
**When to apply**: Scope decisions, feature prioritization, architecture simplification.
- "Focus is not about saying yes. It's about saying no."
- When the user wants to add, ask: "What are we willing to remove to make room for this?"
- When a design has 5 components, ask: "Which 2 are essential? What if we shipped only those?"
**Use in prompts**: Add explicit "NOT in scope" section to every implementation prompt.

### 4. Speed Calibration (Bezos)
**When to apply**: Deciding how much analysis is enough.
- 70% of the information you wish you had is enough to decide.
- Waiting for 90% means you're too slow — the cost of delay exceeds the cost of being wrong.
- Exception: one-way doors (Pattern #1) — get to 90%.
**Anti-pattern**: "Let's do more research" when the remaining 30% won't change the decision.

---

## Architecture Thinking

### 5. Choose Boring Technology (McKinley)
**When to apply**: Technology selection, library choice, infrastructure decisions.
- Every team has a limited "innovation budget" — 3 tokens.
- Spend tokens on things that differentiate. Everything else should be boring and proven.
- New technology = unknown failure modes. Boring technology = known failure modes.
**Use in prompts**: When the executor needs to choose a library/tool, add:
"Prefer boring, proven options. Only choose something novel if it's core to the value prop."

### 6. Blast Radius Instinct (Eng Management)
**When to apply**: Assessing risk of any change, scoping implementation phases.
- Before any change: "If this goes wrong, what else breaks?"
- Map the dependency graph. Changes with large blast radius need:
  Feature flags, phased rollout, canary deployment, or separate PR.
- >8 files OR >2 new abstractions = smell. Question whether the scope is right.
**Use in prompts**: Include blast radius assessment in every prompt with >3 file changes.

### 7. Essential vs. Accidental Complexity (Brooks)
**When to apply**: Evaluating whether something "needs" to be complex.
- **Essential complexity**: inherent in the problem domain. Can't be removed.
- **Accidental complexity**: artifact of our tools, choices, or historical decisions. Can be removed.
- When something feels too complex, ask: "Is this complexity essential or accidental?"
- If accidental: can we simplify? If essential: document why.
**Anti-pattern**: Accepting accidental complexity as "just how it is."

### 8. Make the Change Easy, Then Make the Easy Change (Beck)
**When to apply**: Refactoring decisions, implementation sequencing.
- When a change is hard, don't push through. First refactor to make it easy, then make it.
- This means: separate the refactoring PR from the feature PR.
- In prompts: sequence deliverables as "Phase 1: refactor X to enable Y. Phase 2: implement Y."
**Anti-pattern**: Mixing refactoring with feature work in the same commit/PR.

---

## Strategic Thinking

### 9. Paranoid Scanning (Grove)
**When to apply**: Reviewing architecture, assessing project health, post-implementation review.
- "Only the paranoid survive."
- Actively look for what could go wrong: security, performance, scalability, maintainability.
- After every implementation report: "What's the thing we're not seeing?"
**Use in prompts**: Add a "Paranoid Check" section: "What are 3 things that could go wrong
with this implementation that aren't obvious from the happy path?"

### 10. Proxy Skepticism (Bezos Day 1)
**When to apply**: When metrics, processes, or tools become the goal instead of the outcome.
- "The process is not the thing. It's always worth asking, 'do we own the process, or does the process own us?'"
- Watch for: optimizing test coverage percentage instead of actual correctness,
  following a checklist instead of thinking about the specific situation,
  adding process to prevent a problem that happened once.
**Anti-pattern**: "We need a new process for this" when the real answer is "pay attention."

### 11. Chesterton's Fence (Chesterton)
**When to apply**: Before removing, refactoring, or "cleaning up" existing code/processes.
- "Don't remove a fence until you understand why it was built."
- Before removing anything: `git log` / `git blame` to find the original reason.
- If the reason is still valid: keep it. If the reason no longer applies: remove with confidence.
**SP already uses this** (Intent-Check Protocol in Serena). Reinforce as a named pattern.

### 12. Conway's Law (Conway)
**When to apply**: System architecture decisions, team structure discussions.
- "Organizations produce designs which mirror their communication structures."
- If the architecture doesn't match the team, either change the architecture or the team.
- Watch for: microservices with a single team (unnecessary overhead),
  monolith with multiple teams (coordination bottleneck).

---

## Advisory-Specific Patterns

### 13. Scope Iceberg
**When to apply**: User says "just a small change" or "quick fix."
- Every visible change has 3-5x invisible implications (tests, docs, migrations, error handling).
- Before agreeing something is small: "What's under the waterline?"
- Map: the change itself, tests needed, docs to update, error cases, migration path, rollback plan.
**Use in prompts**: Always include a "Scope Check" in the preamble — executor reads the code
and reports if the scope is larger than expected before implementing.

### 14. Decision Reversibility Spectrum
**When to apply**: Choosing between prompt delivery (full session) vs. Fast Lane dispatch.
- Not binary (reversible/irreversible) but a spectrum:
  Trivial -> Easy -> Moderate -> Costly -> Irreversible
- Match the ceremony to the reversibility. Trivial = Fast Lane. Costly = full prompt with design phase.
- Factors: data migration, public API, user-facing behavior, security boundary.

### 15. The Second System Effect (Brooks)
**When to apply**: User wants to rewrite or "do it right this time."
- The second version of any system tends to be over-engineered because the builder
  knows all the problems of the first version and tries to solve all of them at once.
- Counter with: "What are the top 3 problems? Let's fix those. Leave the rest."
- Prefer incremental migration over big-bang rewrites.
**Anti-pattern**: "While we're at it, let's also..." during a rewrite.
