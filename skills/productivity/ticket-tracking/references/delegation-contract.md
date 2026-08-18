# Delegation Contract

Use this template to assign one bounded ticket to an implementation or review agent. Fill every field; write `none` only after checking that the field does not apply.

```markdown
Ticket: <provider-qualified ID>
Role: <implementation | review | investigation>
Goal: <one observable outcome>

Required reading:

- <repository instruction file>
- <phase and task specification>
- <accepted design sections>
- <relevant implementation paths>

Dependencies and evidence:

- <dependency ID>: <verified repository evidence>

Current repository state:

- Branch/worktree: <state>
- Existing relevant changes: <state>

Ownership:

- You may modify: <files or modules>
- Shared files and sequencing: <rule or none>
- Do not modify: <files, modules, or adjacent tasks>

Acceptance criteria:

- <observable criterion>

Validation:

- <exact command or review procedure>

Authority:

- Tracker reads: <allowed or not allowed>
- Tracker writes: <specific allowed mutations or none>
- Commit/push: <allowed or not allowed>
- Starting other tickets: not allowed unless explicitly reassigned

Escalate when:

- <conflict, missing decision, overlap, or unsafe condition>

Expected report:

- changed files and behavior;
- acceptance-criterion evidence;
- validation commands and results;
- assumptions, risks, blockers, and remaining work.
```

The coordinating agent must provide the ticket identity and required context. The assigned agent may fetch the named ticket and linked material, but must not browse the backlog to choose different work.
