#!/usr/bin/env python3
"""Run eval/scenarios.jsonl against Claude Code headless, baseline vs. communication-contract.

No API key needed - runs through the normal subscription (OAuth) login,
the same one used by an interactive session. This intentionally does NOT
pass --bare, so it loads this repo's real .claude/settings.json, CLAUDE.md,
and AGENTS.md for both conditions:

  baseline:                 whatever outputStyle settings.json currently sets
  communication-contract:   same, with outputStyle overridden via --settings

That means CLAUDE.md/AGENTS.md apply equally to both arms (a constant, not a
confound), and this measures the contract layered onto the real project
setup - not the contract in isolation. Each call still counts against your
Claude Code Pro/Max usage quota, even though no per-token bill is issued.

Usage:
  python3 eval/run_eval.py
  python3 eval/run_eval.py --concurrency 6
  python3 eval/run_eval.py --only l0-blocker-not-dropped ov-destructive
"""
import argparse
import asyncio
import json
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCENARIOS_PATH = REPO_ROOT / "eval" / "scenarios.jsonl"
STYLE_PATH = REPO_ROOT / ".claude" / "output-styles" / "communication-contract.md"

CONDITIONS = {
    "baseline": [],
    "communication-contract": ["--settings", '{"outputStyle":"communication-contract"}'],
}


def load_scenarios(path, only_ids):
    scenarios = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            scenario = json.loads(line)
            if only_ids is None or scenario["id"] in only_ids:
                scenarios.append(scenario)
    return scenarios


async def run_one(scenario, condition, extra_args, semaphore):
    cmd = [
        "claude", "-p", scenario["prompt"],
        "--output-format", "json",
        "--permission-mode", "dontAsk",
        *extra_args,
    ]
    async with semaphore:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=REPO_ROOT,
        )
        stdout, stderr = await proc.communicate()

    record = {
        "id": scenario["id"],
        "condition": condition,
        "layer": scenario.get("layer"),
        "section": scenario.get("section"),
        "context": scenario.get("context"),
        "prompt": scenario["prompt"],
        "expected_signal": scenario.get("expected_signal"),
        "returncode": proc.returncode,
    }
    if proc.returncode == 0:
        try:
            payload = json.loads(stdout.decode())
            record["result"] = payload.get("result")
            record["session_id"] = payload.get("session_id")
            record["total_cost_usd"] = payload.get("total_cost_usd")
        except json.JSONDecodeError:
            record["error"] = "invalid_json_output"
            record["raw_stdout"] = stdout.decode(errors="replace")[:2000]
    else:
        record["error"] = stderr.decode(errors="replace")[:2000]
    return record


async def main_async(concurrency, only_ids):
    if not STYLE_PATH.exists():
        print(f"Style file not found: {STYLE_PATH}", file=sys.stderr)
        sys.exit(1)

    scenarios = load_scenarios(SCENARIOS_PATH, only_ids)
    if not scenarios:
        print("No matching scenarios.", file=sys.stderr)
        sys.exit(1)

    results_dir = REPO_ROOT / "eval" / "results" / time.strftime("%Y%m%d-%H%M%S")
    results_dir.mkdir(parents=True, exist_ok=True)
    out_path = results_dir / "results.jsonl"

    semaphore = asyncio.Semaphore(concurrency)
    tasks = [
        run_one(scenario, condition, extra_args, semaphore)
        for scenario in scenarios
        for condition, extra_args in CONDITIONS.items()
    ]

    total_cost = 0.0
    failures = 0
    with open(out_path, "w") as out:
        for coro in asyncio.as_completed(tasks):
            record = await coro
            out.write(json.dumps(record) + "\n")
            out.flush()
            cost = record.get("total_cost_usd") or 0
            total_cost += cost
            ok = record["returncode"] == 0
            failures += 0 if ok else 1
            status = "ok" if ok else "FAIL"
            print(f"[{status}] {record['condition']:24s} {record['id']} (~${cost:.4f} equiv)")

    print(f"\n{len(tasks)} runs complete, {failures} failed.")
    print(f"~${total_cost:.4f} equivalent API cost (billed as Pro/Max quota usage, not cash).")
    print(f"Results: {out_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--concurrency", type=int, default=4, help="Max concurrent subprocess calls (default: 4)")
    parser.add_argument("--only", nargs="*", default=None, help="Run only these scenario ids")
    args = parser.parse_args()
    only_ids = set(args.only) if args.only else None
    asyncio.run(main_async(args.concurrency, only_ids))


if __name__ == "__main__":
    main()
