# Plan: Code Review Skill

## Origin

- Kickoff: `changes/2026-05-29_code-review-skill/1-kickoff.md`
- Autopsy: `changes/2026-05-29_code-review-skill/problem-autopsy.md`
- Pre-thinking: `changes/2026-05-29_code-review-skill/pre-thinking.md`

## Pre-thinking Commitments Consumed

- **Decision:** Proceed
- **Accepted gaps:** none
- **System design constraints:**
  - Canonical implementation surface is Claude Code-style `skills/*/SKILL.md` plus `agents/*.md`.
  - v1 includes the `gh api` posting step.
  - v1 uses independent line comments, not pending review batch submission.
  - Broad project reconnaissance skips `tests/`, but changed test files may receive targeted review when relevant.
  - v1 uses one generic `code-reviewer` subagent; the main skill varies scope and focus per review unit.
- **Primary evaluator:** Closed PR dry-run review using `https://github.com/OWNER/REPO/pull/123`.
- **Pass signal:** Dry-run output includes project information, PR information, review-unit grouping, at least one well-formed generic `code-reviewer` task contract, consolidated review findings or explicit "no findings", and every proposed comment payload has `commit_id`, `path`, `line`, `side`, and markdown `body` mapped to the PR diff.
- **Fail signal:** Workflow cannot inspect the PR, skips project reconnaissance, reviews changed files without PR intent, fails to group related files, gives subagents insufficient context, produces generic unactionable findings, proposes invalid payload fields, or attempts GitHub posting during dry-run.
- **Feedback loop:** Fix the failed skill/subagent contract or workflow step, then rerun the same closed PR dry-run evaluator before broadening validation.

## Approach

Create a new user-invocable `code-review` skill and one generic `code-reviewer` subagent. The skill is the coordinator: it accepts a PR URL, checks prerequisites, uses `gh` and `git` to fetch the PR context, performs bounded project reconnaissance, reconstructs PR intent, groups changed files into review units, dispatches each unit to the subagent, consolidates results, discusses them with the user, and only then posts approved independent line comments.

The subagent is deliberately generic. It receives project information, PR information, assigned files, relevant diffs, review focus, and output schema. It returns evidence-backed findings with severity, file/line references, reasoning, proposed comment bodies, and a merge-readiness verdict.

## Architecture

```
User provides PR URL
        |
        v
skills/code-review/SKILL.md
        |
        +-- Prerequisite and state checks
        |   - git repository
        |   - gh installed/authenticated
        |   - clean or user-approved checkout state
        |
        +-- PR checkout and metadata
        |   - gh pr view
        |   - gh pr checkout or fetch fallback
        |   - head SHA, base branch, changed files, commits, diff
        |
        +-- Context building
        |   - project reconnaissance, excluding broad tests/
        |   - PR description and commit intent
        |   - changed-file grouping
        |
        +-- Subagent dispatch
        |   - agents/code-reviewer.md
        |   - one task per coherent review unit
        |
        +-- Consolidation and user gate
        |   - deduplicate findings
        |   - calibrate severity
        |   - draft approved comment payloads
        |
        +-- Posting
            - dry-run must never post
            - approved live mode posts independent line comments via gh api
```

## Components

### 1. `skills/code-review/SKILL.md`

Responsibilities:
- Parse PR URL or accept PR number/current repository shorthand.
- Check prerequisites: git repo, origin remote, `gh` installed, `gh auth status`, non-dangerous local checkout state.
- Fetch PR metadata with `gh pr view --json`.
- Check out PR branch via `gh pr checkout` using the provided PR URL or number. If checkout cannot be determined, mark outcome `unknown` and stop before review.
- Build project overview using `README*`, root config files, package/project manifests, top-level directories, and source files while excluding broad `tests/` traversal.
- Reconstruct PR intent from description, title, labels if available, commit log, changed-file list, and diff shape.
- Group changed files by module, feature concern, or dependency chain.
- Construct subagent tasks with project information, PR information, assigned files, relevant diff snippets, explicit test-file handling, and output schema.
- Consolidate subagent outputs into findings and proposed comment payloads.
- Discuss findings with the user before any posting.
- Post only explicitly approved independent line comments.

### 2. `agents/code-reviewer.md`

Responsibilities:
- Review one assigned PR unit with full project and PR context.
- Judge whether the implementation matches the PR intent, not just whether local code looks plausible.
- Prioritize correctness, security/privacy, data loss, migration/compatibility, API contract breakage, error handling, maintainability, and test adequacy where assigned.
- Avoid generic style comments unless style affects correctness or maintainability.
- Return a structured result with findings, evidence, suggested comment body, confidence, and verdict.

### 3. Reference Templates

