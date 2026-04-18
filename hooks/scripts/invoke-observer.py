#!/usr/bin/env python3
"""
invoke-observer.py — Invoke Haiku to analyze observations and write learnings.

Called by observer-loop.sh when SIGUSR1 fires or interval elapses.

Flow:
  1. Read .learnings/observations.jsonl (batch of recent observations)
  2. Invoke `claude --model haiku -p "..."` with observations as input
  3. Haiku agent detects corrections → writes .learnings/YYYY-MM-DD_<slug>.md with
     status: pending_review (human must approve before becoming active)
  4. Rotate processed observations to observations.archive/
  5. Rebuild .learnings/index.yaml (only status: active entries)

Design decisions (from issues.md):
  - Decision 1: Uses Claude Code CLI (reuses user login, no API key mgmt)
  - Decision 4 (REVISED 2026-04-17): Observer writes status: active directly.
    Yin-side safety moved from entry gate to corruption-signature auditing.
    See issues.md "Pending Review Gate — REVERSED" section.
"""

import json
import os
import sys
import subprocess
import shutil
from datetime import datetime, timezone

# Minimum observations to warrant an analysis invocation.
# Avoids burning Haiku tokens on trivial batches.
MIN_OBSERVATIONS_TO_ANALYZE = 5

# Maximum observations per invocation (context budget for Haiku)
MAX_OBSERVATIONS_PER_BATCH = 50


def _log(msg: str) -> None:
    """Print a timestamped log line to stdout (captured by observer-loop.sh)."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] invoke-observer: {msg}", flush=True)


def _read_observations(obs_file: str) -> list[dict]:
    """Read observations.jsonl — returns list of parsed entries."""
    if not os.path.isfile(obs_file):
        return []
    out = []
    try:
        with open(obs_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except IOError:
        return []
    return out


def _archive_observations(obs_file: str, learnings_dir: str, count: int) -> None:
    """
    Move the first `count` observations to observations.archive/ to prevent
    re-analyzing them. Writes a timestamped batch archive file.
    """
    if count <= 0 or not os.path.exists(obs_file):
        return

    archive_dir = os.path.join(learnings_dir, "observations.archive")
    os.makedirs(archive_dir, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    archive_path = os.path.join(archive_dir, f"analyzed-{ts}.jsonl")

    try:
        with open(obs_file, "r", encoding="utf-8") as f:
            lines = f.readlines()

        if count >= len(lines):
            # Move entire file
            shutil.move(obs_file, archive_path)
            return

        # Partial move: write first N lines to archive, keep remainder in obs_file
        with open(archive_path, "w", encoding="utf-8") as f:
            f.writelines(lines[:count])
        with open(obs_file, "w", encoding="utf-8") as f:
            f.writelines(lines[count:])
    except IOError:
        pass


def _find_claude_cli() -> str | None:
    """Locate the claude CLI binary."""
    path = shutil.which("claude")
    return path


def _load_active_learnings(learnings_dir: str) -> list[dict]:
    """
    Load all active learnings' frontmatter so the observer can classify new
    corrections as new / supersedes / reinforces.
    Returns list of dicts with: id, domain, trigger, one_liner.
    """
    try:
        import yaml
    except ImportError:
        return []

    active: list[dict] = []
    if not os.path.isdir(learnings_dir):
        return active

    for fname in sorted(os.listdir(learnings_dir)):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(learnings_dir, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
        except IOError:
            continue
        if not content.startswith("---"):
            continue
        end = content.find("\n---", 3)
        if end == -1:
            continue
        try:
            fm = yaml.safe_load(content[3:end].strip())
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue
        if str(fm.get("status", "")).lower() != "active":
            continue

        body = content[end + 4 :].strip()
        active.append(
            {
                "id": fm.get("id", ""),
                "domain": fm.get("domain", ""),
                "trigger": fm.get("trigger", ""),
                "one_liner": _extract_one_liner(body),
            }
        )
    return active


def _build_analysis_prompt(observations: list[dict], learnings_dir: str) -> str:
    """
    Build the prompt given to the Haiku observer agent.
    Observer agent instructions come from agents/learnings-observer.md —
    we only pass the observations, existing learnings, and output expectations here.
    """
    obs_text = "\n".join(json.dumps(o, ensure_ascii=False) for o in observations)

    # Load existing active learnings so the observer can detect supersedes/reinforces
    active = _load_active_learnings(learnings_dir)
    if active:
        existing_text = "\n".join(
            f'  - id={a["id"]} domain={a["domain"]} trigger="{a["trigger"]}" one_liner="{a["one_liner"]}"'
            for a in active
        )
    else:
        existing_text = "  (no existing active learnings)"

    prompt = f"""You are the learnings-observer agent. Analyze the following
