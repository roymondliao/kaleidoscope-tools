#!/usr/bin/env bash
# observer-loop.sh — Background daemon loop for learnings observer.
#
# Usage: observer-loop.sh <project_dir>
# Launched by start-observer.sh via nohup.
#
# Behavior:
#   - trap SIGUSR1 — wake on signal from observe-learnings hook
#   - Interval sleep (default 5 min) — periodic check even without signals
#   - Cooldown — min 60s between analysis invocations (prevents rapid re-trigger)
#   - Idle timeout — exit if no observations for 30 min
#   - On trigger: invoke learnings-observer agent via claude CLI

set +e
unset CLAUDECODE 2>/dev/null || true

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── find python ─────────────────────────────────────────────────────────────

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

# ── resolve state paths ─────────────────────────────────────────────────────

HASH=$("$PYTHON" -c "import hashlib,sys; print(hashlib.sha256(sys.argv[1].encode()).hexdigest()[:12])" "$PROJECT_DIR")
PREFIX="${TMPDIR:-/tmp}/learnings-observer-${HASH}"
PID_FILE="${PREFIX}.pid"
LOG_FILE="${PREFIX}.log"
SENTINEL_FILE="${PREFIX}.last-activity"

INTERVAL_SECONDS="${LEARNINGS_INTERVAL_SECONDS:-300}"
COOLDOWN_SECONDS="${LEARNINGS_COOLDOWN_SECONDS:-60}"
IDLE_TIMEOUT_SECONDS="${LEARNINGS_IDLE_TIMEOUT_SECONDS:-1800}"

# ── cleanup on exit ─────────────────────────────────────────────────────────

cleanup() {
    if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then
        rm -f "$PID_FILE"
    fi
    exit 0
}
trap cleanup TERM INT EXIT

# ── signal handling ─────────────────────────────────────────────────────────

USR1_FIRED=0
on_usr1() { USR1_FIRED=1; }
trap on_usr1 USR1

# ── state tracking ──────────────────────────────────────────────────────────

LAST_ANALYSIS_EPOCH=0

now_epoch() { date +%s; }

file_mtime() {
    local f="$1"
    [ -f "$f" ] || { echo 0; return; }
    stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0
}

# ── main loop ───────────────────────────────────────────────────────────────

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] observer-loop started pid=$$ project=$PROJECT_DIR" >> "$LOG_FILE"

while true; do
    # Sleep in a way that is interruptible by SIGUSR1
    sleep "$INTERVAL_SECONDS" &
    SLEEP_PID=$!
    wait "$SLEEP_PID" 2>/dev/null || true

    # Check idle timeout
    sentinel_epoch=$(file_mtime "$SENTINEL_FILE")
    now=$(now_epoch)
    idle_seconds=$(( now - sentinel_epoch ))

    if [ "$sentinel_epoch" -eq 0 ] || [ "$idle_seconds" -ge "$IDLE_TIMEOUT_SECONDS" ]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] idle timeout (${idle_seconds}s), exiting" >> "$LOG_FILE"
        cleanup
    fi

    # Cooldown check
    time_since_analysis=$(( now - LAST_ANALYSIS_EPOCH ))
    if [ "$time_since_analysis" -lt "$COOLDOWN_SECONDS" ]; then
        USR1_FIRED=0
        continue
    fi

    # Determine if we should analyze:
    #   - SIGUSR1 fired, OR
    #   - Interval elapsed AND observations exist
    should_analyze=0
    if [ "$USR1_FIRED" -eq 1 ]; then
        should_analyze=1
    elif [ -f "${PROJECT_DIR}/.learnings/observations.jsonl" ]; then
        obs_size=$(wc -c < "${PROJECT_DIR}/.learnings/observations.jsonl" 2>/dev/null || echo 0)
        if [ "$obs_size" -gt 0 ]; then
            should_analyze=1
        fi
    fi

    USR1_FIRED=0

    if [ "$should_analyze" -eq 1 ]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] invoking analysis" >> "$LOG_FILE"
        "$PYTHON" "${SCRIPT_DIR}/invoke-observer.py" "$PROJECT_DIR" \
            >> "$LOG_FILE" 2>&1 || true
        LAST_ANALYSIS_EPOCH=$(now_epoch)
    fi
done
