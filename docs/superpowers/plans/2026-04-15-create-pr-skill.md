# Create PR Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a standalone `/create-pr` skill for kaleidoscope-tools that auto-generates PR content from git context using a standardized template, with a user review gate before submission.

**Architecture:** Two files — `SKILL.md` (orchestration logic defining a 6-step workflow) and `reference/pr-template.md` (the PR body template with placeholders). The skill reads git state, auto-fills the template, asks for Jira ticket, presents a draft for approval, then runs `gh pr create`.

**Tech Stack:** Claude Code skill (markdown), `gh` CLI, `git` CLI

---

## File Structure

```
skills/create-pr/
├── SKILL.md              # Orchestration: frontmatter + 6-step workflow
└── reference/
    └── pr-template.md    # PR body template with {placeholders}
```

| File | Responsibility |
|------|---------------|
| `SKILL.md` | Frontmatter (name, description, allowed-tools), workflow steps 1-6, PR type inference rules, error handling, review gate logic |
| `reference/pr-template.md` | PR body structure with 4 sections: PR Type checkboxes, Description, Jira Tickets, ChangeLogs |

---

### Task 1: Create the PR body template

**Files:**
- Create: `skills/create-pr/reference/pr-template.md`

- [ ] **Step 1: Create the reference directory and template file**

```markdown
### PR Type

- [ ] feat: New feature
- [ ] fix: Bug fix
- [ ] docs: Documentation update
- [ ] style: Code style changes (formatting, no logic changes)
- [ ] refactor: Code refactoring (no functional changes)
- [ ] perf: Performance optimization
- [ ] test: Adding or updating tests
- [ ] chore: Build process, CI, tooling, or other non-functional changes

---

### Description

{description}

---

### Jira Tickets

{jira_tickets}

---

### ChangeLogs

{changelogs}
```

This file is pure template — no frontmatter, no logic. The placeholders `{description}`, `{jira_tickets}`, and `{changelogs}` are filled by the skill at runtime. The PR Type checkboxes are toggled by the skill based on auto-detection.

- [ ] **Step 2: Verify the file was created correctly**

Run: `cat skills/create-pr/reference/pr-template.md`
Expected: The template content above with all 4 sections and 3 placeholders.

- [ ] **Step 3: Commit**

```bash
git add skills/create-pr/reference/pr-template.md
git commit -m "feat(create-pr): add PR body template with type/description/jira/changelog sections"
```

---

### Task 2: Create SKILL.md — frontmatter and prerequisites section

**Files:**
- Create: `skills/create-pr/SKILL.md`

- [ ] **Step 1: Write the frontmatter and opening sections**

```markdown
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
```

- [ ] **Step 2: Verify the file was created and frontmatter is valid**

Run: `head -30 skills/create-pr/SKILL.md`
Expected: YAML frontmatter block with name, description, allowed-tools list, and user-invocable flag.

- [ ] **Step 3: Commit**

```bash
git add skills/create-pr/SKILL.md
git commit -m "feat(create-pr): add SKILL.md with frontmatter and prerequisites check"
```

---

### Task 3: Add Step 1 and Step 2 — git state detection and git operations

**Files:**
- Modify: `skills/create-pr/SKILL.md` (append after Prerequisites Check section)

- [ ] **Step 1: Add the git state detection section**

Append the following to `SKILL.md` after the Prerequisites Check section:

```markdown
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
```

- [ ] **Step 2: Verify the appended content**

Run: `grep -c "## Step" skills/create-pr/SKILL.md`
Expected: At least 2 matches (Step 1 and Step 2).

- [ ] **Step 3: Commit**

```bash
git add skills/create-pr/SKILL.md
git commit -m "feat(create-pr): add git state detection and git operations workflow"
```

---

### Task 4: Add Step 3 — diff analysis and auto-fill logic

**Files:**
- Modify: `skills/create-pr/SKILL.md` (append after Step 2)

- [ ] **Step 1: Add the diff analysis section**

Append the following to `SKILL.md`:

```markdown
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
```

- [ ] **Step 2: Verify the appended content**

Run: `grep "## Step 3" skills/create-pr/SKILL.md`
Expected: One match for "## Step 3: Analyze Diff and Auto-Fill".

- [ ] **Step 3: Commit**

