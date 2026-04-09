# quota-guard Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a kaleidoscope-tools plugin that monitors Claude Code Pro quota via statusLine sampling, auto-pauses when quota is low, and generates a structured YAML handoff document for cross-tool continuity.

**Architecture:** statusLine script samples `rate_limits` from stdin JSON and writes to a runtime file. A Stop hook reads this file on every response, and when remaining quota drops below threshold, blocks Claude and guides it to execute a `/quota-guard:handoff` skill that produces a YAML briefing document in `docs/handoff/`. A StopFailure hook provides emergency fallback if rate limit is hit directly.

**Tech Stack:** Bash (hooks/scripts), jq (JSON parsing), YAML (handoff template + config), Markdown (skill definition)

**Spec:** `docs/superpowers/specs/2026-04-09-quota-guard-design.md`

---

## File Structure

```
quota-guard/
  .claude-plugin/
    plugin.json               # Plugin metadata — name, version, author
  hooks/
    hooks.json                # Registers Stop + StopFailure hooks
    quota-stop-guard.sh       # Stop hook — reads quota, checks threshold + guard, blocks if needed
    emergency-snapshot.sh     # StopFailure (rate_limit) — last-resort minimal handoff
  skills/
    handoff/
      SKILL.md                # /quota-guard:handoff skill definition
      template.yaml           # Handoff YAML template with all fields
  scripts/
    quota-sampler.sh          # Pure sampling — reads stdin JSON, writes quota file, no stdout
    quota-wrapper.sh          # Composable wrapper — chains sampler + user's original statusLine
  config.yaml                 # Default settings (threshold: 8, paths)
```

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `quota-guard/.claude-plugin/plugin.json`
- Create: `quota-guard/config.yaml`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "quota-guard",
  "description": "Quota monitoring & cross-tool handoff — monitors Claude Code Pro rate limits via statusLine, auto-pauses on low quota, and generates structured YAML handoff documents for seamless continuation in Codex or Gemini CLI.",
  "version": "0.1.0",
  "author": {
    "name": "Roymond Liao"
  }
}
```

Save to `quota-guard/.claude-plugin/plugin.json`.

- [ ] **Step 2: Create config.yaml**

```yaml
# quota-guard default configuration
# Override via environment variables:
#   QUOTA_GUARD_THRESHOLD — remaining % to trigger handoff (default: 8)
#   QUOTA_GUARD_USER_STATUSLINE — path to user's original statusLine script

threshold: 8
quota_state_dir: "~/.claude/runtime/quota"
handoff_output_dir: "docs/handoff"
```

Save to `quota-guard/config.yaml`.

- [ ] **Step 3: Create directory structure**

```bash
mkdir -p quota-guard/hooks quota-guard/skills/handoff quota-guard/scripts
```

- [ ] **Step 4: Commit**

```bash
git add quota-guard/.claude-plugin/plugin.json quota-guard/config.yaml
git commit -m "feat(quota-guard): scaffold plugin structure with config"
```

---

### Task 2: quota-sampler.sh — Core Sampling

**Files:**
- Create: `quota-guard/scripts/quota-sampler.sh`
- Create: `quota-guard/tests/test-sampler.sh`

- [ ] **Step 1: Write the test script**

This test pipes mock statusLine JSON to the sampler and verifies the output file.

```bash
#!/usr/bin/env bash
# test-sampler.sh — verifies quota-sampler.sh reads stdin JSON and writes correct quota file
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLER="${SCRIPT_DIR}/../scripts/quota-sampler.sh"
TEST_STATE_DIR=$(mktemp -d)
trap "rm -rf $TEST_STATE_DIR" EXIT

# Mock statusLine JSON input
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

# Run sampler with overridden state dir
QUOTA_STATE_DIR="$TEST_STATE_DIR" echo "$MOCK_INPUT" | bash "$SAMPLER"

# Verify output file exists
OUTPUT_FILE="$TEST_STATE_DIR/test-session-001.json"
if [ ! -f "$OUTPUT_FILE" ]; then
  echo "FAIL: quota file not created at $OUTPUT_FILE"
  exit 1
