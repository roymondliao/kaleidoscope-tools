# quota-guard: Quota Monitoring & Cross-Tool Handoff Plugin

**Date**: 2026-04-09
**Status**: Design approved, pending implementation
**Plugin location**: `kaleidoscope-tools/quota-guard/`

## Problem

Claude Code Pro subscription has 5-hour and 7-day rate limit windows. When quota runs low mid-task, users lose context — there's no mechanism to gracefully pause, capture task state, and hand off to another coding agent (Codex, Gemini CLI). The user wants to seamlessly continue development across AI tools when one hits its limit.

## Goal

A kaleidoscope-tools plugin that:
1. Monitors quota usage via statusLine sampling
2. Auto-pauses Claude Code when remaining quota drops below a configurable threshold
3. Produces a structured handoff document that any coding agent can consume to continue the work

## Non-goals

- Resuming within Claude Code (transcript already persists in `~/.claude/`)
- Storing git state (next agent can check itself)
- Deep integration with specific workflows (Claude fills the handoff semantically)
- Replacing the user's existing statusLine display

## Architecture

### Data flow

```
Anthropic API response headers
  → Claude Code runtime (in-memory session telemetry)
    → statusLine stdin JSON (only external outlet for rate_limits)
      → quota-sampler.sh → writes ~/.claude/runtime/quota/{session_id}.json
        → Stop hook reads quota file → if low, blocks → Claude executes /quota-guard:handoff
          → handoff YAML written to docs/handoff/ (also serves as guard marker)
```

### Key constraint

`rate_limits` data exists only in Claude Code's process memory. It is not persisted to disk, not in transcript files, not in OTel metrics. The statusLine stdin JSON is the **only** external channel to access it. This is by official design, not a limitation we're working around.

### Components

| Component | Trigger | Responsibility | Output |
|-----------|---------|---------------|--------|
| `quota-sampler.sh` | Every assistant response (via statusLine) | Extract `rate_limits` from stdin JSON, write to file | `~/.claude/runtime/quota/{session_id}.json` |
| `quota-wrapper.sh` | Every assistant response (via statusLine) | Chain sampler + user's original statusLine | Status line display text |
| `quota-stop-guard.sh` | Every Stop event | Read quota file, check threshold + marker, block if needed | `{"decision": "block"}` or pass |
| `/quota-guard:handoff` skill | Executed by Claude after block, or manually | Generate structured handoff YAML from conversation context | `docs/handoff/{timestamp}-handoff.yaml` |
| `emergency-snapshot.sh` | StopFailure with `rate_limit` matcher | Last-resort minimal handoff when quota already exhausted | `docs/handoff/{timestamp}-emergency.yaml` |

## Plugin structure

```
quota-guard/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json
    quota-stop-guard.sh
    emergency-snapshot.sh
  skills/
    handoff/
      handoff.md            # /quota-guard:handoff skill definition
      template.yaml         # handoff YAML template
  scripts/
    quota-sampler.sh        # pure sampling, no stdout
    quota-wrapper.sh        # sampler + user statusLine chain
  config.yaml               # default settings (threshold, etc.)
```

## Detailed design

### 1. statusLine integration (quota-sampler.sh)

**Input**: Claude Code session JSON via stdin (contains `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`, `resets_at`).

**Output**: Writes `~/.claude/runtime/quota/{session_id}.json` with fields:
- `session_id`, `cwd`, `transcript_path`, `updated_at`
- `five_hour_used_pct`, `five_hour_remaining_pct`, `five_hour_resets_at`
- `seven_day_used_pct`, `seven_day_remaining_pct`, `seven_day_resets_at`

**No stdout** — sampler is silent; display is handled by wrapper or user's own script.

### 2. statusLine wrapper (quota-wrapper.sh)

Composable wrapper that:
1. Pipes stdin to `quota-sampler.sh` (silent, writes file)
2. Pipes stdin to user's original statusLine script (if `QUOTA_GUARD_USER_STATUSLINE` is set)
3. Falls back to a default display (model + quota remaining) if no user script

Three user scenarios:

| Scenario | Setup |
|----------|-------|
| No existing statusLine | Use wrapper directly — shows default model + quota display |
| Has own statusLine | Set `QUOTA_GUARD_USER_STATUSLINE` env var pointing to original script |
| Fully custom | Call `quota-sampler.sh` directly within their own script |

### 3. Stop hook (quota-stop-guard.sh)

Runs on every Stop event. Decision logic:

```
quota file not found?
  → stderr warning "quota-guard: no quota data, statusLine integration may be missing"
  → pass through (exit 0)

read quota file
  → compute min_remaining = min of all non-null remaining percentages

min_remaining >= threshold?
  → pass through

min_remaining < threshold + current-window handoff exists?
  → pass through (handoff already completed in this quota window)

min_remaining < threshold + no current-window handoff?
  → return {"decision": "block", "reason": "...execute /quota-guard:handoff..."}
```

**Guard mechanism (timestamp-based)**:

