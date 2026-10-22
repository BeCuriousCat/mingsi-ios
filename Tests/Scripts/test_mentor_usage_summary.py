import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from uuid import UUID


SPEC = importlib.util.spec_from_file_location(
    "mentor_usage_summary", Path(__file__).resolve().parents[2] / "scripts/summarize_mentor_usage.py")
summary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(summary)

START = "2026-10-01T00:00:00Z"
END = "2026-10-15T00:00:00Z"
PRIVATE = "PRIVATE_BODY_OR_KEY_MUST_NEVER_APPEAR"


def uid(number):
    return str(UUID(int=number))


def event(number, attempt, kind, at="2026-10-02T12:00:00Z", **attributes):
    return {"event_id": uid(number), "attempt_id": uid(attempt), "session_id": None,
            "event_kind": kind, "occurred_at": at, "attributes_json": json.dumps(attributes)}


def entry(number, name="discuss", at="2026-10-02T12:00:00Z"):
    return event(number, number, "entry_started", at, entry=name, has_material="false",
                 content_version="1.1", schema_version="1.0.0")


def export(*events):
    return {"schema_version": 1, "created_at": END, "sections": {
        "mentor_usage_events": list(events), "mentor_feedback": [{"note": PRIVATE}],
        "capture_input_draft": [{"text": PRIVATE}], "prompt_runs": [{"input": PRIVATE}]}}


