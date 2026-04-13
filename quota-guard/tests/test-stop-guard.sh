#!/usr/bin/env bash
# test-stop-guard.sh — verifies Stop hook decision logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="${SCRIPT_DIR}/../hooks/quota-stop-guard.sh"
TEST_STATE_DIR=$(mktemp -d)
TEST_PROJECT_DIR=$(mktemp -d)
trap "rm -rf $TEST_STATE_DIR $TEST_PROJECT_DIR" EXIT

MOCK_HOOK_INPUT='{"session_id":"test-guard-001","transcript_path":"/tmp/t.jsonl","cwd":"/tmp/project"}'

# --- Test 1: No quota file → pass through (exit 0, no block decision) ---
OUTPUT=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT" ] || ! echo "$OUTPUT" | jq -e '.decision' >/dev/null 2>&1; then
  echo "PASS: no quota file → pass through"
else
  echo "FAIL: expected pass through, got: $OUTPUT"
  exit 1
fi

# --- Test 2: Quota above threshold → pass through ---
mkdir -p "$TEST_STATE_DIR"
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 50,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600
}
QUOTA

OUTPUT2=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT2" ] || ! echo "$OUTPUT2" | jq -e '.decision' >/dev/null 2>&1; then
  echo "PASS: quota above threshold → pass through"
else
  echo "FAIL: expected pass through, got: $OUTPUT2"
  exit 1
fi

# --- Test 3: Quota below threshold, no handoff → block ---
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 5,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600
}
QUOTA

OUTPUT3=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  bash "$GUARD" 2>/dev/null)

DECISION=$(echo "$OUTPUT3" | jq -r '.decision // empty')
if [ "$DECISION" = "block" ]; then
  echo "PASS: quota below threshold → block"
else
  echo "FAIL: expected block, got: $OUTPUT3"
  exit 1
fi

# --- Test 4: Quota below threshold + current-window handoff exists → pass through ---
HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff"
mkdir -p "$HANDOFF_DIR"

# resets_at=1738425600 → window start = 1738425600 - 18000 = 1738407600
# Create handoff with timestamp AFTER window start (use a fixed recent timestamp)
# We use current time to be safe
NOW_TS=$(date +%Y-%m-%d-%H%M%S)
cat > "$HANDOFF_DIR/${NOW_TS}-handoff.yaml" << HANDOFF
handoff:
  session_id: "test-guard-001"
  trigger: "quota_low"
HANDOFF

# Set resets_at to be 5 hours from now (so window start = now - 0 seconds, essentially)
FUTURE_RESET=$(($(date +%s) + 18000))
cat > "$TEST_STATE_DIR/test-guard-001.json" << QUOTA
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 5,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": $FUTURE_RESET
}
QUOTA

OUTPUT4=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$HANDOFF_DIR" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT4" ] || ! echo "$OUTPUT4" | jq -e '.decision' >/dev/null 2>&1; then
  echo "PASS: current-window handoff exists → pass through"
else
  echo "FAIL: expected pass through with existing handoff, got: $OUTPUT4"
  exit 1
fi

# --- Test 5: No rate_limits data (API key mode) → pass through ---
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": null,
  "seven_day_remaining_pct": null
}
QUOTA

OUTPUT5=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff2" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT5" ] || ! echo "$OUTPUT5" | jq -e '.decision' >/dev/null 2>&1; then
  echo "PASS: null rate_limits → pass through"
else
  echo "FAIL: expected pass through for null rate_limits, got: $OUTPUT5"
  exit 1
fi

# --- Test 6: Context below checkpoint → no additionalContext ---
SENTINEL_DIR=$(mktemp -d)
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 50,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600,
  "context_used_pct": 30
}
QUOTA

OUTPUT6=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff-t6" \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_DIR" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT6" ] || ! echo "$OUTPUT6" | jq -e '.additionalContext' >/dev/null 2>&1; then
  echo "PASS: context 30% below checkpoint 40% → no sentinel check"
else
  echo "FAIL: expected no additionalContext, got: $OUTPUT6"
  exit 1
fi

# --- Test 7: Context above checkpoint → additionalContext injected ---
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 50,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600,
  "context_used_pct": 45
}
QUOTA

OUTPUT7=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff-t7" \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_DIR" \
  bash "$GUARD" 2>/dev/null) || true

if echo "$OUTPUT7" | jq -e '.additionalContext' >/dev/null 2>&1; then
  echo "PASS: context 45% above checkpoint 40% → sentinel check triggered"
else
  echo "FAIL: expected additionalContext, got: $OUTPUT7"
  exit 1
fi

# --- Test 8: Same checkpoint not triggered twice ---
OUTPUT8=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff-t8" \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_DIR" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT8" ] || ! echo "$OUTPUT8" | jq -e '.additionalContext' >/dev/null 2>&1; then
  echo "PASS: checkpoint 40% already triggered → not triggered again"
else
  echo "FAIL: checkpoint 40% triggered twice, got: $OUTPUT8"
  exit 1
fi

# --- Test 9: Next checkpoint triggers when context grows ---
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 50,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600,
  "context_used_pct": 55
}
QUOTA

OUTPUT9=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff-t9" \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_DIR" \
  bash "$GUARD" 2>/dev/null) || true

if echo "$OUTPUT9" | jq -e '.additionalContext' >/dev/null 2>&1; then
  echo "PASS: context 55% → checkpoint 50% triggered"
else
  echo "FAIL: expected checkpoint 50% trigger, got: $OUTPUT9"
  exit 1
fi

# --- Test 10: Null context_used_pct → skip sentinel check ---
cat > "$TEST_STATE_DIR/test-guard-001.json" << 'QUOTA'
{
  "session_id": "test-guard-001",
  "five_hour_remaining_pct": 50,
  "seven_day_remaining_pct": 60,
  "five_hour_resets_at": 1738425600,
  "context_used_pct": null
}
QUOTA

SENTINEL_DIR2=$(mktemp -d)
OUTPUT10=$(echo "$MOCK_HOOK_INPUT" | \
  QUOTA_STATE_DIR="$TEST_STATE_DIR" \
  QUOTA_GUARD_THRESHOLD=8 \
  QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff-t10" \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_DIR2" \
  bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT10" ] || ! echo "$OUTPUT10" | jq -e '.additionalContext' >/dev/null 2>&1; then
  echo "PASS: null context_used_pct → skip sentinel check"
else
  echo "FAIL: expected skip for null context, got: $OUTPUT10"
  exit 1
fi

rm -rf "$SENTINEL_DIR" "$SENTINEL_DIR2"
