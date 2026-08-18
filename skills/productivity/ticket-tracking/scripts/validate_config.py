#!/usr/bin/env python3
"""Validate a ticket-tracking config file.

Usage: uv run python validate_config.py <config-path>
Exit: 0 and "VALID: <path>" if valid; 1 and "INVALID: <path>" plus a list
of problems on stderr otherwise. Mirrors the exit-code / message contract
used by skills/research/deliberate-consensus/scripts/validate-artifact.sh.
"""

import json
import re
import sys

KNOWN_PLATFORMS = {"jira", "linear"}
KNOWN_SCOPES = {"global", "project"}
SECRET_KEY_PATTERN = re.compile(r"(token|secret|password|api[_-]?key|credential)", re.IGNORECASE)


def collect_secret_like_keys(obj, path=""):
    found = []
    if isinstance(obj, dict):
        for key, value in obj.items():
            key_path = f"{path}.{key}" if path else key
            if SECRET_KEY_PATTERN.search(key):
                found.append(key_path)
            found.extend(collect_secret_like_keys(value, key_path))
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            found.extend(collect_secret_like_keys(item, f"{path}[{i}]"))
    return found


def validate(config: dict) -> list[str]:
    errors = []

    if "scope" in config:
        if config["scope"] not in KNOWN_SCOPES:
            errors.append(f"'scope' must be one of {sorted(KNOWN_SCOPES)}, got {config['scope']!r}")

    platforms = config.get("platforms")
    if platforms is None:
        errors.append("missing required key 'platforms'")
    elif not isinstance(platforms, dict) or not platforms:
        errors.append("'platforms' must be a non-empty object")
    else:
        enabled_keys = []
        for name, entry in platforms.items():
            if name not in KNOWN_PLATFORMS:
                errors.append(f"unknown platform '{name}' (known: {sorted(KNOWN_PLATFORMS)})")
                continue
            if not isinstance(entry, dict):
                errors.append(f"platforms.{name} must be an object")
                continue
            if "enabled" not in entry or not isinstance(entry["enabled"], bool):
                errors.append(f"platforms.{name}.enabled is required and must be a boolean")
                continue
            if entry["enabled"]:
                enabled_keys.append(name)
            if "label" in entry and not isinstance(entry["label"], str):
                errors.append(f"platforms.{name}.label must be a string")
            if "defaults" in entry and not isinstance(entry["defaults"], dict):
                errors.append(f"platforms.{name}.defaults must be an object")

        if platforms and not enabled_keys:
            errors.append("at least one platform under 'platforms' must have enabled: true")

        default_platform = config.get("default_platform")
        if default_platform is not None:
            if default_platform not in platforms:
                errors.append(f"'default_platform' ({default_platform!r}) is not one of the declared platforms")
            elif default_platform not in enabled_keys:
                errors.append(f"'default_platform' ({default_platform!r}) must refer to a platform with enabled: true")

    secret_like = collect_secret_like_keys(config)
    if secret_like:
        errors.append(
            "credentials do not belong in this config (MCP servers hold those); "
            f"suspicious key name(s): {', '.join(secret_like)}"
        )

    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_config.py <config-path>", file=sys.stderr)
        return 1

    path = sys.argv[1]

    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read()
    except OSError as e:
        print(f"ERROR: cannot read {path}: {e}", file=sys.stderr)
        return 1

    try:
        config = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"INVALID: {path}", file=sys.stderr)
        print(f"  - not valid JSON: {e}", file=sys.stderr)
        return 1

    if not isinstance(config, dict):
        print(f"INVALID: {path}", file=sys.stderr)
        print("  - top level must be a JSON object", file=sys.stderr)
        return 1

    errors = validate(config)
    if errors:
        print(f"INVALID: {path}", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"VALID: {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
