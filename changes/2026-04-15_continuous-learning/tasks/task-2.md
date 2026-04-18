# Task 2: SessionStart Hook (check-learnings)

## Context
Read: overview.md

The SessionStart hook runs at every session start and injects a compact summary of project learnings into the agent's context. It follows the exact same pattern as the existing `samsara/hooks/check-codebase-map` hook: check if the relevant file exists, read it, format a message, and output JSON with `hookSpecificOutput.additionalContext`.

Depends on task-1 (index rebuild script) because the hook reads the index.yaml format that the rebuild script produces.

## Files
- Create: `samsara/hooks/check-learnings`
- Reference: `samsara/hooks/check-codebase-map` (pattern to follow)

## Death Test Requirements
- Test: Hook runs when `.learnings/` directory does not exist → must exit 0 with no output (zero token cost)
- Test: Hook runs when `.learnings/index.yaml` exists but is malformed YAML → must inject error message "Learnings index is malformed", NOT exit silently
- Test: Hook runs when `.learnings/index.yaml` exists but `entries` is empty → must exit 0 with no output (no empty list injection)
- Test: Hook runs when `.learnings/index.yaml` has entries pointing to deleted .md files → must include warning in injection, not silently show stale entries

## Implementation Steps
- [ ] Step 1: Write death tests (bash test cases with mock .learnings/ directories)
- [ ] Step 2: Run death tests — verify they fail
- [ ] Step 3: Write unit tests (valid index with 1, 5, 30 entries)
- [ ] Step 4: Run unit tests — verify they fail
- [ ] Step 5: Implement `samsara/hooks/check-learnings`
- [ ] Step 6: Run all tests — verify they pass
- [ ] Step 7: Write scar report
- [ ] Step 8: Report (do not commit)

## Hook Output Format

When learnings exist:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Project Learnings (3 active):\n- [testing] This project uses Vitest not Jest\n- [database] DB migrations cannot use table locks\n- [auth] OAuth tokens expire after 1h, not 24h\nUse /samsara:recall to query full details."
  }
}
```

When no learnings or empty:
```
(exit 0, no output)
```

When malformed:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Project Learnings: INDEX MALFORMED. Run: bash scripts/learnings-rebuild.sh .learnings/"
  }
}
```

## Expected Scar Report Items
- Potential shortcut: Reading YAML with grep/sed instead of a YAML parser — same risk as task-1
- Assumption to verify: `CLAUDE_PROJECT_DIR` is always set when running in a project context
- Assumption to verify: Hook timeout (currently 3000ms for codebase-map) is sufficient for reading index.yaml with 30 entries

## Acceptance Criteria
- Covers: "Silent failure - hook injection fails silently" (malformed index detection)
- Covers: "Degradation - .learnings/ dir exists but is empty" (clean exit)
- Covers: "Success - learnings loaded at session start"
