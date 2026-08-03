# Strategic Partner v8.0 — Startup Latency Baseline (BEFORE)

**Instrument:** `tests/startup-latency-probe.sh` (committed — see § Reproducing)
**Measured:** 2026-08-03 against `~/.claude/projects/`
**Purpose:** the number set v8.0 will be judged against. Measurement only; no
startup behaviour was changed to produce it.

---

## 🎯 HEADLINE BASELINE

> ### Green floor · fresh · non-SP projects · main command
>
> | | tools | seconds |
> |---|---|---|
> | **n** | **2** | **2** |
> | median | **16** | **102.2** |
> | p90 / max | 26 | 182.2 |
> | min | 16 | 102.2 |
>
> Both data points in full: **16 silent tool calls / 102.2 s** and
> **26 silent tool calls / 182.2 s**. Neither emitted any text before the
> briefing landed.

**Read this headline with its n.** Two openings is not a distribution — it is
two observations, from the same project (`Harvey-RFPs`) on the same day
(2026-07-01), by the same user. It is reported because the plan asks for this
exact cell, and both observations were hand-verified against their raw
transcripts. It is **not** a number a ±20 % after-measurement can be tested
against.

For a comparison with usable statistical power, use the wider cell:

> ### All openings in non-SP projects (every floor state, fresh + continuation)
>
> | | n | min | median | p90 | max |
> |---|---|---|---|---|---|
> | silent tool calls | **21** | 3 | **12** | **26** | 26 |
> | seconds to opening | **21** | 62.1 | **111.2** | **214.6** | 266.5 |

**Machine-comparable line** (the after-run prints the same line; diff them):

```
SP-STARTUP-BASELINE openings=73 sessions=69 corpus_files=188 range=2026-06-22..2026-08-03 green_fresh_nonsp_n=2 tools_p50=16 tools_p90=26 tools_max=26 secs_p50=102.2 secs_p90=182.2 all_nonsp_n=21 all_nonsp_tools_p50=12 all_nonsp_tools_p90=26 all_nonsp_secs_p50=111.2
```

The plan's target — *a signal line plus ≤ 3 silent calls on green sessions* —
is below the **minimum** observed anywhere in this corpus (3 calls, one session).
No opening in 66 measured openings met it.

---

## 📐 Methodology

### What one measurement is

One **opening**: a user typed an SP command and waited. Not one session — a
session can contain more than one opening (73 openings across 69 sessions).

An opening is counted for these command forms only:

| Counted | Not counted |
|---|---|
| `/strategic-partner` | `copy-prompt`, `handoff`, `serena`, `help` |
| `/strategic-partner-plugin:strategic-partner` | `backlog`, `update`, `codex-feedback` |
| `/strategic-partner-v2:strategic-partner` | `switch-to-skill`, `try-plugin` |
| `/strategic-partner-serena-candidate:strategic-partner` | |
| any `…:status` recenter briefing | |
| (`advisor` / `sp` aliases, if present) | |

`:status` is included because it is structurally an opening — the same orient-
then-brief sequence — and the plan lists it as an SP entry point. It is broken
out separately in every table.

Three natural-language activations (the model invoked the SP skill itself rather
than the user typing a slash command) exist in the corpus and are **not**
counted, because the wait they impose is not attributable to a startup command.
n=3; excluding them cannot move the figures materially.

### The span measured

**Start:** the timestamp on the user's slash-command turn. This is when the
user pressed Enter.

**End:** the first **user-actionable output**, whichever comes first:

1. an assistant text block with **≥ 4 non-blank lines**, or **≥ 2 non-blank
   lines and ≥ 240 characters** — a structured briefing; or
2. an **`AskUserQuestion`** (or `ExitPlanMode`) tool call — a menu.

**Why the menu counts as an ending.** SP's opening menu *is* an
`AskUserQuestion`. Before this rule was added the span ran straight through the
menu the user was already answering and on into the next phase of work. On the
worst session that turned a real *12 calls / 102 s* opening into a reported
*41 calls / 1 660 s*. Ten of 66 openings (15 %) end this way. The menu itself is
not counted as a silent call — it is the visible deliverable.

**Why one-line text does not end the span.** Every progress line in this corpus
is exactly one line ("Starting the session by loading the startup checklist…"),
including ones up to 789 characters. Every real briefing is multi-line. Such
lines are recorded separately as **signal lines** and do not stop the clock.

