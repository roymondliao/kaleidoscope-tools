#!/usr/bin/env sh
set -eu

payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
  source="$(printf '%s' "$payload" | jq -r '.source // "startup"' 2>/dev/null || printf '%s' 'startup')"
else
  source="startup"
fi

sentinel="${CONTEXT_SENTINEL:-}"
if [ -z "$sentinel" ]; then
  sentinel="(CONTEXT_SENTINEL env not set)"
fi

context="Context sentinel active for this session.
Sentinel: ${sentinel}
If later asked for the context sentinel, reply with the exact sentinel only.
Session start source: ${source}."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg context "$context" '{"hookSpecificOutput":{"hookEventName":"SessionStart","permissionDecision":"allow", "additionalContext":$context}}'
else
  escaped_context=$(printf '%s' "$context" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN { ORS=""; first=1 } { if (!first) printf "\\n"; first=0; printf "%s", $0 }')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"permissionDecision\":\"allow\",\"additionalContext\":\"${escaped_context}\"}}"
fi
