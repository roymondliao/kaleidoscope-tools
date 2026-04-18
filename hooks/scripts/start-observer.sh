#!/usr/bin/env bash
# start-observer.sh — Daemon launcher for learnings observer.
#
# Usage: start-observer.sh <project_dir>
#
# Launches observer-loop.sh as a background (nohup) daemon if not already running.
# Uses OS-temp PID file to detect stale/running daemons.
# Silent on success. Exit 0 if daemon started or already running, 1 on error.
set -euo pipefail

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOOP_SCRIPT="${SCRIPT_DIR}/observer-loop.sh"

if [ ! -x "$LOOP_SCRIPT" ] && [ ! -f "$LOOP_SCRIPT" ]; then
    exit 1
fi

# ── find python (needed by observer-loop indirectly) ────────────────────────

_find_python() {
    local dir="$SCRIPT_DIR"
    local depth=0
    while [ "$depth" -lt 5 ]; do
        if [ -x "${dir}/.venv/bin/python3" ]; then
            printf '%s/.venv/bin/python3' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
        (( depth++ )) || true
    done
    command -v python3 >/dev/null 2>&1 && printf 'python3' && return 0
    return 1
}

PYTHON=$(_find_python) || exit 1

# ── resolve OS-temp state paths ─────────────────────────────────────────────
# Uses the same path convention as learnings_state.state_paths() in Python.
# Keep this logic aligned: sha256 of absolute project dir → first 12 hex chars.

HASH=$("$PYTHON" -c 'import hashlib,sys,os; print(hashlib.sha256(os.path.abspath(sys.argv[1]).encode()).hexdigest()[:12])' "$PROJECT_DIR") || exit 1
PREFIX="${TMPDIR:-/tmp}/learnings-observer-${HASH}"
OBSERVER_PID_FILE="${PREFIX}.pid"
OBSERVER_LOG_FILE="${PREFIX}.log"
OBSERVER_PREFIX="${PREFIX}"

# ── check if daemon is already running (via PID file + kill -0) ─────────────

if [ -f "$OBSERVER_PID_FILE" ]; then
    existing_pid=$(cat "$OBSERVER_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$existing_pid" ] && [ "$existing_pid" -gt 1 ] 2>/dev/null; then
        if kill -0 "$existing_pid" 2>/dev/null; then
            exit 0  # Already running
        fi
    fi
    rm -f "$OBSERVER_PID_FILE"
fi

# ── atomic launch via mkdir lock to prevent race on concurrent hooks ────────

LOCK_DIR="${OBSERVER_PREFIX}.lock.d"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0  # Another hook is launching — let it proceed
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# Re-check after acquiring lock
if [ -f "$OBSERVER_PID_FILE" ]; then
    existing_pid=$(cat "$OBSERVER_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$existing_pid" ] && [ "$existing_pid" -gt 1 ] 2>/dev/null && kill -0 "$existing_pid" 2>/dev/null; then
        exit 0
    fi
fi

# ── launch daemon ───────────────────────────────────────────────────────────

nohup bash "$LOOP_SCRIPT" "$PROJECT_DIR" \
    >>"$OBSERVER_LOG_FILE" 2>&1 </dev/null &

daemon_pid=$!
echo "$daemon_pid" > "$OBSERVER_PID_FILE"

# Tiny sleep to let the daemon initialize (sub-second)
sleep 0.1 2>/dev/null || sleep 1

exit 0
