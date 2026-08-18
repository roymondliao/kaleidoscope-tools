# Linear Provider

Mechanics only. Content structure comes from [content-template.md](../references/content-template.md); type vocabulary comes from [type-mapping.md](../references/type-mapping.md).

## Tools

- Discover: `mcp__claude_ai_Linear__list_teams`, `list_projects`, `list_issues`
- Read: `get_project`, `get_issue`
- Write (upsert — same call for create and update): `save_project`, `save_issue`
- Comment: `save_comment` (write), `list_comments` (read)
- Status: `list_issue_statuses` (per team), `get_issue_status`
- Milestones: `list_milestones`, `get_milestone`, `save_milestone`
- People: `list_users`, `get_user`

`save_issue` and `save_project` are upserts: omit `id` to create, pass an existing `id` to update. There is no separate `create_issue`/`update_issue` pair — do not look for one.

## Hierarchy → object model

| Canonical tier | Linear object |
|---|---|
| Project/Epic | **Project** (`save_project`) |
| Issue/Task/Story (Parent) | **Issue** with no `parentId` (`save_issue`) |
| Issue/Sub-task (Child) | **Issue** with `parentId` set to the parent issue's ID (`save_issue`) |

Unlike Jira, parent and child issues are the *same object type* — a sub-issue is just an issue with `parentId` populated, not a distinct schema. Don't ask for or expect an "issue type" field the way Jira has one; the only structural signal is `parentId`.

## Status

Statuses are per-team, not global. Call `list_issue_statuses { team: "<team>" }` to get the workflow state IDs before writing — do not assume state names match across teams. Set status via `save_issue { id: "<issue-id>", stateId: "<state-id>" }`.

## Assignee / user resolution

`list_users { query: "<name-or-email>" }` or `get_user`, then pass the returned user ID as `assigneeId` on `save_issue`. If resolution fails, create/update unassigned and tell the user.

## Create project

```
mcp__claude_ai_Linear__save_project
{
  "name": "<title>",
  "teamIds": ["<team-id>"],
  "description": "<canonical Project/Epic template, Markdown>",
  "leadId": "<user-id>"        // optional
}
```

## Create issue / sub-issue

```
mcp__claude_ai_Linear__save_issue
{
  "title": "<title>",
  "teamId": "<team-id>",
  "projectId": "<project-id>",
  "description": "<canonical template for the tier + domain, Markdown>",
  "parentId": "<parent-issue-id>",   // omit for Parent tier, set for Child tier
  "assigneeId": "<user-id>",
  "labelIds": ["..."]
}
```

Markdown passes through as-is — Linear renders standard Markdown natively, so no format conversion step is needed (unlike Jira's wiki-markup conversion).

## Comment

`save_comment { issueId: "<id>", body: "<text>" }`

## Verify

`get_issue { id: "<id>" }` — confirm status, assignee, and `parentId` before reporting success.
