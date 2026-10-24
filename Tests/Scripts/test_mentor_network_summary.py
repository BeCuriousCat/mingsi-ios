import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("mentor_network", ROOT / "scripts/summarize_mentor_network.py")
network = importlib.util.module_from_spec(spec)
spec.loader.exec_module(network)

START, UNTIL = "2026-10-01T00:00:00Z", "2026-10-08T00:00:00Z"


def fixture():
    session, request = str(uuid4()), str(uuid4())
    metrics = {"transactionCount": 3, "networkTransactionCount": 2, "cacheTransactionCount": 1,
               "serverPushTransactionCount": 0, "unknownTransactionCount": 0, "redirectCount": 1}
    row = {"schema_version": 1, "attempt_id": str(uuid4()), "trace_id": str(uuid4()), "session_id": session,
           "request_id": request, "request_epoch": 0, "semantic_revision": 0,
           "protocol_kind": "responses", "dispatch_registered_at": "2026-10-02T00:00:01Z",
           "terminal_state": "returned_data", "metrics_state": "received", "metrics_json": json.dumps(metrics),
           "output_budget_field": "max_output_tokens", "output_budget": 16000,
           "usage_state": "received", "usage_json": json.dumps({"source": "responses_event_usage",
               "inputTokens": 12, "outputTokens": 8, "totalTokens": 20, "reasoningTokens": 5,
               "hasInvalidFields": False}), "timing_state": "recording",
           "first_readable_body_ms": 25, "first_visible_body_ms": 40,
           "request_transport_finished_ms": 60, "response_saved_ms": 80}
    document = {"schema_version": 1, "created_at": "2026-10-09T00:00:00Z", "sections": {
        "mentor_requests": [{"id": request, "session_id": session, "epoch": 0, "expected_revision": 0,
                            "state": "committed", "created_at": "2026-10-02T00:00:00Z",
                            "context_snapshot_json": "PRIVATE_PROMPT_SENTINEL"}],
        "mentor_http_attempts": [row], "mentor_items": [{"payload_json": "PRIVATE_BODY_SENTINEL"}]}}
    return document, row


