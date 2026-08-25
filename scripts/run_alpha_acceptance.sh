#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRECHECK="$ROOT_DIR/scripts/check_alpha_prerequisites.sh"
UI_RUNNER="$ROOT_DIR/scripts/run_ui_automation.sh"
LIVE_GLM_RUNNER="$ROOT_DIR/scripts/run_live_glm_acceptance.sh"
source "$ROOT_DIR/scripts/fixed_simulator_guard.sh"

DESTINATION="$MINGSI_FIXED_SIMULATOR_DESTINATION"
UI_DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-alpha-ui-dd"
UI_RESULT_BUNDLE_PATH="${TMPDIR:-/tmp}/mingsi-alpha-ui.xcresult"
UI_ONLY_TESTING="MingSiUITests"
LIVE_DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-alpha-live-glm-dd"
LIVE_OUTPUT_XCTESTRUN=""
SUMMARY_JSON=""
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
  --destination VALUE             xcodebuild destination. Default: fixed iPhone 17 UDID.
  --ui-derived-data-path PATH     DerivedData path for UI automation.
  --ui-result-bundle-path PATH    UI automation xcresult output path.
  --ui-only-testing VALUE         XCTest selector for UI automation. Default: MingSiUITests.
  --live-derived-data-path PATH   DerivedData path for live GLM acceptance.
  --live-output-xctestrun PATH    Output .xctestrun path for live GLM environment injection.
  --summary-json PATH             Write a machine-readable acceptance summary JSON.
  --skip-xcode-select             Skip checking for xcodebuild during preflight.
  --skip-ui                       Skip UI automation, but still require live GLM readiness.
  --dry-run                       Print sanitized plan and key readiness; do not run tests.
  -h, --help                      Show this help.

Accepted BYOK key env vars, in precedence order:
  MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY
If those are absent, the runner also checks the app Keychain item:
  service com.codex.mingsi.glm, account glm_api_key
USAGE
  mingsi_fixed_simulator_usage
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
    --summary-json)
      SUMMARY_JSON="${2:-}"
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

mingsi_validate_simulator_destination "$DESTINATION"

if [[ -z "$LIVE_OUTPUT_XCTESTRUN" ]]; then
  LIVE_OUTPUT_XCTESTRUN="$LIVE_DERIVED_DATA_PATH/Build/Products/MingSi_MingSi_alpha-live-glm.xctestrun"
fi

precheck_args=()
if [[ "$SKIP_XCODE_SELECT" == "1" ]]; then
  precheck_args+=(--skip-xcode-select)
fi

keychain_has_key() {
  case "${MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE:-auto}" in
    present)
      return 0
      ;;
    missing)
      return 1
      ;;
    auto|"")
      security find-generic-password -s com.codex.mingsi.glm -a glm_api_key >/dev/null 2>&1
      ;;
    *)
      printf 'Invalid MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE: %s\n' "$MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE" >&2
      return 1
      ;;
  esac
}

resolve_provided_key_name() {
  if [[ -n "${MINGSI_LIVE_GLM_API_KEY:-}" ]]; then
    printf 'MINGSI_LIVE_GLM_API_KEY'
  elif [[ -n "${MINGSI_GLM_API_KEY:-}" ]]; then
    printf 'MINGSI_GLM_API_KEY'
  elif [[ -n "${GLM_API_KEY:-}" ]]; then
    printf 'GLM_API_KEY'
  elif keychain_has_key; then
    printf 'Keychain'
  fi
}

provided_key_name="$(resolve_provided_key_name)"

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
  local exit_code="$2"
  local preflight_status="$3"
  local ui_status="$4"
  local live_status="$5"
  [[ -n "$SUMMARY_JSON" ]] || return 0

  mkdir -p "$(dirname "$SUMMARY_JSON")"
  cat >"$SUMMARY_JSON" <<JSON
{
  "status": "$(json_escape "$status")",
  "exit_code": $exit_code,
  "preflight": "$(json_escape "$preflight_status")",
  "ui_automation": "$(json_escape "$ui_status")",
  "live_glm": "$(json_escape "$live_status")",
  "provided_key_env": "$(json_escape "$provided_key_name")",
  "accepted_key_envs": ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"],
  "destination": "$(json_escape "$DESTINATION")",
  "skip_ui": $([[ "$SKIP_UI" == "1" ]] && printf true || printf false),
  "dry_run": $([[ "$DRY_RUN" == "1" ]] && printf true || printf false),
  "ui_only_testing": "$(json_escape "$UI_ONLY_TESTING")",
  "ui_derived_data_path": "$(json_escape "$UI_DERIVED_DATA_PATH")",
  "ui_result_bundle_path": "$(json_escape "$UI_RESULT_BUNDLE_PATH")",
  "live_derived_data_path": "$(json_escape "$LIVE_DERIVED_DATA_PATH")",
  "live_output_xctestrun": "$(json_escape "$LIVE_OUTPUT_XCTESTRUN")"
}
JSON
}

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
  if (( ${#precheck_args[@]} > 0 )); then
    for arg in "${precheck_args[@]}"; do
      printf ' %s' "$arg"
    done
  fi
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
  if [[ -n "$provided_key_name" ]]; then
    live_status="ready"
  else
    live_status="missing_key"
  fi
  if [[ "$SKIP_UI" == "1" ]]; then
    ui_status="skipped"
  else
    ui_status="planned"
  fi
  write_summary "dry_run" 0 "not_run" "$ui_status" "$live_status"
  exit 0
fi

mingsi_validate_fixed_simulator

set +e
if (( ${#precheck_args[@]} > 0 )); then
  precheck_output="$("$PRECHECK" "${precheck_args[@]}" 2>&1)"
else
  precheck_output="$("$PRECHECK" 2>&1)"
fi
precheck_status=$?
set -e

if [[ "$precheck_status" != "0" ]]; then
  printf '%s\n' "$precheck_output"
  if [[ "$precheck_status" == "3" ]]; then
    if [[ "$SKIP_UI" == "1" ]]; then
      printf 'ui_automation: skipped\n'
      ui_status="skipped"
    else
      printf 'ui_automation: not_run_preflight_blocked\n'
      ui_status="not_run_preflight_blocked"
    fi
    printf 'alpha_acceptance: blocked_missing_live_glm_key\n'
    printf 'next_step: provide a BYOK key and approved external network window, then run scripts/run_alpha_acceptance.sh\n'
    write_summary "blocked_missing_live_glm_key" "$precheck_status" "missing_key" "$ui_status" "missing_key"
  else
    printf 'alpha_acceptance: blocked_local_prerequisites\n'
    write_summary "blocked_local_prerequisites" "$precheck_status" "missing_local" "not_run_preflight_blocked" "not_run_preflight_blocked"
  fi
  exit "$precheck_status"
fi

printf '%s\n' "$precheck_output"
ui_status="accepted"

if [[ "$SKIP_UI" == "1" ]]; then
  printf 'ui_automation: skipped\n'
  ui_status="skipped"
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
write_summary "accepted" 0 "ready" "$ui_status" "accepted"
