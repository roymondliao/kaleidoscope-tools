# Jira Provider

Mechanics only. Content structure comes from [content-template.md](../references/content-template.md); type vocabulary comes from [type-mapping.md](../references/type-mapping.md).

## Tools

Tool names below are as exposed by the `mcp-atlassian` MCP server itself — portable across whichever coding agent is connected to it. Do not prefix them with a coding-agent-specific namespace in this file (e.g. Claude Code additionally wraps them as `mcp__mcp-atlassian__<tool>`; other agents may wrap or expose them differently). Resolve the actual callable name from the active session's tool list before calling.

- Discover: `jira_get_all_projects`, `jira_search`, `jira_get_project_issues`, `jira_get_sprint_issues`, `jira_get_board_issues`
- Read: `jira_get_issue`
- Write: `jira_create_issue`, `jira_update_issue`, `jira_batch_create_issues`
- Status: `jira_get_transitions` (list what an issue can move to), `jira_transition_issue` (perform the move)
- Link: `jira_create_issue_link`, `jira_link_to_epic`
- Comment: `jira_add_comment`
- People: `jira_get_user_profile`, `confluence_search_user`
- Metadata: `jira_search_fields` (custom field IDs), `jira_get_project_versions`

All names above are confirmed against the `mcp-atlassian` project's own tools reference. The `jira_transition_issue`/`jira_get_transitions` parameter shapes are not independently confirmed here (the reference used didn't document field-level detail) — read the tool's own schema from the connected session before calling rather than trusting a hardcoded field name, and read available transitions via `jira_get_transitions` first since valid target states are workflow-specific per project.

## Status change

1. `jira_get_transitions { "issue_key": "<key>" }` — get the set of transitions actually available from the issue's current state (Jira workflows are directed graphs; not every status is reachable from every other status).
2. Match the user's requested target status to one of the returned transitions by name — if none matches, tell the user which transitions are actually available rather than guessing.
3. `jira_transition_issue` with the matched transition — confirm the exact parameter name from the tool's schema at call time.
4. Verify via `jira_get_issue` that `status` changed to the expected value.

For sequencing a ticket through multiple lifecycle states as part of coordinated work (not a single ad-hoc move), see [orchestrate.md](../references/orchestrate.md) and the canonical-state mapping in [provider-routing.md](../references/provider-routing.md).

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
jira_create_issue
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
jira_update_issue
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
