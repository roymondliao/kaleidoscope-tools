# Create PR Skill Design Spec

> Standalone skill for kaleidoscope-tools that creates pull requests with a standardized body template, auto-filled from git context with a user review gate before submission.

## Context

The project currently has multiple paths to create PRs (`commit-commands:commit-push-pr`, `superpowers:finishing-a-development-branch`, `samsara:validate-and-ship`), but none enforce a consistent PR body format. The existing default is a minimal 2-section template (`## Summary` + `## Test Plan`) that lacks team-specific structure like PR type classification, Jira ticket linking, and detailed changelogs.

This skill introduces a standardized PR template and an intelligent workflow that auto-generates PR content from git context, then presents it for user approval before creation.

## Scope

### In scope (v1)

1. **Smart git state detection** -- detect uncommitted changes, unpushed commits, whether on main
2. **Selective file staging** -- only commit task-relevant files; never auto-add untracked files
3. **Branch management** -- create branch if on main, push if unpushed
4. **PR type auto-detection** -- infer PR type(s) from changed files in the diff
5. **PR body auto-generation** -- fill template with description and changelogs from diff analysis
6. **Jira ticket prompt** -- always ask user for ticket number and URL
7. **Review gate** -- present full draft to user for approval/edits before `gh pr create`
8. **PR title generation** -- `<type(s)>: <concise summary>` format, under 70 characters

### Out of scope (YAGNI)

- Hardcoded Jira base URL (user edits template if they want this)
- Test Plan section in PR body (CI enforces test passage)
- Hook enforcement of template on other PR creation paths
- Integration with samsara or superpowers workflows (standalone)
- PR update/edit after creation
- Draft PR support
- Multi-repo PR creation

## Architecture

```
skills/create-pr/
├── SKILL.md              # Orchestration logic + flow definition
└── reference/
    └── pr-template.md    # PR body template with placeholders
```

### Responsibility separation

| Layer | Responsible for | Not responsible for |
|-------|----------------|---------------------|
| SKILL.md | Workflow orchestration, git state detection, auto-fill logic, review gate flow | Template format decisions |
| pr-template.md | PR body structure and section definitions | Workflow logic, git operations |

## Workflow

### Step 1: Git State Detection

Check three conditions in parallel:

```
git status          → uncommitted/staged changes?
git branch --show   → on main branch?
git log origin/X..X → unpushed commits?
```

### Step 2: Handle Git Operations (conditional)

Decision tree:

```
On main branch?
  YES → Ask user for branch name → create branch → continue
  NO  → continue

Staged changes exist?
  YES → Auto-generate commit message from staged diff → commit
  NO  → Unstaged changes exist?
         YES → Show changed files, ask user which to stage → auto-generate commit message → commit
         NO  → No changes to commit, skip

Commit message follows conventional commit format (e.g., `feat: add scoring logic`), auto-generated from the staged diff.

Branch pushed to remote?
  NO  → git push -u origin <branch>
  YES → Check if ahead of remote → push if needed
```

**Critical rule:** Never run `git add -A` or `git add .`. Only stage files the user explicitly confirms or files already in the staging area.

### Step 3: Analyze Diff and Auto-Fill

**Input:** `git diff main...HEAD` and `git log main..HEAD`

**PR Type detection** from changed files:

| File pattern | Inferred type |
|-------------|---------------|
| New source files with new exports/classes | `feat` |
| Modified source files, no API surface change | `refactor` |
| Only test files (`*test*`, `*spec*`) | `test` |
| Only doc files (`*.md`, `docs/`) | `docs` |
| Only config/CI files (`.yml`, `.json`, `Makefile`) | `chore` |
| Performance-related changes (caching, indexing, batch) | `perf` |
| Only formatting changes (whitespace, imports) | `style` |
| Bug fix indicators (error handling, null checks, edge cases) | `fix` |

Multiple types can be selected when changes span categories.

**Description generation:** One paragraph summarizing the purpose of the changes, derived from commit messages and diff context.

**Changelogs generation:** Bullet list of key changes, one per logical unit of work. Include TODO items for known follow-up work if commit messages mention them.

### Step 4: Ask for Jira Ticket

Prompt the user with:

> What's the Jira ticket for this PR? (e.g., `[VIC-1234](https://jira.example.com/browse/VIC-1234) Ticket Title`)

No inference, no default. Always ask.

### Step 5: Assemble and Present Draft

1. Read `reference/pr-template.md`
2. Fill placeholders:
   - Check the detected PR type boxes (can be multiple)
   - Replace `{description}` with auto-generated description
   - Replace `{jira_tickets}` with user-provided ticket info
   - Replace `{changelogs}` with auto-generated changelog bullets
3. Generate PR title: `<type(s)>: <concise summary>` (under 70 chars)
4. Present both title and body to user
5. Ask: "Does this look good, or would you like to change anything?"

If user requests changes → apply edits → present again.
If user approves → proceed to Step 6.

### Step 6: Create PR

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<assembled PR body>
EOF
)"
```

Return the PR URL to the user.

## PR Body Template

The template stored in `reference/pr-template.md`:

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

## PR Title Format

**Pattern:** `<type(s)>: <concise summary>`

- Single type: `feat: add score_v2 evaluation logic`
- Multiple types: `feat,test: add webhook handler with coverage`
- Max 70 characters
- Summary describes the "what", not the "how"

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `gh` CLI not installed | Stop and tell user to install GitHub CLI |
| Not a git repository | Stop and inform user |
| No remote configured | Stop and inform user |
| No changes to commit and nothing pushed | Stop — nothing to create a PR for |
| `gh pr create` fails (e.g., PR already exists) | Show the error, suggest `gh pr view` |
| User cancels at review gate | Abort PR creation, keep branch and commits intact |

## Assumptions

- The user has `gh` CLI installed and authenticated
- The repository has a remote named `origin`
- The base branch for PRs is `main` (or the repository's default branch)
- The user works on feature branches, not directly on main

If any assumption does not hold, the skill should detect and report the issue rather than fail silently.
