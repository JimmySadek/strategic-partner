# Strategic Partner v8.0 — Startup Latency Baseline v2 (CORRECTED BEFORE)

**Instrument:** `tests/startup-latency-probe.sh` (committed — see § Reproducing)
**Measured:** 2026-08-03 against `~/.claude/projects/`
**Supersedes:** `BASELINE-REPORT.md` (v1), which stays in the repository as
history. v1 is not edited; every correction lives here.
**Purpose:** the number set v8.0 is judged against, after an independent
verification found five defects in the instrument that produced v1. Measurement
only; no startup behaviour was changed to produce it.

---

## 🎯 HEADLINE BASELINE

> ### All openings in non-SP projects — the judgement cell
>
> | | n | min | median | p90 | max |
> |---|---|---|---|---|---|
> | tool calls before control returns | **21** | 3 | **12** | **22** | 26 |
> | seconds until control returns | **21** | 62.1 | **111.2** | 200.8 | 266.5 |
>
> Split by command form, because a shifting mix could move the aggregate
> without either path improving:
>
> | Stratum | n | min | median | p90 | max |
> |---|---|---|---|---|---|
> | main command | 12 | 8 | **14** | **26** | 26 |
> | `:status` recenter | 9 | 3 | **12** | **22** | 22 |

**The green cell is retired as the release gate.** It is still reported, and it
is still two observations:

> ### Green floor · fresh · non-SP · main command
>
> | | tools | seconds |
> |---|---|---|
> | **n** | **2** | **2** |
> | median | 16 | 102.2 |
> | max | 26 | 182.2 |
>
> Both points in full: **16 calls / 102.2 s** and **26 calls / 182.2 s**. At
> n=2 the nearest-rank median *is* the minimum — that cell reports its own
> smaller value, not a central tendency. Read it as a pair, never as a p50.

**The render-before-ask number.** Nine openings returned control to the user
without ever telling them anything: every one handed over an `AskUserQuestion`
menu with no briefing in front of it. Two of the nine are in non-SP projects.
That is the defect v8.0 is judged on, and v1 could not see it because it scored
a menu as an arrival.

**Machine-comparable line** (the after-run prints the same line; diff field by
field):

```
SP-STARTUP-BASELINE openings=71 sessions=67 corpus_files=188 range=2026-06-22..2026-08-03 dedup_removed=2 green_fresh_nonsp_n=2 tools_p50=16 tools_p90=26 tools_max=26 secs_p50=102.2 secs_p90=182.2 all_nonsp_n=21 all_nonsp_tools_p50=12 all_nonsp_tools_p90=22 all_nonsp_tools_max=26 all_nonsp_secs_p50=111.2 all_nonsp_secs_p90=200.8 nonsp_main_n=12 nonsp_main_tools_p50=14 nonsp_main_tools_p90=26 nonsp_status_n=9 nonsp_status_tools_p50=12 nonsp_status_tools_p90=22 nonsp_task_calls_p50=0 nonsp_task_calls_max=1 nonsp_tools_extask_p50=12 nonsp_tools_extask_p90=22 briefing_present=56 briefing_absent=9 signal_line=50/71 text_before_any_tool=46/71 paired_text_to_brief_n=56 paired_text_to_brief_p50=76.7 paired_text_to_brief_p90=203.3 paired_text_to_brief_nonsp_n=19 paired_text_to_brief_nonsp_p50=87.1 paired_text_to_brief_nonsp_p90=187.6 jq_unparsed=0 manifest_sha=8027fd07bd927244
```

---

## 🔄 What changed from v1, and why

Five defects, each found by an independent re-derivation of v1's numbers
(`.handoffs/codex-baseline-verification-2026-08-03.md`), plus two smaller
robustness items carried over from the same review.

