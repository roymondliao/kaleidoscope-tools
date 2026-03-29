# Stage 1 — Stance Generation Template

> Written by: Each critic agent independently

## Required Frontmatter

```yaml
---
stage: 1
type: stance
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{run scripts/timestamp.sh}"
---
```

## Required Sections

### Thesis
Your core argument in 2-3 sentences. State your position clearly.

### Recommendation
One of: `accept` | `reject` | `revise` | `investigate`

### Assumptions
Bulleted list of assumptions your argument depends on. For each:
- State the assumption
- Note evidence supporting it (or mark as `[HYPOTHESIS]` if unsupported)

### Evidence
Bulleted list of concrete evidence references:
- `file:line` or `file:line-range` for code references
- Command output descriptions for runtime evidence
- Each critical claim MUST have at least one evidence reference

### Strongest Reasons
Top 2-3 reasons supporting your recommendation.

### Risk If Wrong
What happens if your recommendation is followed but turns out to be wrong?

### Argument Strength
Describe the strength of your argument in prose. Explain:
- Which parts of your argument are well-supported by evidence
- Which parts are hypotheses that need further investigation
- What is the weakest point in your own reasoning
- How certain are you overall and why
