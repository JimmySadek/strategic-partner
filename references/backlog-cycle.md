# Backlog Cycle — Canonical Reference

This is Strategic Partner's runtime reference for the backlog cycle. The full
design archaeology lives at `.prompts/v6.4/backlog-cycle-design-spec.md`; this
document is the operational version SP loads at orientation and triage time.

The cycle is a hybrid: **GitHub Issues** vocabulary for lifecycle states and
close reasons, **GTD** (Getting Things Done — a personal-productivity capture
discipline) framing for the lightweight inbox stage, and **Kanban**-style
release-boundary triage rhythm.

---

## 🎯 Goal

Replace the older ad-hoc backlog cycle (vague status taxonomy, judgment-call
triggers, opportunistic pruning, inconsistent naming) with a crisp lifecycle
that makes capture, promotion, and closure mechanical wherever possible and
explicit where judgment is unavoidable. Items move through five named states;
transitions name a decision-maker; triggers are typed (mechanical, event,
temporal) so "trigger met" is a yes/no question, not a read.

---

## 🔄 Lifecycle states

Five states. Each has a functional emoji anchor used in command output and
orientation summaries.

| State | Emoji | Meaning |
|---|---|---|
| **inbox** | 📥 | Fresh capture, not yet thought through |
| **clarified** | 🔍 | Understood and scoped; waiting to be triaged for action |
| **parked** | ⏳ | Clarified plus "not now"; waiting on a trigger |
| **active** | 🔄 | Being worked on this session or in flight |
| **closed** | ✅ | Done; sub-classified by close reason |

---

## 🗂️ State storage

The inbox stage lives in either of two storage locations depending on capture
context; the other four states have one home each.

| State | Lives in |
|---|---|
| 📥 inbox (lightweight capture) | `.handoffs/findings-MMDD.md` — append-only log, no per-item frontmatter |
| 📥 inbox (substantive capture) | `.backlog/[verb-prefix]-[slug].md` with `state: inbox` |
| 🔍 clarified, ⏳ parked, 🔄 active | `.backlog/[verb-prefix]-[slug].md` |
| ✅ closed | `.handoffs/backlog-archive/` |

**One logical inbox, two storage shapes.** Orientation and triage scan
**both** the findings file and `.backlog/*.md` for inbox-state items. The
choice between shapes is about weight (a one-liner observation goes to
findings; a substantive idea with a body goes straight to `.backlog/`).

---

## 🚦 State transitions

Eleven transitions; events explicit; decision-maker named on each row.

| From | Event | To | Decision-maker |
|---|---|---|---|
| (capture) | SP observes a finding or issue | 📥 inbox | SP — automatic on capture |
| 📥 inbox | Triage decides "not worth tracking" | (discarded — note in findings) | User |
| 📥 inbox | Triage decides "worth scoping" | 🔍 clarified | User; SP proposes |
| 📥 inbox | Triage decides "do now" | 🔄 active | User |
| 🔍 clarified | Triage decides "defer + set trigger" | ⏳ parked | User |
| 🔍 clarified | Triage decides "do now" | 🔄 active | User |
| ⏳ parked | Trigger condition fires | 🔄 active | SP-detected → user confirms |
| 🔄 active | Work ships (see below) | ✅ closed (`completed`) | SP-detected → user confirms |
| (any non-closed) | Decision: not pursuing | ✅ closed (`not-planned`) | User |
| (any non-closed) | Decision: covered elsewhere | ✅ closed (`duplicate`) | User |
| (any non-closed) | Decision: replaced by new approach | ✅ closed (`superseded`) | User |

**"Work ships" defined.** A commit lands on `main` that implements the
item's scope. SP detects by scanning recent commit messages and diffs for
references to the item's filename or title; on match, SP surfaces a
confirmation prompt to close. Release tagging is NOT required — the commit
landing is enough.

**Reopen rule.** Closed → active is not in the v1 transition set. If a
closed item needs reopening, file a NEW item that names the closed one in
its `origin:` field (example: `origin: "Successor to
.handoffs/backlog-archive/fix-foo-bar.md — first attempt did not resolve the
underlying issue"`). A formal reopen transition may be added later if a real
need emerges.

---

## 🏁 Close reasons

Four reasons; mutually exclusive. Recorded in the closed item's
`close_reason:` field.

