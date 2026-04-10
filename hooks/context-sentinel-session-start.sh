#!/usr/bin/env sh
set -eu

payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
  source="$(printf '%s' "$payload" | jq -r '.source // "startup"' 2>/dev/null || printf '%s' 'startup')"
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"' 2>/dev/null || printf '%s' 'unknown')"
else
  source="startup"
  session_id="unknown"
fi

# Auto-generate random sentinel per session (no env var needed)
sentinel="$(openssl rand -hex 8)"

# Store hash (not plaintext) so Claude can't cheat by reading the file
hash="$(printf '%s' "$sentinel" | shasum -a 256 | cut -d' ' -f1)"
sentinel_dir="$HOME/.claude/runtime/sentinel"
mkdir -p "$sentinel_dir"
printf '%s' "$hash" > "$sentinel_dir/${session_id}.hash"

# Cleanup: remove hash files older than 24 hours
find "$sentinel_dir" -name "*.hash" -type f -mtime +1 -delete 2>/dev/null || true

context="Context sentinel active for this session. Sentinel: ${sentinel} — If later asked for the context sentinel, reply with the exact sentinel only. Session start source: ${source}."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg context "$context" '{"hookSpecificOutput":{"hookEventName":"SessionStart","permissionDecision":"allow","additionalContext":$context}}'
else
  escaped_context=$(printf '%s' "$context" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN { ORS=""; first=1 } { if (!first) printf "\\n"; first=0; printf "%s", $0 }')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"permissionDecision\":\"allow\",\"additionalContext\":\"${escaped_context}\"}}"
fi
