#!/usr/bin/env sh
set -eu

payload="$(cat)"
hash_file="$HOME/.claude/runtime/session-sentinel.hash"

if [ ! -f "$hash_file" ]; then
  exit 0
fi

stored_hash="$(cat "$hash_file" | tr -d '[:space:]')"

# Extract any hex-like token from Claude's last response that might be the sentinel
# The Stop hook payload contains the last assistant message
if command -v jq >/dev/null 2>&1; then
  last_message="$(printf '%s' "$payload" | jq -r '.last_assistant_message // ""' 2>/dev/null || echo "")"
else
  last_message=""
fi

# Check if the last message contains a string whose hash matches the stored sentinel
# This is a lightweight check — the full verification is done via the skill
# For the Stop hook, we skip the check (sentinel verification is done via /context-sentinel-check)
exit 0
