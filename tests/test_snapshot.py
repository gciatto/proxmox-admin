import json
import os
import sys
import time
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from pxadmin import snapshot

API = {
    "version": {"version": "9.0.3"},
    "cluster/status": [
        {"type": "cluster", "name": "lab", "quorate": 1},
        {"type": "node", "name": "pve1", "ip": "10.0.0.1", "online": 1},
        {"type": "node", "name": "pve2", "ip": "10.0.0.2", "online": 0},
    ],
    "cluster/resources": [
        {"type": "node", "node": "pve1", "maxcpu": 32, "maxmem": 128 * 2**30},
        {"type": "qemu", "node": "pve1", "status": "running", "vmid": 100},
        {"type": "qemu", "node": "pve1", "status": "running", "vmid": 101},
        {"type": "storage", "node": "pve1", "storage": "local-lvm", "disk": 2**30, "maxdisk": 10 * 2**30},
    ],
    "storage": [{"storage": "local-lvm", "type": "lvmthin", "content": "images,rootdir"}],
    "access/domains": [{"realm": "pam", "type": "pam"}, {"realm": "corp", "type": "ldap"}],
    "access/users": [{"userid": "alice@corp", "enable": 1}],
    "nodes/pve1/network": [
        {"iface": "vmbr0", "type": "bridge", "cidr": "10.0.0.1/24", "bridge_ports": "eno1"},
        {"iface": "eno2", "type": "eth"},
    ],
}


def fake_get(path):
    if path == "access/acl":
        raise PermissionError("403 Forbidden: Permission check failed (/access, Sys.Audit)")
    if path not in API:
        raise RuntimeError("501 Not Implemented")
    return API[path]


class SnapshotTests(unittest.TestCase):
    def test_collect_records_errors_and_reads_online_and_offline_nodes(self):
        data = snapshot.collect(fake_get)
        self.assertEqual(data["paths"]["storage"], API["storage"])
        self.assertIn("Sys.Audit", data["paths"]["access/acl"]["error"])
        self.assertIn("nodes/pve1/network", data["paths"])
        self.assertIn("error", data["paths"]["nodes/pve2/network"])

    def test_summary(self):
        summary = snapshot.summarize(snapshot.collect(fake_get))
        self.assertIn("Cluster `lab`, quorate: 1, Proxmox VE 9.0.3", summary)
        self.assertIn("| pve1 | 10.0.0.1 | yes | 32 | 128 |", summary)
        self.assertIn("| pve2 | 10.0.0.2 | NO |", summary)
        self.assertIn("| pve1 | qemu | running | 2 |", summary)
        self.assertIn("pve1: 1/10 GiB", summary)
        self.assertIn("| vmbr0 | bridge | 10.0.0.1/24 |", summary)
        self.assertNotIn("eno2", summary)  # unconfigured physical NICs are omitted
        self.assertIn("| corp | ldap |", summary)
        self.assertIn("- `access/acl`: PermissionError", summary)

    def test_write_and_fresh(self):
        with TemporaryDirectory() as d:
            folder = Path(d)
            self.assertIsNone(snapshot.fresh(60, folder))
            summary = snapshot.write(snapshot.collect(fake_get), folder)
            self.assertEqual(snapshot.fresh(60, folder), summary)
            self.assertEqual(json.loads((folder / "snapshot.json").read_text())["paths"]["version"], API["version"])
            old = time.time() - 120
            os.utime(summary, (old, old))
            self.assertIsNone(snapshot.fresh(60, folder))


if __name__ == "__main__":
    unittest.main()
