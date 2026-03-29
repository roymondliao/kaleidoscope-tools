# HEARTBEAT.md

## Purpose
Keep the workspace healthy, current, and reliable.

## On Every Heartbeat
1. Check whether today's daily memory file exists.
   - If not, create `memory/YYYY-MM-DD.md`.

2. Review whether any critical scheduled jobs are stale.
   - If a job has not run within its allowed window, mark it as stale.
   - If CLI/job control is available, trigger a rerun.
   - If not available, write a warning into today's daily memory log.

3. Check shared artifacts freshness.
   - Verify `intel/DAILY-INTEL.md` is for today.
   - Verify `intel/data/YYYY-MM-DD.json` exists if research ran today.

4. Detect obvious coordination issues.
   - If a shared file has conflicting updates, flag it.
   - Prefer one-writer, many-readers. Do not overwrite blindly.

## Every Few Days
1. Read recent `memory/YYYY-MM-DD.md` files.
2. Distill durable preferences, lessons, and workflow rules into `MEMORY.md`.
3. Remove outdated or contradictory items from `MEMORY.md`.

## Weekly Maintenance
1. Archive or prune old daily memory logs if they are no longer useful.
2. Check whether `SOUL.md` and `AGENTS.md` still match the agent’s actual role.
3. Review recurring failures and add prevention rules if needed.

## Failure Handling
- If a scheduled task failed: note time, likely cause, and recovery action.
- If context is getting noisy: recommend pruning stale notes.
- If a source file is missing: do not fabricate; log the gap and stop.

## Guardrails
- Do not infer missing facts.
- Do not silently rewrite shared source-of-truth files without cause.
- Prefer logging and escalation over risky auto-fixes.