| Reason | Meaning |
|---|---|
| `completed` | Work shipped — the original intent is satisfied |
| `not-planned` | Decision not to pursue; item is closed without work |
| `duplicate` | Covered by another item (named via `superseded_by:` for traceability) |
| `superseded` | Approach replaced by a different one (named via `superseded_by:`) |

---

## 🗓️ Triage cadence

Two events fire triage. Per-session lightweight scans are not part of this
cadence — they add noise without earning their keep for a single-user-ish
project.

| Event | When it fires | What SP does |
|---|---|---|
| **Release boundary** | Automatic — before any minor or major release | Walks every inbox-stage item (findings + `.backlog/` inbox), walks every parked item with possibly-fired triggers, surfaces clarified items that could go active in the release cycle |
| **On-demand** | User invokes `/strategic-partner:backlog` | Same scan, regardless of release timing |

### ⌛ Findings disposition (auto-archive after 3 triages)

A finding captured to `.handoffs/findings-MMDD.md` that survives **3
consecutive triage events** without being promoted to `.backlog/` is
auto-archived: SP appends a note `[auto-archived YYYY-MM-DD — not promoted
after 3 triages]` and the finding moves to `.handoffs/findings-archive/`.
This keeps findings files from accumulating indefinitely. The auto-archive
is reversible (the user can move it back), but the signal is clear — if a
finding survived 3 triages without anyone caring, it probably isn't
actionable.

---

## 🎚️ Trigger field structure

Each parked item has a `triggers:` list and an optional `triggers_logic:`
flag controlling how multiple triggers compose:

- **`any`** (default) — any firing trigger surfaces the item at the next
  triage event (OR semantics)
- **`all`** — all listed triggers must fire simultaneously (AND semantics;
  rare, used for items whose readiness genuinely depends on multiple
  conditions holding at once)

Three trigger types:

| Type | What it measures | Evaluation |
|---|---|---|
| **mechanical** | File/count/version condition — directly measurable | SP runs the `check:` shell expression; exit 0 means the condition is met, non-zero means it isn't |
| **event** | External observable — user reports X, feature ships, test pattern fails | SP scans findings, recent handoffs, and current session for the signal |
| **temporal** | Cadence or version-based — "every release," "after N sessions," "before v6.5" | SP compares against current version, time, or session count |

### 📐 Field shape

```yaml
triggers_logic: any | all   # optional, default 'any' (OR); set 'all' for AND
triggers:
  - type: mechanical | event | temporal
    when: <plain English condition for humans>
    check: <optional: shell expression for type=mechanical — exit 0 if met>
```

### 📊 Worked example — OR semantics (default)

```yaml
triggers:
  - type: temporal
    when: "Any minor release after v5.6.0"
  - type: event
    when: "User reports a misroute in active work"
```

Either trigger firing surfaces the item.

### 📊 Worked example — AND semantics

```yaml
triggers_logic: all
triggers:
  - type: temporal
    when: "v5.9.0 has shipped"
  - type: event
    when: "Claude Code tool-ecosystem audit is complete"
```

Both conditions must hold before the item surfaces.

### 📊 Worked example — mechanical with `check:`

```yaml
triggers:
  - type: mechanical
    when: "SKILL.md exceeds 1500 lines"
    check: |
      [ $(wc -l < SKILL.md) -gt 1500 ]
  - type: mechanical
    when: "Any reference file exceeds 500 lines"
    check: |
      find references -name '*.md' -exec wc -l {} + \
        | awk '$1 > 500 { found=1 } END { exit !found }'
```

The `check:` field is a literal shell expression SP runs via `bash -c`.
Exit 0 means trigger fires; any non-zero exit means it does not. YAML block
scalars (`|`) keep shell quoting clean.

**Awk pattern note.** Use `awk '$1 > 500 { found=1 } END { exit !found }'`,
not `awk '$1 > 500 { exit 0 } END { exit 1 }'`. The second pattern is broken
because awk's `exit` runs the END block before final exit, so `END { exit 1 }`
overrides the match's `exit 0`. The correct pattern uses a flag.

---

## 🔤 Naming convention

Filenames are kebab-case lowercase with a verb prefix, ≤ 60 characters. The
verb signals intent at-a-glance.

### 🏷️ Allowed verb prefixes (the only six)

| Prefix | Maps to label | Use for |
|---|---|---|
| **fix-** | `bug` | Defects, incorrect behavior, error conditions |
| **add-** | `feature` | New capabilities or commands |
| **improve-** | `enhancement` | Refinements of existing functionality |
| **investigate-** | `research` | Open questions, exploration without a committed deliverable |
| **migrate-** | `migration` | Moving from one approach or system to another |
| **redesign-** | `refactor:major` | Deep structural rewrites (rare) |