observations from a Claude Code session to detect instances where a HUMAN
CORRECTED the agent's judgment, tool usage, or project-specific assumption.

EXISTING ACTIVE LEARNINGS (you must classify new corrections against these):
---
{existing_text}
---

NEW OBSERVATIONS (JSONL, chronological):
---
{obs_text}
---

For each clear correction you detect, CLASSIFY it against existing learnings:

1. **NEW** — unrelated to any existing learning → write a new active learning.
2. **SUPERSEDES <old_id>** — contradicts an existing learning → write a new
   active learning with `superseded_by` pointing to nothing (you are the
   successor), AND modify the OLD learning file: change its `status` from
   `active` to `invalidated` and add `superseded_by: <new_id>` to its frontmatter.
3. **REINFORCES <old_id>** — same as existing learning → SKIP, do not create
   duplicate. Update the old file's `last_validated` to today's date.

Write new learning files to:
  {learnings_dir}/YYYY-MM-DD_<short-slug>.md

Format (YAML frontmatter + markdown body):
---
id: YYYY-MM-DD_<slug>
domain: <tooling|architecture|process|config|security>
trigger: "When <context that led to the error>"
created: YYYY-MM-DD
last_validated: YYYY-MM-DD
status: active
source_session: <session_id from the observation>
classification: <new|supersedes:OLD_ID>
---

# <Title>

## What went wrong
<What the agent did or assumed incorrectly>

## Root cause
<Why the agent made this error>

## Correct approach
<What should be done instead, based on the human's correction>

## Context
<Project-specific context that makes this correction relevant>

RULES:
- status is `active` — this is the production system (no human gate)
- Only create a learning if the correction is UNAMBIGUOUS
- ALWAYS classify against existing learnings first (NEW / SUPERSEDES / REINFORCES)
- Skip observations that are just questions, discussion, or agent clarifications
- If uncertain, skip — false positives pollute future sessions
- DO NOT modify .learnings/index.yaml — that is rebuilt separately
- DO NOT include code snippets, API keys, or credentials in the learning body
- If NO clear corrections are found, output exactly: NO_CORRECTIONS_DETECTED

After writing files, output a summary line per action:
  CREATED: <new_id> [<domain>] "<one_liner>"
  SUPERSEDED: <new_id> replaces <old_id>
  REINFORCED: <old_id> (last_validated updated)