**Threshold sensitivity — the rule is not load-bearing.** Re-running at
`MIN_LINES`/`MIN_CHARS` of 2/0, 4/240, 6/600 and 8/900 produced a **byte-identical
summary line** every time. The result does not depend on where the threshold sits.

### Metrics recorded per opening

| Metric | Definition |
|---|---|
| silent tool calls | `tool_use` blocks in the span, excluding the terminating menu |
| secs to first output | to the first assistant block of any kind, **including thinking** |
| secs to first visible text | to the first text block, including a one-line signal line |
| secs to the opening | to the span end — the headline latency |
| opening size | characters and non-blank lines of the terminating text block |
| signal line | whether any shorter text block preceded the opening, and its length |
| first user action after | menu answer / next prompt / interrupt / `/exit` / nothing, **and how long after** |

Sub-agent (`Task`) work is covered correctly: the `Task` call counts as one
tool call in the main thread, and its duration lands in the wall clock. Blocks
inside `*/subagents/*` transcripts and `isSidechain: true` lines are excluded.

### Classification rules — and how each was derived

| Category | Rule | Derived from |
|---|---|---|
| **Green floor** | none of the **seven actionable** floor fields is at a non-clean value: `conventions=missing`, `memory=missing`, `git=dirty`, `version=behind`, `routing=missing\|stale`, `oldschema>0`, `commands_registered=no` | the `SP-FLOOR-COMPLETE` hook line, using the non-clean values published in `SKILL.md` § Floor-Signal Handling — SP's own definition, not one invented here |
| **Non-clean floor** | at least one of those seven fired | same |
| **Unclassified floor** | no `SP-FLOOR-COMPLETE` line found for that opening | absence in the transcript |
| **Fresh vs continuation** | `<command-args>` contains `.handoffs/` | the command turn |
| **Empty folder / new project** | floor reports `git=missing` **and** `conventions=missing` | floor line |
| **Standalone skill vs plugin** | command form: `/strategic-partner[:…]` = skill; `…-plugin:` / `-v2:` / `-serena-candidate:` = plugin | command name; cross-checks the floor `plugin=` field |
| **SP dev repo** | project slug `-Users-OldJimmy--config-skillshare-skills-strategic-partner` | transcript directory |
| **SP test harness** | slug matches `SP-Serena-Validation` or `sp-ceremony-smoke` | transcript directory |
| **Session-start vs mid-session** | the opening was the session's first user prompt | position in transcript |

Deliberate choices worth challenging:

- **`version=ahead` and `version=unreachable` do not break green.** SP's own
  table lists only `behind` as actionable. Applying a stricter "every field at
  its ideal value" rule was tested and moved nothing — the green cell stayed at
  n=2.
- **`git=missing` does not break green** either (it is not `dirty`); those
  openings are captured by the empty-folder category instead.
- **A third bucket, `sp-harness`, was added beyond the plan's two.** The plan
  asks only that SP's own repo be separated. But 11 openings come from
  `SP-Serena-Validation` and `/private/tmp/sp-ceremony-smoke` — SP's own
  validation sandboxes, one of which was invoked with the literal argument
  *"Do not dispatch background agents; this is a lifecycle smoke test."*
  Folding synthetic smoke tests into "other projects" would have pulled the
  user-facing median down with runs no user ever waited through. They are
  reported, separately, never blended.

### Statistics

Percentiles use the **nearest-rank (ceiling)** method: for n sorted values, the
p-th percentile is element `ceil(p·n/100)`. Deterministic, integer-preserving,
no interpolation. For even n the median is the lower of the two middle values.
At these sample sizes p90 and max frequently coincide — that is a property of
small n, not a bug.

---

## 📚 Corpus

| | |
|---|---|
| Root | `~/.claude/projects/` (read-only throughout) |
| Transcripts scanned | **188** JSONL files (sub-agent transcripts excluded) |
| SP openings found | **73**, across **69** distinct sessions |
| Opening date range | **2026-06-22 → 2026-08-03** (43 days) |
| Distinct projects | **12** (8 non-SP, 1 SP dev repo, 3 SP test harness dirs) |
| Openings by month | Jun 2026: 2 · Jul 2026: 67 · Aug 2026: 4 |

Split:

| Bucket | Openings | Sessions with a measurable opening |
|---|---|---|
| Non-SP projects | 23 | 21 |
| SP dev repo | 39 | 36 |
| SP test/smoke harness | 11 | 9 |
| **Total** | **73** | **66** |

