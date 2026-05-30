# Pre-thinking: Code Review Skill

## Session: 2026-05-29T22:48:59+08:00

## Step A — Design and Gap Map

### Information Gaps

#### Gap I1: target runtime
**Question:** Which agent runtime should this skill and subagent target as the canonical implementation surface?
**Hypothesis:** The canonical target is Claude Code-style `skills/*/SKILL.md` and `agents/*.md`, because this repository's existing standalone skills and subagents use that shape.

#### Gap I2: review posting permission boundary
**Question:** Should the implemented workflow include the exact `gh api` posting step in v1, or stop at approved draft comments that the user can post manually?
**Hypothesis:** Include the posting step in v1, but require an explicit user approval gate immediately before every `gh api` call.

### Design Decision Gaps

#### Gap D1: changed tests handling
**Question:** If a PR modifies files under `tests/`, should those changed test files be assigned for targeted review, ignored entirely, or only summarized as context?
**Hypothesis:** Do not read tests during broad project reconnaissance, but allow targeted review of changed test files when they are part of the PR's review unit.
**Planning impact:** This changes the review-unit grouping rules, subagent prompt contract, and whether test-only PRs can receive meaningful review.

#### Gap D2: comment submission model
**Question:** Should approved findings be posted as independent review comments, or collected into a single pending GitHub review where possible?
**Hypothesis:** Post independent line comments with `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments`, because the requirement names that endpoint and its required fields.
**Planning impact:** This changes API command design, failure recovery, duplicate avoidance, and whether the workflow needs a "submit review" phase.

#### Gap D3: subagent specialization
**Question:** Should v1 use one generic code-reviewer subagent type for all grouped review units, or multiple specialist reviewer roles?
**Hypothesis:** Use one generic `code-reviewer` subagent in v1, and let the main skill vary the assigned scope and focus per review unit.
**Planning impact:** This changes the number of agent files, task dispatch schema, consolidation complexity, and maintenance burden.

---

## Step B — Gap Answers

### Group 1: runtime-and-review-scope

#### Gap I1: target runtime
**A:** Claude Code-style is the canonical implementation surface.

#### Gap D1: changed tests handling
**A:** The hypothesis is correct: skip `tests/` during broad project reconnaissance, but allow targeted review of changed test files when relevant to the PR.

#### Gap D3: subagent specialization
**A:** Use one generic `code-reviewer` subagent in v1.

### Group 2: posting-and-evaluation

#### Gap I2: review posting permission boundary
**A:** v1 needs to include the `gh api` posting step.

#### Gap D2: comment submission model
**A:** v1 should use independent line comments rather than pending review batch submission.

## Evaluation Contract

**Primary evaluator:** Closed PR dry-run review using `https://github.com/OWNER/REPO/pull/123`
**Agent can perform it by:** Running the completed skill in dry-run mode against the closed PR fixture, using `gh` to inspect PR metadata, description, commits, changed files, and diff; checking out or fetching the PR branch when available; producing project reconnaissance, PR intent summary, changed-file review groups, subagent task prompts, consolidated findings, and proposed independent line comment payloads without calling the posting endpoint.
**Pass signal:** The dry-run output includes project information, PR information, review-unit grouping, at least one well-formed generic `code-reviewer` subagent task contract, consolidated review findings or an explicit "no findings" result, and every proposed comment payload has `commit_id`, `path`, `line`, `side`, and markdown `body` mapped to the PR diff.
**Fail signal:** The workflow cannot inspect the PR, skips project reconnaissance, reviews changed files without PR intent, fails to group related files, gives subagents insufficient context, produces generic unactionable findings, proposes comments without valid diff-line payload fields, or attempts to call the GitHub posting API during dry-run.
**Feedback loop:** First fix the skill/subagent contract or workflow step that failed, then rerun the same closed PR dry-run evaluator before broadening validation.
**Out of scope validation:** Actual GitHub comment creation, GitHub UI rendering of posted comments, review approval/request-changes behavior, and whether the closed PR's original human reviewers would agree with every generated finding.

## Step C — Commitment

**Date:** 2026-05-29T23:02:08+08:00
**Decision:** Proceed
**Accepted gaps:** none
**Unresolved gaps:** none
