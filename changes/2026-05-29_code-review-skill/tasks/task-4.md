# Task 4: Documentation and Dry-Run Evaluator

## Context

Read: `changes/2026-05-29_code-review-skill/overview.md`

After the skill and subagent exist, the repository should expose them in `README.md` and provide evaluator instructions for the closed PR dry-run fixture. The evaluator is the primary validation standard for this feature.

## Files

- Modify: `README.md`
- Create: `changes/2026-05-29_code-review-skill/evaluator.md`

## Death Test Requirements

- Test: Evaluator instructions allow actual posting against the closed PR -> must fail; evaluator must require dry-run only.
- Test: Evaluator evidence omits subagent task prompt or comment payload fields -> must fail; pass signal requires full pipeline evidence.
- Test: README lists the skill but not the subagent -> must fail discoverability check.

## Implementation Steps

- [ ] Step 1: Update `README.md` skill table with `code-review`.
- [ ] Step 2: Update `README.md` agent table with `code-reviewer`.
- [ ] Step 3: Create `evaluator.md` with the closed PR URL, dry-run command/invocation guidance, required evidence checklist, pass signal, fail signal, and out-of-scope validation.
- [ ] Step 4: Inspect all created artifacts against `acceptance.yaml`.
- [ ] Step 5: Record any residual risks or assumptions in scar report.
- [ ] Step 6: Report; do not commit unless explicitly asked.

## Expected Scar Report Items

- Potential shortcut: Treating documentation presence as validation without checking that the evaluator can catch dry-run side effects.
- Assumption to verify: The closed PR remains accessible to the reviewing environment through `gh`.
- Assumption to verify: README discovery tables remain the canonical place for skills and agents.

## Acceptance Criteria

- Covers: "Silent failure - dry-run creates GitHub side effects"
- Covers: "Success - closed PR dry-run review produces review pipeline evidence"