Non-SP projects contributing openings: `FPS-Labs-bam-ui` (6),
`Bots-THARWAT-Bot` (4), `Padel-Related-BAM-MVP` (4),
`VEHERI-site-migration-AI-opt` (3), `CMRAD-internal-tools-Harvey-RFPs` (3),
`AI-parking-cams-proj` (1), `JARVIS-Obsidian-Setup` (1),
`unibloom-premium-revamp` (1).

A manifest of the exact 69 sessions measured (project, session id, date) is
reproducible with `--manifest`; the one behind this report hashes to
`7492805f7ccea8b6` (sha256, first 16). **The after-run should emit its own
manifest and diff it against this one before claiming a like-for-like
comparison** — `~/.claude/projects/` is live and grows as sessions run.

---

## 📊 Distributions

### A. Silent tool calls before the opening arrives — headline metric

| Category | n | min | median | p90 | max |
|---|---|---|---|---|---|
| **ALL openings** | 66 | 3 | **13** | **21** | 26 |
| main command | 42 | 3 | 14 | 21 | 26 |
| `:status` recenter | 24 | 3 | 12 | 18 | 22 |
| first opening in the session | 62 | 3 | 14 | 20 | 26 |
| opening was the 1st user prompt | 33 | 3 | 14 | 18 | 26 |
| **NON-SP PROJECTS** | **21** | **3** | **12** | **26** | **26** |
| · green floor, fresh | 2 | 16 | 16 | 26 | 26 |
| · green floor, fresh, main cmd | 2 | 16 | 16 | 26 | 26 |
| · green floor, fresh, `:status` | 0 | – | – | – | – |
| · non-clean floor, fresh | 14 | 6 | 12 | 26 | 26 |
| · continuation (`.handoffs` arg) | 2 | 11 | 11 | 13 | 13 |
| · empty folder / no git repo | 1 | 8 | 8 | 8 | 8 |
| · standalone skill install | 6 | 11 | 14 | 26 | 26 |
| · plugin install | 15 | 3 | 12 | 26 | 26 |
| **SP DEV REPO** (separate) | 36 | 3 | 14 | 20 | 22 |
| · green floor, fresh | 15 | 3 | 13 | 19 | 22 |
| · non-clean floor | 14 | 12 | 15 | 19 | 21 |
| · continuation | 1 | 9 | 9 | 9 | 9 |
| **SP TEST/SMOKE HARNESS** (separate) | 9 | 3 | 6 | 16 | 16 |
| Unclassified floor (no floor line) | 10 | 3 | 7 | 20 | 21 |

Quartiles, all openings: **p25 = 9, p50 = 13, p75 = 16, p90 = 21, max = 26**.

### B. Wall-clock seconds until the opening arrives

| Category | n | min | median | p90 | max |
|---|---|---|---|---|---|
| **ALL openings** | 66 | 14.1 | **116.1** | **229.8** | 313.5 |
| **NON-SP PROJECTS** | 21 | 62.1 | **111.2** | 214.6 | 266.5 |
| · green floor, fresh | 2 | 102.2 | 102.2 | 182.2 | 182.2 |
| · non-clean floor, fresh | 14 | 74.6 | 128.2 | 266.5 | 266.5 |
| · continuation | 2 | 72.8 | 72.8 | 168.2 | 168.2 |
| · empty folder | 1 | 101.2 | 101.2 | 101.2 | 101.2 |
| · standalone skill | 6 | 72.8 | 168.2 | 214.6 | 214.6 |
| · plugin | 15 | 62.1 | 101.9 | 266.5 | 266.5 |
| **SP DEV REPO** | 36 | 56.6 | 128.0 | 229.8 | 313.5 |
| **SP TEST/SMOKE HARNESS** | 9 | 14.1 | 40.4 | 233.0 | 233.0 |

**The decomposition is the most actionable part of this report:**

| To… | n | min | median | p90 | max |
|---|---|---|---|---|---|
| first output of ANY kind (incl. thinking) | 71 | 2.3 | **14.6** | 28.5 | 56.5 |
| first VISIBLE TEXT | 70 | 2.6 | **23.1** | 130.5 | 229.8 |
| the OPENING | 66 | 14.1 | **116.1** | 229.8 | 313.5 |

