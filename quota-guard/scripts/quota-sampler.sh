#!/usr/bin/env bash
# quota-sampler.sh — Reads statusLine JSON from stdin, writes quota state to file.
# No stdout — this script is silent. Display is handled by quota-wrapper.sh or the user's own statusLine.
# Requires: jq

set -euo pipefail

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // ""')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')

FIVE_USED=$(echo "$INPUT" | jq '.rate_limits.five_hour.used_percentage // null')
SEVEN_USED=$(echo "$INPUT" | jq '.rate_limits.seven_day.used_percentage // null')
FIVE_RESET=$(echo "$INPUT" | jq '.rate_limits.five_hour.resets_at // null')
SEVEN_RESET=$(echo "$INPUT" | jq '.rate_limits.seven_day.resets_at // null')
CONTEXT_USED=$(echo "$INPUT" | jq '.context_window.used_percentage // null')

STATE_DIR="${QUOTA_STATE_DIR:-$HOME/.claude/runtime/quota}"
mkdir -p "$STATE_DIR"

jq -n \
  --arg sid "$SESSION_ID" \
  --arg cwd "$CWD" \
  --arg transcript "$TRANSCRIPT" \
  --argjson ts "$(date +%s)" \
  --argjson five_used "$FIVE_USED" \
  --argjson seven_used "$SEVEN_USED" \
  --argjson five_reset "$FIVE_RESET" \
  --argjson seven_reset "$SEVEN_RESET" \
  --argjson context_used "$CONTEXT_USED" \
  '{
    session_id: $sid,
    cwd: $cwd,
    transcript_path: $transcript,
    updated_at: $ts,
    five_hour_used_pct: $five_used,
    five_hour_remaining_pct: (if $five_used then ([0, (100 - $five_used)] | max) else null end),
    five_hour_resets_at: $five_reset,
    seven_day_used_pct: $seven_used,
    seven_day_remaining_pct: (if $seven_used then ([0, (100 - $seven_used)] | max) else null end),
    seven_day_resets_at: $seven_reset,
    context_used_pct: $context_used
  }' > "$STATE_DIR/$SESSION_ID.json"
