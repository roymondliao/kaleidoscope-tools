# Task 2: Main Code-Review Skill Workflow

## Context

Read: `changes/2026-05-29_code-review-skill/overview.md`

The main skill coordinates the full PR review flow. It must be a Claude Code-style user-invocable skill under `skills/code-review/SKILL.md`. It should follow the operational specificity of `skills/create-pr/SKILL.md`: prerequisites, ordered workflow, failure handling, and explicit user gates.

## Files

- Create: `skills/code-review/SKILL.md`
- Create: `skills/code-review/reference/review-result-template.md`

## Death Test Requirements

- Test: PR checkout outcome is ambiguous -> skill must stop before review and report unknown checkout state.
- Test: Project reconnaissance skips `tests/` -> skill must explicitly state this boundary in project information.
- Test: Subagent task missing project information, PR information, or PR intent -> skill must treat the task as malformed, not dispatch.

## Implementation Steps

- [ ] Step 1: Create skill frontmatter with name, description, user-invocable flag, argument hint, and allowed tools for git/gh/read/search/subagent use.
- [ ] Step 2: Define prerequisite checks: git repository, origin remote, `gh` installed, `gh auth status`, PR URL/number present, and local checkout safety.
- [ ] Step 3: Define PR metadata collection using `gh pr view --json` for title, body, state, head/base refs, head SHA, commits, files, and review URL.
- [ ] Step 4: Define checkout flow with `gh pr checkout` and explicit HEAD SHA verification.
- [ ] Step 5: Define project reconnaissance rules excluding broad `tests/` traversal.
- [ ] Step 6: Define PR intent reconstruction from description, title, commits, changed files, and diff shape.
- [ ] Step 7: Define changed-file grouping and subagent task construction.
- [ ] Step 8: Define consolidation rules and user discussion gate.
- [ ] Step 9: Create `review-result-template.md` for subagent results and main-agent consolidation.
- [ ] Step 10: Check the workflow against the death test requirements by inspection.
- [ ] Step 11: Write scar report.
- [ ] Step 12: Report; do not commit unless explicitly asked.

## Expected Scar Report Items

- Potential shortcut: Treating `gh pr checkout` success text as proof instead of comparing local HEAD to PR head SHA.
- Potential shortcut: Building project summary only from README and missing actual module structure.
- Assumption to verify: Grouping rules handle cross-cutting changes without splitting dependent files into isolated reviews.

## Acceptance Criteria

- Covers: "Silent failure - review runs on wrong checkout"
- Covers: "Silent failure - subagent reviews without PR intent"
- Covers: "Degradation - project reconnaissance is incomplete"
- Covers: "Success - closed PR dry-run review produces review pipeline evidence"