fi

# Verify fields
FIVE_REMAINING=$(jq -r '.five_hour_remaining_pct' "$OUTPUT_FILE")
SEVEN_REMAINING=$(jq -r '.seven_day_remaining_pct' "$OUTPUT_FILE")
SESSION_ID=$(jq -r '.session_id' "$OUTPUT_FILE")

PASS=true
[ "$SESSION_ID" != "test-session-001" ] && echo "FAIL: session_id=$SESSION_ID" && PASS=false
# 100 - 72.5 = 27.5
[ "$FIVE_REMAINING" != "27.5" ] && echo "FAIL: five_hour_remaining_pct=$FIVE_REMAINING (expected 27.5)" && PASS=false
# 100 - 41.2 = 58.8
[ "$SEVEN_REMAINING" != "58.8" ] && echo "FAIL: seven_day_remaining_pct=$SEVEN_REMAINING (expected 58.8)" && PASS=false

if $PASS; then
  echo "PASS: quota-sampler basic test"
else
  echo "Output file contents:"
  cat "$OUTPUT_FILE"
  exit 1
fi

# Test with missing rate_limits (API key mode)
MOCK_NO_RATE='{
  "session_id": "test-session-002",
  "workspace": { "current_dir": "/home/user/project" }
}'
QUOTA_STATE_DIR="$TEST_STATE_DIR" echo "$MOCK_NO_RATE" | bash "$SAMPLER"

NO_RATE_FILE="$TEST_STATE_DIR/test-session-002.json"
if [ ! -f "$NO_RATE_FILE" ]; then
  echo "FAIL: quota file not created for missing rate_limits"
  exit 1
fi

FIVE_NULL=$(jq -r '.five_hour_remaining_pct' "$NO_RATE_FILE")
[ "$FIVE_NULL" != "null" ] && echo "FAIL: expected null for missing rate_limits, got $FIVE_NULL" && exit 1

echo "PASS: quota-sampler missing rate_limits test"
```

Save to `quota-guard/tests/test-sampler.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x quota-guard/tests/test-sampler.sh
bash quota-guard/tests/test-sampler.sh
```

Expected: FAIL — `quota-sampler.sh` does not exist yet.

- [ ] **Step 3: Implement quota-sampler.sh**

```bash
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
    seven_day_resets_at: $seven_reset
  }' > "$STATE_DIR/$SESSION_ID.json"
```

Save to `quota-guard/scripts/quota-sampler.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash quota-guard/tests/test-sampler.sh
```

Expected: `PASS: quota-sampler basic test` and `PASS: quota-sampler missing rate_limits test`

- [ ] **Step 5: Commit**

```bash
git add quota-guard/scripts/quota-sampler.sh quota-guard/tests/test-sampler.sh
git commit -m "feat(quota-guard): add quota-sampler.sh with tests"
```

---

### Task 3: quota-wrapper.sh — Composable statusLine Wrapper

**Files:**
- Create: `quota-guard/scripts/quota-wrapper.sh`
- Create: `quota-guard/tests/test-wrapper.sh`

- [ ] **Step 1: Write the test script**

```bash
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

# Test 1: Default display (no user statusLine)
OUTPUT=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_USER_STATUSLINE="" echo "$MOCK_INPUT" | bash "$WRAPPER" 2>/dev/null)

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

# Test 2: Verify sampler wrote quota file
QUOTA_FILE="$TEST_STATE_DIR/test-wrapper-001.json"
if [ -f "$QUOTA_FILE" ]; then
  echo "PASS: wrapper triggered sampler (quota file exists)"
else
  echo "FAIL: sampler not triggered (no quota file)"
  exit 1
fi

# Test 3: With user statusLine
USER_SL=$(mktemp)
echo '#!/bin/bash' > "$USER_SL"
echo 'echo "CUSTOM_STATUS"' >> "$USER_SL"
chmod +x "$USER_SL"