| # | Fix | Why it mattered | Effect on the numbers |
|---|---|---|---|
| **1** | **Deduplicate openings by user-event UUID**, not by transcript filename | A forked transcript replays the same opening event — same command timestamp, same UUID — into a second file. v1 counted those as two separate waits. | 73 → **71** openings, 69 → **67** session histories. Non-SP p90 falls 26 → **22**. |
| **2** | **Cohort boundary:** `--since <ISO-date>` and `--exclude-manifest <file>` | The corpus grows. Without a boundary the after-run rescans everything and dilutes the post-change result with the 188 baseline files. | No effect on this run. Enables a clean after-run — see § Negative test. |
| **3** | **Split control-return from briefing** | A menu returns control but says nothing. v1 called that "the opening arrived", which makes render-before-ask unmeasurable. | **9 openings now record briefing = ABSENT** instead of a latency number. New `time_to_briefing` metric alongside `time_to_first_actionable_control`. |
| **4** | **Carry floor classification forward within a session** | The floor hook stays silent once it has run for a scope, so a second opening in the same session had no floor line and fell into "unclassified". | Unclassified floor 10 → **6**. Four second-in-session openings reclassified. Empty-folder cell **n=1 → n=2**. |
| **5** | **Count sub-agent dispatch separately** | One sub-agent call counts as one tool call however much work it hides, so a tool-count target could be met by moving work into sub-agents rather than removing it. | New `task_calls` and `tools_excluding_task` per opening. Baseline: p50 **0**, max **1**; 2 openings dispatched one each. |
| LOW | **Count and report `jq` parse errors per file** | v1 sent `jq` stderr to `/dev/null`, so a malformed transcript would have lost events silently. | 0 unparsed files in this corpus. The counter is now in the header, in § G, and in the summary line as `jq_unparsed=`. |
| LOW | **State the nearest-rank caveat at n=2** | At even n the nearest-rank median is the lower of the two middle values, so at n=2 it equals the minimum. | Printed in the run header; stated at every small-n cell here. |

### 🔍 Two corrections to the review's own figures

The review is right about the defects. Two of its published numbers do not
survive its own dedup rule, and one is labelled imprecisely. Both are reported
here rather than quietly reproduced.

**The menu count is 9, not 10.** The review's finding 3 states that "10 measured
openings ended at a menu". That is v1's pre-dedup count. One of those ten —
`0242045a…` in the SP dev repo — is a duplicate fork of `fab556fb…`, and both
copies were menu-terminated. Applying the review's own deduplication leaves
**9** menu-terminated, briefing-absent openings. The substance is unchanged:
every one of them is briefing-absent, and two are in non-SP projects, exactly as
the review says.

**The paired gap is `first text → control`, not `first text → briefing`.** The
review reports "80.1 s overall / 67.0 s non-SP" and a "67.0/179.2 baseline". The
probe reproduces all three of those exactly — as the **control** gap, over the
review's cohort. The two labels diverge for the overall figure because
menu-terminated openings have a control endpoint but no briefing:

| Paired gap (review cohort) | n | median | p90 |
|---|---|---|---|
| first text → **control**, all | 64 | **80.1** | 187.6 |
| first text → **control**, non-SP | 20 | **67.0** | **179.2** |
| first text → briefing, all | 55 | 76.7 | 203.3 |
| first text → briefing, non-SP | 18 | **67.0** | 187.6 |

For non-SP the two coincide at **67.0 s**, so the review's non-SP target is
unambiguous either way. For the overall figure they do not: 80.1 s is the
control gap, 76.7 s the briefing gap. Both are reported so the v8.0 contract can
name the one it means.

### 📅 One corpus change since the review ran

`~/.claude/projects/` is live. Between the review (13:13) and this run, one
session — `e0bf58ea…` in `VEHERI-site-migration-AI-opt`, last written 13:47:50 —
finished the opening that was still in flight when the review counted it. No
file was added or removed: the manifest of v1 still hashes to
`7492805f7ccea8b6`, byte for byte. Only that transcript's contents grew.

| | Review's corpus state | This run |
|---|---|---|
| openings / session histories | 71 / 67 | 71 / 67 |
| openings that never arrived | 7 | **6** |
| non-SP measurable openings | 20 | **21** |
| non-SP main stratum | n=11 | **n=12** |

This is the exact failure mode fix 2 exists to prevent, and it is why every
figure below is given twice: once over the current corpus, once over the
review's cohort, reproduced with the probe's own `--exclude-manifest` flag
rather than by hand.

---

## 📐 Methodology — what is different from v1

Everything not listed here is unchanged from `BASELINE-REPORT.md` § Methodology:
the counted command forms, the substantive-text thresholds and their
insensitivity, the green / non-clean predicate over the seven actionable floor
fields, the SP-dev and harness separation, and nearest-rank percentiles.

### Two endpoints, not one

| Metric | Ends at | Absent when |
|---|---|---|
| `time_to_first_actionable_control` | a structured briefing **or** an `AskUserQuestion` / `ExitPlanMode` menu, whichever is first | the span reaches the user's next input with neither |
| `time_to_briefing` | a structured briefing **only** — a menu never ends it | control returned via a menu and no briefing landed before the user acted |

