# Task 1: Generic Code-Reviewer Subagent

## Context

Read: `changes/2026-05-29_code-review-skill/overview.md`

The feature needs one generic `code-reviewer` subagent for v1. The main skill will group PR changes and assign each review unit to this subagent with project information, PR information, assigned files, and review focus. The subagent must not rely on hidden session context.

## Files

- Create: `agents/code-reviewer.md`

## Death Test Requirements

- Test: A provided subagent task lacks `PR Intent` -> agent instructions must say to return malformed-input/unknown instead of reviewing.
- Test: A provided subagent task has assigned files but no project information -> agent instructions must say to request missing context or mark review scope degraded.
- Test: A provided subagent task includes broad `tests/` assumptions without targeted test files -> agent instructions must require explicit test-scope boundary.

## Implementation Steps

- [ ] Step 1: Write the subagent role and operating constraints.
- [ ] Step 2: Define required input sections: project information, PR information, PR intent, assigned review unit, changed files, relevant diffs, test-scope boundary, and output path or response format.
- [ ] Step 3: Define review standards: correctness, security/privacy, data loss, API contracts, migration/compatibility, error handling, maintainability, and test adequacy where assigned.
- [ ] Step 4: Define output schema with findings, severity, evidence, suggested PR comment body, confidence, and verdict.
- [ ] Step 5: Add malformed/unknown outcome behavior for missing context.
- [ ] Step 6: Check the file against the death test requirements by inspection.
- [ ] Step 7: Write scar report.
- [ ] Step 8: Report; do not commit unless explicitly asked.

## Expected Scar Report Items

- Potential shortcut: Writing generic "best practices" review rules without requiring evidence tied to assigned files.
- Assumption to verify: Severity labels are calibrated and do not overstate minor maintainability concerns.
- Assumption to verify: The output schema is easy for the main skill to consolidate without rewriting every result.

## Acceptance Criteria

- Covers: "Silent failure - subagent reviews without PR intent"
- Covers: "Degradation - changed tests exist"
- Covers: "Success - closed PR dry-run review produces review pipeline evidence"
