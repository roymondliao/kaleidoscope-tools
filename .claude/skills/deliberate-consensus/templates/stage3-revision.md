# Stage 3 — Belief Revision Template

> Written by: Each critic agent after reading attacks directed at them

## Required Frontmatter

```yaml
---
stage: 3
type: belief-revision
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{run scripts/timestamp.sh}"
position_changed: "{yes | no}"
prior_position: "{accept | reject | revise | investigate}"
current_position: "{accept | reject | revise | investigate}"
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
If changed: explain which specific attacks convinced you, quote them, and explain why they undermined your position.
If not changed: explain why the attacks did not undermine your position — rebut them with evidence.

### Attacks Survived
Bulleted list of attacks you successfully rebutted. For each:
- Which agent attacked you
- What they claimed (quote the attack)
- Why their attack does not hold (with evidence)

### Attacks Not Answered
Bulleted list of attacks you cannot fully rebut. For each:
- Which agent attacked you
- What they claimed (quote the attack)
- Why you cannot answer it (missing evidence, valid point, etc.)

### Revised Argument Strength
Describe how your argument has changed after absorbing attacks:
- Which parts of your original argument remain strong
- Which parts were weakened or withdrawn
- What new considerations you now acknowledge