The median user sees *something* after 14.6 s and *some text* after 23.1 s —
then waits another **93 seconds** for the thing they asked for. The gap between
"first text" and "the opening", not the gap before first text, is the cost.

### C. Size of the opening message

Text-terminated openings only (n = 56; the other 10 ended in a menu, 7 never
arrived).

| Metric | n | min | median | p90 | max |
|---|---|---|---|---|---|
| characters, all | 56 | 346 | **1 874** | 2 903 | 3 620 |
| non-blank lines, all | 56 | 2 | **13** | 20 | 29 |
| characters, non-SP | 19 | 1 025 | **2 128** | 2 971 | 2 975 |
| non-blank lines, non-SP | 19 | 3 | **14** | 20 | 21 |

How openings terminate: **56 briefing · 10 menu · 7 never arrived**.

Those 10 menu-terminated openings are worth flagging on their own: the user was
handed a question with nothing but a one-line progress note in front of it. In
one such session (`10a654dd`, SP dev repo) the user answered the menu with
*"why didnt I see the text before the AUQ? :/ shouldnt this be fixed by now"*
and, later, *"still where is the opening text BEFORE the AUQ?"*. That is the
only direct user complaint about openings in the corpus, and it is about a
missing briefing rather than about waiting.

### D. Signal lines

| | count |
|---|---|
| openings **with** a preceding short signal line | **52 / 73 (71 %)** |
| openings with **no** text at all before the opening | 21 / 73 (29 %) |
| · of those, in non-SP projects | 7 |

Tool calls before *any* visible text: **median 0**, p90 16, max 26 (n = 70).
Signal lines run 30–202 characters, always a single line.

**This contradicts the audit's framing, and the correction matters.** See below.

### E. What the user did after the opening

| First action | count | median delay after the opening |
|---|---|---|
| answered the opening menu | 10 | 25.0 s |
| typed another prompt | 32 | 2 075.8 s (~35 min) |
| interrupted (ESC) | 14 | 1 021.0 s (~17 min) |
| `/exit` | 9 | 2 425.3 s (~40 min) |
| no further input at all | 8 | — |

### F. Worst offenders

| tools | secs | repo | form | floor | date | project / session |
|---|---|---|---|---|---|---|
| 26 | 266.5 | other | main | non-clean | 2026-07-09 | `Bots-THARWAT-Bot` / `8954d61f-8b40-47ce-8334-501a8cdd1fc2` |
| 26 | 266.5 | other | main | non-clean | 2026-07-09 | `Bots-THARWAT-Bot` / `d4f84edd-5859-4491-addc-23f49c0d87ec` |
| 26 | 182.2 | other | main | **green** | 2026-07-01 | `CMRAD-internal-tools-Harvey-RFPs` / `c86c646f-8267-4f9c-a628-951c908e6785` |
| 22 | 251.0 | sp-dev | main | green | 2026-08-02 | `strategic-partner` / `d4a9f489-d0a5-4f38-9372-254997529c20` |
| 22 | 197.8 | other | status | non-clean | 2026-07-08 | `Bots-THARWAT-Bot` / `770645bd-a8e3-4592-afb1-ec06b309f3b0` |
| 21 | 229.8 | sp-dev | main | no floor | 2026-07-08 | `strategic-partner` / `86fa7799-f585-4c6c-af60-44acbdb0a983` |
| 21 | 198.9 | sp-dev | main | non-clean | 2026-07-07 | `strategic-partner` / `dbf38e4b-74c0-49df-bb5b-c0a839eda806` |
| 20 | 219.5 | sp-dev | status | no floor | 2026-07-06 | `strategic-partner` / `742650e0-98f7-49e1-9223-26123084c61a` |
| 19 | 186.2 | sp-dev | main | green | 2026-07-09 | `strategic-partner` / `586e489b-91c3-46a0-ac03-2b31e2fbdb09` |
| 19 | 132.2 | sp-dev | main | non-clean | 2026-07-07 | `strategic-partner` / `70aac132-8b76-4f00-81b4-acfc12f20ab9` |
| 16 | **313.5** | sp-dev | status | non-clean | 2026-07-24 | `strategic-partner` / `f6c212b8-5b3d-43b3-bd44-aca48a62ba90` |

Slowest by wall clock, not by call count: `f6c212b8` at **313.5 s** on only 16
calls — evidence that call count and latency are separable, and that a fix
capping call count does not automatically cap the wait.

