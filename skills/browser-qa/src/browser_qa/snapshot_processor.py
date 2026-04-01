"""Snapshot processor — filter, diff, and staleness checking for accessibility tree snapshots."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from dataclasses import dataclass, field

INTERACTIVE_ROLES = frozenset(
    {
        "button",
        "link",
        "textbox",
        "checkbox",
        "radio",
        "select",
        "slider",
        "switch",
        "tab",
        "menuitem",
        "combobox",
        "option",
        "searchbox",
        "spinbutton",
    }
)

LINE_PATTERN = re.compile(
    r"^(?P<indent>\s*)uid=(?P<uid>\S+)\s+(?P<role>\S+)(?:\s+(?P<rest>.*))?$"
)


@dataclass
class SnapshotNode:
    uid: str
    role: str
    raw_line: str
    indent: int
    children: list[SnapshotNode] = field(default_factory=list)

    @property
    def is_interactive(self) -> bool:
        return self.role in INTERACTIVE_ROLES

    @property
    def has_inline_text(self) -> bool:
        rest = LINE_PATTERN.match(self.raw_line)
        if rest and rest.group("rest"):
            return bool(rest.group("rest").strip())
        return False


def parse_snapshot_tree(text: str) -> list[SnapshotNode]:
    nodes: list[SnapshotNode] = []
    stack: list[SnapshotNode] = []
    for line in text.strip().split("\n"):
        m = LINE_PATTERN.match(line)
        if not m:
            continue
        indent = len(m.group("indent"))
        node = SnapshotNode(
            uid=m.group("uid"),
            role=m.group("role"),
            raw_line=line.rstrip(),
            indent=indent,
        )
        while stack and stack[-1].indent >= indent:
            stack.pop()
        if stack:
            stack[-1].children.append(node)
        else:
            nodes.append(node)
        stack.append(node)
    return nodes


def _has_interactive_descendant(node: SnapshotNode) -> bool:
    if node.is_interactive:
        return True
    return any(_has_interactive_descendant(c) for c in node.children)


def _is_empty_structural(node: SnapshotNode) -> bool:
    return len(node.children) == 0 and not node.has_inline_text


def _filter_tree(
    nodes: list[SnapshotNode], interactive: bool, compact: bool
) -> list[SnapshotNode]:
    result = []
    for node in nodes:
        filtered_children = _filter_tree(node.children, interactive, compact)
        keep = True
        if (
            interactive
            and not node.is_interactive
            and not any(_has_interactive_descendant(c) for c in node.children)
        ):
            keep = False
        if compact and _is_empty_structural(node) and not node.is_interactive:
            keep = False
        if keep:
            new_node = SnapshotNode(
                uid=node.uid,
                role=node.role,
                raw_line=node.raw_line,
                indent=node.indent,
                children=filtered_children,
            )
            result.append(new_node)
    return result


def _tree_to_text(nodes: list[SnapshotNode]) -> str:
    lines = []
    for node in nodes:
        lines.append(node.raw_line)
        lines.extend(_tree_to_text(node.children).split("\n"))
    return "\n".join(line for line in lines if line)


def filter_snapshot(text: str, interactive: bool = False, compact: bool = False) -> str:
    tree = parse_snapshot_tree(text)
    filtered = _filter_tree(tree, interactive, compact)
    return _tree_to_text(filtered)


def diff_snapshots(previous: str, current: str) -> str:
    prev_lines = previous.strip().split("\n")
    curr_lines = current.strip().split("\n")
    diff_lines = list(
        difflib.unified_diff(
            prev_lines, curr_lines, fromfile="previous", tofile="current", lineterm=""
        )
    )
    result = []
    for line in diff_lines:
        marker = ""
        if line.startswith("+") and not line.startswith("+++"):
            m = LINE_PATTERN.match(line[1:])
            if m and m.group("role") in INTERACTIVE_ROLES:
                marker = " [NEW]"
        elif line.startswith("-") and not line.startswith("---"):
            m = LINE_PATTERN.match(line[1:])
            if m and m.group("role") in INTERACTIVE_ROLES:
                marker = " [GONE]"
        result.append(line + marker)
    return "\n".join(result)


def check_staleness(uids: list[str], current_snapshot: str) -> dict:
    valid = []
    stale = []
    for uid in uids:
        pattern = re.compile(rf"\buid={re.escape(uid)}\b")
        if pattern.search(current_snapshot):
            valid.append(uid)
        else:
            stale.append(uid)
    return {"valid": valid, "stale": stale}


def main() -> None:
    parser = argparse.ArgumentParser(prog="snapshot-processor")
    subparsers = parser.add_subparsers(dest="command", required=True)

    filter_parser = subparsers.add_parser("filter", help="Filter snapshot tree")
    filter_parser.add_argument(
        "-i",
        "--interactive",
        action="store_true",
        help="Keep only interactive elements",
    )
    filter_parser.add_argument(
        "-c", "--compact", action="store_true", help="Remove empty structural nodes"
    )

    diff_parser = subparsers.add_parser("diff", help="Diff two snapshots")
    diff_parser.add_argument(
        "--previous", required=True, help="Path to previous snapshot file"
    )
    diff_parser.add_argument(
        "--current", required=True, help="Path to current snapshot file"
    )

    stale_parser = subparsers.add_parser("staleness", help="Check UID staleness")
    stale_parser.add_argument(
        "--uids", required=True, help="Comma-separated UIDs to check"
    )
    stale_parser.add_argument(
        "--current", required=True, help="Path to current snapshot file"
    )

    args = parser.parse_args()

    if args.command == "filter":
        text = sys.stdin.read()
        print(filter_snapshot(text, interactive=args.interactive, compact=args.compact))
    elif args.command == "diff":
        with open(args.previous) as f:
            prev = f.read()
        with open(args.current) as f:
            curr = f.read()
        print(diff_snapshots(prev, curr))
    elif args.command == "staleness":
        uids = [u.strip() for u in args.uids.split(",")]
        with open(args.current) as f:
            curr = f.read()
        print(json.dumps(check_staleness(uids, curr)))