A menu-terminated opening with no briefing records **`briefing = ABSENT`**, not
a number. It is not folded into the briefing distribution and it does not
average away.

The briefing search closes when the user acts — including answering the menu,
which arrives as a tool result rather than a typed prompt. Text the model writes
*after* the user answers is a response to that answer, not the opening briefing.
In this corpus **zero** openings had a briefing land between the menu and the
user's answer, so all nine menu-terminated openings are briefing-absent.

### Deduplication

Openings are grouped by the **user-event UUID** of the command turn. Within a
group the probe keeps the copy whose transcript runs furthest past the opening,
measured as the number of events following it. The fork that stops shortly after
the opening is a truncated replay; scoring it as "user never responded" is an
artefact of the fork, not an observation.

Both duplicate pairs, with the evidence the tie-break used:

| Opening UUID | Transcript | Events after opening | |
|---|---|---|---|
| `7150be11…` | `8954d61f…` (THARWAT) | 159 | **kept** |
| `7150be11…` | `d4f84edd…` (THARWAT) | 83 | dropped — this is the copy v1 scored as "no response" |
| `eda7024f…` | `fab556fb…` (SP dev) | 387 | **kept** |
| `eda7024f…` | `0242045a…` (SP dev) | 386 | dropped — menu-terminated, the tenth "menu" of v1 |

### Floor carry-forward

A floor line captured anywhere earlier in a transcript is inherited by a later
opening in that transcript when no newer floor line has appeared. Four openings
changed classification, all of them the **second** opening in their session:

| Project | Session | Now classified |
|---|---|---|
| SP dev repo | `86fa7799…` | non-clean (`git`, `version`) |
| SP dev repo | `d66d25db…` | non-clean (`version`) |
| SP-Serena-Validation | `93900298…` | non-clean (`memory`, `version`, `routing`) |
| `VEHERI-site-migration-AI-opt` | `9ab19596…` | non-clean **+ empty folder** |

The VEHERI row is the one the review named: a second SP command about 12 seconds
after the same empty-folder floor. It moves the empty-folder cell from n=1 to
**n=2**.

### Sub-agent counting

The sub-agent dispatch tool is named **`Agent`** in every transcript in this
corpus; `Task` is the name used by other Claude Code versions. The probe matches
**both, by exact name**. This matters: `TaskCreate` and `TaskUpdate` are
todo-list tools that appear 229 times in the corpus, and a prefix match would
have folded them in and reported a sub-agent count that is almost entirely
todo-list bookkeeping.

### Cohort boundary

`--since <ISO-date>` keeps openings on or after a date. `--exclude-manifest
<file>` drops every opening listed in a manifest. Either works alone or with the
other. A manifest is `slug ⇥ session ⇥ date ⇥ opening-uuid`; exclusion matches on
the UUID when present and on slug/session/date otherwise, so v1-era three-column
manifests still work (verified — see § Negative test).

An empty cohort is reported as an empty cohort and exits **0**. Only a corpus
that yields no openings at all is treated as a broken run (exit 4). Collapsing
those two cases would make "I correctly excluded everything" indistinguishable
from "extraction broke".

---

## 📚 Corpus

| | |
|---|---|
| Root | `~/.claude/projects/` (read-only throughout) |
| Transcripts scanned | **188** JSONL files (sub-agent transcripts excluded) |
| Transcripts `jq` could not parse | **0** |
| Raw opening events | 73 |
| Duplicate forks removed | **2** |
| **SP openings measured** | **71**, across **67** session histories |
| Opening date range | **2026-06-22 → 2026-08-03** (43 days) |
| Distinct projects | **12** (8 non-SP, 1 SP dev repo, 3 SP test-harness dirs) |
| Openings by month | Jun 2026: 2 · Jul 2026: 65 · Aug 2026: 4 |
| Manifest | `baseline-v2-manifest.tsv` — 71 rows, sha256 (first 16) **`8027fd07bd927244`** |

| Bucket | Openings | Session histories | Control returned |
|---|---|---|---|
| Non-SP projects | 22 | 21 | 21 |
| SP dev repo | 38 | 36 | 35 |
| SP test/smoke harness | 11 | 10 | 9 |
| **Total** | **71** | **67** | **65** |

