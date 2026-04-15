---
name: create-pr
description: Create a pull request with a standardized body template, auto-filled from git context with a review gate before submission. Use when the user wants to create a PR, open a pull request, or run /create-pr.
allowed-tools:
- Bash(git status:*)
- Bash(git branch:*)
- Bash(git checkout:*)
- Bash(git add:*)
- Bash(git commit:*)
- Bash(git push:*)
- Bash(git diff:*)
- Bash(git log:*)
- Bash(git rev-list:*)
- Bash(git remote:*)
- Bash(gh pr create:*)
- Bash(gh pr view:*)
- Bash(which gh:*)
- Read
- Grep
- Glob
user-invocable: true
argument-hint: (no arguments needed)
---

# Create PR

Create a pull request with a standardized body template. Auto-fills PR content from git context, asks for Jira ticket, presents a draft for user approval, then creates the PR.

## Prerequisites Check

Before starting the workflow, verify these conditions. If any fail, stop and report the issue to the user:

1. **Git repository**: Run `git rev-parse --is-inside-work-tree`. If it fails, stop: "This is not a git repository."
2. **Remote exists**: Run `git remote get-url origin`. If it fails, stop: "No remote named 'origin' configured."
3. **gh CLI installed**: Run `which gh`. If it fails, stop: "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/"

## Step 1: Git State Detection

Run the following checks in parallel:

1. `git status --porcelain` — check for staged and unstaged changes
2. `git branch --show-current` — get current branch name
3. `git rev-list --count origin/<branch>..<branch>` — check for unpushed commits (if branch has a remote tracking branch)

Classify the state:
- **on_main**: Current branch is `main` or `master`
- **has_staged**: There are staged changes (lines starting with `M `, `A `, `D `, `R ` in `git status --porcelain`)
- **has_unstaged**: There are unstaged changes (lines starting with ` M`, ` D`, `??` in `git status --porcelain`)
- **has_unpushed**: There are commits ahead of the remote tracking branch
- **no_remote_tracking**: The branch has no upstream set

## Step 2: Handle Git Operations

Follow this decision tree in order:

### 2a. Branch management

If **on_main** is true:
- Ask the user: "You are on main. What should the branch name be?"
- Create the branch: `git checkout -b <user-provided-name>`
- Continue with the new branch

### 2b. Staging and committing

If **has_staged** is true:
- Show the staged files to the user: `git diff --cached --name-status`
- Auto-generate a conventional commit message from the staged diff
- Commit: `git commit -m "<generated message>"`

Else if **has_unstaged** is true:
- Show ALL changed/untracked files: `git status --porcelain`
- Ask the user: "Which files should be included in this PR? List the files or say 'all' for all changed files."
- **CRITICAL: Never run `git add -A` or `git add .`**. Only `git add <specific-files>` based on user selection.
- Auto-generate a conventional commit message from the staged diff
- Commit: `git commit -m "<generated message>"`

Else:
- No changes to commit. Continue (there may be already-committed unpushed work).

### 2c. Push to remote

If **no_remote_tracking** is true:
- Push with upstream: `git push -u origin <branch>`

Else if **has_unpushed** is true:
- Push: `git push`

Else:
- Already up to date. Check that there are commits ahead of main: `git rev-list --count main..HEAD`
- If 0 commits ahead of main: stop and tell the user "No changes to create a PR for. The branch is identical to main."

## Step 3: Analyze Diff and Auto-Fill

### 3a. Gather diff context

Run in parallel:
- `git diff main...HEAD` — full diff of all changes on this branch
- `git log main..HEAD --oneline` — commit summaries on this branch

### 3b. Auto-detect PR type(s)

Analyze the changed files from `git diff main...HEAD --name-status` and select ALL applicable types:

| Pattern | Type to check |
|---------|--------------|
| New source files (status `A`) with new exports, classes, or functions | `feat` |
| Modified source files (status `M`) with no new public API surface | `refactor` |
| Only files matching `*test*`, `*spec*`, `*_test.*`, `test_*` | `test` |
| Only files matching `*.md`, `docs/**`, `README*` | `docs` |
| Only files matching `*.yml`, `*.yaml`, `*.json`, `Makefile`, `Dockerfile`, `.github/**`, `.gitlab-ci*` | `chore` |
| Changes that add caching, batching, indexing, or reduce algorithmic complexity | `perf` |
| Only whitespace, import reordering, or formatting changes | `style` |
| Changes that fix error handling, add null checks, handle edge cases, or fix incorrect behavior | `fix` |

Multiple types can be selected. If unsure between types, prefer the more specific one.

### 3c. Generate description

Write one paragraph (2-4 sentences) summarizing the purpose of the changes. Derive this from:
- Commit messages on the branch
- The overall shape of the diff (what modules/files were touched)
- Focus on the "why" and "what", not the "how"

### 3d. Generate changelogs

Write a bullet list of key changes, one per logical unit of work:
- Each bullet starts with a verb: "Added", "Updated", "Removed", "Fixed", "Refactored"
- Include TODO items if commit messages mention follow-up work: `- TODO: <description> (will be handled in another PR)`
- Keep to 3-8 bullets. Group related small changes into one bullet.
