#!/usr/bin/env bash
# emergency-snapshot.sh — StopFailure (rate_limit) hook for quota-guard.
# Last-resort fallback: writes a minimal emergency handoff when quota is already exhausted.
# StopFailure has zero decision control — this is purely observability.
# Requires: jq

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

HANDOFF_DIR="${QUOTA_GUARD_HANDOFF_DIR:-docs/handoff}"
mkdir -p "$HANDOFF_DIR"

TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "unknown")

cat > "$HANDOFF_DIR/${TIMESTAMP}-emergency.yaml" << EOF
handoff:
  version: "1.0"
  created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  source_agent: "claude-code"
  session_id: "$SESSION_ID"
  trigger: "emergency"

project:
  cwd: "$CWD"
  branch: "$BRANCH"

files:
  transcript_path: "$TRANSCRIPT"

notes: "Rate limit hit before handoff could complete. Read the transcript at the path above for full conversation context. The next agent should check git status and docs/handoff/ for any partial handoff files from earlier in this session."
EOF