OUTPUT2=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_USER_STATUSLINE="$USER_SL" echo "$MOCK_INPUT" | bash "$WRAPPER" 2>/dev/null)
rm "$USER_SL"

if echo "$OUTPUT2" | grep -q "CUSTOM_STATUS"; then
  echo "PASS: wrapper chains user statusLine"
else
  echo "FAIL: user statusLine not chained: $OUTPUT2"
  exit 1
fi
```

Save to `quota-guard/tests/test-wrapper.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x quota-guard/tests/test-wrapper.sh
bash quota-guard/tests/test-wrapper.sh
```

Expected: FAIL — `quota-wrapper.sh` does not exist yet.

- [ ] **Step 3: Implement quota-wrapper.sh**

```bash
#!/usr/bin/env bash
# quota-wrapper.sh — Composable statusLine wrapper.
# 1. Runs quota-sampler.sh (silent, writes quota file)
# 2. Runs user's original statusLine (if QUOTA_GUARD_USER_STATUSLINE is set)
# 3. Falls back to default display (model + quota remaining)
# Requires: jq

set -euo pipefail

INPUT=$(cat)

# Determine plugin root from script location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Run sampler silently (no stdout)
echo "$INPUT" | bash "$SCRIPT_DIR/quota-sampler.sh" 2>/dev/null || true

# 2. Chain user's original statusLine, or show default
USER_STATUSLINE="${QUOTA_GUARD_USER_STATUSLINE:-}"

if [ -n "$USER_STATUSLINE" ] && [ -x "$USER_STATUSLINE" ]; then
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
```

Save to `quota-guard/scripts/quota-wrapper.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash quota-guard/tests/test-wrapper.sh
```

Expected: All three PASS lines.

- [ ] **Step 5: Commit**

```bash
git add quota-guard/scripts/quota-wrapper.sh quota-guard/tests/test-wrapper.sh
git commit -m "feat(quota-guard): add quota-wrapper.sh with composable statusLine chaining"
```

---

### Task 4: Handoff YAML Template

**Files:**
- Create: `quota-guard/skills/handoff/template.yaml`

- [ ] **Step 1: Create template.yaml**

```yaml
handoff:
  version: "1.0"
  created_at: ""                # ISO 8601
  source_agent: ""              # "claude-code" | "codex" | "gemini-cli"
  session_id: ""
  trigger: ""                   # "quota_low" | "manual" | "emergency"

quota:
  five_hour_remaining_pct: null
  seven_day_remaining_pct: null
  earliest_reset_at: null       # ISO 8601 of nearest reset

project:
  cwd: ""
  branch: ""
  description: ""               # one-line project summary

workflow:
  name: ""                      # e.g., "samsara:implement", "superpowers:brainstorming"
  phase: ""                     # current phase/step in the workflow
  plan_file: ""                 # relative path to plan doc
  spec_file: ""                 # relative path to spec doc

tasks:
  summary: ""                   # high-level what we're doing
  completed:
    - ""
  in_progress:
    - ""
  remaining:
    - ""

context:
  key_decisions: []             # important decisions made this session
  blockers: []                  # known issues or blockers
  assumptions: []               # things next agent should validate

files:
  code_map: ""                  # relative path to codebase map
  recently_modified: []         # files touched this session
  relevant_docs: []             # paths to relevant documentation

notes: ""                       # free-form context Claude deems important
```

Save to `quota-guard/skills/handoff/template.yaml`.

- [ ] **Step 2: Validate YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('quota-guard/skills/handoff/template.yaml'))" && echo "PASS: valid YAML"
```

Expected: `PASS: valid YAML`

- [ ] **Step 3: Commit**

```bash
git add quota-guard/skills/handoff/template.yaml
git commit -m "feat(quota-guard): add handoff YAML template"
```

---

### Task 5: Handoff Skill Definition

**Files:**
- Create: `quota-guard/skills/handoff/SKILL.md`

- [ ] **Step 1: Write the skill definition**

