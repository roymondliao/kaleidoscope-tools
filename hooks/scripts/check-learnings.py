#!/usr/bin/env python3
"""
check-learnings.py — Parse .learnings/index.yaml, detect corruption signatures,
and output session context.

Called by hooks/check-learnings.sh (thin bash wrapper).

Output protocol (newline-delimited):
  STATUS:<ok|malformed|empty|missing_entries_key|python_no_yaml>
  COUNT:<n>                      (only when STATUS:ok)
  MISSING_COUNT:<n>              (only when STATUS:ok)
  ENTRY:<domain>|<one_liner>     (one per present entry)
  MISSING_ID:<id>                (one per missing .md file)
  CORRUPTION:<signature>|<value> (zero or more — see Corruption section)

Exit: always 0 (errors communicated via STATUS line).
"""

import sys
import os
from datetime import datetime, timezone, timedelta


# Corruption signature thresholds (see issues.md "Corruption Signatures")
CONTRADICTION_WINDOW_DAYS = 30
CONTRADICTION_THRESHOLD = 2  # > this many supersedes in 30d warns
MONOTONE_GROWTH_DAYS = (
    14  # active count growing this long without any invalidation warns
)
STALE_LEARNING_DAYS = 90  # last_validated older than this flags as stale


def _parse_frontmatter(filepath: str, yaml_module) -> tuple[dict, str] | None:
    """Return (frontmatter_dict, body_text) or None on failure."""
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except IOError:
        return None

    if not content.startswith("---"):
        return None
    end = content.find("\n---", 3)
    if end == -1:
        return None

    try:
        fm = yaml_module.safe_load(content[3:end].strip())
    except yaml_module.YAMLError:
        return None
    if not isinstance(fm, dict):
        return None
    return fm, content[end + 4 :].strip()


def _compute_corruption_signatures(
    learnings_dir: str, yaml_module
) -> list[tuple[str, str]]:
    """
    Scan .learnings/*.md and compute corruption signatures.
    Returns list of (signature_name, value) tuples. Empty list = no warnings.
    """
    signatures: list[tuple[str, str]] = []

    if not os.path.isdir(learnings_dir):
        return signatures

    active_count = 0
    invalidated_count = 0
    recent_invalidations = 0
    contradictions_in_window = 0
    stale_active_count = 0

    window_cutoff = (
        datetime.now(timezone.utc) - timedelta(days=CONTRADICTION_WINDOW_DAYS)
    ).date()
    stale_cutoff = (
        datetime.now(timezone.utc) - timedelta(days=STALE_LEARNING_DAYS)
    ).date()

    for fname in os.listdir(learnings_dir):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(learnings_dir, fname)
        parsed = _parse_frontmatter(fpath, yaml_module)
        if parsed is None:
            continue
        fm, _body = parsed

        status = str(fm.get("status", "")).lower()
        classification = str(fm.get("classification", "")).lower()

        if status == "active":
            active_count += 1
            # Check if this active learning supersedes another (contradiction signal)
            if classification.startswith("supersedes"):
                created = fm.get("created")
                if _is_within_window(created, window_cutoff):
                    contradictions_in_window += 1
            # Check staleness
            last_val = fm.get("last_validated")
            if _is_before(last_val, stale_cutoff):
                stale_active_count += 1

        elif status == "invalidated":
            invalidated_count += 1
            # Count recent invalidations (indicates active maintenance)
            last_val = fm.get("last_validated")
            if _is_within_window(last_val, window_cutoff):
                recent_invalidations += 1

    # Signature 1: contradiction rate
    if contradictions_in_window > CONTRADICTION_THRESHOLD:
        signatures.append(
            (
                "contradiction_rate",
                f"{contradictions_in_window} supersedes in last {CONTRADICTION_WINDOW_DAYS}d",
            )
        )

    # Signature 2: monotone growth (active count > 0, zero invalidations ever)
    # This is the 'suspicious zero' — if system has been running long enough to
    # accumulate learnings but nothing has ever been invalidated, observer might
    # be silently creating duplicates instead of superseding
    if active_count >= 10 and invalidated_count == 0:
        signatures.append(
            (
                "monotone_growth",
                f"{active_count} active, zero invalidations — possible duplicate creation",
            )
        )

    # Signature 3: stale learnings
    if stale_active_count > 0 and active_count > 0:
        ratio = (stale_active_count * 100) // active_count
        if ratio > 50:
            signatures.append(
                (
                    "stale_learnings",
                    f"{stale_active_count}/{active_count} active learnings not validated in {STALE_LEARNING_DAYS}d",
                )
            )

    return signatures


