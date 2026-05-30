# Fixture Verification: Code Review Skill

Date: 2026-05-30

Fixture:

```text
https://github.com/OWNER/REPO/pull/123
```

Command:

```bash
gh pr view https://github.com/OWNER/REPO/pull/123 --json number,url,title,body,state,baseRefName,headRefName,headRefOid,commits,files,labels,author
```

Result: success | failure | unknown.

Verified fields:

```yaml
number: 123
url: "https://github.com/OWNER/REPO/pull/123"
title: "<fixture-title>"
state: "MERGED"
baseRefName: "<base-branch>"
headRefName: "<fixture-head-branch>"
headRefOid: "<fixture-head-sha>"
author: "<fixture-author>"
commit_count: "<count>"
changed_file_count: "<count>"
```

Changed files returned by `gh pr view`:

- `<changed-file-1>`
- `<changed-file-2>`
- `<changed-file-3>`

Evaluator implication:

- The fixture access state is explicitly recorded.
- The required metadata fields for the code-review skill are checked.
- If the PR is closed or merged, evaluator runs must remain dry-run and must not attempt posting.
