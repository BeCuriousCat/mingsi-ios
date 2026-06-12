#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check_alpha_prerequisites.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

set +e
missing_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=missing "$SCRIPT" --skip-xcode-select 2>&1)"
missing_status=$?
set -e

[[ "$missing_status" == "3" ]] || fail "missing-key preflight should exit 3, got $missing_status"
assert_contains "MingSi Alpha prerequisites:" "$missing_output"
assert_contains "ui_automation: ready" "$missing_output"
assert_contains "live_glm_runner: ready" "$missing_output"
assert_contains "live_glm: missing_key" "$missing_output"
assert_contains "accepted_key_envs: MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY" "$missing_output"
assert_contains "next_step: provide a BYOK key and approved external network window, then run scripts/run_live_glm_acceptance.sh" "$missing_output"

provided_output="$(MINGSI_GLM_API_KEY="super-secret-value" "$SCRIPT" --skip-xcode-select)"
assert_contains "live_glm: ready" "$provided_output"
assert_contains "MINGSI_GLM_API_KEY=<provided>" "$provided_output"
assert_not_contains "super-secret-value" "$provided_output"

keychain_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=present "$SCRIPT" --skip-xcode-select)"
assert_contains "live_glm: ready" "$keychain_output"
assert_contains "Keychain=<provided>" "$keychain_output"
assert_not_contains "live_glm: missing_key" "$keychain_output"

printf 'PASS: alpha prerequisites script contract\n'
