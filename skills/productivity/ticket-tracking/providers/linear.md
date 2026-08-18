# Linear Provider

Mechanics only. Content structure comes from [content-template.md](../references/content-template.md); type vocabulary comes from [type-mapping.md](../references/type-mapping.md).

## Tools

Tool names below are as exposed by the connected Linear MCP server — portable across whichever coding agent is connected to it. Do not prefix them with a coding-agent-specific namespace in this file (e.g. Claude Code additionally wraps them as `mcp__<server-id>__<tool>`; other agents may wrap or expose them differently). Resolve the actual callable name from the active session's tool list before calling — Linear MCP server implementations vary more than Jira's does (see note below), so verify the write pattern (upsert vs. separate create/update) actually matches what's connected before assuming this section is exact.

- Discover: `list_teams`, `list_projects`, `list_issues`
- Read: `get_project`, `get_issue`
- Write (upsert — same call for create and update, on the server this was documented against): `save_project`, `save_issue`
- Comment: `save_comment` (write), `list_comments` (read)
- Status: `list_issue_statuses` (per team), `get_issue_status`
- Milestones: `list_milestones`, `get_milestone`, `save_milestone`
- People: `list_users`, `get_user`

`save_issue` and `save_project` are upserts on this server: omit `id` to create, pass an existing `id` to update. If the connected server instead exposes separate `create_issue`/`update_issue` tools, use those the same way — the upsert-vs-split-call choice is a per-server API design decision, not part of the canonical model this skill assumes.

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
save_project
{
  "name": "<title>",
  "teamIds": ["<team-id>"],
  "description": "<canonical Project/Epic template, Markdown>",
  "leadId": "<user-id>"        // optional
}
```

## Create issue / sub-issue

```
save_issue
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
