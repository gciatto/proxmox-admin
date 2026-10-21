import contextlib
import io
import os
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from pxadmin.cli import Config, main, print_result


class ConfigTests(unittest.TestCase):
    def test_token_file_and_user_derived_from_id(self):
        with TemporaryDirectory() as d:
            path = Path(d) / "secret"
            path.write_text("abc-123\n")
            with patch.dict(os.environ, {
                "PROXMOX_HOST": "pve.example.org",
                "PROXMOX_PORT": "8006",
                "PROXMOX_TOKEN_ID": "alice@pve!cli",
                "PROXMOX_TOKEN_SECRET": "",
                "PROXMOX_TOKEN_SECRET_FILE": str(path),
                "PROXMOX_USER": "",
                "PROXMOX_VALIDATE_CERTS": "true",
            }, clear=True):
                c = Config.from_env()
            self.assertEqual(c.user, "alice@pve")
            self.assertEqual(c.token_secret, "abc-123")
            self.assertTrue(c.verify_ssl)

    def test_rejects_mismatched_user(self):
        with patch.dict(os.environ, {
            "PROXMOX_HOST": "pve.example.org",
            "PROXMOX_TOKEN_ID": "alice@pve!cli",
            "PROXMOX_TOKEN_SECRET": "abc",
            "PROXMOX_USER": "bob@pve",
        }, clear=True):
            with self.assertRaisesRegex(ValueError, "match"):
                Config.from_env()

    def test_missing_credentials_clean_error(self):
        with patch.dict(os.environ, {}, clear=True), contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(main(["nodes"]), 2)
            self.assertIn("Missing API configuration", stderr.getvalue())

    def test_json_output(self):
        with contextlib.redirect_stdout(io.StringIO()) as stdout:
            print_result([{"node": "pve1", "status": "online"}], True)
            self.assertIn('"pve1"', stdout.getvalue())


if __name__ == "__main__":
    unittest.main()