```markdown
---
name: handoff
description: "Use when quota is low and Claude needs to hand off work to another coding agent (Codex, Gemini CLI), or when the user manually requests a handoff. Generates a structured YAML document capturing task state, workflow progress, and pointers to relevant files."
---

# Quota Guard — Handoff

Generate a structured YAML handoff document so another coding agent can continue this work.

## When This Runs

- **Automatic**: Stop hook detected low quota and blocked. You MUST execute this skill immediately.
- **Manual**: User invoked `/quota-guard:handoff` to proactively hand off before quota runs out.

## Process

1. **Read the template** at `${CLAUDE_PLUGIN_ROOT}/skills/handoff/template.yaml`
2. **Read quota data** from `~/.claude/runtime/quota/{session_id}.json` (if it exists)
3. **Fill every field** based on your conversation context:
   - `handoff.trigger`: `"quota_low"` if auto-triggered, `"manual"` if user-invoked
   - `handoff.source_agent`: `"claude-code"`
   - `quota.*`: from the quota state file
   - `project.*`: current working directory, git branch
   - `workflow.*`: which skill/workflow you're using, what phase you're in
   - `tasks.*`: what's done, what's in progress, what remains — use YOUR understanding of the work, not just the task list
   - `context.*`: key decisions, blockers, assumptions the next agent should know
   - `files.*`: paths to code map, recently modified files, relevant docs
   - `notes`: anything else the next agent needs to know
4. **Write the handoff** to `docs/handoff/{YYYY-MM-DD}-{HHmmss}-handoff.yaml`
   - Create the `docs/handoff/` directory if it doesn't exist
   - The filename timestamp is critical — it serves as the guard marker
5. **Include session_id in the YAML** — the Stop hook uses this to detect the guard marker
6. **Tell the user** handoff is complete:
   - Show the handoff file path
   - Show when quota resets (from `quota.earliest_reset_at`)
   - Suggest closing the session and opening Codex/Gemini CLI in the same project directory
   - Mention: "The next agent should read `docs/handoff/` to pick up where we left off."

## Critical Rules

- **All file paths in the YAML must be relative** to the project root — not absolute paths
- **Do NOT include git state** (status, diff) — the next agent checks that itself
- **Do NOT copy file contents** — only include paths as pointers
- **Be specific in tasks** — "implement the Stop hook guard logic" is better than "continue working"
- **Fill EVERY field** — leave nothing as empty string unless truly not applicable (use `null` for N/A)
```

Save to `quota-guard/skills/handoff/SKILL.md`.

- [ ] **Step 2: Verify skill frontmatter is valid YAML**

```bash
head -4 quota-guard/skills/handoff/SKILL.md | tail -3 | python3 -c "import sys,yaml; yaml.safe_load(sys.stdin)" && echo "PASS: valid frontmatter"
```

Expected: `PASS: valid frontmatter`

- [ ] **Step 3: Commit**

```bash
git add quota-guard/skills/handoff/SKILL.md
git commit -m "feat(quota-guard): add /quota-guard:handoff skill definition"
```

---

### Task 6: Stop Hook — quota-stop-guard.sh

**Files:**
- Create: `quota-guard/hooks/quota-stop-guard.sh`
- Create: `quota-guard/tests/test-stop-guard.sh`

- [ ] **Step 1: Write the test script**

