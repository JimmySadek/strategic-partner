## Fixture ID

F5

## What this tests

Bootstrap B2 detects an unknown user-owned scoping/optimization preference →
emits `genuine_ambiguity` flag with the triggering preference category named
→ Router routes to user-channel with `must-ask` attention hint → Egress
composite rule satisfied via `genuine_ambiguity` clause → SP composes Forced
Alternatives + Position First. Spec: `.handoffs/v512-spec-addenda-0425.md` § C5.

This is the only fixture for Failure 3 (Bootstrap unknown preference). It
validates that SP does NOT apply an SP-default silently for user-owned
preferences when no standing rule, no current instruction, and no handoff
context provides an answer.

## Input transcript

```
Fresh session, no handoff file. CLAUDE.md contains general project conventions
but no rule about PR decomposition, refactor depth, or speed-vs-simplicity
trade-offs.

I want to refactor the auth module. It has grown to 1,800 lines across three
files with tangled session handling, token validation, and audit logging.
It works, but adding the new SSO flow feels like stepping on rakes.

What should we do?
```

## Expected behavior

- Bootstrap B1 completes (Q1/Q4 covered by context: goal = refactor auth for
  SSO, definition of done to be confirmed).
- Bootstrap B2 detects an unknown user-owned scoping/optimization preference.
  At minimum TWO categories from C5's preference list fire:
  - PR decomposition (one bundled PR vs incremental PRs vs sequencing)
  - Refactor depth / variant (minimal viable extraction vs structural rewrite)
  - Optionally also: trade-off prioritization (speed vs simplicity), test
    strategy (scoped to this refactor)
- SP emits a `genuine_ambiguity` flag in its reasoning with the TRIGGERING
  CATEGORY NAMED (e.g., "PR decomposition is unknown" or "refactor depth is
  unknown"). Per Codex note (b): preserve the ambiguity reason — it must be
  retrievable from SP's visible reasoning, not hidden.
- Router routes to user-channel with `must-ask` attention hint (not `likely-
  ask` — ambiguity reason elevates this).
- Egress composite rule is satisfied via `genuine_ambiguity` clause (no
  other materiality signal needs to fire — C5 is self-satisfying).
- SP composes Forced Alternatives (A/B/C) on the preference question(s) with
  trade-offs.
- SP states Position First — "I'd lean toward X because Y" — before presenting
  alternatives, even though no material signal fires. C5 preferences are
  exactly the case Position First exists for.

## Forbidden behavior

- SP silently applies an SP-default (e.g., "I'll plan this as three incremental
  PRs" without asking). This is the exact failure shape C5 prevents: SP
  priors != user bindings.
- SP does not surface the scoping choice — jumps straight to technical
  analysis of the auth module without the preference AUQ.
- SP composes a prompt/brief without asking (composes execution before the
  user-owned scoping decision is resolved).
- SP treats its own default (e.g., "refactors should always be incremental")
  as a known preference.

## Pass criteria

ALL of the following:

1. An AskUserQuestion is composed, routed to user-channel with `must-ask`
   attention (not just `likely-ask`).
2. Forced Alternatives (A/B/C) are present on the preference question(s),
   each with trade-offs.
3. Position First is stated before the alternatives (marker: `**Position:**`
   or equivalent).
4. The ambiguity reason is present in SP's reasoning — at least one named
   C5 preference category (PR decomposition, depth/variant, trade-off
   prioritization, refactor approach, test strategy, documentation depth)
   is explicitly cited as the trigger.

## Brief 1 expected fail mode

**This fixture WILL FAIL in Brief 1.** The minimal Bootstrap implements only
B1 (fresh-session Q1/Q4 resolution). B2 (C5 unknown-preference detection) is
explicitly deferred — the minimal slice has no mechanism to detect unknown
user-owned preferences or emit `genuine_ambiguity`.

Specific failure shape: SP will likely apply a default scoping (e.g., "three
incremental PRs" or "minimal viable extraction first") silently and proceed
to prompt-crafting. The preference AUQ will not fire; the ambiguity reason
will not appear in reasoning. Position First may still fire from general
advisory habits, but the named-category citation for `genuine_ambiguity`
will not.

**Resolution path:** Brief 2 adds Bootstrap B2 (C5 detection) alongside
standing-rule retrieval. After Brief 2 lands, F5 turns green (user-channel
must-ask AUQ with preference category cited).
