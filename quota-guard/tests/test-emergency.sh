#!/usr/bin/env bash
# test-emergency.sh — verifies emergency-snapshot.sh writes a minimal handoff
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EMERGENCY="${SCRIPT_DIR}/../hooks/emergency-snapshot.sh"
TEST_OUTPUT_DIR=$(mktemp -d)
trap "rm -rf $TEST_OUTPUT_DIR" EXIT

MOCK_INPUT='{
  "session_id": "test-emergency-001",
  "transcript_path": "/tmp/transcript.jsonl",
  "cwd": "/home/user/project"
}'

echo "$MOCK_INPUT" | QUOTA_GUARD_HANDOFF_DIR="$TEST_OUTPUT_DIR" bash "$EMERGENCY"

# Find the output file
OUTFILE=$(find "$TEST_OUTPUT_DIR" -name "*-emergency.yaml" -type f | head -1)
if [ -z "$OUTFILE" ]; then
  echo "FAIL: emergency snapshot not created"
  exit 1
fi

# Verify content
if grep -q "trigger.*emergency" "$OUTFILE" && grep -q "session_id.*test-emergency-001" "$OUTFILE"; then
  echo "PASS: emergency snapshot contains required fields"
else
  echo "FAIL: emergency snapshot missing fields"
  cat "$OUTFILE"
  exit 1
fi

if grep -q "transcript_path" "$OUTFILE"; then
  echo "PASS: emergency snapshot contains transcript_path"
else
  echo "FAIL: missing transcript_path"
  exit 1
fi
