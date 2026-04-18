# Task 1: Index Rebuild Script

## Context
Read: overview.md

The index rebuild script is the foundation component. Both the SessionStart hook (task-2) and the recall skill (task-3) depend on a well-formed index.yaml. The script scans `.learnings/*.md` files, parses YAML frontmatter, and generates/regenerates `index.yaml`.

This script lives at `scripts/learnings-rebuild.sh` (shared, not samsara-specific) because it is infrastructure for the `.learnings/` format itself.

## Files
- Create: `scripts/learnings-rebuild.sh`
- Test: Manual testing via creating sample `.learnings/` files and running the script

## Learning File Format (reference)

```yaml
---
id: YYYY-MM-DD_slug
domain: <category>
trigger: "When <context>"
created: YYYY-MM-DD
last_validated: YYYY-MM-DD
status: active | archived
source_session: <session-id or "manual">
---

# Title

## What went wrong
<description>

## Root cause
<description>

## Correct approach
<description>

## Context
<context>
```

## Index File Format (output)

```yaml
version: 1
last_rebuilt: <ISO 8601 timestamp>
active_count: <number>
archived_count: <number>

entries:
  - id: <learning-id>
    domain: <domain>
    one_liner: "<first sentence of 'What went wrong' + key detail from 'Correct approach'>"
    created: <date>
```

## Death Test Requirements
- Test: Script runs on `.learnings/` with 3 .md files but index.yaml only has 1 entry → must detect 2 orphans and add them
- Test: Script runs on `.learnings/` where index.yaml references a file that was deleted → must detect stale entry and remove it
- Test: Script runs on `.learnings/` with 35 active files → must archive 5 oldest (by last_validated), leaving 30 active
- Test: Script runs on `.learnings/` with a .md file that has malformed YAML frontmatter → must skip with warning, not crash
- Test: Script runs on empty `.learnings/` directory → must produce valid index.yaml with 0 entries

## Implementation Steps
- [ ] Step 1: Write death tests (bash test cases or test script)
- [ ] Step 2: Run death tests — verify they fail
- [ ] Step 3: Write unit tests (valid inputs, boundary conditions)
- [ ] Step 4: Run unit tests — verify they fail
- [ ] Step 5: Implement `scripts/learnings-rebuild.sh`
- [ ] Step 6: Run all tests — verify they pass
- [ ] Step 7: Write scar report
- [ ] Step 8: Report (do not commit)

## Expected Scar Report Items
- Potential shortcut: Using grep/sed for YAML parsing instead of a proper YAML parser — fragile if frontmatter format varies
- Assumption to verify: `one_liner` generation by extracting first sentence — may fail on multi-sentence paragraphs or non-English text
- Assumption to verify: `last_validated` date comparison in bash — date arithmetic portability between macOS and Linux

## Acceptance Criteria
- Covers: "Silent failure - learning written but index not updated" (orphan detection)
- Covers: "Silent failure - index references deleted learning" (stale reference detection)
- Covers: "Degradation - archive threshold exceeded" (30 entry cap enforcement)
- Covers: "Success - index rebuild detects and reports integrity issues"
