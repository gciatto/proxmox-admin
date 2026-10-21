"""Read-only snapshot of a cluster's configuration and state, for administrators and AI agents."""

from __future__ import annotations

import json
import os
import time
from collections import Counter
from pathlib import Path
from typing import Any, Callable

# API paths read once per cluster; a path the token may not read is recorded as an error.
CLUSTER_PATHS = (
    "version",
    "cluster/status",
    "cluster/resources",
    "cluster/options",
    "storage",
    "pools",
    "access/domains",
    "access/users",
    "access/groups",
    "access/acl",
    "cluster/ha/resources",
    "cluster/backup",
    "cluster/replication",
    "cluster/sdn/zones",
    "cluster/sdn/vnets",
)
NODE_PATHS = ("nodes/{node}/network",)

DIR_SNAPSHOT = Path(os.environ.get("PVE_SNAPSHOT_DIR", "/tmp/pve-snapshot"))


def collect(get: Callable[[str], Any]) -> dict[str, Any]:
    paths: dict[str, Any] = {}

    def read(path: str) -> Any:
        try:
            paths[path] = get(path)
        except Exception as exc:  # permission denied, not installed, node offline, ...
            paths[path] = {"error": f"{type(exc).__name__}: {exc}"}
        return paths[path]

    for path in CLUSTER_PATHS:
        read(path)
    for node in nodes(paths):
        for template in NODE_PATHS:
            read(template.format(node=node["name"]))
    return {"collected_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "paths": paths}


def ok(value: Any) -> list[dict[str, Any]]:
    """The list returned by an API path, or [] if it failed."""
    return value if isinstance(value, list) else []


def nodes(paths: dict[str, Any]) -> list[dict[str, Any]]:
    return [e for e in ok(paths.get("cluster/status")) if e.get("type") == "node"]


def table(rows: list[dict[str, Any]], columns: tuple[str, ...]) -> list[str]:
    if not rows:
        return ["(none)", ""]
    lines = ["| " + " | ".join(columns) + " |", "|" + " --- |" * len(columns)]
    for row in rows:
        cells = (str(row.get(c, "")).replace("|", "\\|").replace("\n", " ") for c in columns)
        lines.append("| " + " | ".join(cells) + " |")
    return [*lines, ""]


def gib(value: Any) -> str:
    return f"{value / 2**30:.0f}" if isinstance(value, (int, float)) else ""


def summarize(snapshot: dict[str, Any]) -> str:
    paths = snapshot["paths"]
    version = paths.get("version", {})
    status = ok(paths.get("cluster/status"))
    cluster = next((e for e in status if e.get("type") == "cluster"), {})
    resources = ok(paths.get("cluster/resources"))
    out = [
        f"# Proxmox cluster snapshot ({snapshot['collected_at']})",
        "",
        f"Cluster `{cluster.get('name', '(standalone)')}`, quorate: {cluster.get('quorate', '?')}, "
        f"Proxmox VE {version.get('version', '?') if isinstance(version, dict) else '?'}.",
        "",
        "## Nodes",
        "",
    ]
    usage = {r.get("node"): r for r in resources if r.get("type") == "node"}
    out += table(
        [
            {
                **n,
                "online": "yes" if n.get("online") else "NO",
                "cpus": usage.get(n["name"], {}).get("maxcpu", ""),
                "mem GiB": gib(usage.get(n["name"], {}).get("maxmem")),
            }
            for n in nodes(paths)
        ],
        ("name", "ip", "online", "cpus", "mem GiB"),
    )

    guests = [r for r in resources if r.get("type") in ("qemu", "lxc")]
    out += ["## Guests", ""]
    counts = Counter((g.get("node"), g.get("type"), g.get("status")) for g in guests)
    out += table(
        [{"node": n, "type": t, "status": s, "count": c} for (n, t, s), c in sorted(counts.items())],
        ("node", "type", "status", "count"),
    )
    out += ["Full list: `px guests`.", ""]

    out += ["## Storage", ""]
    usage_by_storage: dict[str, list[str]] = {}
    for r in resources:
        if r.get("type") == "storage":
            used = f"{r.get('node')}: {gib(r.get('disk'))}/{gib(r.get('maxdisk'))} GiB"
            usage_by_storage.setdefault(r.get("storage", ""), []).append(used)
    out += table(
        [{**s, "usage": "; ".join(usage_by_storage.get(s["storage"], []))} for s in ok(paths.get("storage"))],
        ("storage", "type", "content", "shared", "nodes", "usage"),
    )

    out += ["## Networks", ""]
    for node in nodes(paths):
        interfaces = [
            i for i in ok(paths.get(f"nodes/{node['name']}/network")) if i.get("type") != "eth" or i.get("cidr")
        ]
        out += [f"### {node['name']}", ""]
        out += table(
            sorted(interfaces, key=lambda i: i.get("iface", "")),
            ("iface", "type", "cidr", "gateway", "bridge_ports", "slaves", "vlan-raw-device", "comments"),
        )
    out += ["SDN zones / vnets:", ""]
    out += table(ok(paths.get("cluster/sdn/zones")), ("zone", "type"))
    out += table(ok(paths.get("cluster/sdn/vnets")), ("vnet", "zone", "tag", "alias"))

    out += ["## Access", "", "Realms:", ""]
    out += table(ok(paths.get("access/domains")), ("realm", "type", "comment"))
    out += ["Users:", ""]
    out += table(ok(paths.get("access/users")), ("userid", "enable", "groups", "comment"))
    out += ["Groups:", ""]
    out += table(ok(paths.get("access/groups")), ("groupid", "users", "comment"))
    out += ["ACL:", ""]
    out += table(ok(paths.get("access/acl")), ("path", "type", "ugid", "roleid", "propagate"))
    out += ["Pools:", ""]
    out += table(ok(paths.get("pools")), ("poolid", "comment"))

    out += ["## HA, backup, replication", ""]
    out += table(ok(paths.get("cluster/ha/resources")), ("sid", "state", "group", "comment"))
    out += table(
        ok(paths.get("cluster/backup")),
        ("id", "enabled", "schedule", "storage", "vmid", "all", "pool", "mode", "comment"),
    )
    out += table(ok(paths.get("cluster/replication")), ("id", "guest", "target", "schedule"))

    errors = {p: v["error"] for p, v in paths.items() if isinstance(v, dict) and "error" in v}
    if errors:
        out += [
            "## Not collected",
            "",
            "403: the API token lacks the privilege (e.g. `Sys.Audit`); 501 or 500: not available "
            "in this Proxmox VE version or setup.",
            "",
        ]
        out += [f"- `{p}`: {e}" for p, e in sorted(errors.items())] + [""]
    out += ["Raw data: `snapshot.json` next to this file (`jq '.paths[\"storage\"]'`); more: `px get PATH`."]
    return "\n".join(out) + "\n"


def write(snapshot: dict[str, Any], folder: Path = DIR_SNAPSHOT) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    for name, text in (("snapshot.json", json.dumps(snapshot, indent=1, default=str)),
                       ("summary.md", summarize(snapshot))):
        tmp = folder / f".{name}.tmp"
        tmp.write_text(text, encoding="utf-8")
        tmp.replace(folder / name)
    return folder / "summary.md"


def fresh(max_age: float, folder: Path = DIR_SNAPSHOT) -> Path | None:
    summary = folder / "summary.md"
    if summary.is_file() and time.time() - summary.stat().st_mtime < max_age:
        return summary
    return None
