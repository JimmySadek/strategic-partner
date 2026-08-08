# Real Claude Code ceremony smoke - 2026-07-09

Environment: Claude Code 2.1.205, local `plugin/strategic-partner` loaded with
project settings only. These are intentionally small evidence notes; the source
transcripts remain in Claude Code's local project history.

## Startup paths

| Path | Session | Evidence |
|---|---|---|
| Typed plugin command | `dce71531-4e7f-4c29-bb42-68bf5810b9ac` | `UserPromptExpansion` emitted `SP-FLOOR-COMPLETE`; the following `UserPromptSubmit` did not repeat the floor. Missing final `AskUserQuestion` caused one startup block, and the corrective Stop was allowed. |
| Model-invoked Skill | `d4937acc-c3a0-4a70-abda-8301bd8ec010` | Natural-language activation reached `PreToolUse:Skill`; the floor was present before the Skill ran and the advisor rendered project orientation. The print-mode budget ended before the final startup Stop. |
| Resident advisor | `6a23144d-8e35-4556-bd06-3d2db100e427` | `SessionStart` recognized `agent_type=strategic-partner-plugin:sp-advisor`, emitted the floor before the first prompt, and the following `UserPromptSubmit` emitted no duplicate floor. Missing startup evidence blocked once; the corrective Stop was allowed. |
| Explicit continuation | `b6b14903-3a89-40bb-9725-ed2bd53e4f03` | `UserPromptExpansion` emitted the floor and Claude read the exact `.handoffs/lifecycle-smoke-0709-2215.md` argument. The print-mode budget ended before the full orientation. |

## Closeout path

Session `dce71531-4e7f-4c29-bb42-68bf5810b9ac` reproduced the reported failure
shape with `Stop here for now.` followed by a recap-only response. The Stop hook
returned structured `decision: block` JSON naming all four missing requirements:
Closure Walk Status, a same-turn handoff write, insights or an explicit fallback,
and the plugin-namespaced continuation fence. A second Stop with
`stop_hook_active=true` was allowed, proving the recovery cannot loop.

A real corrective closure run began the full checks but exhausted its explicit
smoke-test budget before writing the handoff. The complete valid-closeout path is
therefore covered by the focused synthetic fixture, while the real smoke proves
the original recap-only failure is intercepted and the one-shot escape works.
