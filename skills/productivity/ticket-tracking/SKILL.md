---
name: ticket-tracking
description: This skill should be used for any Jira or Linear ticket-tracking work: creating or updating a project/epic, issue, or sub-issue; changing an issue's status or adding a comment; coordinating, sequencing, delegating, or reviewing ticket-driven implementation work across a main agent and assigned agents; or executing one explicitly assigned ticket within bounded scope. Triggers include "create a Jira issue", "open a Linear issue", "add a sub-task", "create an epic/project", "update the description of <ticket>", "move <ticket> to in progress", "comment on <ticket>", "go implement <ticket>", "delegate this ticket to an agent", "what's next in the backlog", "I was assigned <ticket>, implement it".
user-invocable: true
---

# Ticket Tracking

One skill, three modes, over Jira and Linear through a platform-agnostic content and lifecycle model.

## Which mode applies

1. **Orchestrate** — coordinating, sequencing, delegating, reviewing, or advancing ticket-driven work across a main agent and assigned agents → follow [references/orchestrate.md](references/orchestrate.md) and stop reading here.
2. **Execute-assigned** — this agent received one explicitly assigned ticket (ID, bounded scope, acceptance criteria) from a coordinating agent → follow [references/execute-assigned.md](references/execute-assigned.md) and stop reading here.
3. **Author** — creating/updating a project/epic, issue, or sub-issue; changing status as a one-off; or posting a comment, with no coordinating agent involved → continue below.

Orchestrate and execute-assigned already receive a provider-qualified ticket reference (e.g. `jira:ABC-123`) as part of their input, so they don't need the platform-resolution steps below — those exist because Author mode is the one place a request can arrive with no platform specified at all (e.g. "create an issue for X").

## Author mode

### Step 0: Load or set up config

Config lives outside this plugin's own source tree — it's user-installed state, not something this repo ships. Check, in order:

1. `${CLAUDE_PROJECT_DIR}/.claude/plugin-data/kaleidoscope-tools/ticket-tracking/config.json` (project override)
2. `${CLAUDE_PLUGIN_DATA}/ticket-tracking/config.json` (global)

Use the first one that exists — **whole file, not merged** with the other. If neither exists, run [references/setup-flow.md](references/setup-flow.md) before doing anything else.

Whichever file is used, validate it every time, even if it already existed:
```
uv run python ${CLAUDE_PLUGIN_ROOT}/skills/productivity/ticket-tracking/scripts/validate_config.py <path>
```
If validation fails, tell the user what's wrong (from the script's stderr output) and offer to re-run setup — don't try to silently patch a broken config.

### Step 1: Resolve which platform

- Exactly one platform `enabled: true` → use it, no question asked.
- Multiple enabled and the request names one explicitly (e.g. "in Jira", "on Linear") → use that one.
- Multiple enabled and the request doesn't specify → ask via AskUserQuestion, using each platform's `label` from config as the option text (pre-select `default_platform` if set). Do not silently guess — picking the wrong tracker for a ticket is visible to whoever else has access to it and isn't a quiet thing to undo.

### Step 2: Resolve the canonical tier

Map the request to one of three tiers — see [references/type-mapping.md](references/type-mapping.md) for the full platform mapping and why it isn't 1:1:

| User says | Tier |
|---|---|
| "epic", "project", "initiative-level thing" | Project/Epic |
| "issue", "story", "task" (no mention of a parent) | Issue/Task/Story (Parent) |
| "sub-issue", "sub-task", "a step under X" | Issue/Sub-task (Child) |

If ambiguous (e.g. "create a ticket for X" with no tier signal and no parent context), ask rather than default to one tier.

### Step 3: Resolve the domain and draft content

Pick the content domain (`engineering-delivery`, `learning-topic`, or another established one) per [references/content-template.md](references/content-template.md). Infer it from context when obvious (repo-relative paths and code in the request → `engineering-delivery`; a book/paper/course reference with no repo → `learning-topic`); ask when it isn't.

Draft the description using the template for the resolved tier + domain. The Project/Epic tier's template is fixed regardless of domain. When the created issue is going to be handed to Orchestrate mode for delegation, also satisfy [references/ticket-contract.md](references/ticket-contract.md)'s required fields (Dependencies, Ownership, Risks) — content-template.md covers what to write when authoring; ticket-contract.md is the readiness bar for delegating.

**Always show the draft to the user and get explicit approval before writing anything** (use AskUserQuestion: approve / needs changes / cancel). This applies to every operation below, not just creation — including status changes and comments, since all of them are visible, not-quietly-reversible actions on a system other people may also see. This approval gate is the safety boundary for this skill now that it can be triggered automatically by the model rather than only by explicit user invocation — do not treat model-auto-trigger as license to skip it.

### Step 4: Execute via the provider

Once approved, hand off to the platform-specific mechanics:

- Jira → [providers/jira.md](providers/jira.md)
- Linear → [providers/linear.md](providers/linear.md)

Each covers: tool names, the tier → platform-object mapping, assignee/user resolution, comment posting, and (Jira only) the two-step create-then-describe write required to avoid the wiki-markup newline bug.

#### The five author operations

1. **Create/update project or epic** — Project/Epic tier, fixed template. Update = re-draft the changed sections only, show a diff-shaped summary of what's changing before writing.
2. **Create/update issue** — Issue/Task/Story (Parent) tier, domain template.
3. **Create/update sub-issue** — Issue/Sub-task (Child) tier, domain template. Requires an identified parent (ask for it if not given — don't guess which open issue is the parent).
4. **Change issue status** — a single ad-hoc move. Resolve the target state through the provider's status mechanism (Jira: no dedicated transition tool in this skill's toolset, follow [references/provider-routing.md](references/provider-routing.md); Linear: `list_issue_statuses` then `save_issue` with `stateId`). For sequencing work through a full lifecycle, that's Orchestrate mode, not this.
5. **Update comment** — draft the comment text, get approval, post via the provider's comment tool.

### Step 5: Verify and report

After every write, read the object back (`jira_get_issue` / Linear `get_issue`) and confirm the fields that were supposed to change actually did — especially assignee, since resolution can fail silently and leave a ticket unassigned. Report the ticket key/URL and what was actually set, flagging anything that didn't take.

## Resources

Mode entry points:
- [references/orchestrate.md](references/orchestrate.md) — coordinating agent: select, sequence, delegate, review
- [references/execute-assigned.md](references/execute-assigned.md) — assigned agent: implement one bounded ticket

Shared by Orchestrate and Execute-assigned:
- [references/delegation-contract.md](references/delegation-contract.md) — required fields for handing off one ticket
- [references/ticket-contract.md](references/ticket-contract.md) — what makes a ticket ready to delegate
- [references/context-loading.md](references/context-loading.md) — what to read before implementing
- [references/execution-report.md](references/execution-report.md) — completion/blockage report format
- [references/provider-routing.md](references/provider-routing.md) — canonical lifecycle state ↔ provider state mapping

Author mode:
- [references/setup-flow.md](references/setup-flow.md) — first-run config setup (AskUserQuestion sequence, file paths, required validation)
- [references/type-mapping.md](references/type-mapping.md) — canonical tier vocabulary and platform mapping
- [references/content-template.md](references/content-template.md) — section structure per tier and domain
- [scripts/validate_config.py](scripts/validate_config.py) — config validator (`uv run python`, stdlib only)

Providers (all modes, wherever a tracker read/write is needed):
- [providers/jira.md](providers/jira.md) — Jira mechanics
- [providers/linear.md](providers/linear.md) — Linear mechanics
