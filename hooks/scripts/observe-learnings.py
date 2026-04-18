#!/usr/bin/env python3
"""
observe-learnings.py — Capture user prompt + context to observations.jsonl.

Called by hooks/observe-learnings.sh (thin bash wrapper) on UserPromptSubmit.
Reads hook JSON from stdin, extracts the user's message, and appends a
structured observation to .learnings/observations.jsonl.

This is Layer 1 of the two-layer architecture:
- Layer 1 (this): passively capture data, no analysis
- Layer 2 (learnings-observer agent): background Haiku analyzes and writes learnings

Observations are append-only JSONL. Each line:
{
  "timestamp": "ISO8601",
  "session_id": "...",
  "type": "user_prompt",
  "content": "truncated user message",
  "cwd": "..."
}
"""

import json
import sys
import os
import re
import signal
import subprocess
from datetime import datetime, timezone

# Shared state helpers (OS-temp daemon state management)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import learnings_state


# Maximum characters to store per observation (prevent bloat)
MAX_CONTENT_LENGTH = 3000

# Auto-purge observations older than 30 days
PURGE_AGE_DAYS = 30

# Secret scrubbing pattern
SECRET_RE = re.compile(
    r"(?i)(api[_-]?key|token|secret|password|authorization|credentials?|auth)"
    r"""(["'\s:=]+)"""
    r"([A-Za-z]+\s+)?"
    r"([A-Za-z0-9_\-/.+=]{8,})"
)


def scrub_secrets(text: str) -> str:
    """Replace common secret patterns with [REDACTED]."""
    return SECRET_RE.sub(
        lambda m: m.group(1) + m.group(2) + (m.group(3) or "") + "[REDACTED]", text
    )


def _bridge_to_observer(project_dir: str) -> None:
    """
    Layer 1 → Layer 2 bridge:
    1. Increment observation counter
    2. Lazy-start observer daemon if not running
    3. Send SIGUSR1 every N observations (throttled)

    All failures are silent — hook must never block the user's session.
    """
    paths = learnings_state.state_paths(project_dir)
    learnings_state.touch_sentinel(paths["sentinel_file"])

    count = learnings_state.increment_counter(paths["counter_file"])
    daemon_pid = learnings_state.read_daemon_pid(paths["pid_file"])

    # Lazy-start: if daemon is not running, launch it
    if daemon_pid is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        start_script = os.path.join(script_dir, "start-observer.sh")
        if os.path.exists(start_script):
            try:
                # Detached launch — do not wait, do not hold stdin/stdout/stderr
                subprocess.Popen(
                    ["bash", start_script, project_dir],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
            except (OSError, subprocess.SubprocessError):
                pass
        return  # No signal on the same invocation that started the daemon

    # Throttled signal: only every SIGNAL_EVERY_N observations
    if count >= learnings_state.SIGNAL_EVERY_N:
        try:
            os.kill(daemon_pid, signal.SIGUSR1)
            learnings_state.reset_counter(paths["counter_file"])
        except (ProcessLookupError, PermissionError, OSError):
            pass


def main() -> None:
    # Read hook JSON from stdin
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return
        data = json.loads(raw)
    except (json.JSONDecodeError, IOError):
        return

    # Extract fields from Claude Code hook format
    session_id = data.get("session_id", "unknown")
    cwd = data.get("cwd", "")

    # UserPromptSubmit provides the user's message in tool_input
    tool_input = data.get("tool_input", data.get("input", {}))
    if isinstance(tool_input, dict):
        content = tool_input.get("content", tool_input.get("message", ""))
    else:
        content = str(tool_input)

    if not content:
        return

    # Skip subagent sessions
    agent_id = data.get("agent_id", "")
    if agent_id:
        return

    # Determine project directory
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    if not project_dir:
        # Try to derive from cwd via git
        if cwd and os.path.isdir(cwd):
            try:
                import subprocess

                result = subprocess.run(
                    ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                    capture_output=True,
                    text=True,
                    timeout=3,
                )
                if result.returncode == 0:
                    project_dir = result.stdout.strip()
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

    if not project_dir:
        return

    learnings_dir = os.path.join(project_dir, ".learnings")
    os.makedirs(learnings_dir, exist_ok=True)

    observations_file = os.path.join(learnings_dir, "observations.jsonl")

    # Truncate and scrub content
    content_clean = scrub_secrets(content[:MAX_CONTENT_LENGTH])

    # Build observation
    observation = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "session_id": session_id,
        "type": "user_prompt",
        "content": content_clean,
        "cwd": cwd,
    }

    # Append to observations.jsonl
    try:
        with open(observations_file, "a", encoding="utf-8") as f:
            f.write(json.dumps(observation, ensure_ascii=False) + "\n")
    except IOError:
        return

    # ── Layer 1→2 Bridge: lazy-start daemon + SIGUSR1 throttle ──────────────
    _bridge_to_observer(project_dir)

    # Auto-purge: archive old observation files (once per day)
    purge_marker = os.path.join(learnings_dir, ".last-purge")
    should_purge = True
    if os.path.exists(purge_marker):
        age = datetime.now().timestamp() - os.path.getmtime(purge_marker)
        should_purge = age > 86400  # 24 hours

    if should_purge:
        try:
            archive_dir = os.path.join(learnings_dir, "observations.archive")
            os.makedirs(archive_dir, exist_ok=True)

            # Check file size and rotate if needed
            if os.path.exists(observations_file):
                size_mb = os.path.getsize(observations_file) / (1024 * 1024)
                if size_mb > 10:
                    ts = datetime.now().strftime("%Y%m%d-%H%M%S")
                    archive_path = os.path.join(archive_dir, f"observations-{ts}.jsonl")
                    os.rename(observations_file, archive_path)

            # Clean archives older than PURGE_AGE_DAYS
            for fname in os.listdir(archive_dir):
                fpath = os.path.join(archive_dir, fname)
                age_days = (
                    datetime.now().timestamp() - os.path.getmtime(fpath)
                ) / 86400
                if age_days > PURGE_AGE_DAYS:
                    os.remove(fpath)

            # Touch purge marker
            with open(purge_marker, "w") as f:
                f.write("")
        except (IOError, OSError):
            pass


if __name__ == "__main__":
    main()