```bash
#!/usr/bin/env bash
# test-stop-guard.sh — verifies Stop hook decision logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GUARD="${SCRIPT_DIR}/../hooks/quota-stop-guard.sh"
TEST_STATE_DIR=$(mktemp -d)
TEST_PROJECT_DIR=$(mktemp -d)
trap "rm -rf $TEST_STATE_DIR $TEST_PROJECT_DIR" EXIT

MOCK_HOOK_INPUT='{"session_id":"test-guard-001","transcript_path":"/tmp/t.jsonl","cwd":"/tmp/project"}'

# --- Test 1: No quota file → pass through (exit 0, no JSON output) ---
OUTPUT=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  echo "$MOCK_HOOK_INPUT" | bash "$GUARD" 2>/dev/null) || true

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

OUTPUT2=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_THRESHOLD=8 QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  echo "$MOCK_HOOK_INPUT" | bash "$GUARD" 2>/dev/null) || true

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

OUTPUT3=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_THRESHOLD=8 QUOTA_GUARD_HANDOFF_DIR="$TEST_PROJECT_DIR/docs/handoff" \
  echo "$MOCK_HOOK_INPUT" | bash "$GUARD" 2>/dev/null)

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

# Create a handoff file with a recent timestamp (in the current 5h window)
# resets_at=1738425600 → window start = resets_at - 18000 = 1738407600
# Make handoff timestamp AFTER window start
HANDOFF_TS=$(date -r 1738420000 +%Y-%m-%d-%H%M%S 2>/dev/null || date -d @1738420000 +%Y-%m-%d-%H%M%S 2>/dev/null || echo "2025-02-01-140000")
cat > "$HANDOFF_DIR/${HANDOFF_TS}-handoff.yaml" << 'HANDOFF'
handoff:
  session_id: "test-guard-001"
  trigger: "quota_low"
HANDOFF

OUTPUT4=$(QUOTA_STATE_DIR="$TEST_STATE_DIR" QUOTA_GUARD_THRESHOLD=8 QUOTA_GUARD_HANDOFF_DIR="$HANDOFF_DIR" \
  echo "$MOCK_HOOK_INPUT" | bash "$GUARD" 2>/dev/null) || true

if [ -z "$OUTPUT4" ] || ! echo "$OUTPUT4" | jq -e '.decision' >/dev/null 2>&1; then
  echo "PASS: current-window handoff exists → pass through"
else
  echo "FAIL: expected pass through with existing handoff, got: $OUTPUT4"
  exit 1
fi
```

Save to `quota-guard/tests/test-stop-guard.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x quota-guard/tests/test-stop-guard.sh
bash quota-guard/tests/test-stop-guard.sh
```

Expected: FAIL — `quota-stop-guard.sh` does not exist yet.

- [ ] **Step 3: Implement quota-stop-guard.sh**

```bash
#!/usr/bin/env bash
# quota-stop-guard.sh — Stop hook for quota-guard plugin.
# Reads quota state file, checks threshold, applies timestamp-based guard.
# Returns {"decision": "block"} when quota is low and no current-window handoff exists.
# Requires: jq

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
```

Save to `quota-guard/hooks/quota-stop-guard.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash quota-guard/tests/test-stop-guard.sh
```

Expected: All four PASS lines.

- [ ] **Step 5: Commit**

```bash
git add quota-guard/hooks/quota-stop-guard.sh quota-guard/tests/test-stop-guard.sh
git commit -m "feat(quota-guard): add Stop hook with timestamp-based guard"
```

---

### Task 7: Emergency Fallback — emergency-snapshot.sh

**Files:**
- Create: `quota-guard/hooks/emergency-snapshot.sh`
- Create: `quota-guard/tests/test-emergency.sh`

- [ ] **Step 1: Write the test script**

```bash
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

QUOTA_GUARD_HANDOFF_DIR="$TEST_OUTPUT_DIR" echo "$MOCK_INPUT" | bash "$EMERGENCY"

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
```

