#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/fixed_simulator_guard.sh"
UI_RUNNER="$ROOT_DIR/scripts/run_ui_automation.sh"
LIVE_GLM_RUNNER="$ROOT_DIR/scripts/run_live_glm_acceptance.sh"
PROJECT_PATH="$ROOT_DIR/MingSi.xcodeproj"
SKIP_XCODE_SELECT=0

usage() {
  cat <<'USAGE'
Usage: scripts/check_alpha_prerequisites.sh [options]

Check whether MingSi's post-MVP Alpha external prerequisites are ready.

Options:
  --skip-xcode-select     Skip checking for xcodebuild on PATH.
  -h, --help              Show this help.

Exit codes:
  0  UI automation and live GLM runner prerequisites are locally ready.
  2  Local tooling or runner files are missing.
  3  Local runners are ready, but no BYOK GLM key is visible.

Key detection checks accepted environment variables first, then the fixed simulator's Keychain
item used by KeychainAPIKeyStore: service com.codex.mingsi.glm, account
glm_api_key. Set MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=present|missing for tests only.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-xcode-select)
      SKIP_XCODE_SELECT=1
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

status=0
missing_local=0
missing_key=0

printf 'MingSi Alpha prerequisites:\n'

if [[ -d "$PROJECT_PATH" ]]; then
  printf 'project: ready (%s)\n' "$PROJECT_PATH"
else
  printf 'project: missing (%s)\n' "$PROJECT_PATH"
  missing_local=1
fi

if [[ "$SKIP_XCODE_SELECT" == "1" ]]; then
  printf 'xcodebuild: skipped\n'
elif command -v xcodebuild >/dev/null 2>&1; then
  printf 'xcodebuild: ready\n'
else
  printf 'xcodebuild: missing\n'
  missing_local=1
fi

if [[ -x "$UI_RUNNER" ]] && "$UI_RUNNER" --dry-run >/dev/null; then
  printf 'ui_automation: ready\n'
else
  printf 'ui_automation: missing_or_invalid\n'
  missing_local=1
fi

if [[ -x "$LIVE_GLM_RUNNER" ]] && "$LIVE_GLM_RUNNER" --dry-run >/dev/null; then
  printf 'live_glm_runner: ready\n'
else
  printf 'live_glm_runner: missing_or_invalid\n'
  missing_local=1
fi

printf 'accepted_key_envs: MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY\n'

keychain_has_key() {
  case "${MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE:-auto}" in
    present)
      return 0
      ;;
    missing)
      return 1
      ;;
    auto|"")
      python3 "$ROOT_DIR/scripts/check_simulator_glm_key.py" "$MINGSI_FIXED_SIMULATOR_UDID"
      ;;
    *)
      printf 'Invalid MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE: %s\n' "$MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE" >&2
      return 1
      ;;
  esac
}

provided_key_name=""
if [[ -n "${MINGSI_LIVE_GLM_API_KEY:-}" ]]; then
  provided_key_name="MINGSI_LIVE_GLM_API_KEY"
elif [[ -n "${MINGSI_GLM_API_KEY:-}" ]]; then
  provided_key_name="MINGSI_GLM_API_KEY"
elif [[ -n "${GLM_API_KEY:-}" ]]; then
  provided_key_name="GLM_API_KEY"
elif keychain_has_key; then
  provided_key_name="Keychain"
fi

if [[ -n "$provided_key_name" ]]; then
  printf '%s=<provided>\n' "$provided_key_name"
  printf 'live_glm: ready\n'
else
  printf 'live_glm: missing_key\n'
  printf 'next_step: provide a BYOK key and approved external network window, then run scripts/run_live_glm_acceptance.sh\n'
  missing_key=1
fi

if [[ "$missing_local" == "1" ]]; then
  status=2
elif [[ "$missing_key" == "1" ]]; then
  status=3
fi

exit "$status"