**The single most user-facing case is row 3**: a *green*, *fresh*, non-SP
project, 26 silent calls, **182 seconds with no output whatsoever** — no signal
line, no thinking text the user could read as progress — before a 2 975-character
briefing appeared.

### G. Which floor signals fired (non-SP, non-clean)

| signal | openings |
|---|---|
| `git` (dirty) | 8 |
| `routing` (missing/stale) | 6 |
| `oldschema` (> 0) | 6 |
| `version` (behind) | 4 |
| `memory` (missing) | 2 |
| `conventions` (missing) | 2 |

This is why the green cell is n=2: in real projects the working tree is usually
dirty and the routing matrix usually absent. **A design that only gets fast when
the floor is green will be fast for almost nobody** — 17 of 23 non-SP openings
had a non-clean floor.

---

## 🔍 Where this contradicts the earlier 8–16 figure

The audit reported **"8–16 silent tool calls before the user sees a single
character."** Measured properly, that splits into one half right and one half
wrong.

**The call count is roughly right, and is really an interquartile range.**
Across 66 openings: p25 = 9, p75 = 16. 40 of 66 openings (61 %) fall inside
8–16. But 14 (21 %) are **above** 16, reaching 26 — so quoting 8–16 as the range
hides the tail, which is exactly the part that hurts. And 12 (18 %) are below 8.

**"Before the user sees a single character" is wrong for most openings.**
52 of 73 openings (71 %) emit a short one-line signal first, at a median of
**zero** tool calls. Those users do see characters — quickly. What they then do
is wait ~93 seconds more, through ~13 further silent calls, for the actual
briefing.

**Why this measurement is better:**

1. **It is a census, not a sample.** All 188 transcripts, all 73 openings,
   rather than "a handful of transcripts" eyeballed.
2. **It parses structure instead of reading prose.** Tool calls are counted from
   `tool_use` blocks; text is counted from `text` blocks. Nothing is inferred
   from how a transcript looks.
3. **It carries wall clock, which the earlier figure lacked entirely.** Call
   count alone cannot distinguish 26 fast calls (182 s) from 16 slow ones
   (313 s). Both exist here.
4. **It separates SP's own repo and its smoke harnesses** from user-facing work.
   The earlier figure did not, and SP's dev repo supplies 39 of 73 openings —
   more than half — with an unusually large memory and decision log.
5. **It survived being wrong once.** The first version of the span rule ran past
   `AskUserQuestion` menus and reported a 41-call / 1 660-second worst case. That
   number was an artefact. It was caught by hand-checking outliers against raw
   transcripts, and the corrected worst case is 26 calls / 313.5 s.

**Practical consequence for v8.0's target.** The target is *"a signal line plus
≤ 3 silent calls on green sessions."* The signal-line half is already met 71 % of
the time and is not where the pain is. The ≤ 3 calls half is far from current
behaviour: the minimum observed anywhere is 3, the non-SP median is 12, and no
green non-SP opening came in under 16.

---

## ⚠️ Abandonment — the honest number is essentially zero

The audit says a session was abandoned at the opening menu. **That is not
reproducible in this corpus.** Counting plainly:

| Signal | count |
|---|---|
| interrupted **before** the opening ever arrived | **0** |
| quit (ESC or `/exit`) **within 60 s** of the opening arriving | **1** |
| opening arrived, user never responded at all | 5 (4 non-SP) |
| opening never arrived at all | 7 (2 non-SP) |

A naive count — "first action after the opening was interrupt, `/exit`, or
nothing" — gives **31 of 73 (42 %)**, and that number would be misleading. Once
the *delay* to that action is measured, it collapses: the 14 interrupts came a
median of **17 minutes** after the opening (range 45.5 s to 8.4 days), and the
9 `/exit`s came a median of **40 minutes** after (earliest 497 s). These are
ordinary mid-session ESC presses and end-of-session exits, not people quitting at
a menu. Reporting 42 % as opening abandonment would have been a fabricated
result; it is recorded here only so the trap is visible.

**Say it plainly: the latency is real and large, but this corpus does not show
it causing abandonment.** The one qualitative artefact that does exist is the
user complaint quoted in § C — and it is about a *missing briefing before the
menu*, not about the wait.

---

## 🚨 Threats to validity

1. **The headline cell is n=2.** Same project, same day, same user. Do not treat
   a change in it as signal.