class MentorNetworkSummaryTests(unittest.TestCase):
    def report(self, document, **kwargs):
        return network.summarize(document, START, UNTIL, **kwargs)

    def test_counts_native_transactions_not_one_dispatch_and_keeps_cache_separate(self):
        doc, _ = fixture()
        report = self.report(doc)
        self.assertEqual(report["dispatch_registrations"], 1)
        self.assertEqual(report["native_http"]["exact_total_if_fully_observed"], 2)
        self.assertEqual(report["native_http"]["cache_transactions_observed"], 1)
        self.assertEqual(report["budget"]["remaining_if_fully_observed"], 48)
        self.assertFalse(report["budget"]["stop_new_dispatches_until_reconciled"])
        self.assertTrue(report["budget"]["not_authorization_to_send"])
        self.assertIsNone(report["complete_usable_responses"])
        self.assertEqual(report["goal_status"], "not_assessed")

    def test_missing_empty_unknown_and_conflicting_native_metrics_block_budget_claim(self):
        for variant in ["missing", "empty", "unknown", "conflict"]:
            doc, row = fixture()
            values = json.loads(row["metrics_json"])
            if variant == "missing": row.update(metrics_state="pending", metrics_json=None)
            elif variant == "empty":
                values.update({key: 0 for key in values})
                row["metrics_json"] = json.dumps(values)
            elif variant == "unknown":
                values.update(transactionCount=4, unknownTransactionCount=1)
                row["metrics_json"] = json.dumps(values)
            else: row["metrics_state"] = "conflict"
            report = self.report(doc)
            self.assertIsNone(report["native_http"]["exact_total_if_fully_observed"])
            self.assertIsNone(report["budget"]["remaining_if_fully_observed"])
            self.assertIsNone(report["budget"]["observed_over_limit"])
            self.assertTrue(report["budget"]["stop_new_dispatches_until_reconciled"])

    def test_known_network_lower_bound_keeps_known_loads_when_other_fetch_type_unknown(self):
        doc, row = fixture()
        metrics = json.loads(row["metrics_json"])
        metrics.update(transactionCount=4, unknownTransactionCount=1)
        row["metrics_json"] = json.dumps(metrics)
        self.assertEqual(self.report(doc)["native_http"]["known_network_lower_bound"], 2)

    def test_request_without_attempt_stays_in_denominator_and_stops_sending(self):
        doc, _ = fixture(); doc["sections"]["mentor_http_attempts"] = []
        report = self.report(doc)
        self.assertEqual(report["application_requests"], 1)
        self.assertEqual(report["requests_without_attempt_observation"], 1)
        self.assertIsNone(report["native_http"]["exact_total_if_fully_observed"])
        self.assertTrue(report["budget"]["stop_new_dispatches_until_reconciled"])

    def test_additional_attempts_retries_and_overrun_are_retained(self):
        doc, row = fixture()
        second = copy.deepcopy(row); second["attempt_id"] = str(uuid4()); second["terminal_state"] = "failed"
        doc["sections"]["mentor_http_attempts"].append(second)
        report = self.report(doc, max_http=3)
        self.assertEqual(report["native_http"]["exact_total_if_fully_observed"], 4)
        self.assertTrue(report["budget"]["observed_over_limit"])
        self.assertTrue(report["budget"]["stop_new_dispatches_until_reconciled"])
        self.assertEqual(report["transport_terminal_states"], {"failed": 1, "returned_data": 1})

    def test_identical_duplicate_deduplicates_but_conflicting_identity_is_rejected(self):
        doc, row = fixture(); doc["sections"]["mentor_http_attempts"].append(copy.deepcopy(row))
        report = self.report(doc)
        self.assertEqual(report["duplicate_identical_rows_ignored"], 1)
        self.assertEqual(report["native_http"]["exact_total_if_fully_observed"], 2)
        doc["sections"]["mentor_http_attempts"][1]["terminal_state"] = "failed"
        with self.assertRaises(network.InvalidInput): self.report(doc)

    def test_foreign_request_or_epoch_never_counts_toward_current_request(self):
        for key, value in [("request_id", str(uuid4())), ("session_id", str(uuid4())),
                           ("request_epoch", 1), ("semantic_revision", 1)]:
            doc, row = fixture(); row[key] = value
            with self.assertRaises(network.InvalidInput): self.report(doc)

    def test_before_window_request_dispatch_counts_against_actual_http_budget(self):
        doc, _ = fixture(); doc["sections"]["mentor_requests"][0]["created_at"] = "2026-09-30T00:00:00Z"
        report = self.report(doc)
        self.assertEqual(report["application_requests"], 0)
        self.assertEqual(report["dispatches_for_requests_started_outside_window"], 1)
        self.assertEqual(report["native_http"]["exact_total_if_fully_observed"], 2)

    def test_missing_usage_is_null_and_explicit_zero_is_zero(self):
        doc, row = fixture(); row.update(usage_state="pending", usage_json=None)
        report = self.report(doc)
        self.assertEqual(report["reported_usage"]["tokens_by_field"]["totalTokens"], {"sum_reported": None, "report_count": 0})
        row.update(usage_state="received", usage_json=json.dumps({"source": "responses_event_usage", "inputTokens": 0, "hasInvalidFields": False}))
        report = self.report(doc)
        self.assertEqual(report["reported_usage"]["tokens_by_field"]["inputTokens"], {"sum_reported": 0, "report_count": 1})
        self.assertIsNone(report["reported_usage"]["verified_cost"])

    def test_usage_conflict_invalid_and_inconsistent_report_never_sum_as_real_usage(self):
        for state in ["conflict", "invalid", "empty", "received"]:
            doc, row = fixture(); row["usage_state"] = state
            if state == "received":
                usage = json.loads(row["usage_json"]); usage["totalTokens"] = 1; row["usage_json"] = json.dumps(usage)
            self.assertEqual(self.report(doc)["reported_usage"]["usable_reports"], 0)

    def test_failed_body_and_visible_timings_report_missing_separately_and_never_use_terminal_as_first(self):
        doc, row = fixture(); row.update(terminal_state="failed", first_readable_body_ms=None, first_visible_body_ms=None, response_saved_ms=None)
        report = self.report(doc)
        timings = report["timing_by_protocol_budget_and_outcome"]["responses:max_output_tokens:16000"]
        self.assertIsNone(timings["first_readable_body_ms"]["failed"]["p50_ms"])
        self.assertEqual(timings["first_readable_body_ms"]["failed"]["missing_or_conflicting"], 1)
        self.assertEqual(timings["request_transport_finished_ms"]["failed"]["p50_ms"], 60)

    def test_conflicting_timing_excluded_even_when_values_present(self):
        doc, row = fixture(); row["first_visible_body_ms"] = 1
        timing = self.report(doc)["timing_by_protocol_budget_and_outcome"]["responses:max_output_tokens:16000"]
        self.assertEqual(timing["first_readable_body_ms"]["returned_data"]["count"], 0)

    def test_different_output_budgets_never_share_one_latency_percentile(self):
        doc, row = fixture()
        second = copy.deepcopy(row); second["attempt_id"] = str(uuid4())
        second["output_budget"] = 8192
        second.update(first_readable_body_ms=250, first_visible_body_ms=400,
                      request_transport_finished_ms=600, response_saved_ms=800)
        doc["sections"]["mentor_http_attempts"].append(second)
        report = self.report(doc)
        timing = report["timing_by_protocol_budget_and_outcome"]
        self.assertEqual(timing["responses:max_output_tokens:8192"]["first_readable_body_ms"]["returned_data"]["p50_ms"], 250)
        self.assertEqual(timing["responses:max_output_tokens:16000"]["first_readable_body_ms"]["returned_data"]["p50_ms"], 25)

    def test_observation_after_snapshot_is_rejected_and_early_snapshot_is_flagged(self):
        doc, _ = fixture(); doc["created_at"] = "2026-10-02T00:00:00Z"
        with self.assertRaises(network.InvalidInput): self.report(doc)
        doc["created_at"] = "2026-10-03T00:00:00Z"
        self.assertTrue(self.report(doc)["window"]["snapshot_before_window_end"])

    def test_awaiting_transport_and_exhausted_budget_do_not_permit_more_dispatches(self):
        doc, row = fixture(); row["terminal_state"] = "pending"
        self.assertTrue(self.report(doc)["budget"]["stop_new_dispatches_until_reconciled"])
        row["terminal_state"] = "returned_data"
        report = self.report(doc, max_http=2)
        self.assertFalse(report["budget"]["observed_over_limit"])
        self.assertEqual(report["budget"]["remaining_if_fully_observed"], 0)
        self.assertTrue(report["budget"]["stop_new_dispatches_until_reconciled"])

    def test_old_rows_without_new_columns_keep_missing_observations(self):
        doc, row = fixture()
        for key in ["usage_state", "usage_json", "timing_state", *network.STAGES, "output_budget", "output_budget_field"]: row.pop(key)
        report = self.report(doc)
        self.assertEqual(report["budget"]["unknown_output_budget_attempts"], 1)
        self.assertTrue(report["budget"]["stop_new_dispatches_until_reconciled"])
        self.assertEqual(report["reported_usage"]["states"], {"pending": 1})

    def test_bool_negative_float_and_mismatched_native_totals_rejected(self):
        for value in [True, -1, 1.25, "PRIVATE_NUMERIC_SENTINEL"]:
            doc, row = fixture(); row["request_epoch"] = value
            with self.assertRaises(network.InvalidInput): self.report(doc)
        doc, row = fixture(); values = json.loads(row["metrics_json"]); values["transactionCount"] = 1; row["metrics_json"] = json.dumps(values)
        with self.assertRaises(network.InvalidInput): self.report(doc)
        doc, row = fixture(); row["schema_version"] = True
        with self.assertRaises(network.InvalidInput): self.report(doc)

    def test_no_private_text_ids_urls_or_unknown_metadata_in_report_or_errors(self):
        doc, row = fixture(); row["private"] = "PRIVATE_CREDENTIAL_SENTINEL"
        encoded = json.dumps(self.report(doc))
        self.assertNotIn("PRIVATE_", encoded)
        for key in ["session_id", "request_id", "trace_id", "attempt_id"]: self.assertNotIn(row[key], encoded)
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)/"private.json"; source.write_text(json.dumps(doc))
            out, error = io.StringIO(), io.StringIO()
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(error):
                status = network.main([str(source), "--from", "PRIVATE_BAD_TIME", "--until", UNTIL])
            self.assertEqual(status, 2)
            self.assertNotIn("PRIVATE_", out.getvalue()+error.getvalue())
            self.assertNotIn(directory, out.getvalue()+error.getvalue())

    def test_cli_creates_only_new_private_file_and_never_overwrites(self):
        doc, _ = fixture()
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)/"export.json"; target=Path(directory)/"summary.json"
            source.write_text(json.dumps(doc)); original=source.read_bytes()
            argv=[str(source), "--from", START, "--until", UNTIL, "--output", str(target)]
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(network.main(argv), 0)
                first=target.read_bytes()
                self.assertEqual(network.main(argv), 2)
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            self.assertEqual(first,target.read_bytes());self.assertEqual(original,source.read_bytes())


if __name__ == "__main__": unittest.main()
