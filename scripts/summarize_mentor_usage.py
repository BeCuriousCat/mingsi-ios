#!/usr/bin/env python3
"""Summarize a single local export without copying private content or scoring goals."""

import argparse
from collections import Counter, defaultdict
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys
from uuid import UUID


MAX_INPUT_BYTES = 128 * 1024 * 1024
ENTRIES = ("listen", "recall", "discuss", "capture", "continue", "history",
           "legacy-nudge", "legacy-nudge-selection", "unknown")
KINDS = {"entry_started", "content_presented", "request_finished", "session_left",
         "understanding_confirmed", "benefit_feedback"}
FEEDBACK = {"unknown", "benefit_unknown", "benefit_helped", "benefit_partly_helped",
            "benefit_not_helpful", "not_relevant", "already_known"}
REASONS = {"user", "switch", "entry_failed", "entry_cancelled", "succeeded", "failed",
           "cancelled", "interrupted", "timed_out"}
ENUMS = {
    "entry": set(ENTRIES), "switched_entry": set(ENTRIES),
    "has_material": {"true", "false"}, "first_content": {"true", "false"},
    "schema_version": {"1.0.0"},
    "timing_scope": {"entry_to_content", "request", "attempt"},
    "content_kind": {"lesson", "response"}, "presentation": {"new", "revisit"},
    "exit_phase": {"entry", "history", "understanding", "idle", "editing", "reading",
                   "selecting_lesson", "lesson_exhausted", "submitting", "showing_response",
                   "paused", "ended", "failed"},
    "exit_action": {"finish", "pause", "switch"}, "reason": REASONS, "feedback": FEEDBACK,
}
LIMITS = [
    "This is one observed export, not a complete ledger of real use.",
    "Deleted sessions and failed event writes can remove observations; missing counts are unknown.",
    "Material presence is not a measure of preparation effort or startup burden.",
    "Feedback enums, reading and understanding confirmation do not establish concrete benefit.",
    "First complete content latency is not first-token latency; revisit is separate from new content.",
    "Request terminal events are not all actual HTTP attempts and do not prove G3 reliability.",
    "Build, prompt and provider versions are not captured by these events; do not pool candidates.",
    "Burden, voluntary return, independent reuse and human blind comparisons require separate evidence.",
    "A real data-kind label is supplied by the operator, not verified by this tool.",
]


class InvalidInput(ValueError):
    """Only fixed, content-free error codes may leave this process."""


class SafeArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise InvalidInput("invalid_cli_arguments")


def strict_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise InvalidInput("duplicate_json_key")
        result[key] = value
    return result


def decode_json(value):
    try:
        return json.loads(value, object_pairs_hook=strict_object,
                          parse_constant=lambda _: (_ for _ in ()).throw(InvalidInput("nonfinite_json")))
    except (json.JSONDecodeError, UnicodeError, RecursionError):
        raise InvalidInput("invalid_json") from None


def instant(value):
    if not isinstance(value, str) or len(value) > 40:
        raise InvalidInput("invalid_timestamp")
    # App exports and CLI windows must use an explicit RFC3339 offset.
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})", value):
        raise InvalidInput("invalid_timestamp")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        raise InvalidInput("invalid_timestamp") from None


def identity(value):
    try:
        if not isinstance(value, str) or len(value) != 36:
            raise ValueError
        return str(UUID(value))
    except (ValueError, AttributeError):
        raise InvalidInput("invalid_event_identity") from None


