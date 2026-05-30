---
name: code-review
description: Review a GitHub pull request from URL. Checks out the PR with gh, builds project and PR context, delegates coherent review units to code-reviewer, consolidates findings, and prepares approved line comments.
allowed-tools:
- Bash(git rev-parse:*)
- Bash(git remote:*)
- Bash(git status:*)
- Bash(git branch:*)
- Bash(git checkout:*)
- Bash(git fetch:*)
- Bash(git diff:*)
- Bash(git log:*)
- Bash(gh auth status:*)
- Bash(gh pr view:*)
- Bash(gh pr checkout:*)
- Bash(gh api:*)
- Bash(which gh:*)
- Read
- Write
- Grep
- Glob
- Task
user-invocable: true
argument-hint: "<pr-url-or-number> [--dry-run]"
---

# Code Review

Review a GitHub pull request with bounded project reconnaissance, PR intent reconstruction, focused subagent review, user discussion, and optional approved line-comment posting.

## Operating Principles

- Understand the project before judging the PR.
- Understand the PR intent before judging changed files.
- Review changed files in coherent groups, not as an unordered file list.
- Broad project reconnaissance skips `tests/`; changed test files may be targeted review inputs.
- Subagents must receive project information, PR information, PR intent, assigned files, relevant diffs, and test-scope boundary.
- Generated findings are drafts until the user approves them.
- Dry-run mode must never create GitHub side effects.

## Inputs

The user must provide:

```text
/code-review <pr-url-or-number> [--dry-run]
```

If no PR URL or number is provided, ask for it and stop until the user responds.

Use `--dry-run` when validating the workflow or reviewing a closed PR. Dry-run mode performs all review steps through payload generation but never posts comments.

## State Model

Every major operation has three possible outcomes:

- **success:** The operation completed and evidence proves the intended state.
- **failure:** The operation failed with a known cause that can be reported.
- **unknown:** The outcome cannot be determined. Unknown is not success and must not be treated as safe to continue unless the step explicitly defines a degraded path.

## Step 0: Prerequisites

Run these checks before touching the PR branch:

1. `git rev-parse --is-inside-work-tree`
   - Failure: stop with "This is not a git repository."
2. `git remote get-url origin`
   - Failure: stop with "No remote named origin is configured."
3. `which gh`
   - Failure: stop with "GitHub CLI (gh) is not installed."
4. `gh auth status`
   - Failure: stop with the auth error and ask the user to authenticate.
5. `git status --porcelain`
   - If dirty, show the changed files and ask the user whether to continue, stash manually, or stop. Do not mutate unrelated local changes.

Record:

```yaml
pr_input: "<url-or-number>"
dry_run: true | false
starting_branch: "<branch>"
starting_head: "<sha>"
local_state: clean | dirty | unknown
```

## Step 1: PR Metadata

Fetch PR metadata with `gh pr view`:

```bash
gh pr view <pr-url-or-number> \
  --json number,url,title,body,state,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,commits,files,labels,author
```

Required fields:

- `number`
- `url`
- `title`
- `body`
- `state`
- `baseRefName`
- `headRefName`
- `headRefOid`
- `commits`
- `files`

If `gh pr view` succeeds but any required field is missing, classify PR metadata as `unknown` and stop before checkout.

## Step 2: Checkout and Verify

Check out the PR branch:

```bash
gh pr checkout <pr-url-or-number>
```

Then verify the local checkout:

```bash
git rev-parse HEAD
git branch --show-current
```

Compare `git rev-parse HEAD` to the PR `headRefOid`.

Outcome rules:

- **success:** local HEAD equals `headRefOid`.
- **failure:** `gh pr checkout` fails with a clear error.
- **unknown:** checkout command output is ambiguous, branch cannot be determined, or local HEAD does not equal PR `headRefOid`.

If checkout outcome is `unknown`, stop before reading changed files:

```text
Checkout outcome unknown. Expected PR head <headRefOid>, but local HEAD is <actual>. Review stopped to avoid analyzing the wrong branch.
```

## Step 3: Gather Diff and Commit Context

After checkout verification succeeds, gather:

```bash
git log <baseRefName>..HEAD --oneline
git diff <baseRefName>...HEAD --name-status
git diff <baseRefName>...HEAD
```

If the base branch is missing locally, fetch it first:

```bash
git fetch origin <baseRefName>
```

Classify diff context:

- **success:** commit log, name-status, and diff are available.
- **failure:** git reports a known missing ref or invalid range after fetch.
- **unknown:** diff is empty or inconsistent with `gh pr view` changed files.

Unknown diff context must stop subagent dispatch.

## Step 4: Project Reconnaissance

Build a bounded project summary before PR review.

Read:

- `README*`
- `AGENTS.md`, `CLAUDE.md`, or equivalent local agent instructions
- Root manifests and config files such as `pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `Makefile`, `Dockerfile`, `.github/**`
- Top-level directory map from `rg --files`
- Source directories relevant to changed files

Do not broadly read:

- `tests/**`
- `**/tests/**`
- generated assets, dependency folders, build outputs, caches

If the PR changes test files, list those test files separately as targeted review candidates. They may be assigned to a review unit when they are necessary to judge the PR.

Project Information must include:

```yaml
project_information:
  purpose: "<what the project does>"
  tech_stack: ["<runtime/framework/tooling>"]
  module_map:
    - path: "<directory>"
      responsibility: "<summary>"
  local_conventions:
    - "<instruction or pattern>"
  reconnaissance_boundary:
    broad_tests_read: false
    excluded_patterns:
      - "tests/**"
      - "**/tests/**"
    targeted_changed_tests:
      - "<path or empty>"
  degraded_mode: false
  degradation_reason: null
```

If this summary cannot be built reliably, mark `degraded_mode: true`, include `degradation_reason`, and pass that degraded context to subagents. Do not claim full project understanding.

## Step 5: PR Intent Reconstruction

Build PR Information and PR Intent from:

- PR title
- PR description/body
- Labels
- Commit messages
- Changed-file summary
- Diff shape

Output:

```yaml
pr_information:
  number: <number>
  url: "<url>"
  state: open | closed | merged | unknown
  base: "<baseRefName>"
  head: "<headRefName>"
  head_sha: "<headRefOid>"
  author: "<author>"
  commits:
    - "<short summary>"
  changed_files:
    - path: "<path>"
      status: added | modified | deleted | renamed | unknown

pr_intent:
  why: "<why this PR appears to exist>"
  expected_change: "<behavior/API/docs/tooling this PR changes>"
  out_of_scope:
    - "<known non-goal, or empty>"
  confidence: high | medium | low
```

If PR intent confidence is low because title/body/commits are empty or contradictory, ask the user for intent before dispatching subagents.

## Step 6: Review Unit Grouping

Group changed files into coherent review units. Prefer grouping by:

- Same module or feature area
- Producer/consumer relationship
- API contract and implementation
- Runtime code and its directly changed tests
- Migration/config and code depending on it
- Documentation and examples that describe the same behavior

Avoid:

- One review unit per file when files are clearly related
- One giant review unit when unrelated modules changed
- Separating changed tests from the code they validate unless they are context-only

Each review unit must include:

```yaml
review_unit:
  name: "<short name>"
  rationale: "<why these files belong together>"
  assigned_files:
    - "<path>"
  related_context_files:
    - "<path>"
  changed_tests:
    reviewed_for_findings:
      - "<path>"
    context_only:
      - "<path>"
  focus:
    - correctness
    - security_privacy
    - api_contract
    - maintainability
    - tests
```

## Step 7: Subagent Task Construction

For each review unit, construct a task for `agents/code-reviewer.md`.

Before dispatch, validate the task includes:

- Project Information
- PR Information
- PR Intent
- Assigned Review Unit
- Test Scope Boundary
- Output Requirements

If any required section is missing, classify the task as malformed and do not dispatch it.

The subagent prompt must include:

```markdown
## Project Information
...

## PR Information
...

## PR Intent
...

## Assigned Review Unit
...

## Test Scope Boundary
...

## Output Requirements
Use the schema in skills/code-review/reference/review-result-template.md.
Return findings only for assigned scope unless external context proves a concrete defect.
```

## Step 8: Consolidation

After all subagent results return:

1. Reject malformed outputs that do not follow `reference/review-result-template.md`.
2. Deduplicate findings that point to the same root cause.
3. Preserve severity from the strongest evidence, but downgrade overbroad claims.
4. Separate:
   - Findings recommended for PR comments
   - Findings to discuss with the user but not post yet
   - No-finding review units
   - Unknown or degraded review units
5. For each recommended comment, prepare a draft with path, candidate line, side, and body. Payload validation and posting rules are defined in the posting section of this skill.

Present the consolidated review to the user before any posting:

```markdown
## Review Summary
- Verdict: ready | ready_with_comments | needs_changes | blocked
- Review units completed: N
- Findings recommended for comments: N
- Unknown/degraded units: N

## Findings
1. [severity] path:line — title
   Why it matters: ...
   Suggested comment: ...

## Proposed Comment Payloads
...
```

Ask the user which findings, if any, should be posted.

## Step 9: Posting

Posting is only allowed after explicit user approval. Dry-run mode must never post.

See `reference/comment-payload-template.md` for the payload contract and validation rules.

Before posting, derive endpoint coordinates from PR metadata:

```yaml
comment_endpoint:
  owner: "<owner from PR URL or head/base repository metadata>"
  repo: "<repository name from PR URL or gh metadata>"
  pull_number: <number from gh pr view>
```

If owner, repo, or pull number cannot be determined unambiguously, mark posting outcome `unknown` and do not post.

### 9a. Dry-Run Behavior

If `dry_run: true`, stop at payload generation.

Dry-run output must include:

```yaml
dry_run: true
posting_executed: false
fixture_pr: "https://github.com/OWNER/REPO/pull/123" # when using evaluator fixture
proposed_payloads:
  - commit_id: "<headRefOid>"
    path: "<path>"
    line: <line>
    side: RIGHT | LEFT
    body: |
      <markdown body>
    validation:
      required_fields_present: true
      diff_line_verified: true
      source_finding: "<finding id>"
```

Do not run `gh api` in dry-run mode. If the user asks to post while dry-run is active, explain that dry-run has no side effects and ask them to rerun without `--dry-run` on an open PR.

### 9b. Payload Validation

Before showing payloads for approval, validate every proposed independent line comment:

Required fields:

- `commit_id` — PR head commit SHA, usually `headRefOid`
- `path` — file path in the PR diff
- `line` — new-file line number for `RIGHT`, or old-file line number for `LEFT`
- `side` — exactly `RIGHT` or `LEFT`
- `body` — markdown review comment body

Validation rules:

1. `commit_id` must equal the PR head SHA used for checkout verification.
2. `path` must appear in the PR changed files.
3. `line` must be tied to diff hunk evidence for `path`.
4. `side` must match the finding side:
   - `RIGHT` for new-side comments.
   - `LEFT` for old-side comments.
5. `body` must be non-empty markdown and must describe the concrete issue.
6. A payload with missing, null, or unknown `commit_id`, `path`, `line`, `side`, or `body` is invalid.

Invalid or unverified payloads must be shown under "Needs manual mapping" and must not be posted.

### 9c. User Approval Gate

After validation, present:

```markdown
## Validated Payloads
1. path:line side=RIGHT
   Body:
   ...

## Blocked Payloads
1. finding-id — missing/invalid field or unverified diff line
```

Ask the user exactly which validated payloads to post. Acceptable approvals:

- "post all validated"
- explicit payload IDs, such as "post P1 and P3"
- "do not post"

Do not infer approval from general agreement with the review summary. Approval must reference posting.

### 9d. Live Posting Command

For each approved payload, post an independent line comment from a JSON payload file. Do not inline markdown `body`, `path`, or other payload values into shell command arguments; review comments can contain quotes, backticks, or newlines.

Write a per-payload JSON file:

```json
{
  "body": "<markdown body>",
  "commit_id": "<head sha>",
  "path": "<file path>",
  "line": 123,
  "side": "RIGHT"
}
```

Then call:

```bash
gh api \
  --method POST \
  /repos/{owner}/{repo}/pulls/{pull_number}/comments \
  --input <payload-json-file>
```

Use the owner, repo, and pull number from the PR URL or `gh pr view` metadata. The PR URL pattern must be `https://github.com/{owner}/{repo}/pull/{number}`. If the URL and metadata disagree, stop with posting outcome `unknown`.

Post only approved payloads. Never post blocked payloads. Remove payload files after reporting posting results.

### 9e. Posting Results

Track each payload separately:

```yaml
posting_results:
  - payload_id: "P1"
    status: success | failure | unknown
    github_comment_url: "<url or null>"
    error: "<error or null>"
```

Status rules:

- **success:** `gh api` returns a created comment object or URL for the payload.
- **failure:** GitHub returns a known validation, auth, permission, or not-found error.
- **unknown:** command times out, output is truncated, the CLI exits ambiguously, network status is unclear, or only some approved payloads return results.

If any payload status is `unknown`, report it to the user and do not retry automatically. Blind retries can create duplicate comments.

## Error Handling

| Condition | Required behavior |
|---|---|
| Missing PR input | Ask user for PR URL or number |
| Not a git repository | Stop before running `gh pr view` |
| Missing origin remote | Stop and report missing remote |
| `gh` missing or unauthenticated | Stop and report setup action |
| Dirty worktree | Ask user before checkout; do not mutate unrelated changes |
| PR metadata missing required fields | Stop with metadata outcome `unknown` |
| Checkout HEAD does not match PR head SHA | Stop with checkout outcome `unknown` |
| Diff context inconsistent with PR metadata | Stop before subagent dispatch |
| Project reconnaissance incomplete | Mark degraded context; do not claim full understanding |
| Subagent task missing required sections | Treat as malformed; do not dispatch |
| Subagent output malformed | Exclude from findings and report unknown unit |
| Dry-run reaches posting phase | Output payloads only; never run `gh api` |
| Payload missing required fields | Block posting for that payload |
| Payload line mapping unverified | Block posting for that payload |
| `gh api` result ambiguous | Mark payload status `unknown`; do not retry blindly |

## Completion

The skill is complete when it has either:

- Produced a dry-run review package with project info, PR info, review groups, subagent tasks/results, consolidated findings, and proposed payloads; or
- Posted only user-approved independent line comments and reported per-payload success/failure/unknown states.