Non-SP projects contributing openings: `FPS-Labs-bam-ui` (6),
`Padel-Related-BAM-MVP` (4), `VEHERI-site-migration-AI-opt` (3),
`CMRAD-internal-tools-Harvey-RFPs` (3), `Bots-THARWAT-Bot` (3),
`AI-parking-cams-proj` (1), `JARVIS-Obsidian-Setup` (1),
`unibloom-premium-revamp` (1).

`Bots-THARWAT-Bot` drops from 4 openings to 3: the fourth was the duplicate
fork.

---

## 📊 Distributions

### A. Tool calls before control returns

| Category | n | min | median | p90 | max |
|---|---|---|---|---|---|
| **ALL openings** | 65 | 3 | **13** | **20** | 26 |
| main command | 41 | 3 | 14 | 21 | 26 |
| `:status` recenter | 24 | 3 | 12 | 18 | 22 |
| first opening in the session | 61 | 3 | 14 | 19 | 26 |
| opening was the 1st user prompt | 32 | 3 | 13 | 18 | 26 |
| **NON-SP PROJECTS** | **21** | **3** | **12** | **22** | **26** |
| · main command | 12 | 8 | **14** | **26** | 26 |
| · `:status` recenter | 9 | 3 | **12** | **22** | 22 |
| · green floor, fresh | 2 | 16 | 16 | 26 | 26 |
| · green floor, fresh, main cmd | 2 | 16 | 16 | 26 | 26 |
| · green floor, fresh, `:status` | 0 | – | – | – | – |
| · non-clean floor, fresh | 15 | 6 | 12 | 22 | 26 |
| · continuation (`.handoffs` arg) | 2 | 11 | 11 | 13 | 13 |
| · **empty folder / no git repo** | **2** | 8 | 8 | 12 | 12 |
| · standalone skill install | 6 | 11 | 14 | 26 | 26 |
| · plugin install | 15 | 3 | 12 | 22 | 26 |
| **SP DEV REPO** (separate) | 35 | 3 | 15 | 20 | 22 |
| · green floor, fresh | 15 | 3 | 13 | 19 | 22 |
| · non-clean floor | 15 | 6 | 16 | 21 | 21 |
| · continuation | 1 | 9 | 9 | 9 | 9 |
| **SP TEST/SMOKE HARNESS** (separate) | 9 | 3 | 6 | 16 | 16 |
| Unclassified floor (no floor line) | 6 | 3 | 7 | 20 | 20 |

### A2. Sub-agent dispatch inside that count

| Metric | n | min | median | p90 | max |
|---|---|---|---|---|---|
| tool calls TOTAL, non-SP | 21 | 3 | **12** | **22** | 26 |
| · of which sub-agent | 21 | 0 | **0** | 0 | **1** |
| · total excluding sub-agent | 21 | 3 | **12** | **22** | 26 |
| tool calls TOTAL, all | 65 | 3 | 13 | 20 | 26 |
| · of which sub-agent | 65 | 0 | 0 | 0 | 1 |
| · total excluding sub-agent | 65 | 3 | 13 | 20 | 26 |

Only **2** openings dispatched a sub-agent, one call each, both in non-SP
projects: `unibloom-premium-revamp / 52241bac…` (11 calls, 168.2 s) and
`FPS-Labs-bam-ui / 9d3fa6ce…` (14 calls, 214.6 s).

Today's startup does essentially no sub-agent work, so total and
total-excluding-sub-agent are identical at every percentile. That is the point of
recording it: **the baseline for sub-agent usage is p50 = 0, max = 1**, so any
after-run where the tool total falls while the sub-agent count rises is moving
work, not removing it. Without this column that substitution is invisible.

### B. Wall-clock seconds until control returns

| Category | n | min | median | p90 | max |
|---|---|---|---|---|---|
| **ALL openings** | 65 | 14.1 | **122.3** | 219.5 | 313.5 |
| **NON-SP PROJECTS** | 21 | 62.1 | **111.2** | 200.8 | 266.5 |
| · green floor, fresh | 2 | 102.2 | 102.2 | 182.2 | 182.2 |
| · non-clean floor, fresh | 15 | 74.6 | 128.2 | 214.6 | 266.5 |
| · continuation | 2 | 72.8 | 72.8 | 168.2 | 168.2 |
| · empty folder | 2 | 100.2 | 100.2 | 101.2 | 101.2 |
| · standalone skill | 6 | 72.8 | 168.2 | 214.6 | 214.6 |
| · plugin | 15 | 62.1 | 101.9 | 197.8 | 266.5 |
| **SP DEV REPO** | 35 | 56.6 | 128.9 | 229.8 | 313.5 |
| **SP TEST/SMOKE HARNESS** | 9 | 14.1 | 40.4 | 233.0 | 233.0 |

