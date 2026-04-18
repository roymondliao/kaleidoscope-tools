#!/usr/bin/env bash
# Tests for hooks/scripts/invoke-observer.py
# Tests the testable units without actually invoking `claude` CLI:
#   - _read_observations parses JSONL correctly
#   - _load_active_learnings filters by status
#   - _build_analysis_prompt includes existing learnings + observations
#   - _archive_observations moves processed batch
#   - _rebuild_index produces correct index.yaml from .md files
#   - --rebuild-only skips claude invocation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_PYTHON="${REPO_ROOT}/.venv/bin/python3"
MODULE_DIR="${REPO_ROOT}/hooks/scripts"

pass_count=0
fail_count=0
pass() { echo "  PASS: $1"; pass_count=$((pass_count+1)); }
fail() { echo "  FAIL: $1" >&2; fail_count=$((fail_count+1)); }

# Helper to load invoke-observer.py as a module
load_module_code='
import sys, os, tempfile, importlib.util
sys.path.insert(0, "'"$MODULE_DIR"'")
spec = importlib.util.spec_from_file_location("invoker", "'"$MODULE_DIR"'/invoke-observer.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
'

# ── Test 1: _read_observations parses JSONL correctly ───────────────────────

echo "Test 1: _read_observations parses JSONL"
result=$("$VENV_PYTHON" - <<PY
$load_module_code
tmp = tempfile.mktemp(suffix=".jsonl")
with open(tmp, "w") as f:
    f.write('{"timestamp":"2026-04-17T10:00:00Z","content":"hello"}\n')
    f.write('{"timestamp":"2026-04-17T10:01:00Z","content":"world"}\n')
    f.write('\n')  # blank line — should be skipped
    f.write('{broken json}\n')  # malformed — should be skipped
obs = mod._read_observations(tmp)
print("OK" if len(obs) == 2 and obs[0]["content"] == "hello" else f"FAIL len={len(obs)}")
os.remove(tmp)
PY
)
[ "$result" = "OK" ] && pass "parses valid JSONL, skips blanks and malformed" || fail "got: $result"

# ── Test 2: _load_active_learnings filters by status ───────────────────────

echo "Test 2: _load_active_learnings filters correctly"
result=$("$VENV_PYTHON" - <<PY
$load_module_code
tmp = tempfile.mkdtemp()
# Create 3 .md files: 1 active, 1 invalidated, 1 archived
for name, status in [("a", "active"), ("b", "invalidated"), ("c", "archived")]:
    with open(os.path.join(tmp, f"2026-04-17_{name}.md"), "w") as f:
        f.write(f"""---
id: 2026-04-17_{name}
domain: tooling
trigger: "When {name}"
status: {status}
created: 2026-04-17
last_validated: 2026-04-17
---

# {name}
## What went wrong
Thing {name} happened.

## Correct approach
Fix {name}.
""")
active = mod._load_active_learnings(tmp)
ok = len(active) == 1 and active[0]["id"] == "2026-04-17_a"
print("OK" if ok else f"FAIL: {active}")
PY
)
[ "$result" = "OK" ] && pass "only active learnings loaded" || fail "got: $result"

# ── Test 3: _build_analysis_prompt includes existing learnings ─────────────

echo "Test 3: prompt includes existing active learnings"
result=$("$VENV_PYTHON" - <<PY
$load_module_code
tmp = tempfile.mkdtemp()
with open(os.path.join(tmp, "2026-04-17_x.md"), "w") as f:
    f.write("""---
id: 2026-04-17_x
domain: tooling
trigger: "When X"
status: active
created: 2026-04-17
last_validated: 2026-04-17
---

# x
## What went wrong
Thing x happened.

## Correct approach
Fix x.
""")
observations = [{"timestamp":"T","content":"test obs"}]
prompt = mod._build_analysis_prompt(observations, tmp)
# Prompt should mention the existing learning id AND the observations
ok = "2026-04-17_x" in prompt and "test obs" in prompt
# And should include the classification rules
ok = ok and "NEW" in prompt and "SUPERSEDES" in prompt and "REINFORCES" in prompt
ok = ok and "status: active" in prompt  # new design: writes active directly
print("OK" if ok else f"FAIL: prompt snippet: {prompt[:500]}")
PY
)
[ "$result" = "OK" ] && pass "prompt includes existing learnings + classification rules" || fail "got: $result"

# ── Test 4: _archive_observations moves batch, leaves remainder ────────────

echo "Test 4: _archive_observations moves processed batch"
result=$("$VENV_PYTHON" - <<PY
$load_module_code
tmp = tempfile.mkdtemp()
obs_file = os.path.join(tmp, "observations.jsonl")
with open(obs_file, "w") as f:
    for i in range(5):
        f.write(f'{{"idx":{i}}}\n')

mod._archive_observations(obs_file, tmp, 3)

# Remaining 2 entries in obs_file
with open(obs_file) as f:
    remaining = [l for l in f if l.strip()]
if len(remaining) != 2:
    print(f"FAIL remaining={len(remaining)}")
else:
    # Archive file should have 3
    archive_dir = os.path.join(tmp, "observations.archive")
    archives = [f for f in os.listdir(archive_dir) if f.startswith("analyzed-")]
    if len(archives) != 1:
        print(f"FAIL archives={len(archives)}")
    else:
        with open(os.path.join(archive_dir, archives[0])) as f:
            archived = [l for l in f if l.strip()]
        print("OK" if len(archived) == 3 else f"FAIL archived={len(archived)}")
PY
)
[ "$result" = "OK" ] && pass "3 entries archived, 2 remain in obs_file" || fail "got: $result"

# ── Test 5: _rebuild_index only includes active entries ────────────────────

echo "Test 5: rebuild_index filters by status"
result=$("$VENV_PYTHON" - <<PY | tail -1
$load_module_code
tmp = tempfile.mkdtemp()
for name, status in [("a", "active"), ("b", "invalidated"), ("c", "archived")]:
    with open(os.path.join(tmp, f"2026-04-17_{name}.md"), "w") as f:
        f.write(f"""---
id: 2026-04-17_{name}
domain: tooling
trigger: "When {name}"
status: {status}
created: 2026-04-17
last_validated: 2026-04-17
---

# {name}
## What went wrong
Sentence about {name}.
""")

mod._rebuild_index(tmp)

import yaml
with open(os.path.join(tmp, "index.yaml")) as f:
    idx = yaml.safe_load(f)

ok = (idx["active_count"] == 1 and
      idx["archived_count"] == 1 and
      len(idx["entries"]) == 1 and
      idx["entries"][0]["id"] == "2026-04-17_a")
print("OK" if ok else f"FAIL: {idx}")
PY
)
[ "$result" = "OK" ] && pass "rebuilt index only contains active entries" || fail "got: $result"

# ── Test 6: --rebuild-only mode skips observation reading ──────────────────

echo "Test 6: --rebuild-only mode"
result=$("$VENV_PYTHON" - <<PY
import subprocess, tempfile, os, sys
tmp = tempfile.mkdtemp()
learnings_dir = os.path.join(tmp, ".learnings")
os.makedirs(learnings_dir)

# Create a learning without index
with open(os.path.join(learnings_dir, "2026-04-17_x.md"), "w") as f:
    f.write("""---
id: 2026-04-17_x
domain: tooling
trigger: "When X"
status: active
created: 2026-04-17
last_validated: 2026-04-17
---

# x
## What went wrong
Thing x happened.
""")

# Run with --rebuild-only
result = subprocess.run(
    ["$VENV_PYTHON", "$MODULE_DIR/invoke-observer.py", "--rebuild-only", tmp],
    capture_output=True, text=True, timeout=10
)

# Should exit 0 and create index.yaml
index_exists = os.path.exists(os.path.join(learnings_dir, "index.yaml"))
ok = result.returncode == 0 and index_exists
print("OK" if ok else f"FAIL exit={result.returncode} index={index_exists} stdout={result.stdout[:300]}")
PY
)
[ "$result" = "OK" ] && pass "--rebuild-only exits 0 and rebuilds index" || fail "got: $result"

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
