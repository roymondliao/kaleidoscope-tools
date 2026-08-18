"""URL validator — blocks dangerous schemes and cloud metadata endpoints."""

from __future__ import annotations

import argparse
import ipaddress
import socket
import sys
from dataclasses import dataclass
from urllib.parse import urlparse

ALLOWED_SCHEMES = frozenset({"http", "https"})

LOCALHOST_ADDRESSES = frozenset(
    {
        "127.0.0.1",
        "0.0.0.0",
        "::1",
        "localhost",
    }
)

METADATA_IPS = frozenset(
    {
        ipaddress.ip_address("169.254.169.254"),
        ipaddress.ip_address("fd00::"),
    }
)

METADATA_HOSTNAMES = frozenset(
    {
        "metadata.google.internal",
        "metadata.azure.internal",
    }
)


@dataclass
class ValidationResult:
    allowed: bool
    reason: str = ""


def _is_metadata_ip(ip_str: str) -> bool:
    try:
        addr = ipaddress.ip_address(ip_str)
    except ValueError:
        return False
    return addr in METADATA_IPS or addr.is_link_local


def validate_url(url: str) -> ValidationResult:
    if not url:
        return ValidationResult(False, "Empty URL")
    try:
        parsed = urlparse(url)
    except Exception:
        return ValidationResult(False, "Malformed URL")
    if parsed.scheme not in ALLOWED_SCHEMES:
        return ValidationResult(
            False, f"Blocked scheme: {parsed.scheme!r}. Only http and https allowed."
        )
    hostname = parsed.hostname
    if not hostname:
        return ValidationResult(False, "No hostname in URL")
    if hostname in LOCALHOST_ADDRESSES:
        return ValidationResult(True)
    if hostname in METADATA_HOSTNAMES:
        return ValidationResult(False, f"Blocked cloud metadata hostname: {hostname}")
    if _is_metadata_ip(hostname):
        return ValidationResult(False, f"Blocked cloud metadata IP: {hostname}")
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        results = socket.getaddrinfo(hostname, port)
    except OSError:
        return ValidationResult(False, f"Could not resolve hostname: {hostname}")
    for _family, _type, _proto, _canonname, sockaddr in results:
        ip_str = str(sockaddr[0])
        if _is_metadata_ip(ip_str):
            return ValidationResult(
                False, f"Blocked: {hostname} resolves to cloud metadata IP {ip_str}"
            )
    return ValidationResult(True)


def main() -> None:
    parser = argparse.ArgumentParser(prog="url-validator")
    parser.add_argument("url", help="URL to validate")
    args = parser.parse_args()
    result = validate_url(args.url)
    if result.allowed:
        print("OK", file=sys.stdout)
        sys.exit(0)
    else:
        print(f"BLOCKED: {result.reason}", file=sys.stderr)
        sys.exit(1)
