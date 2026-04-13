# Sentinel Auto-Verify Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend quota-guard's Stop hook to automatically verify the context sentinel at configurable context usage checkpoints, triggering compact when verification fails.

**Architecture:** quota-sampler.sh is extended to write `context_used_pct` alongside quota data. The Stop hook reads this value and, when a new checkpoint is crossed, injects an `additionalContext` reminder (no block) asking Claude to verify its sentinel. Checkpoint state is tracked per-session in a file to prevent re-triggering.

**Tech Stack:** Bash, jq, bc

**Spec:** `docs/superpowers/specs/2026-04-13-sentinel-auto-verify-design.md`

---

## File Structure

```
quota-guard/
  config.yaml                    # MODIFY: add sentinel_checkpoints
  scripts/
    quota-sampler.sh             # MODIFY: add context_used_pct to output
  hooks/
    quota-stop-guard.sh          # MODIFY: add sentinel checkpoint logic after quota check
  tests/
    test-sampler.sh              # MODIFY: add context_used_pct test
    test-stop-guard.sh           # MODIFY: add sentinel checkpoint tests
```

Also touched (not in quota-guard):
```
hooks/
  context-sentinel-session-start.sh  # MODIFY: clear checkpoint state on new sentinel generation
```

---

### Task 1: Extend quota-sampler.sh to write context_used_pct

**Files:**
- Modify: `quota-guard/scripts/quota-sampler.sh`
- Modify: `quota-guard/tests/test-sampler.sh`

- [ ] **Step 1: Add context_used_pct test to test-sampler.sh**

Add this test at the end of `quota-guard/tests/test-sampler.sh` (after the "no stdout" test):

```bash
# --- Test 4: context_used_pct is written ---
MOCK_WITH_CONTEXT='{
  "session_id": "test-session-003",
  "workspace": { "current_dir": "/home/user/project" },
  "rate_limits": {
    "five_hour": { "used_percentage": 30, "resets_at": 1738425600 }
  },
  "context_window": {
    "used_percentage": 52.3
  }
}'
echo "$MOCK_WITH_CONTEXT" | QUOTA_STATE_DIR="$TEST_STATE_DIR" bash "$SAMPLER"

CTX_FILE="$TEST_STATE_DIR/test-session-003.json"
CTX_PCT=$(jq -r '.context_used_pct' "$CTX_FILE")
if [ "$CTX_PCT" = "52.3" ]; then
  echo "PASS: context_used_pct written correctly"
else
  echo "FAIL: context_used_pct=$CTX_PCT (expected 52.3)"
  exit 1
fi

# --- Test 5: context_used_pct null when missing ---
MOCK_NO_CTX='{
  "session_id": "test-session-004",
  "workspace": { "current_dir": "/home/user/project" }
}'
echo "$MOCK_NO_CTX" | QUOTA_STATE_DIR="$TEST_STATE_DIR" bash "$SAMPLER"

NO_CTX_FILE="$TEST_STATE_DIR/test-session-004.json"
NO_CTX_PCT=$(jq -r '.context_used_pct' "$NO_CTX_FILE")
if [ "$NO_CTX_PCT" = "null" ]; then
  echo "PASS: context_used_pct null when missing"
else
  echo "FAIL: expected null, got $NO_CTX_PCT"
  exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash quota-guard/tests/test-sampler.sh
```

Expected: First 3 tests PASS, Test 4 FAIL (field `context_used_pct` not in output yet).

- [ ] **Step 3: Add context_used_pct to quota-sampler.sh**

In `quota-guard/scripts/quota-sampler.sh`, add after line 17 (`SEVEN_RESET=...`):

```bash
CONTEXT_USED=$(echo "$INPUT" | jq '.context_window.used_percentage // null')
```

Then add `--argjson context_used "$CONTEXT_USED"` to the `jq -n` command's arguments, and add `context_used_pct: $context_used` to the JSON output object (after the `seven_day_resets_at` line).

The full updated `jq -n` block becomes:

```bash
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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash quota-guard/tests/test-sampler.sh
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add quota-guard/scripts/quota-sampler.sh quota-guard/tests/test-sampler.sh
git commit -m "feat(quota-guard): add context_used_pct to sampler output"
```

---

### Task 2: Update config.yaml with sentinel_checkpoints

**Files:**
- Modify: `quota-guard/config.yaml`

- [ ] **Step 1: Add sentinel_checkpoints to config.yaml**

Replace the full content of `quota-guard/config.yaml` with:

```yaml
# quota-guard default configuration
# Override via environment variables:
#   QUOTA_GUARD_THRESHOLD — remaining % to trigger handoff (default: 8)
#   QUOTA_GUARD_USER_STATUSLINE — path to user's original statusLine script
#   QUOTA_GUARD_SENTINEL_CHECKPOINTS — comma-separated context % thresholds (default: "40,50,60,70,80")

threshold: 8
quota_state_dir: "~/.claude/runtime/quota"
handoff_output_dir: "docs/handoff"
sentinel_checkpoints: [40, 50, 60, 70, 80]
```

- [ ] **Step 2: Commit**

```bash
git add quota-guard/config.yaml
git commit -m "feat(quota-guard): add sentinel_checkpoints config"
```

---

### Task 3: Add sentinel checkpoint logic to Stop hook

**Files:**
- Modify: `quota-guard/hooks/quota-stop-guard.sh`
- Modify: `quota-guard/tests/test-stop-guard.sh`