Decomposition, all openings:

| To… | n | min | median | p90 | max |
|---|---|---|---|---|---|
| first output of ANY kind (incl. thinking) | 69 | 2.3 | **14.2** | 29.0 | 56.5 |
| first VISIBLE TEXT | 68 | 2.6 | **22.6** | 132.2 | 229.8 |
| control returning | 65 | 14.1 | **122.3** | 219.5 | 313.5 |

**Do not subtract those medians.** They come from different populations, and
`122.3 − 22.6` is not a wait anyone experienced. The paired figures are in § C2.

### C. Size of the opening message

Text-terminated openings only (n = 56; 9 ended at a menu, 6 never arrived).

| Metric | n | min | median | p90 | max |
|---|---|---|---|---|---|
| characters, all | 56 | 346 | **1 851** | 2 903 | 3 620 |
| non-blank lines, all | 56 | 2 | **13** | 20 | 29 |
| characters, non-SP | 19 | 1 025 | **1 874** | 2 971 | 2 975 |
| non-blank lines, non-SP | 19 | 3 | **14** | 20 | 21 |

### C2. Control returned vs user actually briefed

| | count |
|---|---|
| openings where the briefing **was** the endpoint | 56 |
| **BRIEFING ABSENT — control returned, nothing said** | **9** |
| · of those, in non-SP projects | **2** |
| · of those, ended at a menu | 9 |
| briefing landed *after* control returned | 0 |
| openings that never returned control at all | 6 |

| Seconds from the command | n | min | median | p90 | max |
|---|---|---|---|---|---|
| control returned, all | 65 | 14.1 | **122.3** | 219.5 | 313.5 |
| briefing rendered, all | 56 | 14.1 | **125.6** | 229.8 | 313.5 |
| control returned, non-SP | 21 | 62.1 | **111.2** | 200.8 | 266.5 |
| briefing rendered, non-SP | 19 | 72.8 | **111.2** | 214.6 | 266.5 |

Paired per-opening gaps — each row is a distribution of real per-opening
differences, **not** one median minus another:

| Gap | n | min | median | p90 | max |
|---|---|---|---|---|---|
| first text → briefing, all | 56 | 0.0 | **76.7** | 203.3 | 302.4 |
| first text → briefing, non-SP | 19 | 0.0 | **87.1** | 187.6 | 243.3 |
| first text → control, all | 65 | 0.0 | **82.6** | 187.6 | 302.4 |
| first text → control, non-SP | 21 | 0.0 | **87.1** | 179.2 | 243.3 |

The review's cohort produces **80.1 / 67.0 / 179.2** for the same rows; see
§ Verification.

### D. Signal lines

| | count |
|---|---|
| openings **with** a preceding short signal line | **50 / 71 (70.4 %)** |
| openings that emitted text **before any tool call** | **46 / 71 (64.8 %)** |
| openings with no text at all before control returned | 21 / 71 |
| · of those, in non-SP projects | 7 |

Tool calls before any visible text: median **0**, p90 16, max 26 (n = 68).

"Emitted text before any tool call" is the stronger reading of *visible progress
first*, and it is the one v8.0's 100 % floor should be written against — 64.8 %,
not 70.4 %.

### E. What the user did after the opening

| First action | count | median delay after control returned | delay n |
|---|---|---|---|
| answered the opening menu | 9 | 160.2 s | 9 |
| typed another prompt | 33 | 2 075.8 s (~35 min) | 30 |
| interrupted (ESC) | 14 | 1 021.0 s (~17 min) | 14 |
| `/exit` | 9 | 2 425.3 s (~40 min) | 8 |
| no further input at all | 6 | — | – |

Counts total 71. The delay column has a smaller n wherever control never
returned, because there is no endpoint to measure the delay from.

### F. Worst offenders by tool count (top 5 of 15)