Save to `quota-guard/tests/test-emergency.sh` and `chmod +x`.

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x quota-guard/tests/test-emergency.sh
bash quota-guard/tests/test-emergency.sh
```

Expected: FAIL — `emergency-snapshot.sh` does not exist yet.

- [ ] **Step 3: Implement emergency-snapshot.sh**

```bash
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
```

Save to `quota-guard/hooks/emergency-snapshot.sh` and `chmod +x`.

- [ ] **Step 4: Run test to verify it passes**

```bash
bash quota-guard/tests/test-emergency.sh
```

Expected: Both PASS lines.

- [ ] **Step 5: Commit**

```bash
git add quota-guard/hooks/emergency-snapshot.sh quota-guard/tests/test-emergency.sh
git commit -m "feat(quota-guard): add StopFailure emergency snapshot"
```

---

### Task 8: hooks.json — Hook Registration

**Files:**
- Create: `quota-guard/hooks/hooks.json`

- [ ] **Step 1: Create hooks.json**

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/quota-stop-guard.sh\"",
            "timeout": 10000
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "matcher": "rate_limit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/emergency-snapshot.sh\"",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

Save to `quota-guard/hooks/hooks.json`.

- [ ] **Step 2: Validate JSON syntax**

```bash
jq . quota-guard/hooks/hooks.json > /dev/null && echo "PASS: valid JSON"
```

Expected: `PASS: valid JSON`

- [ ] **Step 3: Commit**

```bash
git add quota-guard/hooks/hooks.json
git commit -m "feat(quota-guard): register Stop and StopFailure hooks"
```

---

### Task 9: Enable Plugin & Integration Verification

**Files:**
- Modify: `.claude/settings.json` (project-level, if needed)

- [ ] **Step 1: Verify plugin can be discovered**

Check that the plugin structure is complete and can be found by Claude Code:

```bash
echo "--- Plugin structure ---"
find quota-guard -type f | sort

echo "--- plugin.json ---"
cat quota-guard/.claude-plugin/plugin.json | jq .

echo "--- hooks.json ---"
cat quota-guard/hooks/hooks.json | jq .

echo "--- All scripts executable ---"
for f in quota-guard/scripts/*.sh quota-guard/hooks/*.sh; do
  [ -x "$f" ] && echo "OK: $f" || echo "MISSING +x: $f"
done
```

- [ ] **Step 2: Run all tests**

```bash
echo "=== Sampler ===" && bash quota-guard/tests/test-sampler.sh
echo "=== Wrapper ===" && bash quota-guard/tests/test-wrapper.sh
echo "=== Stop Guard ===" && bash quota-guard/tests/test-stop-guard.sh
echo "=== Emergency ===" && bash quota-guard/tests/test-emergency.sh
```

Expected: All tests PASS.

- [ ] **Step 3: Manual smoke test — quota-sampler with real statusLine data**

Pipe a realistic statusLine JSON payload to the sampler and verify the output:

```bash
echo '{
  "session_id": "smoke-test",
  "model": {"id":"claude-opus-4-6","display_name":"Opus"},
  "workspace": {"current_dir":"/Users/yuyu_liao/personal/kaleidoscope-tools"},
  "rate_limits": {
    "five_hour": {"used_percentage": 92, "resets_at": 1750000000},
    "seven_day": {"used_percentage": 45, "resets_at": 1750500000}
  }
}' | QUOTA_STATE_DIR=/tmp/quota-test bash quota-guard/scripts/quota-sampler.sh

cat /tmp/quota-test/smoke-test.json | jq .
rm -rf /tmp/quota-test
```

Verify output shows `five_hour_remaining_pct: 8` and `seven_day_remaining_pct: 55`.

- [ ] **Step 4: Commit final state**

```bash
git add -A quota-guard/
git commit -m "feat(quota-guard): complete plugin with all components and tests"
```

---

## Spec Coverage Checklist

| Spec Section | Task |
|-------------|------|
| Plugin structure | Task 1 |
| statusLine integration (quota-sampler.sh) | Task 2 |
| statusLine wrapper (quota-wrapper.sh) | Task 3 |
| Handoff YAML template | Task 4 |
| Handoff skill (/quota-guard:handoff) | Task 5 |
| Stop hook (quota-stop-guard.sh) | Task 6 |
| Emergency fallback (emergency-snapshot.sh) | Task 7 |
| hooks.json registration | Task 8 |
| Guard mechanism (timestamp-based) | Task 6 (integrated into stop guard) |
| Configuration (config.yaml + env vars) | Task 1 (config.yaml) + Task 6 (env var reads) |
| Integration verification | Task 9 |
