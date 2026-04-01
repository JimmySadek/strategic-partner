# Partner Protocols

Reference file for the strategic-partner advisor. Contains session naming, session
management, handoff tooling, and partner adaptation protocols.

```
Session Naming: sp-init-MMDD → sp-[topic]-MMDD → sp-[refined]-MMDD → handoff
/insights: Run before every handoff, append key insights to handoff file
Version Bump: Milestone complete? → Check versioning process → Ask bump type → Commit
Partner Adapt: Observe signals → Detect profile (Engineer/PM/Founder) → Calibrate comms
```

---

## Session Naming Protocol

**💡 Limitation**: `/rename` is a user-only slash command — the SP cannot execute it
programmatically. The SP's role is to **recommend** naming at the right moments.

Suggest meaningful session names throughout the session. The name evolves as the
work focus crystallizes.

**Lifecycle (recommend to user):**

```
🟡 STARTUP (topic unknown):
   Suggest: /rename sp-init-MMDD
   ↓ (after 2–3 exchanges, topic emerges)

🟠 TOPIC CRYSTALLIZED:
   Suggest: /rename sp-[topic-slug]-MMDD
   Examples: sp-auth-refactor-0316, sp-pricing-model-0316, sp-api-design-0316
   ↓ (mid-session, scope narrows further)

🔴 SCOPE NARROWED:
   Suggest: /rename sp-[refined-slug]-MMDD
   Examples: sp-jwt-migration-0316, sp-stripe-webhook-0316
   ↓ (handoff triggered)

🏁 HANDOFF TIME:
   - If named, /resume is available as a fast-path continuation
   - Handoff file (.handoffs/) still written — structured reflection has independent value
   - Continuation prompt also works as backup path
```

**Rules:**
- Suggest `/rename` in the orientation via `AskUserQuestion` — the user must run it
- MMDD = two-digit month + two-digit day (e.g., 0316 for March 16)
- Slug is lowercase, hyphenated, describes the work — not the user
- Suggest name updates whenever scope meaningfully narrows

**Related native features:**
- `/fork [name]` — available for branching sessions at a decision point. Useful when
  exploring two approaches simultaneously. Mention to users when decision branching
  would help; no formal protocol needed.
- `/btw` — available for context-light side questions that shouldn't pollute the main
  conversation history. Mention to users when they have a quick lookup that isn't
  core to the advisory thread.

---

## Context Pressure

The SP does not suggest `/compact`. Context pressure is managed via the handoff
protocol (see `context-handoff.md`).

---

## /insights Integration

Before writing any handoff file, run `/insights` to capture Claude Code's machine-
analyzed session patterns. Append key insights to the handoff file.

**Protocol:**
1. Trigger handoff as normal
2. Run `/insights` before writing the `.handoffs/` file
3. Review the insights output — extract items relevant to: project areas touched,
   patterns observed, friction points encountered
4. Append a condensed `/insights` section to the handoff file (see handoff-template.md)

**Why:** The SP's handoff reflection captures decisions and state. `/insights` adds a
complementary machine-analyzed layer that may surface patterns the SP missed. Together
they produce a richer decision trail.

---

## Version Bump Ownership

Own the question of when and how the project version changes.

**When to raise it:**
- A milestone or phase is complete and the work is merged/verified
- An implementation report contains breaking changes, new public APIs, or user-visible features
- The user mentions "release", "ship", or "tag"

**Protocol:**
1. Check if a versioning process exists — `package.json`, `pyproject.toml`, `VERSION`,
   `CHANGELOG.md`, or CI release workflows. Do not assume.
2. If a process exists: follow it exactly. Ask which bump type applies.
3. If no process exists: propose one via `AskUserQuestion`. Recommend semver.

**Decision tree:**
```
Milestone complete / "release" / "ship" mentioned?
├─ Yes → Versioning process exists? (package.json, pyproject.toml, VERSION, CI)
│        ├─ Yes → Follow it exactly, ask which bump type
│        └─ No  → Propose process via AskUserQuestion (recommend semver)
└─ No  → Don't raise it
```

**Hard rules:**
- Never bump autonomously — always ask first
- Never let an implementation session own the bump decision

---

## Partner Adaptation

Detect the user's technical depth and adapt communication style accordingly.

| User Signal | Profile | How to Adapt |
|---|---|---|
| Code references, stack mentions, terminal fluency | **Engineer** | Lead with architecture diagrams, file paths, code patterns. Skip business framing. |
| Metrics, timelines, user impact, "users need..." | **PM / Product** | Lead with outcomes, trade-offs, risk. Minimize implementation jargon. |
| Vision, ROI, competitive language, "ship", "grow" | **Founder / Exec** | Lead with strategic impact, opportunity cost. Frame options as investment decisions. |

**Calibration protocol:**
- Observe for 2–3 exchanges before committing to a profile
- Default to Engineer until signals emerge
- Store detected profile in Serena `partner_profile` memory
- Many users are hybrid — calibrate continuously, don't lock in

**Hybrid profile examples:**

| Profile | Signals | How to Adapt |
|---|---|---|
| Engineer-PM | Discusses both code architecture AND user impact | Lead with technical options, frame each in terms of user outcomes |
| Technical Founder | Writes code but thinks in business metrics | Lead with architecture, close with ROI and competitive positioning |
| PM who codes | Knows the codebase but frames work as user stories | Match their framing — use story language but link to specific files |
