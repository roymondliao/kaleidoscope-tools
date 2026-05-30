# Independent Line Comment Payload Template

The code-review skill posts v1 review feedback as independent GitHub PR line comments only after user approval.

Endpoint:

```text
POST /repos/{owner}/{repo}/pulls/{pull_number}/comments
```

Endpoint coordinates must be derived from PR metadata:

```yaml
owner: "<owner>"
repo: "<repo>"
pull_number: <number>
```

The PR URL pattern must be `https://github.com/{owner}/{repo}/pull/{number}`. If URL parsing and `gh pr view` metadata disagree, do not post.

## Payload Shape

```yaml
payload_id: "P1"
commit_id: "<pr-head-sha>"
path: "<file path in PR diff>"
line: <new-or-old-file-line-number>
side: RIGHT | LEFT
body: |
  <markdown review comment>
source:
  finding_id: "F1"
  review_unit: "<unit name>"
  evidence: "<diff hunk or path:line evidence>"
validation:
  required_fields_present: true
  commit_matches_pr_head: true
  path_in_changed_files: true
  diff_line_verified: true
  side_verified: true
```

## Required Fields

- `commit_id`: PR head commit SHA.
- `path`: File path exactly as it appears in the PR diff.
- `line`: Line number on the selected side.
- `side`: `RIGHT` for the new side, `LEFT` for the old side.
- `body`: Markdown comment body.

Any missing required field blocks posting.

## Validation Checklist

Before user approval:

- `commit_id` equals the PR `headRefOid` used for checkout verification.
- `path` appears in the PR changed-file list.
- `line` is present in a diff hunk for that path.
- `side` is exactly `RIGHT` or `LEFT`.
- `body` is non-empty and describes a concrete, evidence-backed issue.
- `source.finding_id` points back to a consolidated finding.

## Dry-Run Rule

In dry-run mode, payloads are generated but never posted.

Dry-run output must say:

```yaml
dry_run: true
posting_executed: false
```

## Posting Command

```bash
gh api \
  --method POST \
  /repos/{owner}/{repo}/pulls/{pull_number}/comments \
  -f body='<markdown body>' \
  -f commit_id='<pr-head-sha>' \
  -f path='<file path>' \
  -F line=<line> \
  -f side='<RIGHT-or-LEFT>'
```

## Result States

```yaml
posting_result:
  payload_id: "P1"
  status: success | failure | unknown
  github_comment_url: "<url or null>"
  error: "<error or null>"
```

- `success`: GitHub returns the created comment.
- `failure`: GitHub returns a clear validation, auth, permission, or not-found error.
- `unknown`: timeout, ambiguous CLI output, truncated output, network uncertainty, or partial batch result.

Unknown results must be reported. Do not retry automatically.
