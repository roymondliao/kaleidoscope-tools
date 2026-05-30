# Kickoff: Code Review Skill

## Problem Statement

Users need a repeatable PR review workflow that starts from a PR URL, checks out the PR branch with `gh`, understands the target repository before judging changes, decomposes the PR into coherent review units, dispatches those units to reviewer subagents with enough shared context, consolidates their findings for discussion, and only after user alignment posts line-specific GitHub review comments through the pull request review comments API.

## Evidence

- The repository already packages reusable skills under `skills/*/SKILL.md` and subagents under `agents/*.md`, so a code review workflow fits the existing project shape.
- Existing skills such as `skills/create-pr/SKILL.md` encode operational GitHub workflows with `gh`, prerequisites, guarded user approval, and explicit error handling; code review needs the same level of operational specificity.
- Existing agents such as `agents/analytical-critic.md` and `agents/pragmatic-critic.md` show that subagents should receive scoped tasks, evidence requirements, and output schema rather than vague review instructions.
- The user explicitly needs review comments to target PR diff lines via `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`, requiring reliable collection of `commit_id`, `path`, `line`, `side`, and markdown `body`.
- The referenced superpowers reviewer template emphasizes concrete file:line findings, actual severity, explanation of why each issue matters, and a clear ready-to-merge assessment.

## Risk of Inaction

PR review remains ad hoc. The main agent may over-focus on changed files without understanding project intent, assign subagents insufficient context, produce duplicated or contradictory review feedback, or post comments before the user has agreed with the findings. Bad review comments are costly because they create noise directly on a teammate's PR and may misrepresent the user's review stance.

## Scope

### Must-Have (with death conditions)

- **PR intake and checkout via `gh`** — Death condition: if `gh` cannot reliably fetch and check out PR branches across the target repositories, the workflow should stop at advisory review instead of pretending it can operate on local code.
- **Project reconnaissance before review** — Death condition: if reconnaissance routinely consumes more time/context than the PR review itself without improving finding quality, reduce it to a bounded project summary step.
- **Exclude `tests/` from broad codebase reconnaissance** — Death condition: if review accuracy drops because test architecture is essential to understanding the project, allow targeted test reads only after the changed production files are understood.
- **PR intent reconstruction from description and commit logs** — Death condition: if PR descriptions and commits are frequently empty or misleading, require user-provided intent before dispatching subagents.
- **Changed-file grouping into coherent review units** — Death condition: if grouping creates duplicate reviews or hides cross-file defects, fall back to one reviewer for the whole PR plus optional specialist passes.
- **Subagent prompt contract with project info, PR info, assigned files, and output schema** — Death condition: if subagents return generic comments despite the contract, collapse back to main-agent review until the prompt is improved.
- **Main-agent consolidation and user discussion gate before posting comments** — Death condition: if users consistently want advisory-only output and never post comments, split GitHub posting into an optional follow-up skill.
- **Line-specific GitHub review comment posting** — Death condition: if line mapping to PR diff hunks is unreliable, never post comments automatically; present draft comments and exact mapping failures instead.

### Nice-to-Have

- Support multi-line review comments with `start_line` and `start_side`.
- Support batching comments into a GitHub review instead of independent comments.
- Add review specialization by concern type, such as security, architecture, behavior, and tests.
- Detect and avoid duplicate comments on the same PR line.
- Persist reusable project summaries for repeated reviews in the same repository.

### Explicitly Out of Scope

- Automatically approving, requesting changes, or merging PRs.
- Posting review comments before explicit user approval.
- Editing PR code as part of the review workflow.
- Reviewing every test file during initial project reconnaissance.
- Replacing human judgment on whether a finding should be posted publicly.
- Building a general GitHub PR management platform.

## North Star

```yaml
metric:
  name: "Accepted Review Finding Rate"
  definition: "Percentage of generated review findings that the user agrees are valid and worth discussing or posting"
  current: "unmeasured"
  target: ">= 80% across the first 10 reviewed PRs"
  invalidation_condition: "User primarily wants fast superficial review comments rather than high-signal correctness review"
  corruption_signature: "The skill inflates acceptance by producing fewer, safer, generic findings that avoid real risks. Detect by comparing accepted findings against later bugs or reviewer feedback missed by the workflow."

sub_metrics:
  - name: "context_completeness"
    current: "unmeasured"
    target: "project summary, PR intent, changed-file map, and review grouping present for every dispatched subagent"
    proxy_confidence: medium
    decoupling_detection: "Subagent outputs still contain generic advice or incorrect project assumptions despite all context fields being present"
  - name: "line_comment_mapping_success"
    current: "unmeasured"
    target: ">= 95% of approved comments map to valid PR diff line parameters"
    proxy_confidence: high
    decoupling_detection: "GitHub accepts comments but they appear on confusing or low-context lines in the rendered PR diff"
  - name: "duplicate_finding_rate"
    current: "unmeasured"
    target: "<= 10% duplicate or overlapping findings after consolidation"
    proxy_confidence: medium
    decoupling_detection: "Findings are not literal duplicates but ask for the same underlying fix from different file angles"
```

## Stakeholders

- **Decision maker:** yuyu_liao (project owner)
- **Impacted teams:** Users of kaleidoscope-tools who want repeatable PR review workflows; maintainers of skills and agents in this repo; PR authors receiving comments generated through the workflow
- **Damage recipients:** PR authors who may receive noisy or incorrect comments; reviewers/users who must validate and curate generated findings; subagent prompt maintainers who must keep the review contract accurate as GitHub and local agent capabilities change
