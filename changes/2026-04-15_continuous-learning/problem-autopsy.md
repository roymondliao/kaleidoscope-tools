# Problem Autopsy: Continuous Learning

## original_statement

> "Right-sizing 路由" 其實我們之前也討論過，是否需要有一個 interface 作為入口來判斷該走哪邊。2, 3, 4, 5 點似乎沒有討論過。

(Initial topic was compound-engineering pattern adoption. During interrogation, patterns 2-5 were killed. Discussion evolved into:)

> continuous-learning 要學的不是開發問題，要學的是該 project 本質上的問題。即時 Samsara 在厲害，也可能會有那 1% 的錯誤，而 continuous-learning 就是用來學習這可能出錯的問題，然後讓該錯誤是一個 troubleshooting 可學習可參考的內容。

> 我認為開發真理是不變的，但真理需要的是進化，精神依然陰面思維，但陰面也是會進化。

## reframed_statement

Agent sessions are stateless regarding their own judgment errors. When a human corrects an agent's project-specific mistake (wrong tool choice, incorrect assumption about project constraints, misunderstanding of local conventions), that correction exists only in session memory. The next session has no access to it. Continuous learning is a mechanism to persist and retrieve these agent-level corrections — not coding preferences, not system-level code risks, but the agent's own blind spots in a specific project context.

## translation_delta

```yaml
translation_delta:
  - original: "continuous-learning 要學的不是開發問題"
    reframed: "Learning target is agent judgment errors, not code defects"
    delta: "User explicitly distinguishes from scar reports (code-level) — this is meta-learning about the agent itself"
  - original: "該 project 本質上的問題"
    reframed: "Project-scoped failure patterns"
    delta: "User emphasizes project-specificity — a React project's agent errors differ from a Rails project's"
  - original: "那 1% 的錯誤"
    reframed: "Residual error rate that even a well-designed harness cannot eliminate"
    delta: "User acknowledges samsara's axioms cover 99% but accepts 1% of errors are emergent and context-dependent"
  - original: "開發真理是不變的，但真理需要的是進化"
    reframed: "Core axioms are immutable; their application in specific contexts evolves through experience"
    delta: "Yin-side philosophy itself is not static — it learns which project contexts expose which blind spots"
```

## kill_conditions

```yaml
kill_conditions:
  - condition: "Learnings accumulate but agent behavior does not measurably change"
    rationale: "If the loading mechanism works but agents ignore the loaded knowledge, the system is carrying cost without value. Storage without behavioral impact is theater."
  - condition: "Learning system itself becomes a source of silent failures"
    rationale: "If the observation/recording logic has bugs that produce incorrect learnings, it silently corrupts future agent decisions. A learning system that teaches wrong lessons is worse than no learning system."
  - condition: "Format standardization for shared use forces learnings to be so generic they lose actionability"
    rationale: "If making learnings workflow-neutral strips them of the specific context that makes them useful (trigger conditions, root cause, project-specific constraints), the shared design undermines the purpose."
```

## damage_recipients

```yaml
damage_recipients:
  - who: "Skill authors across all workflows"
    cost: "Must write learnings in neutral format, cannot use workflow-specific vocabulary. Learning entries must be understandable without knowing samsara, superpowers, or any specific workflow."
  - who: "Session startup time"
    cost: "SessionStart hook adds index loading step. Bounded to ~1500 tokens by three-layer design, but non-zero cost on every session."
  - who: "Repository cleanliness"
    cost: ".learnings/ directory adds files to the repo. Must be maintained, reviewed, and occasionally pruned. Adds cognitive load for contributors who encounter it."
```

## observable_done_state

When a human corrects an agent's project-specific judgment error, the correction is immediately written to `<project>/.learnings/` as a structured file. In the next session on the same project, the index of past corrections is loaded at startup. The agent does not repeat the same category of error — the repeat failure rate for known correction types trends toward zero.
