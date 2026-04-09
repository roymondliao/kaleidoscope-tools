#!/usr/bin/env bash
# quota-stop-guard.sh — Stop hook for quota-guard plugin.
# Reads quota state file, checks threshold, applies timestamp-based guard.
# Returns {"decision": "block"} when quota is low and no current-window handoff exists.
# Requires: jq, bc

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Configuration
THRESHOLD="${QUOTA_GUARD_THRESHOLD:-8}"
STATE_DIR="${QUOTA_STATE_DIR:-$HOME/.claude/runtime/quota}"
HANDOFF_DIR="${QUOTA_GUARD_HANDOFF_DIR:-docs/handoff}"

# 1. Check quota file exists
QUOTA_FILE="$STATE_DIR/$SESSION_ID.json"
if [ ! -f "$QUOTA_FILE" ]; then
  echo "quota-guard: no quota data found. statusLine integration may not be configured." >&2
  exit 0
fi

# 2. Read remaining percentages, compute minimum
QUOTA=$(cat "$QUOTA_FILE")
FIVE_REM=$(echo "$QUOTA" | jq '.five_hour_remaining_pct // empty')
SEVEN_REM=$(echo "$QUOTA" | jq '.seven_day_remaining_pct // empty')

# Collect non-null values
REMAINING_VALUES=()
[ -n "$FIVE_REM" ] && REMAINING_VALUES+=("$FIVE_REM")
[ -n "$SEVEN_REM" ] && REMAINING_VALUES+=("$SEVEN_REM")

# No rate_limits data (API key mode) → pass through
if [ ${#REMAINING_VALUES[@]} -eq 0 ]; then
  exit 0
fi

# Find minimum remaining
MIN_REMAINING="${REMAINING_VALUES[0]}"
for val in "${REMAINING_VALUES[@]}"; do
  if (( $(echo "$val < $MIN_REMAINING" | bc -l) )); then
    MIN_REMAINING="$val"
  fi
done

# 3. Above threshold → pass through
if (( $(echo "$MIN_REMAINING >= $THRESHOLD" | bc -l) )); then
  exit 0
fi

# 4. Below threshold — check timestamp-based guard
# Current 5h window start = resets_at - 18000 (5 hours in seconds)
FIVE_RESETS_AT=$(echo "$QUOTA" | jq '.five_hour_resets_at // empty')
if [ -n "$FIVE_RESETS_AT" ]; then
  WINDOW_START=$((FIVE_RESETS_AT - 18000))
else
  # Fallback: if no resets_at, use 5 hours ago
  WINDOW_START=$(($(date +%s) - 18000))
fi

# Search for handoff files matching this session_id created after window start
if [ -d "$HANDOFF_DIR" ]; then
  while IFS= read -r handoff_file; do
    [ -z "$handoff_file" ] && continue
    # Check if this handoff belongs to current session
    if grep -q "session_id.*$SESSION_ID" "$handoff_file" 2>/dev/null; then
      # Extract timestamp from filename: YYYY-MM-DD-HHMMSS-handoff.yaml
      BASENAME=$(basename "$handoff_file")
      FILE_TS_STR=$(echo "$BASENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' || true)
      if [ -n "$FILE_TS_STR" ]; then
        # Convert filename timestamp to epoch
        # Format: YYYY-MM-DD-HHMMSS → YYYY-MM-DD HH:MM:SS
        FORMATTED="${FILE_TS_STR:0:10} ${FILE_TS_STR:11:2}:${FILE_TS_STR:13:2}:${FILE_TS_STR:15:2}"
        # macOS date -j -f, Linux date -d
        FILE_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$FORMATTED" +%s 2>/dev/null || \
                     date -d "$FORMATTED" +%s 2>/dev/null || echo "0")
        # If handoff is from current window → pass through
        if [ "$FILE_EPOCH" -ge "$WINDOW_START" ]; then
          exit 0
        fi
      fi
    fi
  done < <(find "$HANDOFF_DIR" -name "*-handoff.yaml" -type f 2>/dev/null)
fi

# 5. Below threshold + no current-window handoff → block
MIN_INT=$(printf '%.0f' "$MIN_REMAINING")
jq -n \
  --arg reason "Quota remaining: ${MIN_INT}% (threshold: ${THRESHOLD}%). Please execute /quota-guard:handoff to generate a handoff document before the session ends." \
  '{
    "decision": "block",
    "reason": $reason
  }'
