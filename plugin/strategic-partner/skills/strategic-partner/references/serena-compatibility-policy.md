# Serena Compatibility Policy

Strategic Partner owns the quality of the Serena integration it recommends,
across both the standalone skill and plugin distributions. Serena remains an
external runtime during the dual-support period.

## Supported contract

An SP-supported Claude Code setup has all of these properties:

- one stable `serena-agent` installation at SP's currently tested version,
  `1.5.3`;
- exactly one user-level MCP server named `serena`;
- `--context=claude-code`, `--project-from-cwd`, and
  `--open-web-dashboard False` on the launcher;
- activation, search-drift reminder, permission-aware auto-approval, and
  session cleanup hooks from the same Serena installation;
- no broad static Serena allow entry; the official hook approves Serena tools
  only when Claude is already in `acceptEdits` or `auto` mode;
- no enabled legacy marketplace Serena plugin beside the managed server;
- no competing user, local, or repository Serena launcher, including one
  registered under a different server name;
- no changes to repository `.serena/` artifacts or memories during setup.

The quiet-dashboard flag suppresses the automatic browser tab. It does not
disable Serena's dashboard; users can still open it deliberately.

## Runtime capability contract

SP discovers Serena capabilities instead of assuming permanent tool names.
The required behaviors are:

- inspect the current configuration and exact active repository path;
- read initial instructions once per session when exposed;
- activate an exact path when activation is exposed;
- list and read memories;
- run onboarding only after user approval.

In Serena's single-project Claude context, `activate_project` may be hidden. A
wrong active path in that context is a launcher defect, not a reason to add a
second server.

## Namespace compatibility

During migration, SP recognizes both:

| Setup | Tool prefix |
|---|---|
| SP-managed user server | `mcp__serena__` |
| Legacy official plugin | `mcp__plugin_serena_serena__` |

Both prefixes receive the same source-mutation guard. Workflows should refer to
capabilities; exact prefixes belong only in compatibility and guard code.

## Health states

| State | Meaning | Safe action |
|---|---|---|
| `healthy` | The full supported contract is present | Stay quiet |
| `absent` | No Serena runtime or server is installed | Offer stable install |
| `legacy-plugin` | The moving marketplace launcher is enabled | Offer migration |
| `outdated` | Runtime is development, too old, or hooks are absent | Offer supported stable version |
| `misconfigured` | Server lacks Claude context or exact-cwd binding | Repair launcher |
| `noisy-dashboard` | Automatic browser opening is still enabled | Add quiet-launch flag |
| `partial-hooks` | One or more lifecycle hooks are missing | Merge missing hooks |
| `stale-permissions` | A broad static Serena approval bypasses permission mode | Remove it and keep conditional approval |
| `duplicate` | More than one registration is active, or local/project scope would conflict with the managed user server | Fail closed; migrate plugin/user safely or review project scope separately |
| `unsupported-platform` | Automatic repair has no equivalent proof | Route Windows users to WSL2 |

The doctor is local and read-only. Repair is backup-first, idempotent,
consent-gated, verified after mutation, and rolled back on failure.

## Plugin direction

Plugin-owned automatic Serena connection is the declared destination. It stays
disabled until the plugin can resolve a disclosed stable runtime, its observed
namespace is covered by guards and tests, existing standalone registrations can
be migrated safely, and cold-session proof confirms one server, exact worktree
activation, quiet launch, memory preservation, and rollback. Skill users retain
the managed user-level path throughout the dual-support period.
