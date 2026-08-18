# Execute-Assigned Mode

For an agent or sub-agent that received one explicitly assigned ticket — a ticket ID, bounded scope, repository references, ownership boundaries, acceptance criteria, and validation requirements from a coordinating agent (see [orchestrate.md](orchestrate.md) and [delegation-contract.md](delegation-contract.md)). Supports Linear, Jira, GitHub Issues, and repository-local task specifications while preserving main-agent control of sequencing and ticket state.

Work on the assigned ticket only. Do not select another ticket, expand the phase, or infer permission to manage the backlog.

## Load the assignment

1. Confirm the ticket identifier, task goal, owned files or modules, excluded scope, acceptance criteria, and required validation.
2. Read the external ticket when access is provided, but do not mutate its status, assignment, or content unless that authority is explicit.
3. Load repository context according to [context-loading.md](context-loading.md).
4. Inspect the current Git state and existing implementation before editing. Preserve unrelated and user-owned changes.

If the external provider is unavailable, use repository specifications only when they provide an unambiguous task contract. Report that the ticket could not be read rather than inventing missing details.

## Reconcile the sources

Apply repository execution constraints first, followed by accepted design, phase decisions, the assigned task specification, and then ticket coordination metadata.

If a ticket conflicts with repository design or current code:

1. Capture the exact conflicting statements and paths.
2. Inspect nearby implementation and relevant history when available.
3. Report the evidence to the coordinating agent.
4. Pause only the affected work until a decision is made.

Do not resolve a material conflict through an undocumented assumption.

## Implement within ownership

- Modify only the assigned files or modules and the smallest necessary supporting surface.
- Ask the coordinating agent to sequence changes to shared files when another assignment may overlap.
- Follow existing architecture and naming unless the ticket explicitly changes them.
- Keep provider-specific IDs, secrets, and environment values out of source and ticket prose.
- Record any necessary deviation from the task contract before relying on it.

Complete each acceptance criterion with observable evidence. Avoid unrelated cleanup, opportunistic refactors, and new dependencies that are not required by the assignment.

## Validate the result

Run the assignment's exact validation commands and all repository-mandated checks applicable to the changed surface. If a check cannot run, capture the command, failure, cause, and impact; do not substitute an unapproved command that bypasses repository instructions.

Review the final diff for:

- scope and ownership compliance;
- accidental changes or generated noise;
- test coverage for changed behavior;
- consistency with design and adjacent tasks;
- secrets or environment-specific identifiers.

## Report completion or blockage

Format the handoff with [execution-report.md](execution-report.md). Provide evidence, not only a completion claim.

Do not mark the ticket completed, commit, push, or start another ticket unless the coordinating agent explicitly granted that authority. A successful execution ends when all assigned acceptance criteria are evidenced and the report is delivered. A blocked execution ends when the exact blocker, completed work, remaining work, and required decision are reported.
