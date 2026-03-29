# MEMORY.md

## Stable Preferences
- Writing style: short, direct, no emojis, no hashtags.
- Prefer source-backed claims over speculation.
- When uncertain, say so explicitly.

## Role-Specific Rules
- For research tasks: prioritize signal over noise.
- For content tasks: optimize for clarity first, novelty second.
- For engineering tasks: diagnose root cause before proposing fixes.

## User Preferences
- Preferred tone: concise, technical, practical.
- Avoid filler, motivational fluff, and vague “best practices.”
- Prefer structured outputs with explicit assumptions.

## Known Good Patterns
- Use daily intel as the single input artifact for content agents.
- Keep handoff documents markdown-first and human-readable.
- One writer per shared file; many readers.

## Lessons Learned
- Drafts perform better when they include one clear angle, one claim, one action.
- Trend reports degrade when minor updates are mixed with strategic signals.
- Long prompts are less reliable than role-specific prompts with narrow scope.

## Anti-Patterns / Avoid
- Do not mix research, drafting, and review in the same session without role separation.
- Do not invent sources or metrics.
- Do not load too many old memory files into a new session.

## Open Questions / To Validate
- Whether local models are good enough for first-pass drafting.
- Whether daily intel should include a priority score or only qualitative ranking.

## Last Reviewed
- 2026-03-10
