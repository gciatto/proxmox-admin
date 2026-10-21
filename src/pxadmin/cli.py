"""Read-only Proxmox cluster inspection, suitable for scripts and interactive use."""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from pxadmin import snapshot


@dataclass(frozen=True)
class Config:
    host: str
    port: int
    user: str
    token_id: str
    token_secret: str
    verify_ssl: bool

    @classmethod
    def from_env(cls) -> "Config":
        host = os.environ.get("PROXMOX_HOST", "").strip()
        token_id = os.environ.get("PROXMOX_TOKEN_ID", "").strip()
        token_secret = os.environ.get("PROXMOX_TOKEN_SECRET", "").strip()
        token_path = os.environ.get("PROXMOX_TOKEN_SECRET_FILE", "")
        if not token_secret and token_path and Path(token_path).is_file():
            token_secret = Path(token_path).read_text(encoding="utf-8").strip()
        user = os.environ.get("PROXMOX_USER", "").strip()
        if not user and "!" in token_id:
            user = token_id.split("!", 1)[0]

        missing = [name for name, value in (
            ("PROXMOX_HOST", host),
            ("PROXMOX_TOKEN_ID", token_id),
            ("API token secret file", token_secret),
        ) if not value]
        if missing:
            raise ValueError("Missing API configuration: " + ", ".join(missing))
        if "!" not in token_id or not user or token_id.split("!", 1)[0] != user:
            raise ValueError("PROXMOX_TOKEN_ID must be user@realm!tokenname and match PROXMOX_USER")
        try:
            port = int(os.environ.get("PROXMOX_PORT", "8006"))
        except ValueError as exc:
            raise ValueError("PROXMOX_PORT must be an integer") from exc
        if not (1 <= port <= 65535):
            raise ValueError("PROXMOX_PORT must be between 1 and 65535")

        verify_ssl = os.environ.get("PROXMOX_VALIDATE_CERTS", "true").lower() not in {
            "false", "0", "no"
        }
        return cls(host, port, user, token_id, token_secret, verify_ssl)


def connect(config: Config) -> Any:
    from proxmoxer import ProxmoxAPI

    token_name = config.token_id.split("!", 1)[1]
    return ProxmoxAPI(
        config.host,
        user=config.user,
        token_name=token_name,
        token_value=config.token_secret,
        port=config.port,
        verify_ssl=config.verify_ssl,
        timeout=15,
    )


def print_result(data: Any, json_mode: bool) -> None:
    if json_mode:
        print(json.dumps(data, indent=2, sort_keys=True, default=str))
        return
    if isinstance(data, list):
        if not data:
            print("(no entries)")
            return
        preferred = ("name", "node", "vmid", "realm", "userid", "groupid", "poolid", "storage",
                     "iface", "sid", "path", "type", "status", "online", "id")
        fields = [key for key in preferred if any(isinstance(item, dict) and key in item for item in data)]
        if not fields:
            print(json.dumps(data, indent=2, sort_keys=True, default=str))
            return
        widths = {field: max(len(field), *(len(str(item.get(field, ""))) for item in data if isinstance(item, dict))) for field in fields}
        print("  ".join(field.ljust(widths[field]) for field in fields))
        print("  ".join("-" * widths[field] for field in fields))
        for item in data:
            print("  ".join(str(item.get(field, "")).ljust(widths[field]) for field in fields))
    else:
        print(json.dumps(data, indent=2, sort_keys=True, default=str))


def doctor() -> int:
    host = os.environ.get("PROXMOX_HOST", "")
    token_id = os.environ.get("PROXMOX_TOKEN_ID", "")
    token_path = Path(os.environ.get("PROXMOX_TOKEN_SECRET_FILE", "/run/secrets/proxmox-token"))
    ssh_dir = Path.home() / ".ssh"
    inventory = Path("/workspace/ansible/inventory/hosts.yml")
    checks = {
        "API host configured": bool(host),
        "API token ID configured": bool(token_id),
        "API token secret file nonempty": token_path.is_file() and token_path.stat().st_size > 0,
        "SSH directory mounted": ssh_dir.is_dir(),
        "SSH known_hosts present": (ssh_dir / "known_hosts").is_file(),
        "Ansible inventory configured": inventory.is_file(),
    }
    for name, ok in checks.items():
        print(f"{'OK' if ok else 'MISSING':7s} {name}")
    print("No network requests were made. SSH-only use does not require an API token.")
    return 0 if all(checks.values()) else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="px", description=__doc__)
    parser.add_argument("--json", action="store_true", help="Show raw JSON response")
    sub = parser.add_subparsers(dest="command", required=True)
    for command, description in (
        ("doctor", "Check mounted config and credentials (local only)"),
        ("status", "Show cluster membership/status"),
        ("nodes", "List cluster nodes"),
        ("guests", "List VMs and LXC containers"),
        ("storage", "List storage resources"),
        ("version", "Show API version"),
    ):
        sub.add_parser(command, help=description)
    get = sub.add_parser("get", help="Read any API path, e.g. 'px get nodes/pve1/network'")
    get.add_argument("path")
    get.add_argument("params", nargs="*", metavar="KEY=VALUE", help="query parameters")
    snap = sub.add_parser(
        "snapshot",
        help=f"Collect storage, networks, access, HA, backups... into {snapshot.DIR_SNAPSHOT} "
        "(cached; reused while fresh) and print the summary",
    )
    snap.add_argument("--max-age", type=float, default=900, help="seconds a cached snapshot is reused")
    snap.add_argument("--refresh", action="store_true", help="ignore the cached snapshot")
    snap.add_argument("--quiet", action="store_true", help="only write the files")
    args = parser.parse_args(argv)
    if args.command == "doctor":
        return doctor()
    if args.command == "snapshot" and not args.refresh:
        cached = snapshot.fresh(args.max_age)
        if cached:
            if not args.quiet:
                print(cached.with_name("snapshot.json").read_text() if args.json else cached.read_text())
            return 0
    try:
        config = Config.from_env()
        pve = connect(config)
        if args.command == "snapshot":
            pve.version.get()  # fail once, uncached, if the API is unreachable or rejects the token
            data = snapshot.collect(lambda path: pve(path).get())
            summary = snapshot.write(data)
            if not args.quiet:
                print(json.dumps(data, indent=1, default=str) if args.json else summary.read_text())
            return 0
        if args.command == "get":
            params = dict(param.split("=", 1) for param in args.params if "=" in param)
            data = pve(args.path.strip("/")).get(**params)
        elif args.command == "status":
            data = pve.cluster.status.get()
        elif args.command == "nodes":
            data = pve.nodes.get()
        elif args.command == "guests":
            data = pve.cluster.resources.get(type="vm")
        elif args.command == "storage":
            data = pve.cluster.resources.get(type="storage")
        else:
            data = pve.version.get()
        print_result(data, args.json)
        return 0
    except (ValueError, OSError) as exc:
        print(f"px: {exc}", file=sys.stderr)
        return 2
    except Exception as exc:
        # HTTP/API errors should surface without printing credential values.
        print(f"px: Proxmox request failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
