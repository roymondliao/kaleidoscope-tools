# Ticket Contract

Use this contract to keep tickets concise, provider-neutral context routers. Store durable design and detailed implementation decisions in the repository.

## Required fields

Every executable ticket must contain:

- **ID and title**: stable provider identifier and outcome-oriented title.
- **Goal**: one observable result.
- **Scope**: included behavior, files, or modules.
- **Out of scope**: adjacent work explicitly excluded.
- **Repository references**: repository-relative paths plus relevant headings or symbols.
- **Dependencies**: ticket IDs and the repository evidence expected from each dependency.
- **Acceptance criteria**: finite, testable conditions.
- **Validation**: exact commands or review procedures.
- **Ownership**: expected owner and any shared-file constraints.
- **Risks or decisions**: unresolved items that can change implementation.

## Ticket template

```markdown
## Goal

<One observable outcome>

## Repository context

- Phase: `changes/<phase>/README.md`
- Design: `docs/<document>.md#<section>`
- Task: `changes/<phase>/tasks/<task>.md`
- Relevant code: `<repo-relative path or symbol>`

## Scope

- <Included work>

## Out of scope

- <Excluded work>

## Dependencies

- <ticket ID>: <required repository evidence>

## Acceptance criteria

- [ ] <Observable and testable condition>

## Validation

- `<exact command or review procedure>`

## Ownership and coordination

- Owner: <person or agent role>
- Shared files: <paths and sequencing rule, or none>

## Risks, decisions, or blockers

- <Open item and decision owner, or none>
```

## Privacy boundary

Include only information appropriate for the ticket provider and repository collaborators. Use symbolic environment names and repository-relative paths.

Do not include:

- access tokens, cookies, credentials, or private keys;
- Cloudflare account IDs, database IDs, Access audience values, or secrets;
- customer data, personal data, or raw production records;
- local absolute paths, private hostnames, or copied secret-bearing logs.

Refer to the approved secret store or configuration key name without copying its value.

## Quality check

A ticket is ready only if a new agent can identify what to read, what to change, what not to change, how to prove completion, and who decides unresolved questions without searching the backlog for missing context.
