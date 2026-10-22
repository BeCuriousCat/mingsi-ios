#!/usr/bin/env python3
"""Use only the currently selected CC Switch Codex provider; never print its key."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import sqlite3
import subprocess
import tempfile
import tomllib


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-xctestrun", type=Path, required=True)
    parser.add_argument("--result-bundle-path", type=Path, required=True)
    parser.add_argument("--mentor-streaming", action="store_true", help="Run one audited mentor stream; observe preview before completion and SQLite save; never retry.")
    parser.add_argument("--request-boundaries", action="store_true", help="Run two distinct requested-question and quoted-wording turns with SQLite reopening; never retry.")
    parser.add_argument("--selected-excerpt", action="store_true", help="Run one distinct selected-teacher-context request; never retry.")
    parser.add_argument("--mentor-request", action="store_true", help="Run three distinct new-version fatigue/listening/help turns with SQLite reopening; never retry.")
    parser.add_argument("--mentor-uncertainty", action="store_true", help="Run three distinct new-version mentor boundary turns with SQLite reopening; never retry.")
    parser.add_argument("--guidance-selection", action="store_true", help="Run two distinct synthetic hint show/hold cases once each; never retry.")
    parser.add_argument("--mentor-criteria", action="store_true", help="Run two distinct new-version mentor turns through SQLite save/reopen; one attempt per turn, stop on first failure.")
    parser.add_argument("--direct-explanation", action="store_true", help="Run one streamed schema-7 direct-help request through AppStore and SQLite reopening; never retry.")
    parser.add_argument("--answer-review", action="store_true", help="Run three distinct synthetic answer-review choices once each.")
    parser.add_argument("--lens-library", action="store_true", help="Run four distinct synthetic lens scenarios once each.")
    parser.add_argument("--lens-goals", type=Path, help="Run the synthetic lens goal dataset once per selected turn; never retry.")
    parser.add_argument("--lens-case-ids", help="Optional comma-separated IDs from --lens-goals; unknown IDs fail before calling.")
    parser.add_argument("--perspective-understanding", action="store_true", help="Run the new perspective prompt once, then one distinct user-stop turn; never retry requests.")
    parser.add_argument("--import-connection", action="store_true",
                        help="Save the selected Responses connection in the fixed simulator Keychain instead of calling the model.")
    parser.add_argument("--today-guidance", action="store_true", help="Run synthetic Today question and stop-boundary acceptance.")
    parser.add_argument("--question-purpose-positive", action="store_true", help="Run only one new question-purpose scenario; do not repeat the no-question request.")
    parser.add_argument("--outcome-guidance", action="store_true", help="Run four synthetic action, calibration, and principle requests.")
    parser.add_argument("--result-calibration", action="store_true", help="Run three synthetic observed and conflicting result requests.")
    parser.add_argument("--history-evidence", action="store_true", help="Run three synthetic history-context and growth requests.")
    parser.add_argument("--principle-practice", action="store_true", help="Run four synthetic principle behavior/outcome separation requests.")
    parser.add_argument("--guidance-evidence", action="store_true", help="Run three synthetic guidance behavior evidence requests.")
    parser.add_argument("--topic-boundary", action="store_true", help="Run two synthetic actions without history-derived training.")
    parser.add_argument("--action-clarity", action="store_true", help="Run the two topic scenarios and one concrete negative prediction.")
    parser.add_argument("--action-clarity-remaining", action="store_true", help="Run only comparison and negative prediction, after replaying the captured network response offline.")
    parser.add_argument("--initial-coach-evidence", action="store_true", help="Run three synthetic initial coach gap and stop-boundary scenarios.")
    parser.add_argument("--initial-coach-positive", action="store_true", help="Run only one new unsupported-intent guidance scenario; do not repeat the prior three samples.")
    args = parser.parse_args()
    lens_cases = None
    if args.lens_goals:
        lens_cases = json.loads(args.lens_goals.read_text())
        if args.lens_case_ids:
            requested = set(args.lens_case_ids.split(","))
            available = {case["id"] for case in lens_cases}
            if not requested <= available:
                parser.error("Unknown lens case IDs")
            lens_cases = [case for case in lens_cases if case["id"] in requested]
        if not lens_cases or len(lens_cases) > 20:
            parser.error("Choose between 1 and 20 lens cases")
    elif args.lens_case_ids:
        parser.error("--lens-case-ids requires --lens-goals")
    if args.question_purpose_positive:
        args.today_guidance = True
    if args.initial_coach_positive:
        args.initial_coach_evidence = True
    if args.action_clarity_remaining:
        args.action_clarity = True
    if args.action_clarity:
        args.topic_boundary = True
    if sum([bool(args.lens_goals), args.mentor_streaming, args.request_boundaries, args.selected_excerpt, args.mentor_request, args.mentor_uncertainty, args.guidance_selection, args.mentor_criteria, args.direct_explanation, args.perspective_understanding, args.answer_review, args.lens_library, args.initial_coach_evidence, args.topic_boundary, args.import_connection, args.today_guidance, args.outcome_guidance, args.result_calibration, args.history_evidence, args.principle_practice, args.guidance_evidence]) > 1:
        parser.error("Choose one operation")
    database = Path.home() / ".cc-switch/cc-switch.db"
    with sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True) as connection:
        rows = connection.execute("SELECT name, settings_config FROM providers WHERE app_type='codex' AND is_current=1").fetchall()
    if len(rows) != 1:
        raise RuntimeError("Expected exactly one selected CC Switch Codex provider")
    name, raw = rows[0]
    settings = json.loads(raw)
    config = tomllib.loads(settings["config"])
    provider = config["model_providers"][config["model_provider"]]
    if provider.get("wire_api") != "responses" or not provider["base_url"].startswith("https://"):
        raise RuntimeError("The selected provider must use HTTPS Responses")
    key = settings["auth"]["OPENAI_API_KEY"]
    if not key.strip() or not config.get("model"):
        raise RuntimeError("Selected provider is missing its API key or model")

    source = args.source_xctestrun.resolve()
    with source.open("rb") as handle:
        run = plistlib.load(handle)
    target = run["MingSiTests"]
    for field in ["EnvironmentVariables", "TestingEnvironmentVariables"]:
        env = target.setdefault(field, {})
        # These are credentials specifically authorized for this provider.
        # Do not inherit GLM credentials or any unrelated process credentials.
        for variable in list(env):
            if variable.startswith("MINGSI_LIVE_") or variable == "MINGSI_IMPORT_MODEL_CONNECTION":
                del env[variable]
        # Xcode treats TestingEnvironmentVariables as paths, collapsing https://
        # into https:/. Custom URL/credential values belong only in EnvironmentVariables.
        if field == "TestingEnvironmentVariables":
            continue
        env.update({
            "MINGSI_LIVE_GLM_API_KEY": key,
            "MINGSI_LIVE_GLM_BASE_URL": provider["base_url"],
            "MINGSI_LIVE_GLM_MODEL": config["model"],
            "MINGSI_LIVE_MODEL_PROTOCOL": "responses",
        })
        if args.import_connection:
            env["MINGSI_IMPORT_MODEL_CONNECTION"] = "1"
        else:
            env["MINGSI_LIVE_MENTOR_ACCEPTANCE"] = "1"
            env["MINGSI_LIVE_GLM_ACCEPTANCE"] = "1"
            if args.mentor_streaming:
                env["MINGSI_LIVE_MENTOR_STREAMING"] = "1"
            if args.request_boundaries:
                env["MINGSI_LIVE_REQUEST_BOUNDARIES"] = "1"
            if args.selected_excerpt:
                env["MINGSI_LIVE_SELECTED_EXCERPT"] = "1"
            if args.mentor_request:
                env["MINGSI_LIVE_MENTOR_REQUEST"] = "1"
            if args.mentor_uncertainty:
                env["MINGSI_LIVE_MENTOR_UNCERTAINTY"] = "1"
            if args.guidance_selection:
                env["MINGSI_LIVE_GUIDANCE_SELECTION"] = "1"
            if args.mentor_criteria:
                env["MINGSI_LIVE_MENTOR_CRITERIA"] = "1"
            if args.direct_explanation:
                env["MINGSI_LIVE_DIRECT_EXPLANATION"] = "1"
            if args.answer_review:
                env["MINGSI_LIVE_ANSWER_REVIEW"] = "1"
            if args.lens_library:
                env["MINGSI_LIVE_LENS_LIBRARY"] = "1"
            if lens_cases:
                env["MINGSI_LIVE_LENS_GOALS_JSON"] = json.dumps(lens_cases, ensure_ascii=False)
            if args.perspective_understanding:
                env["MINGSI_LIVE_PERSPECTIVE_UNDERSTANDING"] = "1"
            if args.initial_coach_evidence:
                env["MINGSI_LIVE_INITIAL_COACH_EVIDENCE"] = "1"
                if args.initial_coach_positive:
                    env["MINGSI_LIVE_INITIAL_COACH_POSITIVE_ONLY"] = "1"
            if args.today_guidance:
                env["MINGSI_LIVE_TODAY_ACCEPTANCE"] = "1"
                if args.question_purpose_positive:
                    env["MINGSI_LIVE_QUESTION_PURPOSE_POSITIVE"] = "1"
            if args.outcome_guidance:
                env["MINGSI_LIVE_OUTCOME_ACCEPTANCE"] = "1"
            if args.result_calibration:
                env["MINGSI_LIVE_RESULT_CALIBRATION"] = "1"
            if args.history_evidence:
                env["MINGSI_LIVE_HISTORY_EVIDENCE"] = "1"
            if args.principle_practice:
                env["MINGSI_LIVE_PRINCIPLE_PRACTICE"] = "1"
            if args.guidance_evidence:
                env["MINGSI_LIVE_GUIDANCE_EVIDENCE"] = "1"
            if args.topic_boundary:
                env["MINGSI_LIVE_TOPIC_BOUNDARY"] = "1"
            if args.action_clarity:
                env["MINGSI_LIVE_ACTION_CLARITY"] = "1"
            if args.action_clarity_remaining:
                env["MINGSI_LIVE_ACTION_CLARITY_REMAINING"] = "1"

    selector = "testImportModelConnectionWhenExplicitlyEnabled" if args.import_connection else "testLiveMentorSemanticCasesWhenExplicitlyEnabled"
    if args.mentor_streaming:
        selector = "testLiveAuditedMentorStreamingWhenExplicitlyEnabled"
    if args.initial_coach_evidence:
        selector = "testLiveInitialCoachEvidenceWhenExplicitlyEnabled"
    if args.today_guidance:
        selector = "testLiveTodayQuestionAndStopBoundaryWhenExplicitlyEnabled"
    if args.outcome_guidance:
        selector = "testLiveOutcomeGuidanceWhenExplicitlyEnabled"
    if args.result_calibration:
        selector = "testLiveResultCalibrationWhenExplicitlyEnabled"
    if args.history_evidence:
        selector = "testLiveHistoricalEvidenceBoundaryWhenExplicitlyEnabled"
    if args.principle_practice:
        selector = "testLivePrinciplePracticeWhenExplicitlyEnabled"
    if args.guidance_evidence:
        selector = "testLiveGuidanceEvidenceWhenExplicitlyEnabled"
    if args.topic_boundary:
        selector = "testLiveActionDoesNotTurnHistoricalLabelsIntoTrainingWhenExplicitlyEnabled"
    if args.lens_library:
        selector = "testLiveExpandedLensLibraryWhenExplicitlyEnabled"
    if lens_cases:
        selector = "testLiveLensGoalsWhenExplicitlyEnabled"
    if args.answer_review:
        selector = "testLiveAnswerReviewChoiceWhenExplicitlyEnabled"
    if args.perspective_understanding:
        selector = "testLivePerspectiveUnderstandingAndUserStopWhenExplicitlyEnabled"
    if args.direct_explanation:
        selector = "testLiveDirectExplanationWhenExplicitlyEnabled"
    if args.request_boundaries:
        selector = "testLiveMentorRequestedQuestionAndQuotedWordingWhenExplicitlyEnabled"
    if args.selected_excerpt:
        selector = "testLiveSelectedTeacherExcerptWhenExplicitlyEnabled"
    if args.mentor_request:
        selector = "testLiveMentorFatigueAndRequestedHelpWhenExplicitlyEnabled"
    if args.mentor_uncertainty:
        selector = "testLiveMentorUncertaintyAndBoundaryAcrossThreeTurnsWhenExplicitlyEnabled"
    if args.guidance_selection:
        selector = "testLiveGuidanceSelectionWhenExplicitlyEnabled"
    if args.mentor_criteria:
        selector = "testLiveMentorCriteriaAcrossPersistedTurnsWhenExplicitlyEnabled"
    # TESTROOT-relative product paths require the copy to live beside its source.
    # mkstemp creates a 0600 file; remove it as soon as the hosted test completes.
    descriptor, temporary = tempfile.mkstemp(prefix="MingSi-cc-switch-", suffix=".xctestrun", dir=source.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            plistlib.dump(run, handle)
        print(json.dumps({"provider": name, "model": config["model"], "protocol": "responses",
                          "operation": "synthetic lens goal evaluation (one request per turn)" if lens_cases else "single audited mentor streaming preview and save" if args.mentor_streaming else "two requested-question and quoted-wording turns with SQLite reopening" if args.request_boundaries else "single selected-teacher excerpt request" if args.selected_excerpt else "three fatigue/listening/request turns with SQLite reopening" if args.mentor_request else "three new-version mentor uncertainty turns with SQLite reopening" if args.mentor_uncertainty else "synthetic guidance selection" if args.guidance_selection else "new-version mentor criteria with SQLite reopening" if args.mentor_criteria else "streamed schema-7 direct explanation with AppStore save/reopen" if args.direct_explanation else "new-version perspective and stopping boundary" if args.perspective_understanding else "synthetic answer review" if args.answer_review else "synthetic lens library" if args.lens_library else "synthetic initial coach evidence" if args.initial_coach_evidence else "synthetic topic boundary" if args.topic_boundary else "synthetic guidance evidence" if args.guidance_evidence else "synthetic principle practice" if args.principle_practice else ("synthetic historical evidence" if args.history_evidence else ("import" if args.import_connection else ("synthetic result calibration" if args.result_calibration else ("synthetic outcome acceptance" if args.outcome_guidance else ("synthetic Today acceptance" if args.today_guidance else "synthetic mentor acceptance")))))}, ensure_ascii=False), flush=True)
        result = subprocess.run([
            "xcodebuild", "-xctestrun", temporary,
            "-destination", "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4",
            "-resultBundlePath", str(args.result_bundle_path),
            "-collect-test-diagnostics", "never",
            "-only-testing:MingSiTests/LiveGLMAcceptanceTests/" + selector,
            "test-without-building", "-quiet",
        ])
    finally:
        Path(temporary).unlink(missing_ok=True)
    if result.returncode:
        raise SystemExit(result.returncode)
    summary = json.loads(subprocess.check_output([
        "xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(args.result_bundle_path)
    ]))
    if summary.get("passedTests") != 1 or summary.get("skippedTests") != 0 or summary.get("failedTests") != 0:
        raise SystemExit("Selected test did not pass without skips")
    print("connection_import: verified" if args.import_connection else "execution: verified; semantic_review: required")


if __name__ == "__main__":
    main()
