"""Auth wall detector — identifies pages requiring human intervention."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field

CAPTCHA_PATTERNS = [
    re.compile(r"\bcaptcha\b", re.IGNORECASE),
    re.compile(r"\brecaptcha\b", re.IGNORECASE),
    re.compile(r"\bhcaptcha\b", re.IGNORECASE),
    re.compile(r"\bturnstile\b", re.IGNORECASE),
]

MFA_PATTERNS = [
    re.compile(r"\bverification\s*code\b", re.IGNORECASE),
    re.compile(r"\botp\b", re.IGNORECASE),
    re.compile(r"\bauthenticator\b", re.IGNORECASE),
    re.compile(r"\btwo.?factor\b", re.IGNORECASE),
    re.compile(r"\b2fa\b", re.IGNORECASE),
    re.compile(r"\bmulti.?factor\b", re.IGNORECASE),
]

OAUTH_PATTERNS = [
    re.compile(r"accounts\.google\.com", re.IGNORECASE),
    re.compile(r"login\.microsoftonline\.com", re.IGNORECASE),
    re.compile(r"github\.com/login/oauth", re.IGNORECASE),
    re.compile(r"appleid\.apple\.com", re.IGNORECASE),
]

PASSWORD_PATTERNS = [
    re.compile(r"\btextbox\b.*\b[Pp]assword\b"),
]

CONSECUTIVE_FAILURE_THRESHOLD = 2


@dataclass
class DetectionResult:
    needs_human: bool
    reason: str = ""
    signals: list[str] = field(default_factory=list)
    suggestion: str = ""


def detect_auth_wall(
    snapshot: str,
    prev_snapshot: str | None = None,
    fail_count: int = 0,
) -> DetectionResult:
    signals: list[str] = []

    for pattern in CAPTCHA_PATTERNS:
        if pattern.search(snapshot):
            signals.append(f"CAPTCHA pattern matched: {pattern.pattern}")
            return DetectionResult(
                needs_human=True,
                reason="captcha_detected",
                signals=signals,
                suggestion="Page contains CAPTCHA verification. Please complete it in the browser.",
            )

    for pattern in MFA_PATTERNS:
        if pattern.search(snapshot):
            signals.append(f"MFA pattern matched: {pattern.pattern}")
            return DetectionResult(
                needs_human=True,
                reason="mfa_detected",
                signals=signals,
                suggestion="Page requires multi-factor authentication. Please complete verification in the browser.",
            )

    for pattern in OAUTH_PATTERNS:
        if pattern.search(snapshot):
            signals.append(f"OAuth provider detected: {pattern.pattern}")
            return DetectionResult(
                needs_human=True,
                reason="oauth_redirect",
                signals=signals,
                suggestion="Page redirected to OAuth provider. Please complete authentication in the browser.",
            )

    if prev_snapshot is not None and fail_count >= CONSECUTIVE_FAILURE_THRESHOLD:
        if snapshot.strip() == prev_snapshot.strip():
            signals.append(f"Snapshot unchanged after {fail_count} operations")
            return DetectionResult(
                needs_human=True,
                reason="consecutive_failures",
                signals=signals,
                suggestion="Page has not changed after multiple operations. It may require human intervention.",
            )

    for pattern in PASSWORD_PATTERNS:
        if pattern.search(snapshot):
            signals.append("Password field detected (low weight, not triggering)")

    return DetectionResult(needs_human=False, reason="", signals=signals)


def main() -> None:
    parser = argparse.ArgumentParser(prog="auth-detector")
    parser.add_argument("--prev-snapshot", help="Path to previous snapshot file")
    parser.add_argument(
        "--fail-count", type=int, default=0, help="Consecutive no-change count"
    )
    args = parser.parse_args()

    snapshot = sys.stdin.read()

    prev_snapshot = None
    if args.prev_snapshot:
        with open(args.prev_snapshot) as f:
            prev_snapshot = f.read()

    result = detect_auth_wall(
        snapshot, prev_snapshot=prev_snapshot, fail_count=args.fail_count
    )
    output = {
        "needs_human": result.needs_human,
        "reason": result.reason,
        "signals": result.signals,
        "suggestion": result.suggestion,
    }
    print(json.dumps(output, indent=2))