No date prefixes, no version stamps, no type-tags in filenames. That metadata
lives in the frontmatter (`opened:`, `triggers.type=temporal`, `labels:`),
not the filename.

### 🪜 Mixed-intent items (precedence ladder)

If an item legitimately spans multiple verbs, pick the prefix that represents
the **primary intent**. Precedence when an item plausibly fits more than one:

1. **fix-** — defects always take priority; the bug-fix character dominates
2. **migrate-** — structural moves take priority over enhancements
3. **add-** — new capability over refinement of existing
4. **improve-** — refinement of existing
5. **investigate-** — exploration without a committed deliverable
6. **redesign-** — used standalone for deep rewrites; rarely bundles with another intent

Secondary intents go into the `labels:` field. Example: a fix that adds a new
capability becomes `fix-foo-with-new-bar.md` with `labels: [bug, feature, ...]`.

---

## 🏷️ Labels schema

The `labels:` field is a flat list. Conventional shapes:

- `bug` / `feature` / `enhancement` / `research` / `migration` / `refactor:major`
  — the type (one or more; redundant with the verb prefix but canonical, and
  mixed-intent items list both)
- `priority:high` / `priority:medium` / `priority:low` — priority
- `severity:critical` / `severity:high` / `severity:medium` / `severity:low`
  — severity (bug items only)
- `area:routing` / `area:voice` / `area:hooks` / `area:codex` / `area:closure-walk`
  / etc. — area of the codebase
- `area:unknown` — used at promotion time when the area isn't clear yet; the
  user updates it later. The label is for grouping and search, not for gating
  any logic — items with `area:unknown` are not de-prioritized.

Labels are open-ended; new `area:*` tags can be coined as needed.

---

## 📄 File format template

Full frontmatter for a parked, active, or clarified item:

```yaml
---
title: <verb-led title matching the file's verb prefix>
state: inbox | clarified | parked | active
labels: [<type>, area:<area>, priority:<level>, ...]
opened: YYYY-MM-DD
status_updated: YYYY-MM-DD   # optional — last meaningful frontmatter change
origin: <single sentence — where the item came from>
progress: <optional — one-line summary; used when state=parked with prior work>
triggers_logic: any | all    # optional, default 'any'
triggers:
  - type: mechanical | event | temporal
    when: <plain English condition>
    check: <optional: shell expression for type=mechanical>
---

# <full title>

<body — context, rationale, scope notes, links to related items. No length constraint.>
```

For closed items (in `.handoffs/backlog-archive/`), the frontmatter
additionally carries:

```yaml
state: closed
close_reason: completed | not-planned | duplicate | superseded
closed: YYYY-MM-DD
superseded_by: <reference — only for duplicate and superseded>
```

---

## 🛟 Auto-migration (v6.4 install upgrade)

Every existing SP user has `.backlog/` items in the OLD schema (pre-v6.4).
The new code reads the NEW schema. On first startup after upgrade, SP
scans `.backlog/*.md` and surfaces a one-time migration prompt if old-schema
items are found. The user picks **Migrate now** (script runs immediately),
**Preview** (dry-run shown first), or **Skip** (a flag file is written;
SP renders a banner at orientation bottom until the user runs the migration
manually).

The migration script lives at `.scripts/migrate-backlog.sh` (inside Strategic
Partner's install directory — see SKILL.md § Backlog Auto-Migration for the
canonical invocation pattern). It:

- Runs safety preflights — dirty-tree check, git-repo check, pre-migration
  backup to `.handoffs/pre-migration-backup-YYYYMMDD-HHMMSS/`
- Applies the per-item transformation (verb prefix added, frontmatter
  upgraded, trigger prose converted to a structured list)
- Lands a single atomic commit ONLY when `.backlog/` is tracked by git.
  When `.backlog/` is gitignored — the typical case, since most projects
  treat backlog items as local working state — the commit step is a no-op
  and rollback uses the pre-migration backup directory rather than `git
  revert`. The backup is the universal rollback path; the git commit is
  an optional secondary path that only fires when the project tracks
  `.backlog/`
- Is idempotent — re-runs after a successful migration are no-ops

See `.scripts/migrate-backlog.sh` for the implementation and the design
spec § "Auto-migration" for the full UX details.
