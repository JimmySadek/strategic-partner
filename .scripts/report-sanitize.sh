#!/usr/bin/env bash
# .scripts/report-sanitize.sh — deterministic pass of the /report-issue
# sanitiser (GitHub issue #2, layered-controls design).
#
# Reads a report draft on stdin, writes the sanitised draft on stdout.
# This is the mechanical pass: it strips shapes a regex can recognise.
# A semantic pass (client names, person names, org names) and a mandatory
# preview follow in the command flow — this script is deliberately only
# one of three controls, so it never needs to be clever.
#
# STRIPPED (stable placeholders):
#   absolute filesystem paths (/Users/..., /home/..., /opt/...)  -> [path]
#   home-relative paths (~/...)                                  -> [path]
#   email addresses                                              -> [email]
#   URLs and bare domains                                        -> [url]
#     EXCEPT github.com/JimmySadek/strategic-partner (the plugin
#     tracker) and github.com/anthropics references, which survive
#   git remote URLs (ssh, scp-style, and https ....git forms)    -> [remote]
#   common secret shapes                                         -> [secret]
#     AWS-style key ids (AKIA/ASIA + 16 chars)
#     token/key/secret/password followed by : or = and a value
#     long hex runs (32 chars or more)
#     long base64-ish runs (32 chars or more, containing a digit;
#       the digit requirement keeps long prose words and markdown
#       hyphen rules out of the net)
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
# Depends only on sed and awk (stock macOS / Linux).

set -u

# Sentinels protect the two allowed reference families from the URL and
# remote rules below. They use '@@', which sits outside every match class
# in this pipeline, so a sentinelled reference can never half-match.
KEEP_TRACKER='@@SP_KEEP_TRACKER@@'
KEEP_ANTHROPIC='@@SP_KEEP_ANTHROPIC@@'

sed -E \
  -e "s#github\.com/JimmySadek/strategic-partner#${KEEP_TRACKER}#g" \
  -e "s#github\.com/anthropics#${KEEP_ANTHROPIC}#g" \
  -e 's#ssh://[^@[:space:]][^[:space:]]*#[remote]#g' \
  -e 's#[A-Za-z0-9_.-]+@[A-Za-z0-9.-]+:[A-Za-z0-9/_.~-]+#[remote]#g' \
  -e 's#https?://[^@[:space:]]+\.git#[remote]#g' \
  -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z]+#[email]#g' \
  -e 's#https?://[^@[:space:]]+#[url]#g' \
  -e 's#([A-Za-z0-9-]+\.)+(com|net|org|io|ai|dev|app|co|edu|gov)(/[^[:space:]]*)?#[url]#g' \
  -e 's#(/Users|/home|/opt)(/[A-Za-z0-9._+-]+)*/?#[path]#g' \
  -e 's#~(/[A-Za-z0-9._+-]+)+/?#[path]#g' \
  -e 's#(AKIA|ASIA)[0-9A-Z]{16}#[secret]#g' \
  -e 's#((token|Token|TOKEN|key|Key|KEY|secret|Secret|SECRET|password|Password|PASSWORD)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1[secret]#g' \
  -e 's#[0-9a-fA-F]{32,}#[secret]#g' \
| awk '
  # Long base64-ish tokens: 32+ chars of the base64/base64url alphabet
  # (slash excluded — it would swallow long relative paths) that contain
  # at least one digit. Rebuilds each line by hand so indentation and
  # spacing survive untouched.
  {
    out = ""; rest = $0
    while (match(rest, /[A-Za-z0-9+=_-]{32,}/)) {
      tok = substr(rest, RSTART, RLENGTH)
      out = out substr(rest, 1, RSTART - 1)
      if (tok ~ /[0-9]/) out = out "[secret]"; else out = out tok
      rest = substr(rest, RSTART + RLENGTH)
    }
    print out rest
  }' \
| sed -E \
  -e "s#${KEEP_TRACKER}#github.com/JimmySadek/strategic-partner#g" \
  -e "s#${KEEP_ANTHROPIC}#github.com/anthropics#g"
