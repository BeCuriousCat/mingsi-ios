#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRECHECK="$ROOT_DIR/scripts/check_alpha_prerequisites.sh"
UI_RUNNER="$ROOT_DIR/scripts/run_ui_automation.sh"
LIVE_GLM_RUNNER="$ROOT_DIR/scripts/run_live_glm_acceptance.sh"

DESTINATION="platform=iOS Simulator,name=iPhone 17"
UI_DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-alpha-ui-dd"
UI_RESULT_BUNDLE_PATH="${TMPDIR:-/tmp}/mingsi-alpha-ui.xcresult"
UI_ONLY_TESTING="MingSiUITests"
LIVE_DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-alpha-live-glm-dd"
LIVE_OUTPUT_XCTESTRUN=""
SKIP_XCODE_SELECT=0
SKIP_UI=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/run_alpha_acceptance.sh [options]

Run MingSi's post-MVP Alpha acceptance gate:
  1. local prerequisite preflight
  2. iOS accessibility-driven UI automation
  3. opt-in live BYOK GLM XCTest harness

Options:
  --destination VALUE             xcodebuild destination. Default: iPhone 17 simulator.
  --ui-derived-data-path PATH     DerivedData path for UI automation.
  --ui-result-bundle-path PATH    UI automation xcresult output path.
  --ui-only-testing VALUE         XCTest selector for UI automation. Default: MingSiUITests.
  --live-derived-data-path PATH   DerivedData path for live GLM acceptance.
  --live-output-xctestrun PATH    Output .xctestrun path for live GLM environment injection.
  --skip-xcode-select             Skip checking for xcodebuild during preflight.
  --skip-ui                       Skip UI automation, but still require live GLM readiness.
  --dry-run                       Print sanitized plan and key readiness; do not run tests.
  -h, --help                      Show this help.

Accepted BYOK key env vars, in precedence order:
  MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --ui-derived-data-path)
      UI_DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --ui-result-bundle-path)
      UI_RESULT_BUNDLE_PATH="${2:-}"
      shift 2
      ;;
    --ui-only-testing)
      UI_ONLY_TESTING="${2:-}"
      shift 2
      ;;
    --live-derived-data-path)
      LIVE_DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --live-output-xctestrun)
      LIVE_OUTPUT_XCTESTRUN="${2:-}"
      shift 2
      ;;
    --skip-xcode-select)
      SKIP_XCODE_SELECT=1
      shift
      ;;
    --skip-ui)
      SKIP_UI=1
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

if [[ -z "$LIVE_OUTPUT_XCTESTRUN" ]]; then
  LIVE_OUTPUT_XCTESTRUN="$LIVE_DERIVED_DATA_PATH/Build/Products/MingSi_MingSi_alpha-live-glm.xctestrun"
fi

precheck_args=()
if [[ "$SKIP_XCODE_SELECT" == "1" ]]; then
  precheck_args+=(--skip-xcode-select)
fi

provided_key_name=""
if [[ -n "${MINGSI_LIVE_GLM_API_KEY:-}" ]]; then
  provided_key_name="MINGSI_LIVE_GLM_API_KEY"
elif [[ -n "${MINGSI_GLM_API_KEY:-}" ]]; then
  provided_key_name="MINGSI_GLM_API_KEY"
elif [[ -n "${GLM_API_KEY:-}" ]]; then
  provided_key_name="GLM_API_KEY"
fi

print_key_readiness() {
  printf 'accepted_key_envs: MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY\n'
  if [[ -n "$provided_key_name" ]]; then
    printf '%s=<provided>\n' "$provided_key_name"
    printf 'live_glm: ready\n'
  else
    printf 'live_glm: missing_key\n'
  fi
}

print_plan() {
  printf 'MingSi Alpha acceptance plan:\n'
  printf 'destination: %s\n' "$DESTINATION"
  printf 'skip_ui: %s\n' "$([[ "$SKIP_UI" == "1" ]] && printf true || printf false)"
  printf '\n'
  printf '1. scripts/check_alpha_prerequisites.sh'
  for arg in "${precheck_args[@]}"; do
    printf ' %s' "$arg"
  done
  printf '\n'
  if [[ "$SKIP_UI" == "1" ]]; then
    printf '2. scripts/run_ui_automation.sh skipped by --skip-ui\n'
  else
    printf '2. scripts/run_ui_automation.sh --destination %q --derived-data-path %q --result-bundle-path %q --only-testing %q\n' \
      "$DESTINATION" "$UI_DERIVED_DATA_PATH" "$UI_RESULT_BUNDLE_PATH" "$UI_ONLY_TESTING"
  fi
  printf '3. scripts/run_live_glm_acceptance.sh --destination %q --derived-data-path %q --output-xctestrun %q\n' \
    "$DESTINATION" "$LIVE_DERIVED_DATA_PATH" "$LIVE_OUTPUT_XCTESTRUN"
  printf '\n'
  print_key_readiness
}

if [[ "$DRY_RUN" == "1" ]]; then
  print_plan
  exit 0
fi

set +e
precheck_output="$("$PRECHECK" "${precheck_args[@]}" 2>&1)"
precheck_status=$?
set -e

if [[ "$precheck_status" != "0" ]]; then
  printf '%s\n' "$precheck_output"
  if [[ "$precheck_status" == "3" ]]; then
    if [[ "$SKIP_UI" == "1" ]]; then
      printf 'ui_automation: skipped\n'
    else
      printf 'ui_automation: not_run_preflight_blocked\n'
    fi
    printf 'alpha_acceptance: blocked_missing_live_glm_key\n'
    printf 'next_step: provide a BYOK key and approved external network window, then run scripts/run_alpha_acceptance.sh\n'
  else
    printf 'alpha_acceptance: blocked_local_prerequisites\n'
  fi
  exit "$precheck_status"
fi

printf '%s\n' "$precheck_output"

if [[ "$SKIP_UI" == "1" ]]; then
  printf 'ui_automation: skipped\n'
else
  "$UI_RUNNER" \
    --destination "$DESTINATION" \
    --derived-data-path "$UI_DERIVED_DATA_PATH" \
    --result-bundle-path "$UI_RESULT_BUNDLE_PATH" \
    --only-testing "$UI_ONLY_TESTING"
  printf 'ui_automation: accepted\n'
fi

"$LIVE_GLM_RUNNER" \
  --destination "$DESTINATION" \
  --derived-data-path "$LIVE_DERIVED_DATA_PATH" \
  --output-xctestrun "$LIVE_OUTPUT_XCTESTRUN"
printf 'live_glm: accepted\n'
printf 'alpha_acceptance: accepted\n'
