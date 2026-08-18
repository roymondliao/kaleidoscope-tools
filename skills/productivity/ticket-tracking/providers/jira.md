# Jira Provider

Mechanics only. Content structure comes from [content-template.md](../references/content-template.md); type vocabulary comes from [type-mapping.md](../references/type-mapping.md).

## Tools

- Discover: `mcp__mcp-atlassian__jira_get_all_projects`, `jira_search`, `jira_get_project_issues`, `jira_get_sprint_issues`, `jira_get_board_issues`
- Read: `jira_get_issue`
- Write: `jira_create_issue`, `jira_update_issue`, `jira_batch_create_issues`
- Link: `jira_create_issue_link`, `jira_link_to_epic`
- Comment: `jira_add_comment`
- People: `jira_get_user_profile`, `confluence_search_user`
- Metadata: `jira_search_fields` (custom field IDs), `jira_get_project_versions`

There is no dedicated transition/status tool in this tool set. For status changes, follow [provider-routing.md](../references/provider-routing.md) rather than guessing a field name — read the issue's available transitions before writing.

## Hierarchy → `issue_type`

| Canonical tier | `issue_type` value | Extra field |
|---|---|---|
| Project/Epic | `Epic` | — |
| Issue/Task/Story (Parent) | `Story` or `Task` | — |
| Issue/Sub-task (Child) | `Subtask` | `additional_fields.parent` = parent issue key |

Jira enforces these as structurally distinct issue types (different field schemas), unlike Linear where parent/child are the same object. Confirm available types for the target project before assuming `Story` vs `Task` — project configuration varies.

## Assignee resolution

Jira Cloud requires an account ID (`XXXXXX:uuid`), not a name or email.

1. If the value already matches `XXXXXX:uuid`, use it as-is.
2. Otherwise resolve via `confluence_search_user` with `query: "user.fullname ~ \"<name-or-email>\""` and extract `account_id`.
3. If resolution fails, create the issue unassigned and tell the user — do not guess an account ID.

## Create + describe (two-step, required)

Passing `description` directly to `jira_create_issue` corrupts newlines — `* bullet` becomes `_ italic _`. Always split the write:

**Step 1 — create the skeleton, no description:**
```
mcp__mcp-atlassian__jira_create_issue
{
  "project_key": "<project_key>",
  "summary": "<title>",
  "issue_type": "<Epic|Story|Task|Subtask>",
  "assignee": "<account_id>",
  "components": "<component>",
  "additional_fields": {
    "labels": ["..."],
    "parent": "<parent_key>"   // only for Subtask
  }
}
```

**Step 2 — set the description via update, immediately after:**
```
mcp__mcp-atlassian__jira_update_issue
{
  "issue_key": "<returned_key>",
  "fields": { "description": "h3. Why\n\n* ...\n\nh3. What\n\n..." }
}
```
Passing description through `fields` (not the create call) preserves newlines and renders Jira wiki markup (`h3.`, `*`, `[ ]`) correctly. Convert the Markdown-shaped canonical template to Jira wiki markup at this step (`###`→`h3.`, unordered list `-`/`*` stays `*`).

## Comment

`jira_add_comment { "issue_key": "<key>", "comment": "<text>" }`

## Verify

`jira_get_issue { "issue_key": "<key>", "fields": "assignee,components,status" }` — confirm what was actually set before reporting success; assignee resolution failures in particular can silently leave the issue unassigned.
