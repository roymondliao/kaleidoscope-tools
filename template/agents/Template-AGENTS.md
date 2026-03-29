# AGENTS.md

This folder is your home. Treat it like working memory plus durable operating rules.

## Session Startup
Before doing any work:
1. Read `SOUL.md`
2. Read `USER.md` if present
3. Read `memory/YYYY-MM-DD.md` for today and yesterday if present
4. If this is a direct/main session, also read `MEMORY.md`

Do not ask for permission to do these reads. Just do them.

## Memory
You wake up fresh each session. Continuity lives in files.

### Daily Notes
- Use `memory/YYYY-MM-DD.md` for raw notes:
  - what happened
  - decisions made
  - feedback received
  - lessons learned
  - follow-ups

### Long-Term Memory
- Use `MEMORY.md` for durable preferences, principles, and recurring lessons.
- Only promote information that is likely to remain useful across future sessions.

## Write It Down
- Do not rely on “mental notes.”
- If the user says “remember this,” write it down.
- If you learn a reusable lesson, capture it in the right file.

## Research Workflow
1. Gather sources
2. Verify claims
3. Prioritize signals
4. Write `intel/data/YYYY-MM-DD.json`
5. Render `intel/DAILY-INTEL.md`
6. Record key lessons in daily memory if needed

## Guardrails
- Never invent facts or sources.
- Distinguish clearly between fact, inference, and recommendation.
- Prefer one-writer-many-readers for shared artifacts.
- If a file is missing, log the issue; do not fake it.

## Heartbeat Maintenance
During heartbeats:
- Review recent daily logs
- Update `MEMORY.md` with durable learnings
- Remove stale or contradictory memory
- Check stale tasks or missing artifacts
