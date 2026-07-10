---
name: serena
description: "Check, install, repair, verify, or roll back Strategic Partner's Serena setup"
category: utility
complexity: standard
mcp-servers: []
---

# /strategic-partner:serena — Serena Steward

Own the Serena setup experience for the user. Keep healthy setups quiet and
explain unhealthy setups without namespace or package-manager jargon unless the
user asks.

## Resolve the bundled tools

Find the active Strategic Partner install directory from this command, then
require both of these bundled scripts:

```text
{sp-dir}/.scripts/serena-doctor.sh
{sp-dir}/.scripts/serena-repair.sh
```

Never substitute a maintainer checkout path. If either script is missing,
explain that the SP install is incomplete and route to `:update` before making
any Serena change.

## Flow

1. Run the doctor locally with `--format=json`. This is read-only and must not
   use the network.
2. If state is `healthy`, say only: `✅ Serena is connected correctly and will
   start quietly.` End unless the user explicitly asked for technical detail.
3. If state is `unsupported-platform`, explain the supported WSL2 route. Do not
   attempt repair.
   If state is `duplicate` with `scope_conflict: true`, show whether the conflict
   is local or project-scoped and offer a separately reviewed cleanup; do not
   run the managed repair or edit a project `.mcp.json` automatically.
4. For every other state, lead with:
   - what is wrong in plain language;
   - what SP still does without Serena;
   - the exact outcome of the recommended repair: one stable server, exact
     repository/worktree activation, quiet dashboard startup, lifecycle hooks,
     preserved memories, and a rollback backup.
   If the doctor reports `uv_available: false` and installation or upgrade is
   required, preview the package-manager command and ask a separate question
   before dispatching
   `{sp-dir}/.scripts/serena-repair.sh --install-prerequisite --yes`. Re-run
   the doctor and repair preview afterward. Never combine executable-code
   download consent with Serena repair consent.
5. For automatically repairable states, run
   `{sp-dir}/.scripts/serena-repair.sh --plan` and show its output. Then use
   `AskUserQuestion` with:
   - **Fix Serena for me (Recommended)** — dispatch the approved repair and
     verify its result;
   - **Show technical details** — show detected state, versions, files touched,
     launcher flags, and rollback location without changing anything;
   - **Not now** — continue with SP's repository-native fallbacks.
6. Only after **Fix Serena for me** is selected, dispatch an implementation
   worker to run:

   ```text
   {sp-dir}/.scripts/serena-repair.sh --apply --yes
   {sp-dir}/.scripts/serena-repair.sh --verify
   ```

   The worker must return the command output and stop on any rollback or
   non-zero exit. Do not run the mutation directly inside the advisory thread.
7. On success, tell the user to start a fresh Claude session in the repository.
   In that session, verify the exact active path with Serena's current
   configuration capability. A worktree must report the worktree path, never
   its parent checkout.

## Rollback

When the user explicitly requests rollback, preview it first and require
confirmation before dispatching:

```text
{sp-dir}/.scripts/serena-repair.sh --rollback --yes
```

Rollback restores the captured Claude settings and prior Serena runtime state.
It never rewrites `.serena/` project files or memories.

## Boundaries

- Diagnosis is read-only and local.
- Installation, repair, plugin disablement, hook edits, and rollback require
  explicit user approval.
- Never attach a second Serena server to work around a bad first one.
- Never edit marketplace caches.
- Never run onboarding without separate approval.
