# Evaluator: Code Review Skill

## Primary Evaluator

Run a dry-run review against this closed PR fixture:

```text
https://github.com/OWNER/REPO/pull/123
```

The evaluator validates the review pipeline and proposed comment payloads. It must not validate live GitHub posting.

Fixture metadata should be verified with:

```bash
gh pr view https://github.com/OWNER/REPO/pull/123 --json number,url,title,body,state,baseRefName,headRefName,headRefOid,commits,files,labels,author
```

Do not commit private repository names, private PR URLs, private branch names, author names, or real head SHAs. Record sanitized evidence in `fixture-verification.md`.

## Invocation

From a local checkout of the target repository, invoke:

```text
/code-review https://github.com/OWNER/REPO/pull/123 --dry-run
```

If the PR branch cannot be checked out because the PR is closed or the source branch is unavailable, the evaluator may use `gh pr view` metadata and diff inspection as far as GitHub allows. The checkout state must be marked `failure` or `unknown`; it must not be presented as a successful checkout.

## Required Evidence

Before running the fixture review, verify the local artifacts:

```bash
scripts/verify-code-review-artifacts.sh
```

The dry-run output must include all of these sections:

- Project Information
  - Project purpose
  - Tech stack
  - Module/folder map
  - Local conventions
  - Reconnaissance boundary showing broad `tests/` reading was skipped
  - Any degraded mode marker and reason
- PR Information
  - PR URL and number
  - State
  - Base and head refs
  - Head SHA when available
  - Commit summary
  - Changed-file summary
- PR Intent
  - Why the PR appears to exist
  - Expected change
  - Confidence level
- Review Units
  - Group name
  - Grouping rationale
  - Assigned files
  - Changed test handling
  - Review focus
- Subagent Task Prompt Evidence
  - At least one task for `agents/code-reviewer.md`
  - The task must include Project Information, PR Information, PR Intent, Assigned Review Unit, Test Scope Boundary, and Output Requirements
- Consolidated Results
  - Findings, or an explicit no-findings result
  - Unknown or degraded review units, if any
  - Verdict
- Proposed Independent Line Comment Payloads
  - `commit_id`
  - `path`
  - `line`
  - `side`
  - markdown `body`
  - validation status for required fields and diff-line mapping
- Dry-run Proof
  - `dry_run: true`
  - `posting_executed: false`

## Pass Signal

The evaluator passes when:

- `scripts/verify-code-review-artifacts.sh` passes.
- The workflow inspects the fixture PR metadata, commits, changed files, and diff as far as the closed PR allows.
- The output includes project information, PR information, PR intent, changed-file review groups, and at least one well-formed subagent task prompt.
- The output includes consolidated findings or an explicit no-findings result.
- Every proposed payload has `commit_id`, `path`, `line`, `side`, and markdown `body`, or is explicitly blocked with a reason.
- The output proves no `gh api POST /repos/{owner}/{repo}/pulls/{pull_number}/comments` command was executed.

## Fail Signal

The evaluator fails when:

- The workflow skips project reconnaissance.
- The workflow reviews changed files without PR intent.
- The workflow dispatches a subagent task missing Project Information, PR Information, PR Intent, Assigned Review Unit, Test Scope Boundary, or Output Requirements.
- The workflow claims checkout success without matching local HEAD to the PR head SHA.
- The workflow proposes a postable payload missing `commit_id`, `path`, `line`, `side`, or `body`.
- The workflow attempts to post comments during dry-run.

## Out of Scope

- Actual GitHub comment creation.
- GitHub UI rendering of posted comments.
- Approval, request-changes, merge, or close behavior.
- Whether the original human reviewers would agree with every generated finding.
