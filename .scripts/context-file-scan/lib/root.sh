#!/usr/bin/env bash
# .scripts/context-file-scan/lib/root.sh
# Project root discovery per scanner-design-spec.md mini-decision 16.
# Sourceable — defines functions; no top-level side effects.

# scanner_project_root [START_DIR]
#   Echoes the absolute project root. Tries `git rev-parse --show-toplevel`
#   first; falls back to START_DIR (default: cwd) when not in a git repo.
#   Always echoes a path even when fallback is used; never errors out.
#
#   Codex finding #7: multi-file fixture tests need to scan a
#   fixture-as-root rather than the enclosing SP repo. The
#   `SCANNER_PROJECT_ROOT_OVERRIDE` env var (testing-only) takes
#   precedence over both git-root and fallback resolution. Production
#   code never sets this var; it's the test-isolation seam.
scanner_project_root() {
  local start="${1:-$PWD}"
  if [ -n "${SCANNER_PROJECT_ROOT_OVERRIDE:-}" ] \
     && [ -d "${SCANNER_PROJECT_ROOT_OVERRIDE}" ]; then
    printf '%s' "${SCANNER_PROJECT_ROOT_OVERRIDE}"
    return 0
  fi
  local root
  root=$(cd "$start" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$root" ] && [ -d "$root" ]; then
    printf '%s' "$root"
    return 0
  fi
  cd "$start" 2>/dev/null && pwd
}

# scanner_is_git_repo [START_DIR]
#   Echoes "true" if START_DIR (default: cwd) is inside a git working tree;
#   "false" otherwise. Used by the layer probe and the root-discovery
#   info-severity note per spec § 7.3.
scanner_is_git_repo() {
  local start="${1:-$PWD}"
  if (cd "$start" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    echo true
  else
    echo false
  fi
}

# scanner_root_note [START_DIR]
#   Echoes a one-line info-severity note when the project root falls back
#   to cwd (i.e., not in a git repo). Empty when in a git repo. Consumers
#   surface this in scan_metadata.notes.
scanner_root_note() {
  local start="${1:-$PWD}"
  if [ "$(scanner_is_git_repo "$start")" = "false" ]; then
    echo "Not in a git repository; using current directory as project root."
  fi
}