2. **One user, one machine.** Every session is from a single developer. Tool
   latency, MCP server set (Serena is installed and used heavily during
   startup), disk speed, and model choice are all constant here and would differ
   elsewhere.
3. **SP's dev repo dominates the corpus** — 39 of 73 openings. It is separated
   everywhere, but it means the non-SP figures rest on 23 openings from 8
   projects.
4. **Thinking blocks render in Claude Code.** The probe counts only `text`
   blocks as visible output, per the brief. Users do see thinking text, so
   "the user sees nothing" overstates the case: median time to *any* assistant
   output is 14.6 s, versus 23.1 s to text. The 182-second row in § F is the
   genuinely silent case — it has no leading text at all.
5. **Model mix is uncontrolled and changed inside the window.** Sessions span
   Opus 4.7/4.8, Fable 5 and Opus 5. Extended-thinking time is a large share of
   the wall clock and varies by model and effort setting. An after-run on a
   different model cannot attribute a wall-clock delta to v8.0 alone. **Tool
   count is the more robust comparator; wall clock is context.**
6. **"Fresh" means "invoked without a handoff argument", not "no prior
   context".** Session `c86c646f` — a headline data point — resumed a handoff
   the model discovered by itself. Only 2 openings carried an explicit
   `.handoffs/` argument, so the continuation cell is nearly empty by
   construction.
7. **Empty-folder is n=1** and is inferred from floor fields (`git=missing` +
   `conventions=missing`), not from a file count — a directory's contents at the
   time of a past session cannot be reconstructed now.
8. **10 openings have no floor line** and cannot be placed in green vs non-clean.
   They are in an explicit unclassified bucket, never silently folded into
   either. None had a usable earlier floor line to fall back on.
9. **7 openings never produced an opening at all** and are excluded from every
   latency table (they have no end timestamp). They are counted in § E.
10. **Zero openings were dropped for missing or unparseable timestamps.**
11. **The corpus is live.** `~/.claude/projects/` grows while sessions run,
    including the session that produced this report. The probe is deterministic
    over a fixed corpus (verified: two consecutive runs were byte-identical),
    but not across time. Hence the manifest.
12. **Percentiles at n ≤ 21 are coarse.** p90 and max coincide in several cells.
13. **`:status` openings are structurally lighter** than main openings
    (median 12 vs 14 calls) and are 24 of 73. Mixing the two shifts "ALL
    openings" downward; that is why every table splits them.

---

## 🔁 Reproducing

```bash
tests/startup-latency-probe.sh                       # full report to stdout
tests/startup-latency-probe.sh --records out.tsv     # one row per opening
tests/startup-latency-probe.sh --manifest man.tsv    # exact sessions measured
```

- **Requires `jq`.** Absent, the probe exits 3 with an explicit message rather
  than reporting zeros — BSD `grep` caps bounded repetition at 255 characters,
  which silently truncates the floor status line, so a grep fallback would
  produce quiet garbage.
- Exits 4 if it scans transcripts and finds no openings, rather than printing an
  empty table.
- macOS `bash` 3.2 clean: no associative arrays, no namerefs. BSD `awk` clean:
  epoch conversion uses a hand-rolled days-from-civil routine, since BSD `awk`
  has no `mktime`.
- Deterministic: file list and all sorts are `LC_ALL=C`; no wall-clock value
  enters the output. Two consecutive runs over this corpus were byte-identical.
- Tunable via `SUBSTANTIVE_MIN_LINES`, `SUBSTANTIVE_MIN_CHARS`, `SP_DEV_SLUG`,
  `SP_HARNESS_RE`, `CORPUS_ROOT` — all documented at the top of the script.
- The corpus is opened read-only. The probe never writes inside
  `~/.claude/projects/`.

`tests/` is gitignored wholesale in this repo, so `.gitignore` gained an
explicit allowlist entry for this file, matching the existing pattern for
`.scripts/release-publish.sh`. The instrument is committed, not left in a
working tree.

### For the after-measurement

1. Run the probe, emit a manifest, and diff it against the baseline manifest —
   state explicitly whether the corpora overlap.
2. Diff the `SP-STARTUP-BASELINE` lines.
3. Compare **`all_nonsp_tools_p50` / `p90`** as the primary judgement (n=21),
   not `green_fresh_nonsp` (n=2).
4. Treat wall-clock deltas as directional only unless the model and effort
   settings match this window.
