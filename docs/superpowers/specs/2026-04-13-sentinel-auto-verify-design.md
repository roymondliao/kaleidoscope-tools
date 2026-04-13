# Automated Context Sentinel Verification via quota-guard

**Date**: 2026-04-13
**Status**: Design approved, pending implementation
**Modifies**: `quota-guard/` plugin (sampler, stop hook, config)

## Problem

The context-sentinel-check mechanism currently requires manual invocation (`/context-sentinel-check`). Loss-in-the-middle — where the model loses attention to tokens in the middle of a large context — happens silently. By the time a user notices degraded responses, significant context has already been lost. Automated detection would catch this early and trigger compact before quality degrades.

## Goal

Extend quota-guard to automatically verify the context sentinel at configurable context usage checkpoints. When verification fails (Claude can't recall the sentinel), inject a compact instruction.

## Non-goals

- Replacing the manual `/context-sentinel-check` skill (it stays as-is in kaleidoscope-tools root)
- Modifying the sentinel generation mechanism (SessionStart hook in kaleidoscope-tools root)
- Adding PostCompact verification (can be added later)

## Conceptual model

quota-guard monitors two session health boundaries:

| Boundary | Trigger | Action |
|----------|---------|--------|
| Quota boundary (existing) | `remaining_pct < 8%` | Handoff to another agent |
| Context boundary (new) | `context_used_pct >= checkpoint` | Sentinel verification → compact if FAIL |

Both share the same pipeline: sampler writes data → Stop hook reads and decides → action.

## Architecture

### Data flow

```
statusLine stdin JSON
  → quota-sampler.sh
    → writes context_used_pct to ~/.claude/runtime/quota/{session_id}.json (alongside quota data)

Stop hook
  → reads quota file (quota + context_used_pct)
  → existing: quota check → handoff if low
  → new: sentinel checkpoint check → inject verification reminder if threshold crossed
    → Claude verifies on next response → FAIL → compact
```

### Multi-round checkpoint verification

Sentinel verification triggers at configurable context usage thresholds. Each checkpoint fires once per session, tracked via a state file.

**Config:**
```yaml
# quota-guard/config.yaml
sentinel_checkpoints: [40, 50, 60, 70, 80]
```

ENV override: `QUOTA_GUARD_SENTINEL_CHECKPOINTS="40,50,60,70,80"`

**Checkpoint state file:** `~/.claude/runtime/sentinel/{session_id}.checkpoints`

Contains newline-separated list of already-triggered thresholds.

**Stop hook logic (new section, after quota check):**

```
read context_used_pct from quota file
read checkpoints from config (default: [40, 50, 60, 70, 80])
read triggered checkpoints from state file

for checkpoint in checkpoints (ascending):
  if context_used_pct >= checkpoint AND checkpoint not triggered:
    inject additionalContext (DO NOT block):
      "Context usage at {pct}%. Verify your sentinel now:
       Run: echo 'YOUR_SENTINEL' | bash {path}/verify-sentinel.sh
       If FAIL, run /compact immediately."
    write checkpoint to state file
    break (one checkpoint per response)

no new checkpoint → exit 0
```

**Key design decisions:**

1. **No block** — only `additionalContext`. Claude verifies as part of its next response to the user. No state machine, no verification loop.
2. **One checkpoint per response** — `break` after first trigger. Prevents multiple reminders if context jumps past several thresholds at once.
3. **State file tracks triggers, not results** — the hook doesn't need to know if Claude's verification passed or failed. Claude handles the PASS/FAIL → compact flow itself.

### Lifecycle example

```
Context 35%  → no checkpoint reached → pass through
Context 42%  → 40% checkpoint triggered → inject reminder
               → Claude verifies → PASS → continue
Context 53%  → 50% checkpoint triggered → inject reminder
               → Claude verifies → PASS → continue
Context 62%  → 60% checkpoint triggered → inject reminder
               → Claude verifies → FAIL → Claude runs /compact
               → context compressed to ~20%
               → SessionStart fires → new sentinel + new hash
               → checkpoint state file reset (new session or cleared)
```

### Checkpoint reset after compact

When `/compact` runs, Claude Code may trigger SessionStart (on `clear` or `compact` source). The SessionStart hook generates a new sentinel and hash. The Stop hook should treat a context_used_pct that drops significantly (or a missing checkpoint file for the current sentinel) as a fresh start.

Implementation: the checkpoint state file is keyed by session_id. If SessionStart generates a new sentinel (new hash file), the old checkpoint file for that session_id can be deleted in the SessionStart hook.

## Files modified

| File | Change |
|------|--------|
| `quota-guard/config.yaml` | Add `sentinel_checkpoints: [40, 50, 60, 70, 80]` |
| `quota-guard/scripts/quota-sampler.sh` | Read `context_window.used_percentage` from stdin JSON, write to quota file as `context_used_pct` |
| `quota-guard/hooks/quota-stop-guard.sh` | Add sentinel checkpoint logic after existing quota check |

No new files needed. All changes extend existing components.

## Interaction with existing quota check

The Stop hook runs both checks sequentially:

1. **Quota check** (existing) — may return `decision: "block"` for handoff
2. **Sentinel check** (new) — may return `additionalContext` for verification

If quota check blocks, the sentinel check is skipped (handoff takes priority). Sentinel's `additionalContext` is only appended when the hook does NOT block.

```
if quota_remaining < threshold AND no handoff marker:
  → block (handoff) — sentinel check skipped
else:
  → sentinel checkpoint check → maybe append additionalContext
  → exit 0
```

## Configuration

```yaml
# quota-guard/config.yaml (updated)
threshold: 8
quota_state_dir: "~/.claude/runtime/quota"
handoff_output_dir: "docs/handoff"
sentinel_checkpoints: [40, 50, 60, 70, 80]
```

Environment variable overrides:
- `QUOTA_GUARD_SENTINEL_CHECKPOINTS` — comma-separated list of percentages (default: "40,50,60,70,80")

## Assumptions

- `context_window.used_percentage` is present in statusLine JSON (confirmed in official docs)
- Stop hook `additionalContext` (without block) is injected into Claude's context for the next turn
- Claude will follow the verification instruction when injected via additionalContext
- SessionStart hook fires on compact/clear events to regenerate sentinel
- Sentinel hash files exist at `~/.claude/runtime/sentinel/{session_id}.hash` (created by kaleidoscope-tools root SessionStart hook)
- `verify-sentinel.sh` is accessible at a known path within the kaleidoscope-tools plugin

## Risks

| Risk | Mitigation |
|------|-----------|
| Claude ignores additionalContext verification instruction | Phrasing as imperative; manual `/context-sentinel-check` remains as fallback |
| Checkpoint state file not cleaned up after compact | SessionStart hook deletes old checkpoint files; `find -mtime` cleanup |
| context_used_pct not available (API key mode without statusLine) | Sentinel check gracefully skips if field is null |
| verify-sentinel.sh path varies across installations | Use `${CLAUDE_PLUGIN_ROOT}` in additionalContext path |
