# Overview: Code Review Skill

## Goal

Create a Claude Code-style code review skill and generic reviewer subagent that can review a PR from URL through dry-run payload generation and, with user approval, post independent GitHub line comments.

## Architecture

The main `skills/code-review/SKILL.md` workflow coordinates PR checkout, project reconnaissance, PR intent reconstruction, changed-file grouping, subagent dispatch, result consolidation, user approval, and comment posting. The generic `agents/code-reviewer.md` reviews one coherent PR unit at a time with project context, PR context, assigned files, and evidence-backed output rules.

## Tech Stack

- Claude Code skill format: `skills/*/SKILL.md`
- Claude Code agent format: `agents/*.md`
- GitHub CLI: `gh pr view`, `gh pr checkout`, `gh api`
- Git: checkout verification, diff, log, changed-file inspection
- Markdown reference templates under `skills/code-review/reference/`

## Key Decisions

- Claude Code-style artifacts: matches this repository's existing `skills/` and `agents/` structure.
- One generic reviewer subagent: keeps v1 maintainable while allowing main skill to vary scope and focus.
- Independent line comments: follows the requested `POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` endpoint.
- Dry-run evaluator: a closed PR fixture such as `https://github.com/OWNER/REPO/pull/123` validates the pipeline without GitHub side effects.
- Tests handling: broad reconnaissance skips `tests/`, but changed test files may be targeted review inputs.

## Death Cases Summary

1. Wrong checkout looks valid and the review runs on the previous branch.
2. Subagent receives changed files without PR intent and produces plausible but irrelevant findings.
3. Dry-run accidentally posts public GitHub comments.

## File Map

- `skills/code-review/SKILL.md` — main review orchestration workflow.
- `skills/code-review/reference/review-result-template.md` — structured subagent output and consolidation schema.
- `skills/code-review/reference/comment-payload-template.md` — required independent line comment payload fields and validation rules.
- `agents/code-reviewer.md` — generic code reviewer subagent.
- `README.md` — skill and agent discovery table updates.
- `changes/2026-05-29_code-review-skill/evaluator.md` — closed PR dry-run evaluator instructions and evidence checklist.
