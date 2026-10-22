import contextlib
import importlib.util
import io
import json
from pathlib import Path
from unittest.mock import patch
import unittest


SPEC = importlib.util.spec_from_file_location(
    "ci_simulator", Path(__file__).resolve().parents[2] / "scripts/select_ci_simulator.py")
selector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(selector)

ID = "E839A11B-51B4-4AD3-ACF4-A53B95B7C957"


def device(**extra):
    return dict(udid=ID, isAvailable=True,
                deviceTypeIdentifier="com.apple.CoreSimulator.SimDeviceType.iPhone-17", **extra)


class CISimulatorSelectionTests(unittest.TestCase):
    def test_selects_only_existing_available_ios_26_iphone(self):
        document = {"devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-5": [device()],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [device()],
            "com.apple.CoreSimulator.SimRuntime.tvOS-26-5": [device()],
        }}
        self.assertEqual(selector.select_device(document), ID)
        document["devices"]["com.apple.CoreSimulator.SimRuntime.iOS-26-5"][0]["isAvailable"] = False
        with self.assertRaises(ValueError):
            selector.select_device(document)

    def test_ipad_and_invalid_identifiers_do_not_become_shell_output(self):
        bad = device()
        bad["udid"] = "invalid\nPRIVATE=1"
        tablet = device()
        tablet["deviceTypeIdentifier"] = "com.apple.CoreSimulator.SimDeviceType.iPad-Pro"
        with self.assertRaises(ValueError):
            selector.select_device({"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [bad, tablet]}})

    def test_local_machine_is_refused_without_any_tool_invocation(self):
        with patch.dict(selector.os.environ, {}, clear=True), patch.object(selector.subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(selector.main(), 2)
            run.assert_not_called()

    def test_runner_invokes_only_read_only_inventory_and_outputs_validated_id(self):
        inventory = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [device()]}}
        result = type("Result", (), {"stdout": json.dumps(inventory)})()
        output = io.StringIO()
        with patch.dict(selector.os.environ, {"GITHUB_ACTIONS": "true", "RUNNER_OS": "macOS"}), \
                patch.object(selector.subprocess, "run", return_value=result) as run, \
                contextlib.redirect_stdout(output):
            self.assertEqual(selector.main(), 0)
        self.assertEqual(output.getvalue(), "MINGSI_CI_SIMULATOR_ID=" + ID + "\n")
        self.assertEqual(run.call_args.args[0], ["xcrun", "simctl", "list", "devices", "available", "--json"])

    def test_uuid_matches_xcode_uppercase_destination_even_for_lowercase_inventory(self):
        candidate = device()
        candidate["udid"] = ID.lower()
        inventory = {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [candidate]}}
        self.assertEqual(selector.select_device(inventory), ID)


if __name__ == "__main__":
    unittest.main()