```bash
git add skills/create-pr/SKILL.md
git commit -m "feat(create-pr): add diff analysis and PR type auto-detection logic"
```

---

### Task 5: Add Steps 4, 5, 6 — Jira prompt, review gate, and PR creation

**Files:**
- Modify: `skills/create-pr/SKILL.md` (append after Step 3)

- [ ] **Step 1: Add Steps 4, 5, and 6**

Append the following to `SKILL.md`:

```markdown
## Step 4: Ask for Jira Ticket

Ask the user:

> What's the Jira ticket for this PR? Please provide in the format: `[VIC-XXXX](https://jira.example.com/browse/VIC-XXXX) Ticket Title`
>
> Or type "skip" if there is no Jira ticket for this PR.

Do not infer or guess the ticket number. Always ask. If the user says "skip", leave the Jira Tickets section as "N/A".

## Step 5: Assemble and Present Draft

### 5a. Build the PR body

1. Read `reference/pr-template.md` from this skill's directory
2. Fill the template:
   - **PR Type checkboxes**: Change `- [ ]` to `- [x]` for each detected type from Step 3b
   - **{description}**: Replace with the generated description from Step 3c
   - **{jira_tickets}**: Replace with the user's Jira ticket from Step 4
   - **{changelogs}**: Replace with the generated changelog bullets from Step 3d

### 5b. Generate PR title

Format: `<type(s)>: <concise summary>`

Rules:
- Single type: `feat: add score_v2 evaluation logic`
- Multiple types: `feat,test: add webhook handler with coverage`
- Maximum 70 characters
- Summary describes the "what", not the "how"

### 5c. Present the draft

Show the user the complete draft in this format:

> **PR Title:** `<generated title>`
>
> **PR Body:**
>
> <the fully assembled PR body>

Then ask: "Does this look good, or would you like to change anything?"

- If the user requests changes: apply the edits and present the updated draft again.
- If the user approves (e.g., "looks good", "ok", "yes", "lgtm"): proceed to Step 6.

## Step 6: Create PR

Run:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<assembled PR body>
EOF
)"
```

If `gh pr create` succeeds: show the PR URL to the user.

If `gh pr create` fails:
- If the error mentions a PR already exists: suggest `gh pr view --web` to open the existing PR.
- For any other error: show the full error message to the user.

After PR creation, do NOT push additional changes or modify the PR. The skill is complete.
```

- [ ] **Step 2: Verify all 6 steps exist**

Run: `grep "^## Step" skills/create-pr/SKILL.md`
Expected output:
```
## Step 1: Git State Detection
## Step 2: Handle Git Operations
## Step 3: Analyze Diff and Auto-Fill
## Step 4: Ask for Jira Ticket
## Step 5: Assemble and Present Draft
## Step 6: Create PR
```

- [ ] **Step 3: Commit**

```bash
git add skills/create-pr/SKILL.md
git commit -m "feat(create-pr): add Jira prompt, review gate, and PR creation steps"
```

---

### Task 6: Smoke test the skill

**Files:**
- Read: `skills/create-pr/SKILL.md` (full file)
- Read: `skills/create-pr/reference/pr-template.md` (full file)

- [ ] **Step 1: Read back both files in full and verify completeness**

Read `skills/create-pr/SKILL.md` and verify:
- Frontmatter has: `name`, `description`, `allowed-tools`, `user-invocable`
- All 6 steps are present and in order
- No placeholders like TBD or TODO
- Error handling is covered (prerequisites section)
- `reference/pr-template.md` is referenced correctly in Step 5a

Read `skills/create-pr/reference/pr-template.md` and verify:
- All 4 sections present: PR Type, Description, Jira Tickets, ChangeLogs
- 8 PR type checkboxes present
- 3 placeholders present: `{description}`, `{jira_tickets}`, `{changelogs}`

- [ ] **Step 2: Verify the skill would be discoverable**

Run: `ls -la skills/create-pr/SKILL.md skills/create-pr/reference/pr-template.md`
Expected: Both files exist and have non-zero size.

- [ ] **Step 3: Final commit with all files verified**

If any issues were found in Step 1, fix them and commit:
```bash
git add skills/create-pr/
git commit -m "fix(create-pr): address issues from smoke test"
```

If no issues found, no commit needed. Skill is complete.
