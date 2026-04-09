#!/usr/bin/env bash
# test-sampler.sh — verifies quota-sampler.sh reads stdin JSON and writes correct quota file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLER="${SCRIPT_DIR}/../scripts/quota-sampler.sh"
TEST_STATE_DIR=$(mktemp -d)
trap "rm -rf $TEST_STATE_DIR" EXIT

# --- Test 1: Normal rate_limits ---
MOCK_INPUT='{
  "session_id": "test-session-001",
  "transcript_path": "/tmp/transcript.jsonl",
  "workspace": { "current_dir": "/home/user/project" },
  "cwd": "/home/user/project",
  "rate_limits": {
    "five_hour": { "used_percentage": 72.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  }
}'

echo "$MOCK_INPUT" | QUOTA_STATE_DIR="$TEST_STATE_DIR" bash "$SAMPLER"

OUTPUT_FILE="$TEST_STATE_DIR/test-session-001.json"
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "FAIL: quota file not created at $OUTPUT_FILE"
  exit 1
fi

FIVE_REMAINING=$(jq -r '.five_hour_remaining_pct' "$OUTPUT_FILE")
SEVEN_REMAINING=$(jq -r '.seven_day_remaining_pct' "$OUTPUT_FILE")
SESSION_ID=$(jq -r '.session_id' "$OUTPUT_FILE")

PASS=true
[ "$SESSION_ID" != "test-session-001" ] && echo "FAIL: session_id=$SESSION_ID" && PASS=false
[ "$FIVE_REMAINING" != "27.5" ] && echo "FAIL: five_hour_remaining_pct=$FIVE_REMAINING (expected 27.5)" && PASS=false
[ "$SEVEN_REMAINING" != "58.8" ] && echo "FAIL: seven_day_remaining_pct=$SEVEN_REMAINING (expected 58.8)" && PASS=false

if $PASS; then
  echo "PASS: quota-sampler basic test"
else
  echo "Output file contents:"
  cat "$OUTPUT_FILE"
  exit 1
fi

# --- Test 2: Missing rate_limits (API key mode) ---
MOCK_NO_RATE='{
  "session_id": "test-session-002",
  "workspace": { "current_dir": "/home/user/project" }
}'
echo "$MOCK_NO_RATE" | QUOTA_STATE_DIR="$TEST_STATE_DIR" bash "$SAMPLER"

NO_RATE_FILE="$TEST_STATE_DIR/test-session-002.json"
if [ ! -f "$NO_RATE_FILE" ]; then
  echo "FAIL: quota file not created for missing rate_limits"
  exit 1
fi

FIVE_NULL=$(jq -r '.five_hour_remaining_pct' "$NO_RATE_FILE")
[ "$FIVE_NULL" != "null" ] && echo "FAIL: expected null for missing rate_limits, got $FIVE_NULL" && exit 1

echo "PASS: quota-sampler missing rate_limits test"

# --- Test 3: No stdout output ---
STDOUT_OUTPUT=$(echo "$MOCK_INPUT" | QUOTA_STATE_DIR="$TEST_STATE_DIR" bash "$SAMPLER")
if [ -n "$STDOUT_OUTPUT" ]; then
  echo "FAIL: sampler produced stdout: $STDOUT_OUTPUT"
  exit 1
fi
echo "PASS: quota-sampler produces no stdout"
