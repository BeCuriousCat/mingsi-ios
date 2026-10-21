import hashlib
from contextlib import closing
import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "simulator_key_probe", Path(__file__).resolve().parents[2] / "scripts/check_simulator_glm_key.py"
)
probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe)


class SimulatorKeyProbeTests(unittest.TestCase):
    def test_key_detection_accepts_text_utf8_and_hashed_indexes(self):
        for encode in (lambda x: x, lambda x: x.encode(), lambda x: hashlib.sha1(x.encode()).digest()):
            with self.subTest(encoding=encode), tempfile.TemporaryDirectory() as directory:
                database = Path(directory) / "keychain.db"
                with closing(sqlite3.connect(database)) as connection, connection:
                    connection.execute("CREATE TABLE genp (svce, acct)")
                    connection.execute("INSERT INTO genp VALUES (?, ?)",
                                       (encode("com.codex.mingsi.glm"), encode("glm_api_key")))
                before = database.read_bytes()
                self.assertTrue(probe.has_api_key(database))
                self.assertEqual(database.read_bytes(), before)

    def test_model_configuration_and_other_services_do_not_count_as_a_key(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "keychain.db"
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.execute("CREATE TABLE genp (svce, acct)")
                connection.executemany("INSERT INTO genp VALUES (?, ?)", [
                    ("com.codex.mingsi.glm", "glm_model_name"),
                    ("com.codex.mingsi.glm", "glm_base_url"),
                    ("another.app", "glm_api_key"),
                ])
            self.assertFalse(probe.has_api_key(database))

    def test_responses_key_metadata_is_detected_without_reading_credential_data(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "keychain.db"
            with closing(sqlite3.connect(database)) as connection, connection:
                connection.execute("CREATE TABLE genp (svce, acct)")
                connection.execute("INSERT INTO genp VALUES (?, ?)", (
                    hashlib.sha1(b"com.codex.mingsi.glm").digest(),
                    hashlib.sha1(b"responses_glm_api_key").digest()))
            self.assertTrue(probe.has_api_key(database))

    def test_missing_database_is_not_created(self):
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "missing.db"
            self.assertFalse(probe.has_api_key(database))
            self.assertFalse(database.exists())

    def test_only_requested_device_is_considered(self):
        response = subprocess.CompletedProcess([], 0, json.dumps({"devices": {"runtime": [
            {"udid": "other-device", "dataPath": "/other-device"},
            {"udid": "fixed-device", "dataPath": "/fixed-device"},
        ]}}).encode())
        with patch.object(probe.subprocess, "run", return_value=response), \
             patch.object(probe, "has_api_key", return_value=True) as lookup:
            self.assertTrue(probe.simulator_has_api_key("fixed-device"))
            lookup.assert_called_once_with(Path("/fixed-device/Library/Keychains/keychain-2-debug.db"))


if __name__ == "__main__":
    unittest.main()
