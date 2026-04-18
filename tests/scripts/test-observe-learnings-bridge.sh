#!/usr/bin/env bash
# Tests for hooks/scripts/observe-learnings.py — specifically the
# Layer 1 → Layer 2 bridge (_bridge_to_observer).
#
# We can't easily invoke the hook end-to-end (it launches a real daemon)
# but we can test the pure-function pieces:
#   - counter increments on successive invocations
#   - signal is sent only every SIGNAL_EVERY_N calls
#   - lazy-start is attempted when no daemon exists
#
# These tests stub out subprocess.Popen and os.kill to observe calls.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PYTHON="${REPO_ROOT}/.venv/bin/python3"
MODULE_DIR="${REPO_ROOT}/hooks/scripts"

pass_count=0
fail_count=0
pass() { echo "  PASS: $1"; pass_count=$((pass_count+1)); }
fail() { echo "  FAIL: $1" >&2; fail_count=$((fail_count+1)); }

# ── Test 1: counter increments on each bridge call ──────────────────────────

echo "Test 1: _bridge_to_observer increments counter on each call"
result=$("$VENV_PYTHON" - <<PY
import sys, os, tempfile
sys.path.insert(0, "$MODULE_DIR")

# Set env vars BEFORE importing learnings_state so constants pick them up
os.environ["LEARNINGS_SIGNAL_EVERY_N"] = "5"

# Reload learnings_state with the new env
import importlib
import learnings_state
importlib.reload(learnings_state)

# Stub subprocess.Popen and os.kill to avoid real side effects
import subprocess as _sp
popen_calls = []
kill_calls = []

class FakePopen:
    def __init__(self, *args, **kwargs):
        popen_calls.append(args)

_orig_popen = _sp.Popen
_sp.Popen = FakePopen

import signal as _signal
_orig_kill = os.kill
def fake_kill(pid, sig):
    # Delegate liveness checks (sig=0) to real os.kill; only track real signals
    if sig == 0:
        return _orig_kill(pid, sig)
    kill_calls.append((pid, sig))
os.kill = fake_kill

# Import the bridge function
import importlib.util
spec = importlib.util.spec_from_file_location("observe_module", "$MODULE_DIR/observe-learnings.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# Temp project dir
project_dir = tempfile.mkdtemp()
paths = learnings_state.state_paths(project_dir)

# Clean any prior counter
for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)

# First bridge call: no daemon → should attempt Popen (lazy-start), no SIGUSR1
mod._bridge_to_observer(project_dir)
assert len(popen_calls) == 1, f"expected 1 popen, got {len(popen_calls)}"
assert len(kill_calls) == 0, f"expected 0 real signals on lazy-start, got {len(kill_calls)}"

# Check counter file content
with open(paths["counter_file"]) as f:
    c1 = int(f.read().strip())
assert c1 == 1, f"expected counter=1 after lazy-start, got {c1}"

print("OK")

# Cleanup
for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)
os.kill = _orig_kill
_sp.Popen = _orig_popen
PY
)
[ "$result" = "OK" ] && pass "counter=1 and Popen attempted on first call (no daemon)" || fail "got: $result"

# ── Test 2: subsequent calls with live daemon → counter grows, signal throttled ─

echo "Test 2: signal only fires every N calls"
result=$("$VENV_PYTHON" - <<PY
import sys, os, tempfile
sys.path.insert(0, "$MODULE_DIR")
os.environ["LEARNINGS_SIGNAL_EVERY_N"] = "3"

import importlib
import learnings_state
importlib.reload(learnings_state)

import subprocess as _sp
popen_calls = []
kill_calls = []

class FakePopen:
    def __init__(self, *args, **kwargs):
        popen_calls.append(args)

_sp.Popen = FakePopen

import signal as _signal
_orig_kill = os.kill
def fake_kill(pid, sig):
    # Delegate sig=0 (liveness) to real kernel, only record real signals
    if sig == 0:
        return _orig_kill(pid, sig)
    kill_calls.append((pid, sig))
os.kill = fake_kill

import importlib.util
spec = importlib.util.spec_from_file_location("observe_module", "$MODULE_DIR/observe-learnings.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

project_dir = tempfile.mkdtemp()
paths = learnings_state.state_paths(project_dir)

# Clean
for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)

# Write a fake live daemon PID (use os.getpid() — we're alive)
with open(paths["pid_file"], "w") as f:
    f.write(str(os.getpid()))

# 3 calls — SIGUSR1 should fire exactly once (on the 3rd)
for _ in range(3):
    mod._bridge_to_observer(project_dir)

# Expected: no Popen (daemon is alive), exactly 1 SIGUSR1 (on 3rd call)
ok = len(popen_calls) == 0 and len(kill_calls) == 1
if ok:
    # Counter should have reset after signal
    with open(paths["counter_file"]) as f:
        final = int(f.read().strip())
    ok = (final == 0)

print("OK" if ok else f"FAIL popen={len(popen_calls)} kills={len(kill_calls)}")

# Cleanup
for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)
os.kill = _orig_kill
PY
)
[ "$result" = "OK" ] && pass "signal fires once per N=3 calls, counter resets after" || fail "got: $result"

# ── Test 3: sentinel file gets touched on each call ─────────────────────────

echo "Test 3: sentinel file updated on each observation"
result=$("$VENV_PYTHON" - <<PY
import sys, os, tempfile, time
sys.path.insert(0, "$MODULE_DIR")

import learnings_state
import subprocess as _sp
class FakePopen:
    def __init__(self, *args, **kwargs): pass
_sp.Popen = FakePopen

_orig_kill = os.kill
def fake_kill_t3(pid, sig):
    if sig == 0:
        return _orig_kill(pid, sig)
os.kill = fake_kill_t3

import importlib.util
spec = importlib.util.spec_from_file_location("observe_module", "$MODULE_DIR/observe-learnings.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

project_dir = tempfile.mkdtemp()
paths = learnings_state.state_paths(project_dir)
for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)

mod._bridge_to_observer(project_dir)
exists = os.path.exists(paths["sentinel_file"])
print("OK" if exists else "FAIL sentinel not created")

for p in (paths["pid_file"], paths["counter_file"], paths["sentinel_file"]):
    if os.path.exists(p):
        os.remove(p)
os.kill = _orig_kill
PY
)
[ "$result" = "OK" ] && pass "sentinel file created/touched on bridge call" || fail "got: $result"

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
