#!/bin/bash
# Shared, side-effect-free classifiers for Strategic Partner session ceremonies.
# Callers own marker files and hook output. This library only classifies input.

sp_is_guarded_utility_command() {
  local command_name="$1"
  local command_args="${2:-}"
  local normalized
  local normalized_args

  normalized=$(printf '%s' "$command_name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s#^/##')
  normalized_args=$(printf '%s' "$command_args" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$normalized" in
    strategic-partner|sp|advisor|*:strategic-partner)
      case "$normalized_args" in :serena*) return 0 ;; esac
      ;;
    strategic-partner-plugin:*|sp-plugin-trial:*|*strategic-partner*:*)
      case "$normalized" in *:serena) return 0 ;; esac
      ;;
  esac
  return 1
}

sp_is_guarded_utility_prompt() {
  local prompt="$1"
  printf '%s' "$prompt" | perl -e '
    undef $/; my $p = <STDIN>;
    exit 0 if $p =~ m{\A\s*/(?:[A-Za-z0-9-]+:)?(?:strategic-partner|sp|advisor):serena(?:\s|\z)};
    exit 0 if $p =~ m{\A\s*/(?:strategic-partner-plugin|sp-plugin-trial|[A-Za-z0-9-]*strategic-partner[A-Za-z0-9-]*):serena(?:\s|\z)};
    exit 1;
  ' 2>/dev/null
}

sp_is_command_activation() {
  local command_name="$1"
  local command_args="${2:-}"
  local normalized
  local normalized_args

  normalized=$(printf '%s' "$command_name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s#^/##')
  normalized_args=$(printf '%s' "$command_args" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  case "$normalized" in
    strategic-partner|sp|advisor|*:strategic-partner)
      case "$normalized_args" in
        :help*|:copy-prompt*|:update*|:serena*) return 1 ;;
      esac
      return 0
      ;;
    strategic-partner-plugin:*|sp-plugin-trial:*|*strategic-partner*:*)
      case "$normalized" in
        *:help|*:copy-prompt|*:update) return 1 ;;
        *:handoff|*:status|*:codex-feedback|*:context-file-scan|*:backlog|*:switch-to-skill) return 0 ;;
      esac
      ;;
  esac

  return 1
}

sp_is_prompt_activation() {
  local prompt="$1"
  printf '%s' "$prompt" | perl -e '
    undef $/; my $p = <STDIN>;
    my $sub = "";
    if ($p =~ m{\A\s*/(?:[A-Za-z0-9-]+:)?(?:strategic-partner|sp|advisor)(?::([a-z-]+))?(?:\s|\z)}) {
      $sub = defined $1 ? $1 : "";
    } elsif ($p =~ m{\A\s*/(?:strategic-partner-plugin|sp-plugin-trial|[A-Za-z0-9-]*strategic-partner[A-Za-z0-9-]*):(help|copy-prompt|update|handoff|status|codex-feedback|context-file-scan|backlog|switch-to-skill)(?:\s|\z)}) {
      $sub = $1;
    } else {
      exit 1;
    }
    exit 1 if $sub =~ /^(?:help|copy-prompt|update|serena)$/;
    exit 0;
  ' 2>/dev/null
}

sp_extract_continuation_path() {
  local text="$1"
  printf '%s' "$text" | perl -e '
    undef $/; my $s = <STDIN>;
    if ($s =~ m{(?:\A|\s)(\.handoffs/(?!\.\.?/)[A-Za-z0-9._/-]+\.md)(?:\s|\z)}) {
      my $p = $1;
      exit 1 if $p =~ m{(?:\A|/)\.\.(?:/|\z)};
      print $p;
      exit 0;
    }
    exit 1;
  ' 2>/dev/null
}

sp_is_session_end_override() {
  local text="$1"
  local normalized
  normalized=$(printf '%s' "$text" | tr '[:upper:]' '[:lower:]' | tr '\n\r\t' '   ')
  case "$normalized" in
    *"don't close"*|*"do not close"*|*"dont close"*|*"keep the session open"*|*"keep this session open"*|*"not a handoff"*|*"without a handoff"*|*"don't hand off"*|*"do not hand off"*)
      return 0
      ;;
  esac
  return 1
}

