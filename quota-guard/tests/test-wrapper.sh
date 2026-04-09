#!/usr/bin/env bash
# test-wrapper.sh — verifies quota-wrapper.sh chains sampler + displays output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="${SCRIPT_DIR}/../scripts/quota-wrapper.sh"
TEST_STATE_DIR=$(mktemp -d)
trap "rm -rf $TEST_STATE_DIR" EXIT

MOCK_INPUT='{
  "session_id": "test-wrapper-001",
  "model": { "display_name": "Opus" },
  "workspace": { "current_dir": "/home/user/project" },
  "rate_limits": {
    "five_hour": { "used_percentage": 72.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  }
}'

# --- Test 1: Default display (no user statusLine) ---
OUTPUT=$(echo "$MOCK_INPUT" | QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_USER_STATUSLINE="" bash "$WRAPPER" 2>/dev/null)

if echo "$OUTPUT" | grep -q "Opus"; then
  echo "PASS: wrapper default display includes model name"
else
  echo "FAIL: wrapper output missing model name: $OUTPUT"
  exit 1
fi

if echo "$OUTPUT" | grep -q "5h"; then
  echo "PASS: wrapper default display includes 5h quota"
else
  echo "FAIL: wrapper output missing 5h quota: $OUTPUT"
  exit 1
fi

# --- Test 2: Verify sampler was triggered ---
QUOTA_FILE="$TEST_STATE_DIR/test-wrapper-001.json"
if [ -f "$QUOTA_FILE" ]; then
  echo "PASS: wrapper triggered sampler (quota file exists)"
else
  echo "FAIL: sampler not triggered (no quota file)"
  exit 1
fi

# --- Test 3: With user statusLine ---
USER_SL=$(mktemp)
cat > "$USER_SL" << 'SCRIPT'
#!/bin/bash
cat > /dev/null
echo "CUSTOM_STATUS"
SCRIPT

OUTPUT2=$(echo "$MOCK_INPUT" | QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_USER_STATUSLINE="$USER_SL" bash "$WRAPPER" 2>/dev/null)
rm "$USER_SL"

if echo "$OUTPUT2" | grep -q "CUSTOM_STATUS"; then
  echo "PASS: wrapper chains user statusLine"
else
  echo "FAIL: user statusLine not chained: $OUTPUT2"
  exit 1
fi
