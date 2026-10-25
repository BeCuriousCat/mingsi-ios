import contextlib
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import sqlite3
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[2] / "scripts/run_cc_switch_acceptance.py"
SPEC = importlib.util.spec_from_file_location("cc_switch_acceptance", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class LensEvaluationRunnerTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name)
        self.addCleanup(self.folder.cleanup)
        (self.root / ".cc-switch").mkdir()
        with sqlite3.connect(self.root / ".cc-switch/cc-switch.db") as connection:
            connection.execute("CREATE TABLE providers (name, settings_config, app_type, is_current)")
            connection.execute("INSERT INTO providers VALUES (?, ?, 'codex', 1)", (
                "Synthetic provider", json.dumps({
                    "auth": {"OPENAI_API_KEY": "synthetic-private-key"},
                    "config": 'model="synthetic-model"\nmodel_provider="fixture"\n[model_providers.fixture]\nbase_url="https://example.test/v1"\nwire_api="responses"',
                })))
        self.source = self.root / "source.xctestrun"
        self.source.write_bytes(plistlib.dumps({"MingSiTests": {
            "EnvironmentVariables": {"MINGSI_LIVE_OLD": "1", "KEEP": "value"},
            "TestingEnvironmentVariables": {"MINGSI_LIVE_GLM_API_KEY": "stale-key"},
        }}))
        self.cases = self.root / "cases.json"
        self.cases.write_text(json.dumps([{"id": "first", "lens": "evidenceCheck", "text": "synthetic",
            "steps": [{"mode": "question", "goals": ["grounding"]}]}]))

    def invoke(self, extra=(), fail=False, method_batch=None):
        args = [str(SCRIPT), "--source-xctestrun", str(self.source),
            "--result-bundle-path", str(self.root / "result.xcresult"),
            *( ["--lens-goals", str(self.cases)] if method_batch is None else ["--coach-methods", str(method_batch)] ), *extra]
        output = io.StringIO()
        temporary_paths = []

        def inspect(command):
            temporary = Path(command[command.index("-xctestrun") + 1])
            temporary_paths.append(temporary)
            self.assertEqual(stat.S_IMODE(temporary.stat().st_mode), 0o600)
            run = plistlib.loads(temporary.read_bytes())["MingSiTests"]
            env = run["EnvironmentVariables"]
            self.assertEqual(env["MINGSI_LIVE_GLM_API_KEY"], "synthetic-private-key")
            self.assertNotIn("MINGSI_LIVE_OLD", env)
            self.assertEqual(env["KEEP"], "value")
            if method_batch is None:
                self.assertEqual(len(json.loads(env["MINGSI_LIVE_LENS_GOALS_JSON"])), 1)
            else:
                self.assertEqual(json.loads(env["MINGSI_LIVE_COACH_METHODS_JSON"])["max_requests"], 18)
                self.assertNotIn("MINGSI_LIVE_LENS_GOALS_JSON", env)
            self.assertEqual(run["TestingEnvironmentVariables"], {})
            self.assertIn("test-without-building", command)
            self.assertTrue(any(arg.endswith("/testLiveLensGoalsWhenExplicitlyEnabled" if method_batch is None else "/testLiveCoachMethodComparisonWhenExplicitlyEnabled") for arg in command))
            if fail:
                raise RuntimeError("simulated execution failure")
            return type("Result", (), {"returncode": 0})()

        with patch.object(sys, "argv", args), patch.object(Path, "home", return_value=self.root), \
             patch.object(runner.subprocess, "run", side_effect=inspect) as run, \
             patch.object(runner.subprocess, "check_output", return_value=b'{"passedTests":1,"failedTests":0,"skippedTests":0}'), \
             contextlib.redirect_stdout(output):
            try:
                runner.main()
            finally:
                self.assertTrue(all(not path.exists() for path in temporary_paths))
                self.assertNotIn("synthetic-private-key", output.getvalue())
        return run.call_count

    def test_credential_is_private_isolated_and_removed_after_success(self):
        self.assertEqual(self.invoke(), 1)

    def test_private_file_is_removed_after_execution_exception(self):
        with self.assertRaisesRegex(RuntimeError, "simulated execution failure"):
            self.invoke(fail=True)

    def test_unknown_case_is_rejected_before_execution(self):
        with self.assertRaises(SystemExit), patch.object(runner.subprocess, "run") as run:
            self.invoke(["--lens-case-ids", "not-in-dataset"])
        run.assert_not_called()

    def test_mutually_exclusive_paid_operations_are_rejected(self):
        with self.assertRaises(SystemExit), patch.object(runner.subprocess, "run") as run:
            self.invoke(["--mentor-streaming"])
        run.assert_not_called()

    def test_method_batch_uses_isolated_credentials_and_its_only_selector(self):
        dataset = self.root / "methods.json"
        dataset.write_text(json.dumps({"no_retry": True, "max_requests": 18, "cases": [{"texts": ["synthetic"]}]}))
        self.assertEqual(self.invoke(method_batch=dataset), 1)

    def test_over_budget_method_batch_is_rejected_before_any_provider_request(self):
        dataset = self.root / "methods.json"
        dataset.write_text(json.dumps({"no_retry": True, "max_requests": 18, "cases": [{"texts": ["synthetic"] * 19}]}))
        with self.assertRaises(SystemExit), patch.object(runner.subprocess, "run") as run:
            self.invoke(method_batch=dataset)
        run.assert_not_called()

    def test_method_batch_cannot_enable_another_paid_path(self):
        dataset = self.root / "methods.json"
        dataset.write_text(json.dumps({"no_retry": True, "max_requests": 18, "cases": [{"texts": ["synthetic"]}]}))
        with self.assertRaises(SystemExit), patch.object(runner.subprocess, "run") as run:
            self.invoke(extra=["--mentor-streaming"], method_batch=dataset)
        run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
