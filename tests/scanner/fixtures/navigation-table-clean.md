# Project

A test fixture with a Where-to-Look-style pointer table that should NOT
fire S2 layer-violation detection (Codex finding #4). Pure navigation
tables — rows of `link → description` shape, no schema-like terms — must
be down-weighted so the schema/architecture pattern doesn't fire.

## Project Facts

- A fact.

## Where to Look

| When | Resource |
|---|---|
| Investigating past hook bugs | `claudedocs/INCIDENTS.md` — incident write-ups (one entry per `INC-YYYY-MM-DD` ID) |
| Cross-referencing patterns or hunting prior lessons across releases | `CHANGELOG.md` — searchable history of every feature and fix |
| Running a release after the four release commits land | `.scripts/release-publish.sh` — automates the GitHub Release step |
| Confirming the current SP version | `SKILL.md` line 11 (`version:` line) |