sp_is_session_end_intent() {
  local text="$1"
  local candidate

  sp_is_session_end_override "$text" && return 1

  candidate=$(printf '%s' "$text" | perl -e '
    undef $/; my $s = <STDIN>;
    $s =~ s/```[\s\S]*?```//g;
    $s =~ s/`[^`]*`//g;
    $s =~ s/^\s*>.*$//mg;
    $s =~ s/"[^"]*"//g;
    $s =~ s/'"'"'[^'"'"']*'"'"'//g;
    if ($s =~ /(?:->|\x{2192})\s*([^\n]+)\s*\z/) { $s = $1; }
    $s =~ s/^\s+|\s+$//g;
    print lc $s;
  ' 2>/dev/null)

  printf '%s' "$candidate" | perl -e '
    undef $/; my $s = <STDIN>;
    $s =~ s/\s+/ /g;
    $s =~ s/^\s+|\s+$//g;
    my $polite = qr/(?:please[,.]?\s*)?/;
    my $tail = qr/(?:[.!]|\s)*\z/;
    my $sentence = qr/[.!](?:\s|\z)/;
    exit 0 if $s =~ /\A$polite(?:ok(?:ay)?[,.]?\s*)?(?:let(?:\x27|\x{2019})s\s+)?stop(?:\s+here)?(?:\s+for\s+(?:the\s+)?now)?$sentence/;
    exit 0 if $s =~ /\A$polite(?:we(?:\x27|\x{2019})re\s+)?done(?:\s+here)?(?:\s+for\s+(?:the\s+)?now)?$sentence/;
    exit 0 if $s =~ /\A$polite(?:we(?:\x27|\x{2019})re\s+)?wrapping\s+up(?:\s+for\s+(?:the\s+)?now)?$sentence/;
    exit 0 if $s =~ /\A$polite(?:that(?:\x27|\x{2019})s|that\s+is)\s+(?:it|all)(?:\s+for\s+(?:the\s+)?now)?$sentence/;
    exit 0 if $s =~ /\A$polite(?:ok(?:ay)?[,.]?\s*)?(?:let(?:\x27|\x{2019})s\s+)?stop(?:\s+here)?(?:\s+for\s+(?:the\s+)?now)?$tail/;
    exit 0 if $s =~ /\A$polite(?:we(?:\x27|\x{2019})re\s+)?done(?:\s+here)?(?:\s+for\s+(?:the\s+)?now)?$tail/;
    exit 0 if $s =~ /\A$polite(?:we(?:\x27|\x{2019})re\s+)?wrapping\s+up(?:\s+for\s+(?:the\s+)?now)?$tail/;
    exit 0 if $s =~ /\A$polite(?:that(?:\x27|\x{2019})s|that\s+is)\s+(?:it|all)(?:\s+for\s+(?:the\s+)?now)?$tail/;
    exit 1;
  ' 2>/dev/null
}

_sp_latest_assistant_has_auq() {
  local transcript_path="$1"
  jq -e -s '
    [ .[] | select((.message.role // .role // "") == "assistant") ]
    | last as $turn
    | ([ $turn | .. | objects | select(.type? == "tool_use" and .name? == "AskUserQuestion") ] | length) > 0
  ' "$transcript_path" >/dev/null 2>&1
}

_sp_has_visible_recenter() {
  local last_assistant_message="$1"
  local normalized
  local visible_length
  normalized=$(printf '%s' "$last_assistant_message" | tr '[:upper:]' '[:lower:]' | tr '\n\r\t' '   ')
  visible_length=$(printf '%s' "$normalized" | wc -c | tr -d ' ')
  [ "${visible_length:-0}" -ge 80 ] 2>/dev/null || return 1
  case "$normalized" in
    *"where things stand"*|*"current project"*|*"project context"*|*"project "*|*" repo"*|*"branch"*|*"working tree"*|*"loaded .handoffs/"*|*"saved track"*|*"resume"*) return 0 ;;
  esac
  return 1
}

_sp_continuation_loaded_or_failed_honestly() {
  local transcript_path="$1"
  local continuation_path="$2"
  local last_assistant_message="$3"

  jq -e -s --arg path "$continuation_path" '
    [ .[] | .. | objects
      | select(.type? == "tool_use" and .name? == "Read")
      | (.input.file_path // .input.path // "")
      | select(. == $path)
    ] | length > 0
  ' "$transcript_path" >/dev/null 2>&1 && return 0

  printf '%s' "$last_assistant_message" | grep -qF "$continuation_path" || return 1
  printf '%s' "$last_assistant_message" | grep -qiE 'could not (load|read)|unable to (load|read)|not found|failed to (load|read)' || return 1
  return 0
}

sp_startup_missing_evidence() {
  local transcript_path="$1"
  local last_assistant_message="$2"
  local continuation_path="${3:-}"
  local floor_ready="${4:-no}"
  local missing=""

  [ "$floor_ready" = "yes" ] || missing="floor result"
  if ! _sp_has_visible_recenter "$last_assistant_message"; then
    [ -n "$missing" ] && missing="$missing, "
    missing="${missing}visible project recenter"
  fi
  if [ -n "$continuation_path" ] && ! _sp_continuation_loaded_or_failed_honestly "$transcript_path" "$continuation_path" "$last_assistant_message"; then
    [ -n "$missing" ] && missing="$missing, "
    missing="${missing}named handoff load"
  fi

  printf '%s' "$missing"
  [ -n "$missing" ]
}

sp_startup_evidence_complete() {
  local missing
  missing=$(sp_startup_missing_evidence "$@")
  [ -z "$missing" ]
}

sp_transcript_has_current_startup_activation() {
  local transcript_path="$1"
  local latest_prompt
  latest_prompt=$(jq -r -s '
    def role: (.message.role // .role // "");
    def content: (.message.content // .content // []);
    [ .[] | select(role == "user")
      | if (content | type) == "string" then content
        elif (content | type) == "array" then [ content[]? | select(.type == "text") | (.text // "") ] | join(" ")
        else "" end
      | select(length > 0)
    ] | last // ""
  ' "$transcript_path" 2>/dev/null)
  [ -n "$latest_prompt" ] || return 1
  sp_is_prompt_activation "$latest_prompt"
}

_sp_latest_closure_span() {
  local transcript_path="$1"
  local records
  local record
  local text
  local index
  local latest=""

  records=$(jq -c -s '
    def role: (.message.role // .role // "");
    def content: (.message.content // .content // []);
    def user_text:
      if (content | type) == "string" then content
      elif (content | type) == "array" then
        [ content[]?
          | if .type == "text" then (.text // "")
            elif .type == "tool_result" then
              if (.content | type) == "string" then .content
              elif (.content | type) == "array" then [ .content[]? | .text? // empty ] | join(" ")
              else "" end
            else "" end
        ] | map(select(length > 0)) | join(" ")
      else "" end;
    def direct_user_text:
      if (content | type) == "string" then (content | length) > 0
      elif (content | type) == "array" then any(content[]?; .type == "text" and ((.text // "") | length > 0))
      else false end;
    to_entries[]
    | select((.value | role) == "user")
    | {index:.key,text:(.value | user_text),direct:(.value | direct_user_text)}
  ' "$transcript_path" 2>/dev/null)

  while IFS= read -r record; do
    [ -n "$record" ] || continue
    text=$(printf '%s' "$record" | jq -r '.text // ""' 2>/dev/null)
    if sp_is_session_end_intent "$text"; then
      index=$(printf '%s' "$record" | jq -r '.index' 2>/dev/null)
      latest="$index"
    elif [ "$(printf '%s' "$record" | jq -r '.direct // false' 2>/dev/null)" = "true" ]; then
      latest=""
    fi
  done <<EOF
$records
EOF

  [ -n "$latest" ] || return 1
  jq -c -s --argjson start "$latest" 'to_entries[] | select(.key >= $start) | .value' "$transcript_path" 2>/dev/null
}

_sp_closure_has_full_status() {
  local span="$1"
  local text
  text=$(printf '%s' "$span" | jq -sr '
    [ .[] | select((.message.role // .role // "") == "assistant")
      | (.message.content // .content // [])
      | if type == "array" then .[]? | select(.type == "text") | (.text // "")
        elif type == "string" then .
        else empty end
    ] | join("\n") | ascii_downcase
  ' 2>/dev/null)

  printf '%s' "$text" | grep -qF 'closure walk status' || return 1
  for marker in \
    'staleness verification' \
    'architecture drift scan' \
    'routing matrix verification' \
    'persistent memory ledger' \
    'project conventions ledger' \
    'working memory ledger' \
    'backlog hygiene' \
    'pending prompts' \
    'pending scripts' \
    'working tree closure'
  do
    printf '%s' "$text" | grep -qF "$marker" || return 1
  done
  return 0
}

_sp_closure_has_handoff_write() {
  local span="$1"
  printf '%s' "$span" | jq -e -s '
    [ .[] | .. | objects
      | select(.type? == "tool_use" and (.name? == "Write" or .name? == "Edit" or .name? == "MultiEdit"))
      | (.input.file_path // .input.path // "")
      | select(test("(^|/)\\.handoffs/[^/]+\\.md$"))
      | select(test("/(findings-[^/]+|last-prompts/|backlog-archive/|scan-acks/)") | not)
    ] | length > 0
  ' >/dev/null 2>&1
}

_sp_closure_has_insights() {
  local span="$1"
  printf '%s' "$span" | jq -e -s '
    [ .[] | select((.message.role // .role // "") == "assistant") ]
    | tostring
    | test("insights?[^\\n]{0,80}(result|saved|captured|recorded|complete|unavailable|not available|could not|fallback|skipped)|command_name[^\\n]{0,40}insights|<command-name>/insights"; "i")
  ' >/dev/null 2>&1
}

_sp_closure_has_plugin_continuation() {
  local span="$1"
  local text
  text=$(printf '%s' "$span" | jq -sr '
    [ .[] | select((.message.role // .role // "") == "assistant")
      | (.message.content // .content // [])
      | if type == "array" then .[]? | select(.type == "text") | (.text // "")
        elif type == "string" then .
        else empty end
    ] | join("\n")
  ' 2>/dev/null)

  printf '%s' "$text" | grep -qF 'START 🟢 COPY' || return 1
  printf '%s' "$text" | grep -qE '/strategic-partner-plugin:strategic-partner[[:space:]]+\.handoffs/[^[:space:]]+\.md' || return 1
  return 0
}

sp_closure_missing_evidence() {
  local transcript_path="$1"
  local span
  local missing=""

  span=$(_sp_latest_closure_span "$transcript_path") || {
    printf 'explicit session-end intent'
    return 0
  }

  if ! _sp_closure_has_full_status "$span"; then missing="Closure Walk Status"; fi
  if ! _sp_closure_has_handoff_write "$span"; then
    [ -n "$missing" ] && missing="$missing, "
    missing="${missing}same-turn handoff write"
  fi
  if ! _sp_closure_has_insights "$span"; then
    [ -n "$missing" ] && missing="$missing, "
    missing="${missing}insights result or fallback"
  fi
  if ! _sp_closure_has_plugin_continuation "$span"; then
    [ -n "$missing" ] && missing="$missing, "
    missing="${missing}plugin continuation fence"
  fi

  printf '%s' "$missing"
  [ -n "$missing" ]
}

sp_closure_evidence_complete() {
  local missing
  missing=$(sp_closure_missing_evidence "$@")
  [ -z "$missing" ]
}

sp_transcript_has_session_end_intent() {
  _sp_latest_closure_span "$1" >/dev/null 2>&1
}
