# Stage 2 — Cross-Examination Template

> Written by: Each critic agent after reading other critics' Stage 1 stances

## Required Frontmatter

```yaml
---
stage: 2
type: cross-exam
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

## Required Sections

For EACH of the other two critics, include a section:

### Attack on {target-agent-name}

#### Weakest Assumption
Identify the most vulnerable assumption in their stance. Explain why it is weak — cite evidence or reasoning.

#### Evidence Gap
What evidence is missing from their argument? What would they need to prove their case?

#### Reasoning Flaw
Identify a logical gap, non-sequitur, or unjustified leap in their reasoning.

#### Hidden Tradeoff
What cost or consequence did they fail to acknowledge?

#### Severity
One of: `low` | `medium` | `high`

Criteria:
- `high`: Undermines their core thesis if true
- `medium`: Weakens their argument but doesn't invalidate it
- `low`: Minor issue, does not significantly affect their conclusion

## Rules
- You MUST attack each of the other two critics on at least one point
- Attacks must be specific — "I disagree" is not an attack
- Reference concrete evidence (file:line, command output) where possible
- Mark evidence-free attacks as `[HYPOTHESIS]`