| tools | secs | repo | form | floor | date | project / session |
|---|---|---|---|---|---|---|
| 26 | 266.5 | other | main | non-clean | 2026-07-09 | `Bots-THARWAT-Bot` / `8954d61f…` |
| 26 | 182.2 | other | main | **green** | 2026-07-01 | `CMRAD-internal-tools-Harvey-RFPs` / `c86c646f…` |
| 22 | 251.0 | sp-dev | main | green | 2026-08-02 | `strategic-partner` / `d4a9f489…` |
| 22 | 197.8 | other | status | non-clean | 2026-07-08 | `Bots-THARWAT-Bot` / `770645bd…` |
| 21 | 229.8 | sp-dev | main | non-clean | 2026-07-08 | `strategic-partner` / `86fa7799…` |

The duplicate `d4f84edd…` row that sat at #2 in v1 is gone — it was the same
wait as row 1, counted twice.

Slowest by wall clock is still `f6c212b8…` at **313.5 s on 16 calls**: call count
and latency are separable, and capping the count does not cap the wait.

**Row 2 remains the most user-facing case** — green floor, fresh, non-SP, 26
calls, 182.2 s before a 2 975-character briefing. Per the review, describe it as
**no user-facing briefing text**, not "no output": it emitted a thinking block
after 11.8 s, then visible tool activity. The wait is real; literal silence is
not.

### G. Unclassified / excluded

| | count |
|---|---|
| openings with no floor line (unclassified) | **6** (was 10) |
| · floor inherited from an earlier line in the session | **4** |
| openings with unusable timestamps | 0 |
| openings where control never returned | 6 |
| duplicate fork copies removed | **2** |
| transcripts `jq` could not fully parse | **0** |

### H. Which floor signals fired (non-SP, non-clean)

| signal | openings |
|---|---|
| `routing` (missing/stale) | 7 |
| `git` (dirty) | 7 |
| `oldschema` (> 0) | 6 |
| `version` (behind) | 4 |
| `memory` (missing) | 3 |
| `conventions` (missing) | 3 |

The v1 conclusion survives deduplication and reclassification: in real projects
the working tree is usually dirty and the routing matrix usually absent, so **a
design that only gets fast on a green floor will be fast for almost nobody.**

---

## 🔬 Verification against the review's corrected figures

Two runs of the same committed probe over the same corpus. The **review cohort**
column is produced by `--exclude-manifest` with a one-row manifest naming the
single session that completed after the review ran — the probe's own cohort
machinery, not a hand edit.

| Figure the review specified | Expected | Current corpus | Review cohort | Verdict |
|---|---|---|---|---|
| unique openings | 71 | **71** | 70 | ✅ MATCH |
| session histories | 67 | **67** | 66 | ✅ MATCH |
| non-SP cell n | 20 | 21 | **20** | ✅ MATCH (review cohort) |
| non-SP tools p50 | 12 | **12** | **12** | ✅ MATCH |
| non-SP tools p90 | 22 | **22** | **22** | ✅ MATCH |
| non-SP tools max | 26 | **26** | **26** | ✅ MATCH |
| signal-line rate | 50/71 | **50/71** | 49/70 | ✅ MATCH |
| text before any tool call | 46/71 | **46/71** | 45/70 | ✅ MATCH |
| paired gap p50, overall | 80.1 s | 82.6 s | **80.1 s** | ✅ MATCH (review cohort, control gap) |
| paired gap p50, non-SP | 67.0 s | 87.1 s | **67.0 s** | ✅ MATCH (review cohort) |
| paired gap p90, non-SP | 179.2 s | 179.2 s | **179.2 s** | ✅ MATCH |
| empty-folder cell n | 2 | **2** | **2** | ✅ MATCH |
| non-SP main stratum | n=11, p50=14, p90=26 | n=12, p50=14, p90=26 | **n=11, p50=14, p90=26** | ✅ MATCH (review cohort) |
| non-SP `:status` stratum | n=9, p50=12, p90=22 | **n=9, p50=12, p90=22** | **n=9, p50=12, p90=22** | ✅ MATCH |
| two consecutive runs byte-identical | yes | **yes** | — | ✅ MATCH |
| menu-terminated openings | 10 | **9** | **9** | ⚠️ MISMATCH — see below |

**Every figure reproduces.** Four of them need the review's cohort rather than
the current corpus, for one reason: the transcript `e0bf58ea…`
(`VEHERI-site-migration-AI-opt`, 2026-08-03) finished its opening after the
review was written. Under the review's cohort every one of those four lands on
the review's exact value.

The manifest diff behind that claim is one row:

```
-Users-OldJimmy-Developer-Work-VEHERI-site-migration-AI-opt	e0bf58ea-b893-4445-88a3-d49d2c9784e8	2026-08-03	cdd014fc-0e0f-4f99-a85d-ad6d2b4f37fb
```