- [ ] **Step 1: Add sentinel checkpoint tests to test-stop-guard.sh**

Add these tests at the end of `quota-guard/tests/test-stop-guard.sh`:

```bash
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
```

- [ ] **Step 2: Run tests to verify new tests fail**

```bash
bash quota-guard/tests/test-stop-guard.sh
```

Expected: Tests 1-5 PASS, Test 6 may PASS (no output = pass through), Tests 7+ FAIL (no sentinel logic yet).

- [ ] **Step 3: Add sentinel checkpoint logic to quota-stop-guard.sh**

Add the following AFTER the existing quota block logic (after line 94 `'`), but BEFORE the script would exit. The key is: if the quota check wants to block, we block and skip sentinel. Otherwise, we do the sentinel checkpoint check.

Restructure the script so the quota block is in a function, and sentinel check runs only if quota doesn't block. Replace the entire content of `quota-guard/hooks/quota-stop-guard.sh` with:

```bash
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
```

- [ ] **Step 4: Run tests to verify all pass**

```bash
bash quota-guard/tests/test-stop-guard.sh
```

Expected: All 10 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add quota-guard/hooks/quota-stop-guard.sh quota-guard/tests/test-stop-guard.sh
git commit -m "feat(quota-guard): add sentinel checkpoint verification to Stop hook"
```

---

### Task 4: Clear checkpoint state on new sentinel generation

**Files:**
- Modify: `hooks/context-sentinel-session-start.sh`

- [ ] **Step 1: Add checkpoint cleanup to SessionStart hook**

In `hooks/context-sentinel-session-start.sh`, add after the line `printf '%s' "$hash" > "$sentinel_dir/${session_id}.hash"` (line 21):

```bash
# Clear checkpoint state for this session (fresh sentinel = fresh checkpoints)
rm -f "$sentinel_dir/${session_id}.checkpoints" 2>/dev/null || true
```

- [ ] **Step 2: Verify SessionStart hook still works**

```bash
echo '{"source":"startup","session_id":"test-cleanup"}' | bash hooks/context-sentinel-session-start.sh | jq .
ls ~/.claude/runtime/sentinel/test-cleanup.*
```

Expected: JSON output with additionalContext. Only `.hash` file exists, no `.checkpoints` file.

- [ ] **Step 3: Commit**

```bash
git add hooks/context-sentinel-session-start.sh
git commit -m "feat(context-sentinel): clear checkpoint state on new sentinel generation"
```

---

### Task 5: Run full test suite and smoke test

**Files:**
- No new files

- [ ] **Step 1: Run all quota-guard tests**

```bash
echo "=== Sampler ===" && bash quota-guard/tests/test-sampler.sh
echo "=== Wrapper ===" && bash quota-guard/tests/test-wrapper.sh
echo "=== Stop Guard ===" && bash quota-guard/tests/test-stop-guard.sh
echo "=== Emergency ===" && bash quota-guard/tests/test-emergency.sh
```

Expected: All tests PASS.

- [ ] **Step 2: Smoke test — full pipeline**

```bash
# 1. Simulate statusLine with context at 45%
echo '{
  "session_id": "smoke-sentinel",
  "model": {"display_name":"Opus"},
  "workspace": {"current_dir":"/tmp/project"},
  "rate_limits": {"five_hour": {"used_percentage": 30, "resets_at": 1750000000}},
  "context_window": {"used_percentage": 45}
}' | QUOTA_STATE_DIR=/tmp/quota-smoke bash quota-guard/scripts/quota-sampler.sh

# 2. Verify context_used_pct was written
jq '.context_used_pct' /tmp/quota-smoke/smoke-sentinel.json

# 3. Run Stop hook — should trigger 40% checkpoint
SENTINEL_SMOKE=$(mktemp -d)
echo '{"session_id":"smoke-sentinel"}' | \
  QUOTA_STATE_DIR=/tmp/quota-smoke \
  QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60" \
  SENTINEL_STATE_DIR="$SENTINEL_SMOKE" \
  bash quota-guard/hooks/quota-stop-guard.sh 2>/dev/null | jq .

# 4. Verify checkpoint was recorded
cat "$SENTINEL_SMOKE/smoke-sentinel.checkpoints"

# 5. Cleanup
rm -rf /tmp/quota-smoke "$SENTINEL_SMOKE"
```

Expected: Step 2 shows `45`. Step 3 shows JSON with `additionalContext` mentioning "checkpoint: 40%". Step 4 shows `40`.

- [ ] **Step 3: Commit final state**

```bash
git add -A quota-guard/ hooks/
git commit -m "feat(quota-guard): complete sentinel auto-verify with tests"
```

---

## Spec Coverage Checklist

| Spec Requirement | Task |
|-----------------|------|
| Sampler writes `context_used_pct` | Task 1 |
| Config `sentinel_checkpoints` | Task 2 |
| Stop hook checkpoint logic (multi-round, no block, additionalContext) | Task 3 |
| One checkpoint per response (`break`) | Task 3 (line: `exit 0` after first match) |
| State file tracks triggered checkpoints | Task 3 (`$CHECKPOINT_FILE`) |
| Quota block takes priority over sentinel check | Task 3 (if/else structure) |
| Checkpoint reset after compact/new sentinel | Task 4 |
| Graceful skip when `context_used_pct` is null | Task 3 (Test 10) |
| ENV override for checkpoints | Task 2 config + Task 3 reads `$QUOTA_GUARD_SENTINEL_CHECKPOINTS` |
| Integration verification | Task 5 |
