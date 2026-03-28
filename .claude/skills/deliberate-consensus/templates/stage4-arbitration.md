# Stage 4 — Arbitration Template

> Written by: Arbiter agent only

## Required Frontmatter

```yaml
---
stage: 4
type: arbitration
agent: arbiter
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

## Required Sections

### Ruling
One of: `accept` | `reject` | `revise` | `investigate`

### Rationale
Explain the reasoning behind the ruling. Reference specific arguments from the critics that survived cross-examination.

### Winning Case
Which critic's position (or synthesis of positions) forms the basis of the ruling? Cite specific surviving arguments.

### Minority Report
For each dissenting critic:
- **Agent:** {agent-name}
- **Thesis:** Their core argument
- **Why Not Selected:** Why their position was not adopted (specific weaknesses identified in cross-exam)

### Unresolved Questions
Bulleted list of questions that the deliberation could not resolve. These should be flagged for future investigation.

### Confidence
A number from 0.00 to 1.00 reflecting confidence in this ruling.

### Consensus Type
One of:
- `strong` — Multiple agents converged after adversarial testing; high-severity attacks mostly answered
- `weak` — Clear majority position exists, but significant minority reservations remain
- `provisional` — Insufficient evidence or unmet conditions; temporary ruling only

## Constraints
- Do NOT introduce new arguments not raised by the critics
- Do NOT re-analyze the codebase independently — judge only what was argued
- Evidence-poor claims from any critic receive reduced weight
- If critical evidence is missing across all critics, degrade ruling to `investigate`
