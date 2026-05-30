# Task 3: Comment Payload Validation and Posting Safety

## Context

Read: `changes/2026-05-29_code-review-skill/overview.md`

v1 includes GitHub posting, but only as independent line comments after explicit user approval. Dry-run mode is required for the closed PR evaluator and must never call the posting endpoint.

## Files

- Modify: `skills/code-review/SKILL.md`
- Create: `skills/code-review/reference/comment-payload-template.md`

## Death Test Requirements

- Test: Dry-run mode reaches posting phase -> skill must output payloads only and must not run `gh api`.
- Test: Proposed payload lacks any of `commit_id`, `path`, `line`, `side`, or `body` -> skill must block posting.
- Test: Posting command returns timeout or ambiguous output -> skill must mark result unknown and must not retry blindly.

## Implementation Steps

- [ ] Step 1: Add dry-run mode behavior to the skill, including the closed PR evaluator fixture.
- [ ] Step 2: Define comment payload validation rules for `commit_id`, `path`, `line`, `side`, and markdown `body`.
- [ ] Step 3: Define diff-line verification requirements before user approval.
- [ ] Step 4: Define the user approval gate for live posting.
- [ ] Step 5: Define `gh api` independent line comment command shape using `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`.
- [ ] Step 6: Define per-payload result states: success, failure, unknown.
- [ ] Step 7: Create `comment-payload-template.md`.
- [ ] Step 8: Check the workflow against the death test requirements by inspection.
- [ ] Step 9: Write scar report.
- [ ] Step 10: Report; do not commit unless explicitly asked.

## Expected Scar Report Items

- Potential shortcut: Assuming GitHub accepts `line` without verifying that it maps to the intended diff hunk.
- Potential shortcut: Retrying failed posting commands automatically and creating duplicate comments.
- Assumption to verify: The skill's allowed tools allow `gh api` without overbroad shell permission patterns.

## Acceptance Criteria

- Covers: "Silent failure - dry-run creates GitHub side effects"
- Covers: "Silent failure - invalid line comment payload looks approved"
- Covers: "Unknown outcome - comment posting result ambiguous"
- Covers: "Success - live approved independent comments are posted"
