# Stage 4 — Arbitration & Dossier Template

> Written by: Arbiter agent only. This is the final output of the deliberation.

## Required Frontmatter

```yaml
---
stage: 4
type: arbitration
agent: arbiter
decision_id: "{decision_id}"
timestamp: "{run scripts/timestamp.sh}"
consensus_type: "{strong | weak | provisional}"
ruling: "{accept | reject | revise | investigate}"
---
```

## Required Sections

### Ruling
One of: `accept` | `reject` | `revise` | `investigate`

### Rationale
Explain the reasoning behind the ruling. Reference specific arguments from the critics that survived cross-examination. Explain WHY each surviving argument matters.

### Winning Case
Which critic's position (or synthesis of positions) forms the basis of the ruling? Cite specific surviving arguments and explain what made them survive.

### Belief Changes Summary
| Agent | Stage 1 Position | Stage 3 Position | Changed? |
|-------|-----------------|-------------------|----------|
| analytical-critic | {pos} | {pos} | {yes/no} |
| risk-critic | {pos} | {pos} | {yes/no} |
| pragmatic-critic | {pos} | {pos} | {yes/no} |

For each agent that changed position, explain what caused the change.
For each agent that didn't change, note which attacks they absorbed and why they held firm.

### Minority Report
For each dissenting critic:
- **Agent:** {agent-name}
- **Thesis:** Their core argument
- **Why Not Selected:** Why their position was not adopted (specific weaknesses identified in cross-exam)

Even if all critics agree, note what was closest to dissent and what would have changed the outcome.

### Unresolved Questions
Bulleted list of questions that the deliberation could not resolve. These should be flagged for future investigation.

### Consensus Type
One of:
- `strong` — Multiple agents converged after adversarial testing; high-severity attacks mostly answered
- `weak` — Clear majority position exists, but significant minority reservations remain
- `provisional` — Insufficient evidence or unmet conditions; temporary ruling only

Explain WHY this consensus type was assigned.

### Next Actions
Concrete next steps based on the ruling. What should the user do now?

## Constraints
- Do NOT introduce new arguments not raised by the critics
- Do NOT re-analyze the codebase independently — judge only what was argued
- Evidence-poor claims from any critic receive reduced weight
- If critical evidence is missing across all critics, degrade ruling to `investigate`
