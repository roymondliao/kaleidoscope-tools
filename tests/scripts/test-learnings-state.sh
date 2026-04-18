#!/usr/bin/env bash
# Tests for hooks/scripts/learnings_state.py
# Pure-function tests: project_hash, state_paths, counter ops, is_daemon_alive
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PYTHON="${REPO_ROOT}/.venv/bin/python3"
MODULE_DIR="${REPO_ROOT}/hooks/scripts"

pass_count=0
fail_count=0

pass() { echo "  PASS: $1"; pass_count=$((pass_count+1)); }
fail() { echo "  FAIL: $1" >&2; fail_count=$((fail_count+1)); }

run_py() {
    # $1 = test name, stdin = python code
    "$VENV_PYTHON" -c "
import sys
sys.path.insert(0, '$MODULE_DIR')
$(cat)
"
}

# ── test 1: project_hash is deterministic for same path ─────────────────────

echo "Test 1: project_hash deterministic"
result=$(run_py <<'PY'
import learnings_state
a = learnings_state.project_hash("/foo/bar")
b = learnings_state.project_hash("/foo/bar")
print("MATCH" if a == b and len(a) == 12 else f"FAIL a={a} b={b}")
PY
)
[ "$result" = "MATCH" ] && pass "project_hash is deterministic and 12 chars" || fail "got: $result"

# ── test 2: different paths → different hashes ──────────────────────────────

echo "Test 2: project_hash differentiates paths"
result=$(run_py <<'PY'
import learnings_state
a = learnings_state.project_hash("/foo/bar")
b = learnings_state.project_hash("/foo/baz")
print("DIFFER" if a != b else "SAME")
PY
)
[ "$result" = "DIFFER" ] && pass "different paths get different hashes" || fail "got: $result"

# ── test 3: empty project_dir → 'global' ────────────────────────────────────

echo "Test 3: empty project_dir returns 'global'"
result=$(run_py <<'PY'
import learnings_state
print(learnings_state.project_hash(""))
PY
)
[ "$result" = "global" ] && pass "empty dir → 'global'" || fail "got: $result"

# ── test 4: state_paths returns all expected keys ───────────────────────────

echo "Test 4: state_paths keys"
result=$(run_py <<'PY'
import learnings_state
p = learnings_state.state_paths("/foo/bar")
required = {"prefix", "pid_file", "log_file", "counter_file", "sentinel_file"}
print("OK" if required <= set(p.keys()) else f"MISSING: {required - set(p.keys())}")
PY
)
[ "$result" = "OK" ] && pass "state_paths has all required keys" || fail "got: $result"

# ── test 5: state_paths uses OS temp, not in-repo ───────────────────────────

echo "Test 5: state_paths uses OS temp"
result=$(run_py <<'PY'
import learnings_state, tempfile
p = learnings_state.state_paths("/foo/bar")
tmp = tempfile.gettempdir()
print("OK" if p["pid_file"].startswith(tmp) else f"FAIL: {p['pid_file']} not in {tmp}")
PY
)
[ "$result" = "OK" ] && pass "daemon state lives in OS temp" || fail "got: $result"

# ── test 6: is_daemon_alive returns False when PID file missing ─────────────

echo "Test 6: is_daemon_alive without PID file"
result=$(run_py <<'PY'
import learnings_state, tempfile, os
tmp = tempfile.mktemp()
if os.path.exists(tmp):
    os.remove(tmp)
print("OK" if learnings_state.is_daemon_alive(tmp) is False else "FAIL")
PY
)
[ "$result" = "OK" ] && pass "missing PID file → not alive" || fail "got: $result"

# ── test 7: is_daemon_alive detects and removes stale PID ───────────────────

echo "Test 7: is_daemon_alive with stale PID"
result=$(run_py <<'PY'
import learnings_state, tempfile, os
tmp = tempfile.mktemp()
# PID 999999 should not exist
with open(tmp, "w") as f:
    f.write("999999")
alive = learnings_state.is_daemon_alive(tmp)
still_exists = os.path.exists(tmp)
print("OK" if alive is False and not still_exists else f"FAIL alive={alive} exists={still_exists}")
PY
)
[ "$result" = "OK" ] && pass "stale PID detected and file removed" || fail "got: $result"

# ── test 8: counter increments and resets ───────────────────────────────────

echo "Test 8: counter increment/reset"
result=$(run_py <<'PY'
import learnings_state, tempfile, os
tmp = tempfile.mktemp()
try:
    c1 = learnings_state.increment_counter(tmp)
    c2 = learnings_state.increment_counter(tmp)
    c3 = learnings_state.increment_counter(tmp)
    learnings_state.reset_counter(tmp)
    c4 = learnings_state.increment_counter(tmp)
    ok = c1 == 1 and c2 == 2 and c3 == 3 and c4 == 1
    print("OK" if ok else f"FAIL c1={c1} c2={c2} c3={c3} c4={c4}")
finally:
    if os.path.exists(tmp):
        os.remove(tmp)
PY
)
[ "$result" = "OK" ] && pass "counter increments and resets correctly" || fail "got: $result"

# ── test 9: read_daemon_pid returns None for missing/stale PID ──────────────

echo "Test 9: read_daemon_pid with missing file"
result=$(run_py <<'PY'
import learnings_state, tempfile, os
tmp = tempfile.mktemp()
if os.path.exists(tmp):
    os.remove(tmp)
pid = learnings_state.read_daemon_pid(tmp)
print("OK" if pid is None else f"FAIL pid={pid}")
PY
)
[ "$result" = "OK" ] && pass "missing PID file returns None" || fail "got: $result"

# ── summary ─────────────────────────────────────────────────────────────────

echo ""
echo "=== RESULTS ==="
echo "  Passed: $pass_count"
echo "  Failed: $fail_count"

if [ "$fail_count" -gt 0 ]; then
    echo "FAILED"
    exit 1
fi
echo "All tests passed."
