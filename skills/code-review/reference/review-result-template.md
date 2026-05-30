# Code Review Result Template

Subagents should return this structure for each assigned review unit.

```yaml
status: success | failure | unknown | malformed_input
review_unit: "<name>"
degraded_context: false
missing_context: []
reviewed_scope:
  files:
    - "<path>"
  test_scope: "not reviewed | context only | targeted review"
verdict: ready | ready_with_comments | needs_changes | blocked
findings:
  - id: "F1"
    severity: critical | high | medium | low
    path: "<file path>"
    line: null
    side: RIGHT | LEFT | null
    title: "<short title>"
    evidence: "<path:line or diff hunk reference>"
    problem: "<what is wrong>"
    why_it_matters: "<impact on PR intent or project behavior>"
    recommendation: "<specific fix or investigation>"
    suggested_comment: |
      <markdown body suitable for a PR review comment>
    confidence: high | medium | low
summary: |
  <brief review summary>
```

## Status Rules

- `success`: The assigned unit was reviewed and the result is evidence-backed.
- `failure`: The assigned files or required diff context could not be read for a known reason.
- `unknown`: The reviewer lacks enough context to judge the unit reliably.
- `malformed_input`: The task omitted required Project Information, PR Information, PR Intent, Assigned Review Unit, Test Scope Boundary, or Output Requirements.

## Finding Rules

- Each finding must cite concrete evidence.
- Each finding must explain why it matters to the PR intent or project behavior.
- `line` should be a new-file line number when known. Use `null` if the reviewer cannot verify a valid diff line.
- `side` should be `RIGHT` for new-side comments, `LEFT` for old-side comments, or `null` when unknown.
- Suggested comments must be concise, specific, and suitable for a public PR review comment.

## Consolidation Notes

The main skill should reject or re-check any finding that:

- Has no concrete evidence.
- Has `line: null` but is selected for posting without later diff-line validation.
- Uses severity that does not match the stated impact.
- Repeats the same root cause as another finding.