def attributes(value):
    if not isinstance(value, str):
        raise InvalidInput("invalid_attributes")
    result = decode_json(value)
    if not isinstance(result, dict):
        raise InvalidInput("invalid_attributes")
    for key, item in result.items():
        valid = isinstance(item, str)
        if key in ENUMS:
            valid = valid and item in ENUMS[key]
        elif key == "content_version":
            valid = valid and len(item) <= 32 and (item in {"mentor-m1", "unavailable", "model-only"} or
                    re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", item) is not None)
        elif key == "duration_ms":
            valid = valid and re.fullmatch(r"[0-9]{1,20}", item) is not None
            valid = valid and int(item) <= 2**64 - 1
        else:
            valid = False
        if not valid:
            raise InvalidInput("unapproved_attribute_metadata")
    return result


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        return {"count": 0, "p50_ms": None, "p95_ms": None, "maximum_ms": None}
    return {"count": len(ordered), "p50_ms": ordered[(len(ordered) * 50 + 99) // 100 - 1],
            "p95_ms": ordered[(len(ordered) * 95 + 99) // 100 - 1], "maximum_ms": ordered[-1]}


def summarize(document, start, until, data_kind="unknown"):
    start, until = instant(start), instant(until)
    if start >= until or data_kind not in {"unknown", "synthetic", "real"}:
        raise InvalidInput("invalid_window_or_data_kind")
    if not isinstance(document, dict) or type(document.get("schema_version")) is not int or document["schema_version"] != 1:
        raise InvalidInput("unsupported_export_schema")
    snapshot = instant(document.get("created_at"))
    sections = document.get("sections")
    if not isinstance(sections, dict):
        raise InvalidInput("invalid_export_sections")
    rows = sections.get("mentor_usage_events")
    if not isinstance(rows, list):
        raise InvalidInput("usage_section_missing")

    events, duplicates = {}, 0
    for row in rows:
        if not isinstance(row, dict):
            raise InvalidInput("invalid_event_row")
        event_id = identity(row.get("event_id"))
        kind = row.get("event_kind")
        if not isinstance(kind, str) or kind not in KINDS:
            raise InvalidInput("unsupported_event_kind")
        event = {"id": event_id, "attempt": identity(row.get("attempt_id")),
                 "session": identity(row["session_id"]) if row.get("session_id") is not None else None,
                 "kind": kind, "at": instant(row.get("occurred_at")),
                 "attributes": attributes(row.get("attributes_json"))}
        if event["at"] > snapshot:
            raise InvalidInput("event_after_export_snapshot")
        if event_id in events:
            if events[event_id] != event:
                raise InvalidInput("conflicting_event_identity")
            duplicates += 1
        events[event_id] = event

    entries = {}
    for event in events.values():
        if event["kind"] == "entry_started":
            if event["attempt"] in entries or event["id"] != event["attempt"]:
                raise InvalidInput("conflicting_entry_attempt")
            entries[event["attempt"]] = event
    cohort = {key: event for key, event in entries.items() if start <= event["at"] < until}
    known_versions = {(event["attributes"].get("content_version", "unknown"),
                       event["attributes"].get("schema_version", "unknown")) for event in cohort.values()}
    mixed_versions = len(known_versions) > 1
    grouped = defaultdict(list)
    orphan_count = out_of_cohort = 0
    for event in events.values():
        if not start <= event["at"] < until:
            continue
        if event["attempt"] not in entries:
            orphan_count += 1
        elif event["attempt"] not in cohort:
            out_of_cohort += 1
        else:
            if event["at"] < cohort[event["attempt"]]["at"]:
                raise InvalidInput("event_before_entry")
            grouped[event["attempt"]].append(event)

    by_entry = {}
    for entry_name in ENTRIES:
        attempts = {key: event for key, event in cohort.items()
                    if event["attributes"].get("entry", "unknown") == entry_name}
        presentation_counts, reasons, exits, switches, feedback = (Counter() for _ in range(5))
        contents = {key: [] for key in ("new", "revisit", "unknown")}
        request_times = defaultdict(list)
        material = Counter()
        versions = Counter()
        missing_content = missing_exit = confirmed = ambiguous_first = untimed_requests = 0
        feedback_observed = 0
        for attempt_id, initial in attempts.items():
            material[initial["attributes"].get("has_material", "unknown")] += 1
            versions[(initial["attributes"].get("content_version", "unknown"),
                      initial["attributes"].get("schema_version", "unknown"))] += 1
            related = grouped[attempt_id]
            presentations = [e for e in related if e["kind"] == "content_presented"]
            missing_content += not bool(presentations)
            missing_exit += not any(e["kind"] == "session_left" for e in related)
            confirmed += any(e["kind"] == "understanding_confirmed" for e in related)
            first = [e for e in presentations if e["attributes"].get("first_content") == "true"]
            if len(first) > 1:
                ambiguous_first += 1
            elif len(first) == 1:
                metadata = first[0]["attributes"]
                if metadata.get("timing_scope") == "entry_to_content" and "duration_ms" in metadata:
                    contents[metadata.get("presentation", "unknown")].append(int(metadata["duration_ms"]))
            benefits = [e for e in related if e["kind"] == "benefit_feedback"]
            if benefits:
                feedback_observed += 1
                latest_at = max(e["at"] for e in benefits)
                latest = {e["attributes"].get("feedback", "unknown") for e in benefits if e["at"] == latest_at}
                feedback[next(iter(latest)) if len(latest) == 1 else "ambiguous_same_timestamp"] += 1
            else:
                feedback["missing"] += 1
            for event in related:
                metadata = event["attributes"]
                if "switched_entry" in metadata:
                    switches[metadata["switched_entry"]] += 1
                if event["kind"] == "content_presented":
                    presentation_counts[metadata.get("presentation", "unknown")] += 1
                if event["kind"] == "session_left":
                    exits[metadata.get("exit_phase", "unknown")] += 1
                if event["kind"] == "request_finished":
                    reason = metadata.get("reason", "unknown")
                    reasons[reason] += 1
                    if metadata.get("timing_scope") == "request" and "duration_ms" in metadata:
                        request_times[reason].append(int(metadata["duration_ms"]))
                    else:
                        untimed_requests += 1
        by_entry[entry_name] = {
            "attempts": len(attempts), "initial_material_presence": dict(sorted(material.items())),
            "presentations": dict(sorted(presentation_counts.items())),
            "attempts_without_observed_content": missing_content,
            "attempts_without_observed_exit": missing_exit,
            "latency_withheld_due_to_version_mixing": mixed_versions,
            "first_complete_content_latency_by_presentation": None if mixed_versions else
                {key: distribution(value) for key, value in contents.items()},
            "ambiguous_first_content_attempts": ambiguous_first,
            "request_terminal_events": dict(sorted(reasons.items())),
            "request_latency_by_terminal_reason": None if mixed_versions else
                {key: distribution(value) for key, value in sorted(request_times.items())},
            "request_events_without_timing": untimed_requests,
            "exit_phase_events": dict(sorted(exits.items())), "switched_entry_events": dict(sorted(switches.items())),
            "understanding_confirmed_attempts": confirmed,
            "latest_feedback_enum_by_attempt": dict(sorted(feedback.items())),
            "feedback_observed_attempts": feedback_observed,
            "entry_content_schema_versions": [{"content": key[0], "schema": key[1], "attempts": count}
                                               for key, count in sorted(versions.items())],
            "concrete_benefit_cases": None,
        }
    return {
        "report_schema_version": 1, "data_kind": data_kind, "goal_status": "not_assessed",
        "window": {"from_inclusive": start.isoformat(), "until_exclusive": until.isoformat(),
                   "export_created_at": snapshot.isoformat(), "snapshot_before_window_end": snapshot < until},
        "percentiles": "nearest_rank", "observed_entry_attempts": len(cohort),
        "mixed_entry_content_schema_versions": mixed_versions,
        "candidate_build_prompt_provider_binding": "not_available_in_usage_events",
        "duplicate_identical_rows_ignored": duplicates, "events_without_entry_in_export": orphan_count,
        "in_window_events_from_attempts_started_outside_window": out_of_cohort,
        "by_initial_entry": by_entry, "limits": LIMITS,
    }


def main(argv=None):
    parser = SafeArgumentParser(prog="summarize_mentor_usage.py", description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--from", dest="start", required=True, help="Inclusive RFC3339 timestamp")
    parser.add_argument("--until", required=True, help="Exclusive RFC3339 timestamp")
    parser.add_argument("--data-kind", choices=("unknown", "synthetic", "real"), default="unknown")
    parser.add_argument("--output", type=Path, help="New private JSON file; never overwrites an existing path")
    try:
        args = parser.parse_args(argv)
        with args.export.open("rb") as handle:
            content = handle.read(MAX_INPUT_BYTES + 1)
        if len(content) > MAX_INPUT_BYTES:
            raise InvalidInput("export_too_large")
        report = summarize(decode_json(content), args.start, args.until, args.data_kind)
        payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        if args.output:
            fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write(payload)
        else:
            sys.stdout.write(payload)
        return 0
    except InvalidInput as error:
        print("Usage summary rejected: " + str(error), file=sys.stderr)
    except (OSError, UnicodeError, RecursionError, ValueError, TypeError, OverflowError):
        # Never print paths, parser excerpts or private text from the export.
        print("Usage summary rejected: input_or_output_unavailable_or_invalid", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