class MentorUsageSummaryTests(unittest.TestCase):
    def report(self, document, **kwargs):
        return summary.summarize(document, START, END, **kwargs)

    def test_failures_early_exit_and_missing_feedback_remain_in_initial_denominators(self):
        report = self.report(export(entry(1), entry(2), entry(3, "listen"),
            event(4, 1, "request_finished", reason="failed", duration_ms="12000", timing_scope="request"),
            event(5, 2, "session_left", exit_phase="entry", reason="entry_cancelled"),
            event(6, 1, "benefit_feedback", feedback="benefit_helped")))
        discuss = report["by_initial_entry"]["discuss"]
        self.assertEqual(report["observed_entry_attempts"], 3)
        self.assertEqual(discuss["attempts"], 2)
        self.assertEqual(discuss["latest_feedback_enum_by_attempt"], {"benefit_helped": 1, "missing": 1})
        self.assertEqual(discuss["attempts_without_observed_content"], 2)
        self.assertEqual(discuss["request_terminal_events"], {"failed": 1})
        self.assertIsNone(discuss["concrete_benefit_cases"])
        self.assertEqual(report["goal_status"], "not_assessed")
        self.assertNotIn(PRIVATE, json.dumps(report))

    def test_switch_and_revisit_do_not_relabel_the_first_entry_or_new_content(self):
        report = self.report(export(entry(1, "recall"),
            event(2, 1, "content_presented", first_content="true", presentation="revisit",
                  switched_entry="listen", timing_scope="entry_to_content", duration_ms="15"),
            event(3, 1, "content_presented", first_content="false", presentation="new")))
        recall = report["by_initial_entry"]["recall"]
        self.assertEqual(recall["attempts"], 1)
        self.assertEqual(report["by_initial_entry"]["listen"]["attempts"], 0)
        self.assertEqual(recall["switched_entry_events"], {"listen": 1})
        self.assertEqual(recall["presentations"], {"new": 1, "revisit": 1})
        self.assertEqual(recall["first_complete_content_latency_by_presentation"]["revisit"]["p50_ms"], 15)
        self.assertIsNone(recall["first_complete_content_latency_by_presentation"]["new"]["p50_ms"])

    def test_identical_duplicate_is_ignored_but_conflicting_identity_is_rejected(self):
        start = entry(1)
        report = self.report(export(start, copy.deepcopy(start)))
        self.assertEqual(report["observed_entry_attempts"], 1)
        self.assertEqual(report["duplicate_identical_rows_ignored"], 1)
        conflict = copy.deepcopy(start)
        conflict["attributes_json"] = json.dumps({"entry": "listen"})
        with self.assertRaisesRegex(summary.InvalidInput, "conflicting_event_identity"):
            self.report(export(start, conflict))

    def test_duplicate_attempt_start_cannot_inflate_or_reclassify_denominator(self):
        extra = entry(1, "listen")
        extra["event_id"] = uid(2)
        with self.assertRaisesRegex(summary.InvalidInput, "conflicting_entry_attempt"):
            self.report(export(entry(1), extra))

    def test_same_second_conflicting_feedback_is_unknown_not_arbitrary_latest(self):
        # App usage dates currently have one-second precision.
        report = self.report(export(entry(1),
            event(2, 1, "benefit_feedback", feedback="benefit_helped"),
            event(3, 1, "benefit_feedback", feedback="benefit_not_helpful")))
        feedback = report["by_initial_entry"]["discuss"]["latest_feedback_enum_by_attempt"]
        self.assertEqual(feedback, {"ambiguous_same_timestamp": 1})

    def test_later_feedback_is_latest_without_multiplying_attempts(self):
        report = self.report(export(entry(1),
            event(2, 1, "benefit_feedback", feedback="benefit_helped"),
            event(3, 1, "benefit_feedback", at="2026-10-03T12:00:00Z", feedback="benefit_not_helpful")))
        self.assertEqual(report["by_initial_entry"]["discuss"]["latest_feedback_enum_by_attempt"],
                         {"benefit_not_helpful": 1})

    def test_multiple_first_content_events_are_not_cherry_picked_for_latency(self):
        report = self.report(export(entry(1), *[
            event(number, 1, "content_presented", first_content="true", presentation="new",
                  duration_ms=str(delay), timing_scope="entry_to_content")
            for number, delay in [(2, 100), (3, 5000)]]))
        row = report["by_initial_entry"]["discuss"]
        self.assertEqual(row["ambiguous_first_content_attempts"], 1)
        self.assertEqual(row["first_complete_content_latency_by_presentation"]["new"]["count"], 0)
        self.assertEqual(row["presentations"]["new"], 2)

    def test_window_cohort_keeps_orphans_separate_and_does_not_import_old_attempts(self):
        report = self.report(export(entry(1, at="2026-09-30T23:59:59Z"), entry(2, at=START), entry(3, at=END),
            event(4, 1, "request_finished", reason="succeeded"),
            event(5, 999, "request_finished", reason="failed")))
        self.assertEqual(report["observed_entry_attempts"], 1)
        self.assertEqual(report["in_window_events_from_attempts_started_outside_window"], 1)
        self.assertEqual(report["events_without_entry_in_export"], 1)
        self.assertEqual(report["by_initial_entry"]["discuss"]["request_terminal_events"], {})

    def test_early_export_and_empty_observation_never_claim_a_completed_window(self):
        data = export()
        data["created_at"] = "2026-10-03T00:00:00Z"
        report = self.report(data)
        self.assertEqual(report["data_kind"], "unknown")
        self.assertTrue(report["window"]["snapshot_before_window_end"])
        self.assertEqual(report["observed_entry_attempts"], 0)
        self.assertIsNone(report["by_initial_entry"]["discuss"]["first_complete_content_latency_by_presentation"]["new"]["p95_ms"])
        with self.assertRaises(summary.InvalidInput):
            self.report(export(event(2, 1, "session_left", at="2026-10-16T00:00:00Z")))

    def test_bad_metadata_and_unknown_kinds_are_rejected_without_private_error_details(self):
        for attrs in [{"entry": PRIVATE}, {"raw_text": PRIVATE}, {"duration_ms": "NaN"},
                      {"duration_ms": str(2**64)}, {"has_material": True}]:
            with self.subTest(attributes=list(attrs)):
                row = entry(1)
                row["attributes_json"] = json.dumps(attrs)
                with self.assertRaises(summary.InvalidInput) as context:
                    self.report(export(row))
                self.assertNotIn(PRIVATE, str(context.exception))
        with self.assertRaises(summary.InvalidInput):
            self.report(export(event(2, 1, PRIVATE)))

    def test_timezone_and_percentiles_have_explicit_semantics(self):
        self.assertEqual(summary.instant("2026-10-01T08:00:00+08:00"), summary.instant(START))
        with self.assertRaises(summary.InvalidInput):
            summary.instant("2026-10-01T00:00:00")
        with self.assertRaises(summary.InvalidInput):
            summary.summarize(export(), END, START)
        self.assertEqual(summary.distribution([40, 10, 30, 20]),
                         {"count": 4, "p50_ms": 20, "p95_ms": 40, "maximum_ms": 40})

    def test_cli_preserves_input_creates_private_output_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, destination = root / "private-export.json", root / "summary.json"
            original = json.dumps(export(entry(1))).encode()
            source.write_bytes(original)
            args = [str(source), "--from", START, "--until", END, "--output", str(destination)]
            self.assertEqual(summary.main(args), 0)
            result = destination.read_text()
            self.assertNotIn(PRIVATE, result)
            self.assertEqual(stat.S_IMODE(destination.stat().st_mode), 0o600)
            errors = io.StringIO()
            with contextlib.redirect_stderr(errors):
                self.assertEqual(summary.main(args), 2)
            self.assertEqual(destination.read_text(), result)
            self.assertEqual(source.read_bytes(), original)
            self.assertNotIn(str(source), errors.getvalue())

    def test_cli_invalid_json_and_metadata_do_not_echo_private_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "private.json"
            for content in [PRIVATE, '{"schema_version":1,"schema_version":1}',
                            json.dumps(export(event(1, 1, "entry_started", entry=PRIVATE)))]:
                source.write_text(content)
                stdout, stderr = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                    self.assertEqual(summary.main([str(source), "--from", START, "--until", END]), 2)
                self.assertEqual(stdout.getvalue(), "")
                self.assertNotIn(PRIVATE, stderr.getvalue())

    def test_missing_usage_section_is_not_mistaken_for_zero_real_attempts(self):
        document = export()
        del document["sections"]["mentor_usage_events"]
        with self.assertRaisesRegex(summary.InvalidInput, "usage_section_missing"):
            self.report(document)

    def test_known_version_mixing_does_not_produce_pooled_latency(self):
        second = entry(2)
        second["attributes_json"] = json.dumps({"entry": "discuss", "content_version": "2.0", "schema_version": "1.0.0"})
        report = self.report(export(entry(1), second,
            event(3, 1, "request_finished", reason="succeeded", timing_scope="request", duration_ms="10"),
            event(4, 2, "request_finished", reason="failed", timing_scope="request", duration_ms="10000")))
        self.assertTrue(report["mixed_entry_content_schema_versions"])
        row = report["by_initial_entry"]["discuss"]
        self.assertEqual(row["attempts"], 2)
        self.assertIsNone(row["request_latency_by_terminal_reason"])
        self.assertIsNone(row["first_complete_content_latency_by_presentation"])
        self.assertEqual(row["request_terminal_events"], {"failed": 1, "succeeded": 1})

    def test_invalid_cli_does_not_echo_argument_content(self):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            self.assertEqual(summary.main(["--unexpected=" + PRIVATE]), 2)
        self.assertEqual(stdout.getvalue(), "")
        self.assertNotIn(PRIVATE, stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
