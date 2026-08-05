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
#   absolute filesystem paths                                    -> [path]
#     Covered roots: /Users, /home, /opt, /mnt, /srv, /var, /tmp,
#     /etc. The last four were added because a client-identifying
#     subpath is just as likely to sit under a mount point, a served
#     tree, a web root, a scratch dir, or a config dir as under a home
#     directory (/mnt/d/clients/Acme/..., /srv/Acme/..., /var/www/acme,
#     /etc/acme/config). Losing a bare "/tmp" mention to [path] is the
#     accepted cost; relative in-plugin paths are untouched because
#     they carry no leading root.
#     Paths whose directory names contain spaces strip whole: after a
#     path root, single-space-joined words are consumed (up to two per
#     hop) as long as a further /segment follows, so
#     "/Users/Jane Doe/Client Alpha/private.yml" strips whole
#   home-relative paths (~/...)                                  -> [path]
#   Windows drive-letter paths (C:\..., any letter)              -> [path]
#     Same space-joined behavior as above, so "C:\Program
#     Files\Acme\private.yml" strips whole rather than leaving the
#     client-named tail behind
#   email addresses                                              -> [email]
#   URLs and bare domains                                        -> [url]
#     including a bare dotted hostname followed by a slash-path under
#     ANY top-level domain ("internal-client.tech/admin"), not just the
#     common-TLD list; the slash-path is required there, so an ordinary
#     dotted filename such as "guard-regression.sh" is not a hostname
#     EXCEPT github.com/JimmySadek/strategic-partner (the plugin
#     tracker) and github.com/anthropics references. The allowlist is
#     exact-match only: the host must be exactly github.com (start of
#     reference or a non-hostname character before it — no prefix, no
#     subdomain), and the path segment must end exactly there (end of
#     reference or a following /). A percent sign extends the segment,
#     never ends it, so percent-encoded lookalikes such as
#     .../strategic-partner%2Dclient are stripped like any other URL
#   git remote URLs (ssh, scp-style, and https ....git forms)    -> [remote]
#   common secret shapes                                         -> [secret]
#     AWS-style key ids (AKIA/ASIA + 16 chars)
#     token/key/secret/password — matched case-insensitively, so
#       PaSsWoRd: strips too — followed by : or =; the value is
#       stripped to END OF LINE, so multi-word passphrases go whole
#     long hex runs (32 chars or more)
#     long base64-ish runs (32 chars or more, slash-containing or not)
#       when they carry a digit or ANY uppercase letter; only an
#       all-lowercase, digit-free run survives, because that shape is
#       indistinguishable from a long word or relative path — that
#       residue is owned by the semantic pass and the preview, per the
#       command file
#
# KNOWN BEHAVIOR (fail-toward-privacy, accepted): ANY word ending in a
# secret keyword followed by : or = loses its line tail — for example
# "monkey: bananas" becomes "monkey: [secret]" — because a suffix match
# that catches api_key= and access_token= cannot tell "monkey" from
# "passkey". Stripping prose there is the accepted cost.
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
# that cannot extend the repo/org name — percent excluded, so encoded
# continuations do not count as boundaries) and end-of-line. The leading
# group pins the host: exactly github.com, preceded by the start of the
# line or a character that cannot extend a hostname, which rejects both
# clientgithub.com and client.github.com.
KEEP_TRACKER='@@SP_KEEP_TRACKER@@'
KEEP_ANTHROPIC='@@SP_KEEP_ANTHROPIC@@'

sed -E \
  -e "s#(^|[^A-Za-z0-9.-])github\.com/JimmySadek/strategic-partner(/|[^/A-Za-z0-9._%-])#\1${KEEP_TRACKER}\2#g" \
  -e "s#(^|[^A-Za-z0-9.-])github\.com/JimmySadek/strategic-partner\$#\1${KEEP_TRACKER}#" \
  -e "s#(^|[^A-Za-z0-9.-])github\.com/anthropics(/|[^/A-Za-z0-9._%-])#\1${KEEP_ANTHROPIC}\2#g" \
  -e "s#(^|[^A-Za-z0-9.-])github\.com/anthropics\$#\1${KEEP_ANTHROPIC}#" \
  -e 's#ssh://[^@[:space:]][^[:space:]]*#[remote]#g' \
  -e 's#[A-Za-z0-9_.-]+@[A-Za-z0-9.-]+:[A-Za-z0-9/_.~-]+#[remote]#g' \
  -e 's#https?://[^@[:space:]]+\.git#[remote]#g' \
  -e 's#[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z][A-Za-z]+#[email]#g' \
  -e 's#https?://[^@[:space:]]+#[url]#g' \
  -e 's#([A-Za-z0-9-]+\.)+(com|net|org|io|ai|dev|app|co|edu|gov)(/[^[:space:]]*)?#[url]#g' \
  -e 's#(^|[^A-Za-z0-9@._/-])([A-Za-z0-9-]+\.)+[A-Za-z]{2,24}/[^[:space:]]*#\1[url]#g' \
  -e 's#(/Users|/home|/opt|/mnt|/srv|/var|/tmp|/etc)(/[A-Za-z0-9._+-]+)*(([ ][A-Za-z0-9._+-]+){1,2}(/[A-Za-z0-9._+-]+)+)*/?#[path]#g' \
  -e 's#~(/[A-Za-z0-9._+-]+)+(([ ][A-Za-z0-9._+-]+){1,2}(/[A-Za-z0-9._+-]+)+)*/?#[path]#g' \
  -e 's#(^|[^A-Za-z0-9])[A-Za-z]:(\\[A-Za-z0-9._+-]+)+(([ ][A-Za-z0-9._+-]+){1,2}(\\[A-Za-z0-9._+-]+)+)*\\?#\1[path]#g' \
  -e 's#(AKIA|ASIA)[0-9A-Z]{16}#[secret]#g' \
  -e 's#(([Tt][Oo][Kk][Ee][Nn]|[Kk][Ee][Yy]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd])[[:space:]]*[:=][[:space:]]*).*$#\1[secret]#' \
  -e 's#[0-9a-fA-F]{32,}#[secret]#g' \
| awk '
  # Long base64-ish tokens. Two scans per line with the same predicate:
  # a run of 32+ chars is a secret when it carries a digit or ANY
  # uppercase letter; only all-lowercase digit-free runs are kept (they
  # are indistinguishable from long words and relative paths). Scan 1
  # uses the strict base64 alphabet including slash (dash/dot/underscore
  # excluded, so relative in-plugin paths break into short runs); scan 2
  # uses the slashless base64url-ish alphabet. Length is checked via
  # RLENGTH, not regex intervals, for mawk compatibility. Rebuilds each
  # line by hand so indentation and spacing survive untouched.
  function scrub(line, re,    out, rest, tok) {
    out = ""; rest = line
    while (match(rest, re)) {
      tok = substr(rest, RSTART, RLENGTH)
      out = out substr(rest, 1, RSTART - 1)
      if (RLENGTH >= 32 && (tok ~ /[0-9]/ || tok ~ /[A-Z]/))
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