The handoff filename contains a timestamp (e.g., `2026-04-09-143000-handoff.yaml`). The quota file contains `five_hour_resets_at` (future reset time). The current 5-hour window started at approximately `resets_at - 5h`.

Guard logic:
1. Find handoff files matching current `session_id` in `docs/handoff/`
2. Extract the timestamp from the most recent matching filename
3. Compare against the current quota window start time (`resets_at - 5h`)
4. If handoff timestamp >= window start → handoff is current → pass through
5. If handoff timestamp < window start → handoff is from a previous window → trigger new handoff

This eliminates the need for ephemeral marker files. The handoff YAML's own timestamp is sufficient to determine whether it belongs to the current quota window.

**Threshold**: Default `8` (percent remaining). Configurable via `QUOTA_GUARD_THRESHOLD` environment variable.

### 4. Handoff skill (/quota-guard:handoff)

A skill that Claude executes to generate the handoff document. Two invocation modes:
- **Automatic**: Stop hook blocks → Claude is guided to execute this skill
- **Manual**: User calls `/quota-guard:handoff` to proactively hand off

The skill instructs Claude to:
1. Read the YAML template
2. Read quota data from `~/.claude/runtime/quota/{session_id}.json`
3. Fill every field based on its conversation context (Claude is the best source of semantic task state)
4. Write to `docs/handoff/{YYYY-MM-DD}-{HHmmss}-handoff.yaml`
5. Inform the user that handoff is complete and session should be closed

### 5. Handoff YAML template

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

**Design principles**:
- All paths are **relative** to project root — portable across machines
- `workflow` section is agent-agnostic — Claude fills it naturally, no hardcoded workflow structures
- `tasks` uses completed/in_progress/remaining — universal across any task granularity
- `files` are pointers (paths), not content — next agent reads them directly
- `quota` section tells the next agent when Claude Code becomes available again

### 6. Emergency fallback (emergency-snapshot.sh)

Triggered by StopFailure hook with `rate_limit` matcher. StopFailure has **zero decision control** — it cannot block or modify behavior. Purely observability.

Writes a minimal emergency handoff:
- `session_id`, `cwd`, `branch`, `trigger: "emergency"`
- `transcript_path` (so next agent can read the conversation)
- Note: "Rate limit hit before handoff could complete. Read transcript for context."

This is the last resort. If threshold is set conservatively (8%), this should rarely trigger.

## Guard mechanism (timestamp-based anti-loop)

Uses the handoff file's timestamp to determine if it belongs to the current quota window. No ephemeral marker files needed.

**Anti-loop (same response cycle):**
1. Claude generates handoff response → writes `docs/handoff/2026-04-09-173000-handoff.yaml`
2. Stop hook fires again → quota still low
3. Finds handoff with timestamp 17:30, current window started at ~15:00 → 17:30 >= 15:00 → **pass through**
4. Claude's handoff response reaches the user

**Cross-window (quota refreshed, same session):**
1. Old handoff exists from 14:30, quota refreshed at 15:00
2. User continues working, quota drops again at 17:30
3. Stop hook: current window started at ~15:00, handoff timestamp 14:30 < 15:00 → **stale, trigger new handoff**
4. New handoff correctly captures updated task state

## Configuration

```yaml
# config.yaml — plugin defaults
threshold: 8                         # percent remaining to trigger handoff
quota_state_dir: "~/.claude/runtime/quota"
handoff_output_dir: "docs/handoff"
```

User overrides via environment variables:
- `QUOTA_GUARD_THRESHOLD` — override default threshold (0-100)
- `QUOTA_GUARD_USER_STATUSLINE` — path to user's original statusLine script

## Assumptions

- `rate_limits` field is present in statusLine JSON for Pro/Max subscribers after first API response. If absent (e.g., API key mode), plugin silently passes through — no monitoring, no errors.
- `jq` is available on the user's system (required for shell scripts parsing JSON).
- Stop hook can return `{"decision": "block"}` to prevent Claude from continuing and inject additional context.
- `docs/handoff/` directory is either gitignored or committed per user preference.
- 8% remaining quota is sufficient for Claude to complete one handoff response.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| 8% not enough for handoff response | Handoff incomplete, hits rate limit | Emergency fallback via StopFailure hook; user can raise threshold |
| statusLine not configured | No quota monitoring, silent pass-through | Stop hook warns on stderr when quota file missing |
| jq not installed | Scripts fail | Check for jq at plugin load, warn user |
| Handoff YAML never cleaned up | docs/handoff/ accumulates old files | User responsibility; could add a cleanup skill later |
| Stop hook grep for marker is slow with many handoff files | Hook timeout | grep is fast for text files; unlikely to be an issue in practice |

## Future considerations

- **Read-side integration**: Skills for Codex/Gemini CLI to auto-discover and consume handoff YAMLs at session start
- **Cleanup skill**: `/quota-guard:cleanup` to prune old handoff files
- **Multi-agent awareness**: If running with `--worktree` or background agents, each agent's quota is shared — may need coordination
