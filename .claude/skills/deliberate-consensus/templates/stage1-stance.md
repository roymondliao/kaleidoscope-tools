# Stage 1 — Stance Generation Template

> Written by: Each critic agent independently
> **Length constraint: Keep total output under 150 lines.** Be precise, not exhaustive.

## Required Frontmatter

```yaml
---
stage: 1
type: stance
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{run scripts/timestamp.sh}"
recommendation: "{accept | reject | revise | investigate}"
---
```

**IMPORTANT:** The `recommendation` field MUST be one of exactly four values: `accept`, `reject`, `revise`, or `investigate`. No other values (e.g., "block", "conditional-accept", "revise-with-conditions") are permitted. Use `reject` for blocking, and explain conditions in the body text.

## Required Sections

### Thesis
2-3 sentences. State your position and recommendation clearly. No background.

### Recommendation
One of: `accept` | `reject` | `revise` | `investigate`

### Key Findings
Bulleted list, **maximum 5 items**. Each finding must:
- State the claim in one sentence
- Cite evidence: `file:line` or `file:line-range`
- Mark unsupported claims as `[HYPOTHESIS]`

Do NOT write paragraphs. One bullet = one finding + one evidence reference.

### Assumptions
Bulleted list, **maximum 3 items**. Only list assumptions that, if wrong, would change your recommendation.

### Risk If Wrong
2-3 sentences. What happens if your recommendation is followed but turns out to be wrong?

### Weakest Point
1-2 sentences. What is the single weakest part of your own argument?

## Rules

- **Do NOT add sections not listed above.** No "Summary", no "Overall Assessment", no "Feasibility Analysis".
- **Do NOT repeat information across sections.** Each fact appears once.
- **Evidence goes in Key Findings only.** Other sections reference findings by number if needed.
- **No percentages, no confidence scores.** Use words: "well-supported", "hypothesis", "uncertain".
