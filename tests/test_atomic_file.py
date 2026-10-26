import os
import unittest
from unittest.mock import patch

from core.atomic_file import create_atomic_temp
from core.update_installer import _probe_directory_writable
from pathlib import Path


class AtomicTempTests(unittest.TestCase):
    def test_access_denied_is_not_retried(self):
        with patch("core.atomic_file.os.open", side_effect=PermissionError("denied")) as open_file:
            with self.assertRaises(PermissionError):
                create_atomic_temp(dir="restricted")
        self.assertEqual(open_file.call_count, 1)

    def test_only_name_collisions_are_retried(self):
        with patch("core.atomic_file.secrets.token_hex", side_effect=["first", "second"]), patch(
            "core.atomic_file.os.open", side_effect=[FileExistsError(), 42]
        ) as open_file:
            fd, path = create_atomic_temp(dir="config", prefix=".cache.")
        self.assertEqual(fd, 42)
        self.assertEqual(path, os.path.join("config", ".cache.second.tmp"))
        self.assertEqual(open_file.call_count, 2)
        self.assertTrue(open_file.call_args.args[1] & os.O_EXCL)
        self.assertEqual(open_file.call_args.args[2], 0o600)

    def test_collision_retries_are_bounded(self):
        with patch("core.atomic_file.os.open", side_effect=FileExistsError()) as open_file:
            with self.assertRaises(FileExistsError):
                create_atomic_temp(dir="config")
        self.assertEqual(open_file.call_count, 8)

    def test_update_write_probe_returns_false_on_access_denied(self):
        with patch(
            "core.update_installer.create_atomic_temp",
            side_effect=PermissionError("denied"),
        ) as create_file:
            self.assertFalse(_probe_directory_writable(Path("restricted")))
        self.assertEqual(create_file.call_count, 1)
