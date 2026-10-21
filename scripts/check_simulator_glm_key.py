"""Probe only Keychain index metadata; the hosted live test verifies access."""

import hashlib
from contextlib import closing
import json
from pathlib import Path
import sqlite3
import subprocess
import sys


def has_api_key(database: Path) -> bool:
    if not database.is_file():
        return False
    # Modern simulator Keychains index service/account by SHA-1, while older
    # schemas use text or UTF-8 blobs. Comparing only plaintext gives a false
    # missing-key result. Never select the encrypted credential data column.
    def indexes(value: str) -> tuple:
        raw = value.encode("utf-8")
        return value, raw, hashlib.sha1(raw).digest()

    try:
        with closing(sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True)) as connection:
            return connection.execute(
                "SELECT 1 FROM genp WHERE svce IN (?, ?, ?) AND acct IN (?, ?, ?, ?, ?, ?) LIMIT 1",
                indexes("com.codex.mingsi.glm") + indexes("glm_api_key") + indexes("responses_glm_api_key"),
            ).fetchone() is not None
    except sqlite3.Error:
        return False


def simulator_has_api_key(device_id: str) -> bool:
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "--json"],
            capture_output=True, check=True, timeout=10,
        )
        devices = json.loads(result.stdout).get("devices", {})
        for group in devices.values():
            for device in group:
                if device.get("udid") == device_id and device.get("dataPath"):
                    return has_api_key(Path(device["dataPath"]) / "Library/Keychains/keychain-2-debug.db")
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    return False


if __name__ == "__main__":
    sys.exit(0 if len(sys.argv) == 2 and simulator_has_api_key(sys.argv[1]) else 1)
