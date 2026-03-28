# Stage 3 — Belief Revision Template

> Written by: Each critic agent after reading attacks directed at them

## Required Frontmatter

```yaml
---
stage: 3
type: belief-revision
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{ISO 8601}"
---
```

## Required Sections

### Prior Position
Your recommendation from Stage 1: `accept` | `reject` | `revise` | `investigate`

### Current Position
Your recommendation now, after considering attacks: `accept` | `reject` | `revise` | `investigate`

### Changed
`yes` or `no`

### Why Changed (or Why Not)
If changed: explain which attacks convinced you and why.
If not changed: explain why the attacks did not undermine your position.

### Attacks Survived
Bulleted list of attacks you successfully rebutted. For each:
- Which agent attacked you
- What they claimed
- Why their attack does not hold (with evidence)

### Attacks Not Answered
Bulleted list of attacks you cannot fully rebut. For each:
- Which agent attacked you
- What they claimed
- Why you cannot answer it (missing evidence, valid point, etc.)

### Remaining Confidence
A number from 0.00 to 1.00 reflecting your updated confidence.
