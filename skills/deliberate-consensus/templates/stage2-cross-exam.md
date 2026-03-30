# Stage 2 — Cross-Examination Template

> Written by: Each critic agent after reading other critics' Stage 1 stances

## Required Frontmatter

```yaml
---
stage: 2
type: cross-exam
agent: "{analytical-critic | risk-critic | pragmatic-critic}"
decision_id: "{decision_id}"
timestamp: "{run scripts/timestamp.sh}"
attacks:
  - target: "{other-agent-1}"
    severity: "{low | medium | high}"
  - target: "{other-agent-2}"
    severity: "{low | medium | high}"
---
```

**IMPORTANT:** The `severity` field in frontmatter MUST be one of exactly three values: `low`, `medium`, or `high`. At least one attack MUST be `high`. The frontmatter is the authoritative source for severity — the body text elaborates the reasoning.

## Required Sections

For EACH of the other two critics, include a section:

### Attack on {target-agent-name}

Before writing your attack, you MUST quote the specific claim from their stance that you are attacking. Use a blockquote.

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
- `high`: If this weakness is confirmed, the opponent's **core thesis collapses** — their recommendation would need to change even if all other points are valid. This is a load-bearing flaw.
- `medium`: This weakness **damages** the opponent's argument but they could patch it — their thesis survives in weakened form if they address this point.
- `low`: A **peripheral issue** that does not affect the opponent's main conclusion. Noting it for completeness.

Use `high` sparingly — only when you can demonstrate that the flaw, if confirmed, would force a different recommendation.

## Rules
- You MUST attack each of the other two critics on at least one point
- Attacks must be specific — "I disagree" is not an attack
- Quote the specific claim you are attacking before explaining why it's wrong
- Reference concrete evidence (file:line, command output) where possible
- Mark evidence-free attacks as `[HYPOTHESIS]`
- **Be aggressive.** Your goal is to find the fatal flaw that collapses their argument. Polite disagreement produces weak consensus — fierce, evidence-backed attacks produce real consensus through survival.
- **Target load-bearing claims first.** Attack the claim that, if removed, makes their entire recommendation fall apart. Peripheral nitpicks waste everyone's time.
- A `high` severity attack MUST cite at least one concrete counter-evidence (file:line, logical proof, or internal contradiction in the opponent's own argument). No evidence = downgrade to `medium`.
- **You MUST rate at least one attack as `high` across your two targets.** If neither opponent has a load-bearing flaw, explicitly explain why their arguments are unusually robust — but this should be exceptional, not the norm.
- **Do NOT include a Summary or Conclusion section.** Your job is to attack, not to synthesize. Synthesis is the Arbiter's responsibility.
