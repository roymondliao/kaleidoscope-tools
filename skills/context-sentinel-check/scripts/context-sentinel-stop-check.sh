#!/usr/bin/env sh
set -eu

payload="$(cat)"
sentinel="${CONTEXT_SENTINEL:-}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop hook triggered" >> "${CLAUDE_PROJECT_DIR}/.claude/hooks/hook.log"

if [ -z "$sentinel" ]; then
  exit 0
fi

if printf '%s' "$payload" | grep -F -- "$sentinel" >/dev/null 2>&1; then
  exit 0
fi

context="Context sentinel exact match check failed.
Please run: compact
Then restate key constraints and sentinel to refresh working memory."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg msg "$context" '{"systemMessage":$msg}'
else
  escaped_context=$(printf '%s' "$context" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN { ORS=""; first=1 } { if (!first) printf "\\n"; first=0; printf "%s", $0 }')
  echo "{\"systemMessage\":\"${escaped_context}\"}"
fi
