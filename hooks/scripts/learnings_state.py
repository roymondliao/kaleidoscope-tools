#!/usr/bin/env python3
"""
learnings_state.py — Shared helpers for observer daemon state management.

All daemon runtime state lives in OS temp (not in-repo).
State is project-scoped via a hash of the project root path.

Path convention:
  /tmp/learnings-observer-<project-hash>.pid       — daemon PID file
  /tmp/learnings-observer-<project-hash>.log       — daemon stderr log
  /tmp/learnings-observer-<project-hash>.counter   — signal throttle counter

Import this module from observe-learnings.py, invoke-observer.py, and any
future daemon-state-aware component.
"""

import hashlib
import os
import tempfile
from pathlib import Path


# Throttle configuration (overridable via env for testing)
SIGNAL_EVERY_N = int(os.environ.get("LEARNINGS_SIGNAL_EVERY_N", "20"))
COOLDOWN_SECONDS = int(os.environ.get("LEARNINGS_COOLDOWN_SECONDS", "60"))
IDLE_TIMEOUT_SECONDS = int(os.environ.get("LEARNINGS_IDLE_TIMEOUT_SECONDS", "1800"))


def project_hash(project_dir: str) -> str:
    """
    Derive a stable 12-character hash for a project directory.
    Uses the absolute path — same repo on different machines gets different hashes,
    which is correct (daemon state is per-machine).
    """
    if not project_dir:
        return "global"
    abs_path = os.path.abspath(project_dir)
    return hashlib.sha256(abs_path.encode("utf-8")).hexdigest()[:12]


def state_paths(project_dir: str) -> dict:
    """
    Return dict of OS-temp paths for all daemon state files.

    Keys: pid_file, log_file, counter_file, sentinel_file
    """
    tmp = tempfile.gettempdir()
    phash = project_hash(project_dir)
    prefix = os.path.join(tmp, f"learnings-observer-{phash}")
    return {
        "prefix": prefix,
        "pid_file": f"{prefix}.pid",
        "log_file": f"{prefix}.log",
        "counter_file": f"{prefix}.counter",
        "sentinel_file": f"{prefix}.last-activity",  # touch on each observation
    }


def is_daemon_alive(pid_file: str) -> bool:
    """
    Check if the daemon PID file points to a live process.
    Returns False and removes stale PID file if process is dead.
    """
    if not os.path.exists(pid_file):
        return False

    try:
        with open(pid_file, "r") as f:
            pid_str = f.read().strip()
        pid = int(pid_str)
        if pid <= 1:
            os.remove(pid_file)
            return False
    except (IOError, ValueError):
        try:
            os.remove(pid_file)
        except OSError:
            pass
        return False

    # os.kill(pid, 0) signals process existence without affecting it
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        try:
            os.remove(pid_file)
        except OSError:
            pass
        return False
    except PermissionError:
        # Process exists but we can't signal it — treat as alive
        return True


def read_daemon_pid(pid_file: str) -> int | None:
    """Return PID from file if daemon is alive, else None."""
    if not is_daemon_alive(pid_file):
        return None
    try:
        with open(pid_file, "r") as f:
            return int(f.read().strip())
    except (IOError, ValueError):
        return None


def increment_counter(counter_file: str) -> int:
    """
    Atomically increment the throttle counter.
    Returns the new count. Resets to 1 on any I/O error.
    """
    current = 0
    try:
        if os.path.exists(counter_file):
            with open(counter_file, "r") as f:
                current = int(f.read().strip() or "0")
    except (IOError, ValueError):
        current = 0

    new_count = current + 1

    try:
        with open(counter_file, "w") as f:
            f.write(str(new_count))
    except IOError:
        pass

    return new_count


def reset_counter(counter_file: str) -> None:
    """Reset the throttle counter after a signal is sent."""
    try:
        with open(counter_file, "w") as f:
            f.write("0")
    except IOError:
        pass


def touch_sentinel(sentinel_file: str) -> None:
    """Update last-activity timestamp so the daemon knows we're still active."""
    try:
        Path(sentinel_file).touch()
    except OSError:
        pass
