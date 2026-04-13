#!/usr/bin/env bash
# quota-stop-guard.sh — Stop hook for quota-guard plugin.
# Two checks:
#   1. Quota check — blocks when quota is low (handoff)
#   2. Sentinel check — injects verification reminder at context checkpoints
# Requires: jq, bc

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Configuration
THRESHOLD="${QUOTA_GUARD_THRESHOLD:-8}"
STATE_DIR="${QUOTA_STATE_DIR:-$HOME/.claude/runtime/quota}"
HANDOFF_DIR="${QUOTA_GUARD_HANDOFF_DIR:-docs/handoff}"
SENTINEL_CHECKPOINTS="${QUOTA_GUARD_SENTINEL_CHECKPOINTS:-40,50,60,70,80}"
SENTINEL_STATE_DIR="${SENTINEL_STATE_DIR:-$HOME/.claude/runtime/sentinel}"

# --- Read quota file ---
QUOTA_FILE="$STATE_DIR/$SESSION_ID.json"
if [ ! -f "$QUOTA_FILE" ]; then
  echo "quota-guard: no quota data found. statusLine integration may not be configured." >&2
  exit 0
fi

QUOTA=$(cat "$QUOTA_FILE")

# ============================================================
# CHECK 1: Quota boundary (existing) — may block for handoff
# ============================================================

FIVE_REM=$(echo "$QUOTA" | jq '.five_hour_remaining_pct // empty')
SEVEN_REM=$(echo "$QUOTA" | jq '.seven_day_remaining_pct // empty')

REMAINING_VALUES=()
[ -n "$FIVE_REM" ] && REMAINING_VALUES+=("$FIVE_REM")
[ -n "$SEVEN_REM" ] && REMAINING_VALUES+=("$SEVEN_REM")

QUOTA_SHOULD_BLOCK=false

if [ ${#REMAINING_VALUES[@]} -gt 0 ]; then
  MIN_REMAINING="${REMAINING_VALUES[0]}"
  for val in "${REMAINING_VALUES[@]}"; do
    if (( $(echo "$val < $MIN_REMAINING" | bc -l) )); then
      MIN_REMAINING="$val"
    fi
  done

  if (( $(echo "$MIN_REMAINING < $THRESHOLD" | bc -l) )); then
    # Check timestamp-based guard for handoff
    FIVE_RESETS_AT=$(echo "$QUOTA" | jq '.five_hour_resets_at // empty')
    if [ -n "$FIVE_RESETS_AT" ]; then
      WINDOW_START=$((FIVE_RESETS_AT - 18000))
    else
      WINDOW_START=$(($(date +%s) - 18000))
    fi

    HANDOFF_FOUND=false
    if [ -d "$HANDOFF_DIR" ]; then
      while IFS= read -r handoff_file; do
        [ -z "$handoff_file" ] && continue
        if grep -q "session_id.*$SESSION_ID" "$handoff_file" 2>/dev/null; then
          BASENAME=$(basename "$handoff_file")
          FILE_TS_STR=$(echo "$BASENAME" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' || true)
          if [ -n "$FILE_TS_STR" ]; then
            FORMATTED="${FILE_TS_STR:0:10} ${FILE_TS_STR:11:2}:${FILE_TS_STR:13:2}:${FILE_TS_STR:15:2}"
            FILE_EPOCH=$(date -j -f "%Y-%m-%d %H:%M:%S" "$FORMATTED" +%s 2>/dev/null || \
                         date -d "$FORMATTED" +%s 2>/dev/null || echo "0")
            if [ "$FILE_EPOCH" -ge "$WINDOW_START" ]; then
              HANDOFF_FOUND=true
              break
            fi
          fi
        fi
      done < <(find "$HANDOFF_DIR" -name "*-handoff.yaml" -type f 2>/dev/null)
    fi

    if [ "$HANDOFF_FOUND" = false ]; then
      QUOTA_SHOULD_BLOCK=true
    fi
  fi
fi

# If quota wants to block → block and skip sentinel check
if [ "$QUOTA_SHOULD_BLOCK" = true ]; then
  MIN_INT=$(printf '%.0f' "$MIN_REMAINING")
  jq -n \
    --arg reason "Quota remaining: ${MIN_INT}% (threshold: ${THRESHOLD}%). Please execute /quota-guard:handoff to generate a handoff document before the session ends." \
    '{
      "decision": "block",
      "reason": $reason
    }'
  exit 0
fi

# ============================================================
# CHECK 2: Context sentinel checkpoint (new) — may inject additionalContext
# ============================================================

CONTEXT_USED=$(echo "$QUOTA" | jq '.context_used_pct // empty')

# No context data → skip sentinel check
if [ -z "$CONTEXT_USED" ]; then
  exit 0
fi

# Parse checkpoints
IFS=',' read -ra CHECKPOINTS <<< "$SENTINEL_CHECKPOINTS"

# Read triggered checkpoints
CHECKPOINT_FILE="$SENTINEL_STATE_DIR/${SESSION_ID}.checkpoints"
TRIGGERED=""
if [ -f "$CHECKPOINT_FILE" ]; then
  TRIGGERED=$(cat "$CHECKPOINT_FILE")
fi

# Find first untriggered checkpoint that context has crossed
for CP in "${CHECKPOINTS[@]}"; do
  CP=$(echo "$CP" | tr -d '[:space:]')
  if (( $(echo "$CONTEXT_USED >= $CP" | bc -l) )); then
    if ! echo "$TRIGGERED" | grep -qx "$CP" 2>/dev/null; then
      # New checkpoint crossed — inject verification reminder
      mkdir -p "$SENTINEL_STATE_DIR"
      echo "$CP" >> "$CHECKPOINT_FILE"

      CONTEXT_INT=$(printf '%.0f' "$CONTEXT_USED")
      VERIFY_PATH="\${CLAUDE_PROJECT_DIR}/skills/context-sentinel-check/scripts/verify-sentinel.sh"

      jq -n \
        --arg ctx "Context usage at ${CONTEXT_INT}% (checkpoint: ${CP}%). Verify your context sentinel NOW. State your sentinel value, then run: echo \"YOUR_SENTINEL\" | bash \"${VERIFY_PATH}\". If the result is FAIL, run /compact immediately." \
        '{ "additionalContext": $ctx }'
      exit 0
    fi
  fi
done

# No new checkpoint → pass through
exit 0
