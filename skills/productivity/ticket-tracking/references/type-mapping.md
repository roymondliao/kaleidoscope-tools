# Type Mapping

Canonical vocabulary this skill uses internally, and what it means on each platform.

| Canonical tier | Jira | Linear |
|---|---|---|
| Project/Epic | Epic (`issue_type: Epic`) | Project |
| Issue/Task/Story (Parent) | Story or Task | Issue with no `parentId` |
| Issue/Sub-task (Child) | Subtask (`issue_type: Subtask` + `parent`) | Issue with `parentId` set |

## Why this isn't a 1:1 structural mapping

Jira represents these three tiers as three structurally distinct issue types with different field schemas. Linear represents only two object types total: **Project** (a container, not an issue) and **Issue** (which can optionally have a `parentId`). A Linear "sub-issue" is not a different kind of thing — it's an Issue like any other, distinguished only by having a parent.

Practical consequence: when asked to "create a sub-issue," the Jira adapter must set `issue_type: Subtask`; the Linear adapter just calls the same `save_issue` it would use for a Parent-tier issue, adding `parentId`. Don't design the dispatch logic around a shared "type" parameter — dispatch on canonical tier, and let each provider file ([jira.md](../providers/jira.md), [linear.md](../providers/linear.md)) decide what that tier means mechanically.

## Depth limit

Neither provider is used here beyond three tiers (Project/Epic → Parent → Child). If a request implies a fourth level (a sub-issue of a sub-issue), flag it — Jira doesn't support nested subtasks, and while Linear's `parentId` chain isn't technically bounded, going past three tiers breaks the canonical model this skill assumes. Ask the user to fold the extra level into the Child tier's content instead of creating it.

## Content template selection

Which content-template applies to a tier is a separate decision from the tier itself — see [content-template.md](content-template.md). The Project/Epic tier always uses one fixed template regardless of domain. The Parent and Child tiers each select a domain-specific template (e.g. `engineering-delivery` vs `learning-topic`); the two tiers are not required to use the same domain template as each other, though in practice they usually match because they describe the same body of work.
