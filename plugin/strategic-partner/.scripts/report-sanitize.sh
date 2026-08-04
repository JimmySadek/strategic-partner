#!/usr/bin/env bash
# .scripts/report-sanitize.sh — deterministic pass of the /report-issue
# sanitiser (GitHub issue #2, layered-controls design).
#
# Reads a report draft on stdin, writes the sanitised draft on stdout.
# This is the mechanical pass: it strips shapes a regex can recognise.
# A semantic pass (client names, person names, org names, and a secret
# hunt for shapes no regex can pin down) and a mandatory preview follow
# in the command flow — this script is deliberately only one of three
# controls, so it never needs to be clever. Where it must choose, it
# fails toward stripping more.
#
# STRIPPED (stable placeholders):
#   absolute filesystem paths (/Users/..., /home/..., /opt/...)  -> [path]
#     including paths whose directory names contain spaces: after a
#     path root, single-space-joined words are consumed (up to two per
#     hop) as long as a further /segment follows, so
#     "/Users/Jane Doe/Client Alpha/private.yml" strips whole
#   home-relative paths (~/...)                                  -> [path]
#   email addresses                                              -> [email]
#   URLs and bare domains                                        -> [url]
#     EXCEPT github.com/JimmySadek/strategic-partner (the plugin
#     tracker) and github.com/anthropics references — allowlisted by
#     COMPLETE path segment only (end of reference or a following /),
#     so lookalikes such as .../strategic-partner-client or
#     .../anthropics.private are stripped like any other URL
#   git remote URLs (ssh, scp-style, and https ....git forms)    -> [remote]
#   common secret shapes                                         -> [secret]
#     AWS-style key ids (AKIA/ASIA + 16 chars)
#     token/key/secret/password followed by : or = — the value is
#       stripped to END OF LINE, so multi-word passphrases go whole
#     long hex runs (32 chars or more)
#     long base64-ish runs (32 chars or more, slash-containing or not)
#       when they carry a digit OR mixed upper+lower case; a
#       lowercase-only, digit-free run is indistinguishable from a long
#       word or relative path, so that residue is owned by the semantic
#       pass and the preview, per the command file
#
# PRESERVED unchanged (over-stripping is a failure, not a safety margin):
#   short content-derived hashes and receipts (7-16 char hex — git short
#     SHAs, guard receipts), version numbers, test counts, command names,
#   and relative in-plugin paths (hooks/..., tests/..., .scripts/...)
#     which identify plugin code, not the client.
#
# Truth-table coverage: tests/lint-report-sanitize.sh (both directions —
# each strip shape shown stripped, each preserve shape shown preserved).
#
# bash 3.2 compatible (project rule): no associative arrays, no namerefs.
# Depends only on sed and awk (stock macOS / Linux; no awk interval
# expressions, so mawk works too).

set -u

# Sentinels protect the two allowed reference families from the URL and
# remote rules below. They use '@@', which sits outside every match class
# in this pipeline, so a sentinelled reference can never half-match. Each
# family needs two rules: segment-boundary (a following / or any char
# that cannot extend the repo/org name) and end-of-line.
KEEP_TRACKER='@@SP_KEEP_TRACKER@@'
KEEP_ANTHROPIC='@@SP_KEEP_ANTHROPIC@@'

sed -E \
  -e "s#github\.com/JimmySadek/strategic-partner(/|[^/A-Za-z0-9._-])#${KEEP_TRACKER}\1#g" \
  -e "s#github\.com/JimmySadek/strategic-partner\$#${KEEP_TRACKER}#" \
  -e "s#github\.com/anthropics(/|[^/A-Za-z0-9._-])#${KEEP_ANTHROPIC}\1#g" \
  -e "s#github\.com/anthropics\$#${KEEP_ANTHROPIC}#" \
  -e 's#ssh://[^@[:space:]][^[:space:]]*#[remote]#g' \
  -e 's#[A-Za-z0-9_.-]+@[A-Za-z0-9.-]+:[A-Za-z0-9/_.~-]+#[remote]#g' \
  -e 's#https?://[^@[:space:]]+\.git#[remote]#g' \
  -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z]+#[email]#g' \
  -e 's#https?://[^@[:space:]]+#[url]#g' \
  -e 's#([A-Za-z0-9-]+\.)+(com|net|org|io|ai|dev|app|co|edu|gov)(/[^[:space:]]*)?#[url]#g' \
  -e 's#(/Users|/home|/opt)(/[A-Za-z0-9._+-]+)*(([ ][A-Za-z0-9._+-]+){1,2}(/[A-Za-z0-9._+-]+)+)*/?#[path]#g' \
  -e 's#~(/[A-Za-z0-9._+-]+)+(([ ][A-Za-z0-9._+-]+){1,2}(/[A-Za-z0-9._+-]+)+)*/?#[path]#g' \
  -e 's#(AKIA|ASIA)[0-9A-Z]{16}#[secret]#g' \
  -e 's#((token|Token|TOKEN|key|Key|KEY|secret|Secret|SECRET|password|Password|PASSWORD)[[:space:]]*[:=][[:space:]]*).*$#\1[secret]#' \
  -e 's#[0-9a-fA-F]{32,}#[secret]#g' \
| awk '
  # Long base64-ish tokens. Two scans per line with the same predicate:
  # a run of 32+ chars is a secret when it carries a digit OR both an
  # upper- and a lower-case letter. Scan 1 uses the strict base64
  # alphabet including slash (dash/dot/underscore excluded, so relative
  # in-plugin paths break into short runs); scan 2 uses the slashless
  # base64url-ish alphabet. Length is checked via RLENGTH, not regex
  # intervals, for mawk compatibility. Rebuilds each line by hand so
  # indentation and spacing survive untouched.
  function scrub(line, re,    out, rest, tok) {
    out = ""; rest = line
    while (match(rest, re)) {
      tok = substr(rest, RSTART, RLENGTH)
      out = out substr(rest, 1, RSTART - 1)
      if (RLENGTH >= 32 && (tok ~ /[0-9]/ || (tok ~ /[A-Z]/ && tok ~ /[a-z]/)))
        out = out "[secret]"
      else
        out = out tok
      rest = substr(rest, RSTART + RLENGTH)
    }
    return out rest
  }
  {
    line = scrub($0, "[A-Za-z0-9+/=]+")
    line = scrub(line, "[A-Za-z0-9+=_-]+")
    print line
  }' \
| sed -E \
  -e "s#${KEEP_TRACKER}#github.com/JimmySadek/strategic-partner#g" \
  -e "s#${KEEP_ANTHROPIC}#github.com/anthropics#g"
