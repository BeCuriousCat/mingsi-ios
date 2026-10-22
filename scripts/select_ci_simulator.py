#!/usr/bin/env python3
"""Select an existing iOS 26+ iPhone on GitHub's macOS runner, without mutation."""

import json
import os
import re
import subprocess
import sys
from uuid import UUID


def select_device(document):
    candidates = []
    for runtime, devices in document.get("devices", {}).items():
        match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
        if not match or int(match[1]) < 26:
            continue
        version = tuple(int(part or 0) for part in match.groups())
        for device in devices:
            if device.get("isAvailable") is not True or "iPhone" not in device.get("deviceTypeIdentifier", ""):
                continue
            try:
                identity = str(UUID(device["udid"]))
            except (ValueError, KeyError, TypeError, AttributeError):
                continue
            candidates.append((version, identity))
    if not candidates:
        raise ValueError("No existing available iOS 26+ iPhone on the hosted runner")
    return sorted(candidates, reverse=True)[0][1]


def main():
    # The local simulator rule stays intact. A runner selection must not silently
    # become an escape hatch on the maintainer's machine.
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_OS") != "macOS":
        print("CI simulator selection requires a GitHub macOS runner", file=sys.stderr)
        return 2
    try:
        result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"],
                                check=True, capture_output=True, text=True, timeout=30)
        selected = select_device(json.loads(result.stdout))
    except (subprocess.SubprocessError, OSError, ValueError, KeyError, TypeError, AttributeError):
        print("No supported existing simulator inventory available", file=sys.stderr)
        return 2
    print("MINGSI_CI_SIMULATOR_ID=" + selected)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