Create `skills/code-review/reference/review-result-template.md` to stabilize subagent output and main-agent consolidation. Create `skills/code-review/reference/comment-payload-template.md` to document required fields for independent review comments.

### 4. Documentation

Update `README.md` skill and agent tables so the new workflow is discoverable. Add `changes/2026-05-29_code-review-skill/evaluator.md` describing how to run the closed PR dry-run evaluator and what evidence to capture.

## I/O States

### PR checkout

- **success:** PR branch is checked out locally and head SHA/base branch are known.
- **failure:** Known blocker such as not a git repository, `gh` missing, `gh` unauthenticated, PR not found, or remote inaccessible.
- **unknown:** Command output does not prove which branch or commit is checked out. Unknown must stop review; it must not continue against the wrong tree.

### Project reconnaissance

- **success:** Project summary includes purpose, stack, module/folder structure, and relevant local conventions.
- **failure:** Required files cannot be read or project root cannot be identified.
- **unknown:** Repo is too large or sparse for a reliable bounded summary. Unknown must be marked and passed to user/subagents; it must not be presented as full understanding.

### Subagent review

- **success:** Subagent returns structured findings or explicit "no findings" with reviewed scope.
- **failure:** Subagent cannot read assigned files or returns malformed output.
- **unknown:** Subagent output is incomplete, generic, or lacks evidence. Unknown must trigger re-dispatch or main-agent review, not consolidation as clean.

### Comment posting

- **success:** `gh api` returns created comment data for the approved payload.
- **failure:** GitHub rejects the payload with a known status or validation error.
- **unknown:** Network timeout, ambiguous CLI output, or partial batch failure. Unknown must be reported to the user with payload status; never retry blindly.

## Death Cases

### Death Case 1: Wrong checkout looks valid

- **Trigger:** `gh pr checkout` fails or checks out an unexpected branch, but local files still exist.
- **Lie:** Review appears to analyze the requested PR.
- **Truth:** Review is performed against the previous branch or wrong commit.
- **Detection:** Compare current HEAD SHA to PR head SHA before reading changed files.

### Death Case 2: Project overview pretends tests were reviewed

- **Trigger:** Broad reconnaissance excludes `tests/`, but output does not state that boundary.
- **Lie:** Subagent assumes project behavior and test coverage were fully understood.
- **Truth:** Test architecture may not have been inspected.
- **Detection:** Project information must explicitly state "tests/ excluded from broad reconnaissance" and list any targeted changed test files reviewed.

### Death Case 3: Subagent lacks PR intent

- **Trigger:** Main agent dispatches changed files and diffs without title, description, commits, or purpose.
- **Lie:** Subagent returns plausible local code comments.
- **Truth:** Findings may contradict the PR's actual reason or miss intent-level defects.
- **Detection:** Every subagent task must include a `PR Intent` section and review objective.

### Death Case 4: Line payload maps to the wrong side

- **Trigger:** Comment payload uses `line` without validating that the line is on the PR diff side intended by the finding.
- **Lie:** GitHub accepts or rejects the comment as an API detail.
- **Truth:** Comment can land on a confusing line or fail after user approval.
- **Detection:** Every proposed payload must include `path`, `line`, `side`, source finding, and diff-hunk evidence before posting.

### Death Case 5: Dry-run posts public comments

- **Trigger:** Skill reaches posting step while evaluating against the closed PR fixture.
- **Lie:** Dry-run validates the full workflow.
- **Truth:** It creates side effects on a real PR or fails because the PR is closed.
- **Detection:** Dry-run mode must make posting commands non-executable and output payloads only.

## Task Decomposition

1. **Task 1: Generic reviewer subagent** — create `agents/code-reviewer.md` with role, review standards, input contract, output schema, and evidence rules.
2. **Task 2: Main code-review skill workflow** — create `skills/code-review/SKILL.md` and `skills/code-review/reference/review-result-template.md` with PR intake, checkout, reconnaissance, intent, grouping, dispatch, and consolidation.
3. **Task 3: Comment payload and posting safety** — extend the skill with independent comment payload validation, dry-run behavior, user approval gate, and `gh api` posting instructions; create `comment-payload-template.md`.
4. **Task 4: Documentation and evaluator evidence** — update `README.md`, add the closed PR dry-run evaluator instructions, and verify the planned artifacts satisfy acceptance criteria.

## Scope Boundaries

- No auto-approval, request-changes, merge, or code edits.
- No posting without user approval.
- No pending review batch in v1.
- No broad `tests/` reconnaissance, but changed test files can be targeted review inputs.
- No guarantee that closed PR dry-run validates GitHub posting side effects.

## Deferred

- Multi-line review comments with `start_line`/`start_side`.
- Pending review batch support.
- Specialist reviewer subagents.
- Duplicate comment detection against existing PR comments.
- Persisted project summaries across reviews.
