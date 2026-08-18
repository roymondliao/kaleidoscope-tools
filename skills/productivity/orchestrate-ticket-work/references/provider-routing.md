# Provider Routing

Use this reference only when accessing or changing an external ticket system. Keep the orchestration workflow independent of provider-specific tool names.

## Identify the provider and ticket

Use an unambiguous reference:

- Linear: `linear:<team-key>-<number>`
- Jira: `jira:<project-key>-<number>`
- GitHub Issues: `github:<owner>/<repo>#<number>`
- Repository-local: `repo:<relative-task-path>`

Resolve team, project, repository, workflow state IDs, and user IDs through provider reads. Do not infer opaque identifiers from display names.

## Normalize provider operations

Map each provider to these canonical operations:

1. Read one exact ticket.
2. Read its parent, dependencies, and blockers.
3. Resolve available statuses and assignees.
4. Update one authorized field or relationship.
5. Read the ticket back and verify the mutation.

Use the provider's dedicated connector or MCP integration when available. If no suitable integration is installed, report the unavailable operation; do not scrape authenticated pages, invent ticket state, or silently substitute another tracker.

## Map lifecycle states

Create a project-specific mapping before the first mutation:

| Canonical state | Meaning                                      | Provider state |
| --------------- | -------------------------------------------- | -------------- |
| `planned`       | Defined but not ready to start               | `<map once>`   |
| `ready`         | Dependencies and task contract are satisfied | `<map once>`   |
| `in_progress`   | An owner is actively implementing            | `<map once>`   |
| `in_review`     | Implementation is complete and under review  | `<map once>`   |
| `completed`     | Review or merge policy is satisfied          | `<map once>`   |

Do not assume identically named states have identical semantics across teams. Preserve provider-specific states such as canceled or duplicate when they carry distinct meaning.

## Mutate safely

Before a write:

- confirm the exact ticket and workspace;
- confirm the requested state or assignee exists;
- summarize the intended mutation when authorization is ambiguous;
- avoid bulk changes unless the user explicitly requested them.

After a write, read back the ticket and confirm the canonical state, provider state, assignee, and dependency links. Report any partial or rejected mutation.
