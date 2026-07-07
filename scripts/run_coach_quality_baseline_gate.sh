#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="platform=iOS Simulator,name=iPhone 17"
PHONE_TRIAL_FILE="$ROOT_DIR/docs/coach-quality-phone-trial.md"
SUMMARY_JSON=""
SKIP_UI=0
SKIP_BUILD=0
ALLOW_PENDING_PHONE_TRIAL=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/run_coach_quality_baseline_gate.sh [options]

Run MingSi's coach quality baseline gate.

The gate checks:
  1. coach-quality golden cases have at least 20 entries and required coverage
  2. coach baseline focused unit/spec tests pass
  3. AppStore state-machine tests pass
  4. UI tests pass unless skipped
  5. xcodebuild build passes unless skipped
  6. the real-phone trial evidence file says Status: PASSED

Options:
  --destination VALUE             xcodebuild destination. Default: iPhone 17 simulator.
  --phone-trial-file PATH         Phone trial evidence file.
  --summary-json PATH             Write a JSON summary.
  --skip-ui                       Skip UI tests.
  --skip-build                    Skip final build.
  --allow-pending-phone-trial     Exit 0 even if phone trial is pending.
  --dry-run                       Print the gate plan without running tests.
  -h, --help                      Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --phone-trial-file)
      PHONE_TRIAL_FILE="${2:-}"
      shift 2
      ;;
    --summary-json)
      SUMMARY_JSON="${2:-}"
      shift 2
      ;;
    --skip-ui)
      SKIP_UI=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --allow-pending-phone-trial)
      ALLOW_PENDING_PHONE_TRIAL=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

write_summary() {
  local status="$1"
  local phone_trial="$2"
  [[ -n "$SUMMARY_JSON" ]] || return 0

  mkdir -p "$(dirname "$SUMMARY_JSON")"
  cat >"$SUMMARY_JSON" <<JSON
{
  "status": "$(json_escape "$status")",
  "phone_trial": "$(json_escape "$phone_trial")",
  "destination": "$(json_escape "$DESTINATION")",
  "phone_trial_file": "$(json_escape "$PHONE_TRIAL_FILE")",
  "skip_ui": $([[ "$SKIP_UI" == "1" ]] && printf true || printf false),
  "skip_build": $([[ "$SKIP_BUILD" == "1" ]] && printf true || printf false),
  "allow_pending_phone_trial": $([[ "$ALLOW_PENDING_PHONE_TRIAL" == "1" ]] && printf true || printf false),
  "dry_run": $([[ "$DRY_RUN" == "1" ]] && printf true || printf false)
}
JSON
}

run_step() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  "$@"
}

check_golden_cases() {
  local file="$ROOT_DIR/docs/coach-quality-golden-cases.json"
  local count
  count="$(jq 'length' "$file")"
  if (( count < 20 )); then
    printf 'Expected at least 20 golden cases, found %s.\n' "$count" >&2
    return 1
  fi

  local required_tags=(
    "流水账"
    "背景缺失"
    "对象不清"
    "证据不足"
    "判断跳跃"
    "行动替代目标"
    "旧经验误用"
    "明日验证不可检查"
  )
  local tag
  for tag in "${required_tags[@]}"; do
    if ! jq -e --arg tag "$tag" '[.[].coverageTags[]] | index($tag)' "$file" >/dev/null; then
      printf 'Missing golden-case coverage tag: %s\n' "$tag" >&2
      return 1
    fi
  done
  printf 'Golden cases: %s entries with required coverage.\n' "$count"
}

phone_trial_status() {
  if [[ -f "$PHONE_TRIAL_FILE" ]] && rg -q '^Status:[[:space:]]*PASSED[[:space:]]*$' "$PHONE_TRIAL_FILE"; then
    printf 'passed'
    return 0
  fi
  printf 'pending'
  return 1
}

check_phone_trial() {
  local status
  status="$(phone_trial_status || true)"
  if [[ "$status" == "passed" ]]; then
    printf 'Phone trial evidence: PASSED.\n'
    return 0
  fi

  printf 'Phone trial evidence is pending: %s\n' "$PHONE_TRIAL_FILE" >&2
  if xcrun xctrace list devices 2>/dev/null | rg -q 'Devices Offline'; then
    printf 'A real iPhone appears offline. Connect/unlock it before the phone-day trial.\n' >&2
  fi
  printf 'To prepare the phone build and evidence fields, run: scripts/prepare_coach_quality_phone_trial.sh\n' >&2
  [[ "$ALLOW_PENDING_PHONE_TRIAL" == "1" ]]
}

focused_tests() {
  xcodebuild test \
    -scheme MingSi \
    -destination "$DESTINATION" \
    -parallel-testing-enabled NO \
    -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachObservationPolicyCoversCoachQualityGoldenCases \
    -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachPatternSummaryPolicyKeepsOnlyRecentGapPatternSummary \
    -only-testing:MingSiTests/TodayAIServiceContextTests/testCoachPatternSummaryIsInjectedOnlyForCoachPrompts \
    -only-testing:MingSiTests/PromptSpecificationDocumentTests/testCoachQualityBaselineDocumentsCurrentStageGuardrails \
    -only-testing:MingSiTests/PromptSpecificationDocumentTests/testCoachQualityGoldenCasesCoverStageStopConditions \
    -only-testing:MingSiTests/PromptSpecificationDocumentTests/testTodayCoachMainPathAvoidsHighCostUserTerms
}

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<PLAN
Coach quality baseline gate plan:
- destination: $DESTINATION
- phone trial file: $PHONE_TRIAL_FILE
- skip UI: $SKIP_UI
- skip build: $SKIP_BUILD
- allow pending phone trial: $ALLOW_PENDING_PHONE_TRIAL
PLAN
  write_summary "dry_run" "$(phone_trial_status || true)"
  exit 0
fi

run_step "Golden cases" check_golden_cases
run_step "Focused coach baseline tests" focused_tests
run_step "State machine tests" xcodebuild test -scheme MingSi -destination "$DESTINATION" -parallel-testing-enabled NO -only-testing:MingSiTests/AppStoreStateMachineTests

if [[ "$SKIP_UI" == "0" ]]; then
  run_step "UI tests" xcodebuild test -scheme MingSi -destination "$DESTINATION" -parallel-testing-enabled NO -only-testing:MingSiUITests
else
  printf '\n== UI tests ==\nSkipped by --skip-ui.\n'
fi

if [[ "$SKIP_BUILD" == "0" ]]; then
  run_step "Build" xcodebuild build -scheme MingSi -destination "$DESTINATION"
else
  printf '\n== Build ==\nSkipped by --skip-build.\n'
fi

if run_step "Phone-day trial evidence" check_phone_trial; then
  write_summary "passed" "$(phone_trial_status || true)"
  printf '\nCoach quality baseline gate passed.\n'
else
  write_summary "blocked_by_phone_trial" "pending"
  printf '\nCoach quality baseline gate is pending the real-phone trial.\n' >&2
  exit 1
fi
