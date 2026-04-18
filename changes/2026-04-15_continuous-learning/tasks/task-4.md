# Task 4: Hook Registration and Integration

## Context
Read: overview.md

This task wires the `check-learnings` hook (task-2) into samsara's hook system and updates project documentation to reflect the new capability.

Depends on task-2 (hook script must exist before registration).

## Files
- Modify: `samsara/hooks/hooks.json` — add check-learnings to SessionStart hooks
- Modify: `samsara/MEMORY.md` — add continuous-learning to project state
- Modify: `samsara/skills/samsara-bootstrap/SKILL.md` — add recall to available skills list

## Death Test Requirements
- Test: After registration, `hooks.json` must remain valid JSON — malformed JSON disables ALL samsara hooks
- Test: New hook entry must not break existing hooks (session-start, check-codebase-map) — verify all three fire on session start
- Test: Bootstrap skill list must include `samsara:recall` with correct trigger description — missing entry means skill is never discovered

## Implementation Details

### hooks.json modification

Add `check-learnings` as the third SessionStart hook:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "timeout": 5000
          },
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-codebase-map\"",
            "timeout": 3000
          },
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/check-learnings\"",
            "timeout": 3000
          }
        ]
      }
    ]
  }
}
```

### samsara-bootstrap SKILL.md modification

Add to Utility Skills section:

```
- **samsara:recall** — 查詢 project-level failure learnings（.learnings/ 目錄）
```

### MEMORY.md modification

Add Phase section documenting continuous-learning implementation status.

## Implementation Steps
- [ ] Step 1: Write death tests (validate JSON syntax, verify all hooks listed)
- [ ] Step 2: Run death tests — verify they fail
- [ ] Step 3: Modify hooks.json
- [ ] Step 4: Modify samsara-bootstrap SKILL.md
- [ ] Step 5: Update samsara/MEMORY.md
- [ ] Step 6: Run all tests — verify they pass (all hooks fire, JSON valid)
- [ ] Step 7: Write scar report
- [ ] Step 8: Report (do not commit)

## Expected Scar Report Items
- Potential shortcut: Adding hook without testing that all three hooks fire together — interaction effects between hooks are possible
- Assumption to verify: 3000ms timeout is sufficient for check-learnings (same as check-codebase-map)
- Assumption to verify: Hook order matters — check-learnings should run after session-start bootstrap but order within the array may not be guaranteed

## Acceptance Criteria
- Covers: "Success - learnings loaded at session start" (end-to-end verification)
