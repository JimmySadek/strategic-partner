# 🛡️ Stewardship Contract

`.sp-managed` lets a repository grant Strategic Partner stewardship over its own
non-code planning artifacts without waiting for a new SP release.

The file is a contract proposal, not authority by itself. SP may manage matching
paths only after the user reviews the contract and creates a local activation
marker outside the repo. A pulled or cloned `.sp-managed` file never widens write
access on its own.

```
repo/.sp-managed
      │
      ├─ user reviews exact patterns
      │
      ├─ local activation marker written outside repo
      │
      └─ SP can manage matching non-code artifacts
```

## Format

Each active line uses:

```text
pattern | role | mode
```

Example:

```text
workspace/decisions/*.md | decisions | manage
workspace/interviews/*.md | interviews | manage
research/benchmarks/*.jsonl | benchmarks | manage
```

- `pattern` is repo-relative.
- `role` is plain-English intent for the artifact class.
- `mode` is advisory metadata for humans. Current guard behavior treats a
  matching, activated line as manageable.

Blank lines and `#` comments are ignored.

## Guard Rules

The guard accepts activated `.sp-managed` matches only for non-code artifact
extensions:

```text
.md .txt .jsonl .csv .html
```

It rejects broad or unsafe patterns such as absolute paths, parent-directory
escapes, and whole-repo wildcards. Wildcard patterns must begin with a literal
non-wildcard folder segment, so `workspace/decisions/*.md` is valid but `*.md`
and `*/*.md` are ignored. The built-in SP managed set remains available:
`.prompts/`, `.handoffs/`, `.scripts/`, `.backlog/`, `specs/` documentation
artifacts, context files, release docs, `.claude-plugin/plugin.json`, and
`output-styles/strategic-partner-voice.md`.

SP still backs off from implementation source files, migrations, runtime config,
secrets, binary artifacts, and generated build outputs. Those go through prompt
crafting or executor dispatch.

## Local Activation

When SP sees a matching `.sp-managed` line but no local activation, the hook
blocks and prints:

- the repo root
- the contract hash
- the local activation marker path

After explicit user approval, SP may create the marker under:

```text
${SP_TRUST_DIR:-$HOME/.claude/strategic-partner/trusted-contracts}/
```

The marker name includes both the repo-root hash and the `.sp-managed` file hash.
Changing `.sp-managed` changes the hash, so the user must re-approve the new
contract.

Marker creation is guarded mechanically. SP must ask via `AskUserQuestion`, the
visible question/options must include `.sp-managed` and the exact marker path,
and the selected option label must be exactly:

```text
Activate stewardship contract
```

Shell redirects to the trust-marker directory are blocked; activation goes
through the guarded file-write path so the transcript confirmation can be
verified.

## Candidate Offer Flow

If SP is blocked on a non-code planning path such as `workspace/decisions/*.md`,
`interviews/*.md`, `research/*.jsonl`, or `specs/*.html`, it should offer to add
a narrow pattern to `.sp-managed`.

Use this shape:

```text
I can treat this as a repo-managed strategy artifact, but only if you approve a
narrow .sp-managed rule:

workspace/decisions/*.md | decisions | manage
```

Never auto-add a pattern. Never broaden to a whole repo. Never use `.sp-managed`
to authorize implementation source work.
