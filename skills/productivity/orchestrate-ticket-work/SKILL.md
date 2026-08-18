---
name: orchestrate-ticket-work
description: Coordinate ticket-driven implementation across a main agent and assigned agents. Use when selecting, sequencing, assigning, reviewing, or advancing work tracked in Linear, Jira, GitHub Issues, or repository-local change specifications; when preparing a self-contained delegation brief; or when reconciling ticket state with repository evidence. Keep provider-specific operations behind a normalized workflow.
---

# Orchestrate Ticket Work

Treat the ticket as a context router and coordination record, not as the sole source of truth. Keep design decisions and executable specifications in the repository.

## Establish the working contract

1. Identify the exact ticket and provider. Do not ask an agent to discover and choose its own next ticket.
2. Read the ticket, its parent or phase, dependencies, acceptance criteria, and linked repository paths.
3. Inspect the referenced repository content and current Git state before deciding that work is ready.
4. Apply repository instructions such as `AGENTS.md` before any ticket-specific instructions.
5. Normalize the ticket against [references/ticket-contract.md](references/ticket-contract.md) when creating, editing, or validating ticket content.

Use repository-relative paths in tickets. Keep credentials, tokens, personal data, production identifiers, and other secrets out of the tracker.

## Resolve authority and conflicts

Use this precedence for implementation decisions:

1. Repository execution constraints such as `AGENTS.md`
2. Accepted architecture, schema, and product design in `docs/`
3. Phase-level design and decisions in `changes/<phase>/`
4. The assigned task specification in `changes/<phase>/tasks/`
5. The external ticket's coordination metadata
6. Explicitly recorded assumptions

Treat the ticket system as authoritative for live status, assignment, and dependency coordination. Treat the repository as authoritative for versioned design and implementation details.

If two sources conflict, investigate the current code and history, report the conflict, and pause only the affected work. Do not silently choose one interpretation or rewrite an accepted decision.

## Select and sequence work

Move a ticket into active work only when all of these conditions hold:

- Its dependencies are complete in both tracker state and repository evidence.
- Its acceptance criteria are testable.
- Its referenced files exist or their planned creation is explicit.
- Its file ownership does not overlap unsafe concurrent work.
- The assigned agent has a bounded task and validation contract.

Use the normalized lifecycle `planned → ready → in_progress → in_review → completed`. Map it to the provider's actual states as described in [references/provider-routing.md](references/provider-routing.md) whenever reading or mutating an external tracker.

Mark a ticket blocked only when a concrete dependency, unresolved contradiction, missing authority, or unavailable required system prevents meaningful progress. Record the blocker and the condition that would unblock it.

## Delegate one bounded assignment

Before delegating, read [references/delegation-contract.md](references/delegation-contract.md) and provide every required field. Include the ticket identifier and essential context directly; do not send only a ticket link or tell the agent to find the next available task.

Assign explicit ownership for files or modules. Reserve shared files for one agent at a time, or sequence work that must touch them. State whether the agent may:

- read the tracker;
- edit repository files;
- run validation;
- update status or assignment;
- commit or push changes.

Default to main-agent ownership of tracker mutations, sequencing, commits, and completion decisions unless the assignment explicitly delegates one of those actions.

## Review and advance the ticket

Review repository evidence, not only the agent's summary:

1. Inspect the diff and confirm it remains within assigned ownership.
2. Verify every acceptance criterion against code, tests, or generated artifacts.
3. Run or verify the required validation commands.
4. Check for conflicts with accepted design and adjacent tasks.
5. Record remaining risks, assumptions, or follow-up work.

Move work to `in_review` only when implementation and required validation are complete. Move it to `completed` only after the defined review or merge policy is satisfied and the corresponding repository change is committed as required by the project workflow.

When changing external state, resolve the exact ticket first, perform only the authorized mutation, then read it back to confirm status, assignee, and links. If the provider is unavailable, continue only from repository specifications that are sufficient for the assigned work, and report that tracker state could not be updated.

## Completion criteria

Finish orchestration only when:

- the ticket and dependencies were resolved;
- an explicit owner and scope were established;
- implementation evidence was reviewed;
- acceptance criteria and validation results were accounted for;
- tracker and repository state agree, or any mismatch is reported;
- the ticket is left in the correct lifecycle state.
