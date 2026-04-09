#!/usr/bin/env bash
# quota-wrapper.sh — Composable statusLine wrapper.
# 1. Runs quota-sampler.sh (silent, writes quota file)
# 2. Runs user's original statusLine (if QUOTA_GUARD_USER_STATUSLINE is set)
# 3. Falls back to default display (model + quota remaining)
# Requires: jq, bc

set -euo pipefail

INPUT=$(cat)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Run sampler silently (no stdout)
echo "$INPUT" | QUOTA_STATE_DIR="${QUOTA_STATE_DIR:-}" bash "$SCRIPT_DIR/quota-sampler.sh" 2>/dev/null || true

# 2. Chain user's original statusLine, or show default
USER_STATUSLINE="${QUOTA_GUARD_USER_STATUSLINE:-}"

if [ -n "$USER_STATUSLINE" ] && [ -f "$USER_STATUSLINE" ]; then
  echo "$INPUT" | bash "$USER_STATUSLINE"
else
  # Default display: [Model] | 5h left: XX% | 7d left: XX%
  MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
  FIVE_USED=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
  SEVEN_USED=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')

  PARTS="[$MODEL]"
  if [ -n "$FIVE_USED" ]; then
    FIVE_LEFT=$(echo "100 - $FIVE_USED" | bc)
    PARTS="$PARTS | 5h left: $(printf '%.0f' "$FIVE_LEFT")%"
  fi
  if [ -n "$SEVEN_USED" ]; then
    SEVEN_LEFT=$(echo "100 - $SEVEN_USED" | bc)
    PARTS="$PARTS | 7d left: $(printf '%.0f' "$SEVEN_LEFT")%"
  fi
  echo "$PARTS"
fi