"""
    return prompt


def _invoke_claude(prompt: str, working_dir: str) -> tuple[int, str, str]:
    """
    Run `claude --model haiku -p <prompt>` in working_dir.
    Returns (exit_code, stdout, stderr).
    """
    claude_bin = _find_claude_cli()
    if not claude_bin:
        return (127, "", "claude CLI not found in PATH")

    try:
        result = subprocess.run(
            [claude_bin, "--model", "haiku", "-p", prompt],
            cwd=working_dir,
            capture_output=True,
            text=True,
            timeout=180,  # 3 minutes max for Haiku analysis
        )
        return (result.returncode, result.stdout, result.stderr)
    except subprocess.TimeoutExpired:
        return (124, "", "claude invocation timed out after 180s")
    except (OSError, subprocess.SubprocessError) as e:
        return (1, "", f"claude invocation failed: {e}")


def _rebuild_index(learnings_dir: str) -> None:
    """
    Rebuild .learnings/index.yaml — contains ONLY status: active entries.
    pending_review and archived entries are NOT indexed (not loaded at session start).
    """
    try:
        import yaml
    except ImportError:
        _log("rebuild skipped: PyYAML not available")
        return

    if not os.path.isdir(learnings_dir):
        return

    active_entries = []
    archived_count = 0
    pending_count = 0

    for fname in sorted(os.listdir(learnings_dir)):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(learnings_dir, fname)
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
        except IOError:
            continue

        if not content.startswith("---"):
            continue
        end = content.find("\n---", 3)
        if end == -1:
            continue

        try:
            fm = yaml.safe_load(content[3:end].strip())
        except yaml.YAMLError:
            continue
        if not isinstance(fm, dict):
            continue

        status = str(fm.get("status", "")).lower()
        if status == "active":
            body = content[end + 4 :].strip()
            one_liner = (
                _extract_one_liner(body)
                or f"[{fm.get('domain', '')}] {fm.get('trigger', '')}"
            )
            active_entries.append(
                {
                    "id": fm.get("id", ""),
                    "domain": fm.get("domain", ""),
                    "one_liner": one_liner,
                    "created": str(fm.get("created", "")),
                }
            )
        elif status == "archived":
            archived_count += 1
        elif status == "pending_review":
            pending_count += 1

    index_path = os.path.join(learnings_dir, "index.yaml")
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        with open(index_path, "w", encoding="utf-8") as f:
            f.write("version: 1\n")
            f.write(f"last_rebuilt: {ts}\n")
            f.write(f"active_count: {len(active_entries)}\n")
            f.write(f"archived_count: {archived_count}\n")
            f.write(f"pending_count: {pending_count}\n\n")
            f.write("entries:\n")
            if not active_entries:
                f.write("  []\n")
            else:
                for e in active_entries:
                    esc = (
                        e["one_liner"]
                        .replace("\\", "\\\\")
                        .replace('"', '\\"')
                        .replace("\n", " ")
                    )
                    f.write(f"  - id: {e['id']}\n")
                    f.write(f"    domain: {e['domain']}\n")
                    f.write(f'    one_liner: "{esc}"\n')
                    f.write(f"    created: {e['created']}\n")
    except IOError:
        _log("rebuild failed: could not write index.yaml")
        return

    _log(
        f"rebuilt index: {len(active_entries)} active, {pending_count} pending, {archived_count} archived"
    )


def _extract_one_liner(body: str) -> str:
    """Extract a one-liner summary from the 'What went wrong' section of a learning body."""
    import re

    m = re.search(
        r"##\s+What went wrong\s*\n(.+?)(?=\n##|\Z)", body, re.DOTALL | re.IGNORECASE
    )
    if not m:
        return ""
    first = m.group(1).strip().split("\n")[0].strip()
    return first[:200]


def main() -> None:
    # Parse args: [--rebuild-only] <project_dir>
    rebuild_only = False
    args = sys.argv[1:]
    if args and args[0] == "--rebuild-only":
        rebuild_only = True
        args = args[1:]

    if not args:
        _log("usage: invoke-observer.py [--rebuild-only] <project_dir>")
        sys.exit(1)

    project_dir = args[0]
    learnings_dir = os.path.join(project_dir, ".learnings")
    obs_file = os.path.join(learnings_dir, "observations.jsonl")

    # Rebuild-only mode: skip observation/Haiku invocation, just rebuild index.
    # Used by /review-learnings after human invalidates/promotes learnings.
    if rebuild_only:
        _log(f"rebuild-only mode: refreshing index for {learnings_dir}")
        _rebuild_index(learnings_dir)
        return

    observations = _read_observations(obs_file)
    if len(observations) < MIN_OBSERVATIONS_TO_ANALYZE:
        _log(
            f"skip: only {len(observations)} observations (need >= {MIN_OBSERVATIONS_TO_ANALYZE})"
        )
        return

    # Cap batch size for Haiku context budget
    batch = observations[:MAX_OBSERVATIONS_PER_BATCH]
    prompt = _build_analysis_prompt(batch, learnings_dir)

    _log(f"invoking claude --model haiku with {len(batch)} observations")
    code, stdout, stderr = _invoke_claude(prompt, project_dir)

    if code != 0:
        _log(f"claude invocation failed (exit {code}): {stderr[:500]}")
        return

    # Check output — Haiku should either write files or output NO_CORRECTIONS_DETECTED
    if "NO_CORRECTIONS_DETECTED" in stdout:
        _log("no corrections detected")
    else:
        _log(f"analysis complete; output: {stdout[:300]}")

    # Archive processed observations regardless of output
    _archive_observations(obs_file, learnings_dir, len(batch))

    # Rebuild index (in case active entries changed — e.g., classification invalidated old ones)
    _rebuild_index(learnings_dir)


if __name__ == "__main__":
    main()
