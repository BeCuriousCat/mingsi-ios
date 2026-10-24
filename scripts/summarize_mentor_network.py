#!/usr/bin/env python3
"""Reconcile one local export's HTTP observations without declaring G3 passed."""

from collections import Counter
import json
import os
from pathlib import Path
import sys

from summarize_mentor_usage import (InvalidInput, SafeArgumentParser, MAX_INPUT_BYTES,
                                    decode_json, distribution, identity, instant)


STAGES = ("first_readable_body_ms", "first_visible_body_ms",
          "request_transport_finished_ms", "response_saved_ms")
COUNTERS = ("networkTransactionCount", "cacheTransactionCount",
            "serverPushTransactionCount", "unknownTransactionCount")
USAGE_COUNTS = ("inputTokens", "outputTokens", "totalTokens", "reasoningTokens")
REQUEST_STATES = {"prepared", "in_flight", "response_received", "committed", "failed",
                  "cancelled", "interrupted", "timed_out"}


def nonnegative(value, nullable=False):
    if value is None and nullable:
        return None
    if type(value) is not int or not 0 <= value <= 2**63 - 1:
        raise InvalidInput("invalid_numeric_observation")
    return value


def unique(rows, key, parse):
    if not isinstance(rows, list):
        raise InvalidInput("observation_section_missing")
    values, duplicates = {}, 0
    for row in rows:
        if not isinstance(row, dict):
            raise InvalidInput("invalid_observation_row")
        item = parse(row)
        identifier = identity(row.get(key))
        if identifier in values:
            if values[identifier] != item:
                raise InvalidInput("conflicting_observation_identity")
            duplicates += 1
        values[identifier] = item
    return values, duplicates


def parse_request(row):
    state = row.get("state")
    if state not in REQUEST_STATES:
        raise InvalidInput("unsupported_request_state")
    return {"session": identity(row.get("session_id")), "state": state,
            "epoch": nonnegative(row.get("epoch")),
            "revision": nonnegative(row.get("expected_revision")),
            "at": instant(row.get("created_at"))}


def parse_attempt(row):
    if type(row.get("schema_version")) is not int or row["schema_version"] != 1:
        raise InvalidInput("unsupported_attempt_schema")
    kind = row.get("protocol_kind")
    if kind not in {"responses", "openAICompatible"}:
        raise InvalidInput("unsupported_transport_protocol")
    terminal = row.get("terminal_state")
    metrics_state = row.get("metrics_state")
    usage_state = row.get("usage_state", "pending")
    timing_state = row.get("timing_state", "recording")
    if (terminal not in {"pending", "returned_data", "failed", "cancelled", "conflict"}
            or metrics_state not in {"pending", "received", "conflict"}
            or usage_state not in {"pending", "received", "empty", "invalid", "conflict"}
            or timing_state not in {"recording", "conflict"}):
        raise InvalidInput("unsupported_observation_state")
    network = None
    counters = None
    if row.get("metrics_json") is not None:
        values = decode_json(row["metrics_json"])
        if not isinstance(values, dict):
            raise InvalidInput("invalid_native_counters")
        total = nonnegative(values.get("transactionCount"))
        counts = [nonnegative(values.get(field)) for field in COUNTERS]
        redirects = nonnegative(values.get("redirectCount"))
        if sum(counts) != total:
            raise InvalidInput("inconsistent_native_counters")
        counters = dict(zip(COUNTERS, counts))
        counters["redirectCount"] = redirects
        if metrics_state == "received" and total > 0 and counts[-1] == 0:
            network = counts[0]
    elif metrics_state in {"received", "conflict"}:
        raise InvalidInput("native_counter_payload_missing")
    field, amount = row.get("output_budget_field"), row.get("output_budget")
    if field is None and amount is None:
        budget_known = False
    else:
        allowed = {"max_output_tokens"} if kind == "responses" else {"max_tokens", "max_completion_tokens"}
        if field not in allowed or nonnegative(amount) not in range(1, 100_001):
            raise InvalidInput("invalid_output_budget")
        budget_known = True
    timings = {stage: nonnegative(row.get(stage), nullable=True) for stage in STAGES}
    ordering = ((STAGES[0], STAGES[1]), (STAGES[0], STAGES[2]),
                (STAGES[0], STAGES[3]), (STAGES[2], STAGES[3]))
    inconsistent_timing = any(timings[a] is not None and timings[b] is not None
                              and timings[a] > timings[b] for a, b in ordering)
    if inconsistent_timing:
        timing_state = "conflict"
    usage = None
    if row.get("usage_json") is not None:
        values = decode_json(row["usage_json"])
        expected = {"responses_event_usage"} if kind == "responses" else {"chat_stream_usage", "chat_completion_usage"}
        if not isinstance(values, dict) or values.get("source") not in expected or type(values.get("hasInvalidFields")) is not bool:
            raise InvalidInput("invalid_service_usage")
        counts = {key: nonnegative(values.get(key), nullable=True) for key in USAGE_COUNTS}
        invalid = values["hasInvalidFields"]
        first, second, total = (counts[key] for key in USAGE_COUNTS[:3])
        if all(value is not None for value in (first, second, total)) and first + second != total:
            invalid = True
        if counts["reasoningTokens"] is not None and second is not None and counts["reasoningTokens"] > second:
            invalid = True
        if usage_state == "received" and not invalid and any(v is not None for v in counts.values()):
            usage = counts
    elif usage_state != "pending":
        raise InvalidInput("service_usage_payload_missing")
    return {"session": identity(row.get("session_id")), "request": identity(row.get("request_id")),
            "trace": identity(row.get("trace_id")), "epoch": nonnegative(row.get("request_epoch")),
            "revision": nonnegative(row.get("semantic_revision")), "protocol": kind,
            "at": instant(row.get("dispatch_registered_at")), "terminal": terminal,
            "metrics_state": metrics_state, "network": network, "counters": counters,
            "budget_known": budget_known, "timing_state": timing_state,
            "budget_scope": f"{kind}:{field}:{amount}" if budget_known else f"{kind}:unknown",
            "timings": timings, "usage_state": usage_state, "usage": usage}