No transcript was added or removed. v1's three-column manifest still hashes to
`7492805f7ccea8b6` exactly, which is precisely why a file-level manifest is not
sufficient on a live corpus — content can grow underneath an unchanged hash. The
v2 manifest is opening-level (71 rows, one per UUID) and hashes to
`8027fd07bd927244`.

**The one mismatch is a correction to the review, not a failure to reproduce
it.** The review says ten openings ended at a menu. That count predates its own
deduplication rule: `0242045a…` and `fab556fb…` are the same menu-terminated
opening in two forked transcripts. Deduplicating leaves **9**. All nine are
briefing-absent and two are non-SP, both exactly as the review states. v8.0's
render-before-ask target should be written against **9 / 9**.

---

## 🧪 Negative test — the cohort boundary

The after-run must be unable to blend with this baseline. Excluding this
report's own manifest must therefore leave nothing.

The manifest is committed alongside this report as `baseline-v2-manifest.tsv`,
so the after-run can exclude this cohort without regenerating it from a corpus
that will have moved on.

```
$ tests/startup-latency-probe.sh --exclude-manifest baseline-v2-manifest.tsv

transcripts scanned : 188
openings found      : 73 raw, 71 after UUID deduplication
cohort is EMPTY     : every opening was excluded by the cohort boundary
excluded by --since (unset)     : 0
excluded by --exclude-manifest  : 71

SP-STARTUP-COHORT-EMPTY corpus_files=188 raw_openings=73 deduped=71 excluded_since=0 excluded_manifest=71 remaining=0
exit 0
```

**Zero of the 71 baseline openings survive.** Exit status is 0 — an empty cohort
is a correct result, not a broken run.

The rest of the boundary behaviour, all verified on this corpus:

| Test | Result |
|---|---|
| exclude 70 of 71 manifest rows | exactly **1** opening remains |
| exclude a v1-style **three-column** manifest (67 rows, no UUID) | all **71** excluded — old manifests still work |
| `--since 2026-08-01` alone | 67 removed, **4** openings remain, range `2026-08-02 .. 2026-08-03` |
| `--since 2026-07-01` **and** `--exclude-manifest` together | 2 removed by date, 68 by manifest, **1** remains |
| `--since 2026-13-99` / `2026-00-10` / `2026-08-32` / `not-a-date` | exit **2** — impossible dates rejected, not silently emptied |
| `--exclude-manifest /nonexistent` | exit **3** |
| corpus with one corrupt transcript | `transcripts unparsed: 1`, offending file named, `jq_unparsed=1` in the summary line |

The corrupt-transcript test ran against a **copy** of two transcripts in a
scratch directory. `~/.claude/projects/` was never written to.

### For the after-measurement

1. Run with `--exclude-manifest` pointed at this report's manifest
   (`8027fd07bd927244`), or with `--since` set past this run's date. Do not run
   over the whole corpus and diff summary lines — that is the dilution fix 2
   exists to prevent.
2. Diff the `SP-STARTUP-BASELINE` lines field by field.
3. Judge on **`all_nonsp_tools_p50` / `p90`**, with `nonsp_main_*` and
   `nonsp_status_*` reported separately and neither allowed to regress.
4. Check `nonsp_task_calls_p50` / `_max` against this baseline's **0 / 1**. A
   tool total that falls while sub-agent calls rise is work moved, not removed.
5. Check `briefing_absent` against **9**. Render-before-ask is met at 0.
6. Check `text_before_any_tool` against **46/71**. The visible-progress floor is
   met at 100 %.
7. Treat wall-clock deltas as directional unless model and effort settings match
   this window.

---

## ⚠️ Abandonment — corrected wording

| Signal | count |
|---|---|
| interrupted **before** control ever returned | **0** |
| quit (ESC or `/exit`) **within 60 s** of control returning | **1** (SP validation harness, not a user project) |
| control returned, user never responded at all | 4 (3 non-SP) |
| control never returned at all | 6 (1 non-SP) |

The v1 claim that a session was abandoned at the opening menu is withdrawn. In
the cited `BAM-MVP` session the substantive opening appeared at `17:10:45`, the
menu at `17:10:49`, and the interrupt plus `/exit` came on July 12 — more than
three days later.

The correct wording, per the review:

> **This corpus demonstrates no attributable user-project abandonment caused by
> startup latency.**