def _is_within_window(date_value: object, cutoff_date: object) -> bool:
    """True if date_value (YYYY-MM-DD or date obj) is on or after cutoff_date."""
    if date_value is None:
        return False
    try:
        if isinstance(date_value, str):
            d = datetime.strptime(date_value, "%Y-%m-%d").date()
        else:
            d = date_value
        return d >= cutoff_date
    except (ValueError, TypeError):
        return False


def _is_before(date_value: object, cutoff_date: object) -> bool:
    """True if date_value is strictly before cutoff_date."""
    if date_value is None:
        return True  # missing last_validated = treat as stale
    try:
        if isinstance(date_value, str):
            d = datetime.strptime(date_value, "%Y-%m-%d").date()
        else:
            d = date_value
        return d < cutoff_date
    except (ValueError, TypeError):
        return True


def main() -> None:
    if len(sys.argv) < 3:
        print("STATUS:malformed")
        return

    index_file = sys.argv[1]
    learnings_dir = sys.argv[2]

    try:
        import yaml
    except ImportError:
        print("STATUS:python_no_yaml")
        return

    # Read and parse index.yaml
    try:
        with open(index_file, "r", encoding="utf-8") as f:
            raw = f.read()
        data = yaml.safe_load(raw)
    except Exception:
        print("STATUS:malformed")
        return

    if not isinstance(data, dict):
        print("STATUS:malformed")
        return

    entries = data.get("entries")

    if entries is None:
        print("STATUS:missing_entries_key")
        return

    if not isinstance(entries, list):
        print("STATUS:malformed")
        return

    if len(entries) == 0:
        print("STATUS:empty")
        # Even when empty, emit corruption signatures (e.g., monotone_growth =
        # 0, but if there are many invalidated files with no active ones, that
        # might warrant future heuristics)
        for sig, val in _compute_corruption_signatures(learnings_dir, yaml):
            print(f"CORRUPTION:{sig}|{val}")
        return

    print("STATUS:ok")
    print(f"COUNT:{len(entries)}")

    missing_count = 0
    for entry in entries:
        if not isinstance(entry, dict):
            continue

        entry_id = entry.get("id", "")
        domain = entry.get("domain", "")
        one_liner = str(entry.get("one_liner", "")).strip()

        # Check backing .md file exists
        found = False
        try:
            for fname in os.listdir(learnings_dir):
                if not fname.endswith(".md"):
                    continue
                if str(entry_id) in fname:
                    found = True
                    break
        except OSError:
            pass

        if not found:
            missing_count += 1
            print(f"MISSING_ID:{entry_id}")
            continue

        domain_safe = domain.replace("|", "/")
        one_liner_safe = one_liner.replace("\n", " ").replace("\r", "")
        print(f"ENTRY:{domain_safe}|{one_liner_safe}")

    print(f"MISSING_COUNT:{missing_count}")

    # Corruption signatures
    for sig, val in _compute_corruption_signatures(learnings_dir, yaml):
        val_safe = val.replace("|", "/").replace("\n", " ")
        print(f"CORRUPTION:{sig}|{val_safe}")


if __name__ == "__main__":
    main()