def summarize(document, start, until, max_http=50, data_kind="unknown"):
    start, until = instant(start), instant(until)
    if start >= until or type(max_http) is not int or not 1 <= max_http <= 50 or data_kind not in {"unknown", "synthetic", "real"}:
        raise InvalidInput("invalid_observation_window")
    if not isinstance(document, dict) or type(document.get("schema_version")) is not int or document["schema_version"] != 1:
        raise InvalidInput("unsupported_export_schema")
    snapshot = instant(document.get("created_at"))
    sections = document.get("sections")
    if not isinstance(sections, dict):
        raise InvalidInput("invalid_export_sections")
    requests, duplicate_requests = unique(sections.get("mentor_requests"), "id", parse_request)
    attempts, duplicate_attempts = unique(sections.get("mentor_http_attempts"), "attempt_id", parse_attempt)
    for attempt in attempts.values():
        request = requests.get(attempt["request"])
        if request is None or (attempt["session"], attempt["epoch"], attempt["revision"]) != (request["session"], request["epoch"], request["revision"]):
            raise InvalidInput("unowned_http_observation")
        if attempt["at"] < request["at"] or attempt["at"] > snapshot:
            raise InvalidInput("invalid_observation_order")
    if any(r["at"] > snapshot for r in requests.values()):
        raise InvalidInput("request_after_snapshot")
    cohort = {key: r for key, r in requests.items() if start <= r["at"] < until}
    dispatches = [a for a in attempts.values() if start <= a["at"] < until]
    linked = {a["request"] for a in attempts.values()}
    unobserved = sum(key not in linked for key in cohort)
    unknown = sum(a["network"] is None for a in dispatches)
    lower_bound = sum(a["network"] or 0 for a in dispatches)
    # Include definitely known native loads even when another transaction's
    # type or callback is unknown. Never mistake this lower bound for a total.
    lower_bound += sum(a["counters"]["networkTransactionCount"] for a in dispatches
                       if a["network"] is None and a["counters"] is not None and a["metrics_state"] == "received")
    exact = lower_bound if unknown == 0 and unobserved == 0 else None
    unknown_budget = sum(not a["budget_known"] for a in dispatches)
    pending = sum(a["terminal"] in {"pending", "conflict"} for a in dispatches)
    safe_to_continue = exact is not None and pending == 0 and unknown_budget == 0 and exact < max_http
    protocols = Counter(a["protocol"] for a in dispatches)
    states = Counter(a["terminal"] for a in dispatches)
    timing_report = {}
    for scope in sorted({a["budget_scope"] for a in dispatches}):
        scoped = [a for a in dispatches if a["budget_scope"] == scope]
        timing_report[scope] = {}
        for stage in STAGES:
            timing_report[scope][stage] = {}
            for state in sorted({a["terminal"] for a in scoped}):
                group = [a for a in scoped if a["terminal"] == state]
                values = [a["timings"][stage] for a in group if a["timing_state"] != "conflict" and a["timings"][stage] is not None]
                timing_report[scope][stage][state] = {**distribution(values), "attempts": len(group),
                                                     "missing_or_conflicting": len(group) - len(values)}
    usage_sums = {}
    for key in USAGE_COUNTS:
        values = [a["usage"][key] for a in dispatches if a["usage"] is not None and a["usage"][key] is not None]
        usage_sums[key] = {"sum_reported": sum(values) if values else None, "report_count": len(values)}
    return {
        "report_schema_version": 1, "data_kind": data_kind, "goal_status": "not_assessed",
        "window": {"from_inclusive": start.isoformat(), "until_exclusive": until.isoformat(),
                   "export_created_at": snapshot.isoformat(), "snapshot_before_window_end": snapshot < until},
        "application_requests": len(cohort), "application_request_states": dict(sorted(Counter(r["state"] for r in cohort.values()).items())),
        "requests_without_attempt_observation": unobserved,
        "dispatch_registrations": len(dispatches), "dispatches_for_requests_started_outside_window": sum(a["request"] not in cohort for a in dispatches),
        "transport_terminal_states": dict(sorted(states.items())), "protocols": dict(sorted(protocols.items())),
        "native_http": {"known_network_lower_bound": lower_bound, "exact_total_if_fully_observed": exact,
                        "attempts_with_unknown_count": unknown,
                        "cache_transactions_observed": sum((a["counters"] or {}).get("cacheTransactionCount", 0) for a in dispatches if a["metrics_state"] == "received")},
        "budget": {"registered_max_http": max_http,
                   "observed_over_limit": True if lower_bound > max_http else (False if exact is not None else None),
                   "remaining_if_fully_observed": max(0, max_http - exact) if exact is not None else None,
                   "unknown_output_budget_attempts": unknown_budget,
                   "stop_new_dispatches_until_reconciled": not safe_to_continue,
                   "not_authorization_to_send": True},
        "reported_usage": {"states": dict(sorted(Counter(a["usage_state"] for a in dispatches).items())),
                           "usable_reports": sum(a["usage"] is not None for a in dispatches),
                           "tokens_by_field": usage_sums,
                           "verified_cost": None},
        "timing_by_protocol_budget_and_outcome": timing_report, "percentiles": "nearest_rank",
        "latency_scope": "unverified_build_prompt_and_service_binding; diagnostic_only",
        "duplicate_identical_rows_ignored": duplicate_requests + duplicate_attempts,
        "complete_usable_responses": None,
        "limits": ["One export cannot recover deleted requests or failed observation writes; preregistered request/UI records remain necessary.",
                   "Native metrics do not reveal provider-side retries or establish billing or upstream identity.",
                   "Build, Prompt, content and service configuration are not bound by this tool; never pool candidates based on this report.",
                   "Transport returned_data or a committed request does not independently prove validated, saved, visible and useful content.",
                   "This report does not open a formal window, authorize a paid call, determine G3 success or establish human benefit."]}


def main(argv=None):
    parser = SafeArgumentParser(prog="summarize_mentor_network.py", description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--from", dest="start", required=True)
    parser.add_argument("--until", required=True)
    parser.add_argument("--max-http", type=int, default=50)
    parser.add_argument("--data-kind", choices=("unknown", "synthetic", "real"), default="unknown")
    parser.add_argument("--output", type=Path)
    try:
        args = parser.parse_args(argv)
        with args.export.open("rb") as handle:
            content = handle.read(MAX_INPUT_BYTES + 1)
        if len(content) > MAX_INPUT_BYTES:
            raise InvalidInput("export_too_large")
        report = summarize(decode_json(content), args.start, args.until, args.max_http, args.data_kind)
        payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        if args.output:
            fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(payload)
        else:
            sys.stdout.write(payload)
        return 0
    except InvalidInput as error:
        print("Network summary rejected: " + str(error), file=sys.stderr)
    except (OSError, UnicodeError, RecursionError, ValueError, TypeError, OverflowError):
        print("Network summary rejected: input_or_output_unavailable_or_invalid", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