Do **not** state that the abandonment rate is proven to be zero. Four openings
have no later response and six never returned control; those are censored or
ambiguous outcomes, not evidence of causation. The naive count — first action
was interrupt, `/exit`, or nothing — is 29 of 71, and it is recorded here only
so the trap stays visible.

---

## 🚨 Threats to validity

Carried from v1 except where the fixes changed them.

1. **The green cell is n=2**, same project, same day, same user, and the
   nearest-rank p50 there is the minimum. Retired as the release gate; kept as a
   controlled stretch fixture.
2. **One user, one machine.** Tool latency, MCP server set, disk speed and model
   choice are constant here and would differ elsewhere.
3. **SP's dev repo supplies 38 of 71 openings.** It is separated everywhere, but
   the non-SP figures rest on 22 openings from 8 projects.
4. **Thinking blocks render in Claude Code.** The probe counts only `text` as
   visible output. Median time to *any* output is 14.2 s versus 22.6 s to text.
5. **Model mix is uncontrolled** and changed inside the window (Opus 4.7/4.8,
   Fable 5, Opus 5). Tool count is the robust comparator; wall clock is context.
6. **"Fresh" means "invoked without a handoff argument"**, not "no prior
   context". Only 2 openings carried an explicit `.handoffs/` argument.
7. **Empty-folder is n=2** and is inferred from floor fields (`git=missing` +
   `conventions=missing`), not from a file count. The second observation comes
   from the fix-4 carry-forward, which infers that a silent floor hook means the
   previous classification still holds — reasonable, but an inference.
8. **6 openings have no floor line** and stay in an explicit unclassified
   bucket, never folded into green or non-clean.
9. **6 openings never returned control** and are excluded from § A/B/C.
10. **Zero openings were dropped** for missing or unparseable timestamps, and
    zero transcripts failed to parse.
11. **The corpus is live, and it moved during this work** — one transcript grew
    between the review and this run without changing the file-level manifest
    hash. That is now a demonstrated risk, not a hypothetical one. The after-run
    must use the opening-level manifest and the cohort flags.
12. **Percentiles at n ≤ 22 are coarse.** p90 and max coincide in several cells,
    and at n=2 the median is the minimum.
13. **`:status` openings are structurally lighter** than main openings (non-SP
    median 12 vs 14) and are 24 of 71, so both strata are reported separately.
14. **Sub-agent usage is near zero today** (max 1 call), so the
    total-excluding-sub-agent column is currently identical to the total. It is
    a guard against a future substitution, not a live signal.

---

## 🔁 Reproducing

```bash
tests/startup-latency-probe.sh                              # full report
tests/startup-latency-probe.sh --records out.tsv            # one row per opening
tests/startup-latency-probe.sh --manifest man.tsv           # exact openings measured
tests/startup-latency-probe.sh --since 2026-08-04           # after-cohort by date
tests/startup-latency-probe.sh --exclude-manifest base.tsv  # after-cohort by manifest
```

| Behaviour | Detail |
|---|---|
| Requires `jq` | Absent → exit **3**. BSD `grep` caps bounded repetition at 255 characters and would silently truncate the floor status line. |
| No openings in the corpus | exit **4**, rather than printing an empty table. |
| Cohort filtered to empty | exit **0** with an explicit empty-cohort line. |
| Bad `--since`, unknown flag | exit **2**. Missing `--exclude-manifest` file → exit **3**. |
| Parse failures | Counted per file, named in § G, surfaced as `jq_unparsed=` in the summary line. Never suppressed. |
| Determinism | File list and every sort are `LC_ALL=C`; no wall-clock value enters the output. Two consecutive runs over this corpus were **byte-identical**. |
| Portability | macOS `bash` 3.2 (no associative arrays, no namerefs); BSD `awk` (epoch conversion is a hand-rolled days-from-civil routine, since BSD `awk` has no `mktime`). |
| Tunables | `SUBSTANTIVE_MIN_LINES`, `SUBSTANTIVE_MIN_CHARS`, `SP_DEV_SLUG`, `SP_HARNESS_RE`, `CORPUS_ROOT` — documented at the top of the script. |
| Corpus safety | Opened read-only. The probe never writes inside `~/.claude/projects/`. |

`tests/` is gitignored wholesale in this repo, so `.gitignore` carries an
explicit allowlist entry for this file, matching the existing pattern for
`.scripts/release-publish.sh`. The instrument is committed, not left in a
working tree.
