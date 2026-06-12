#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_alpha_acceptance.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

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

dry_output="$("$SCRIPT" \
  --dry-run \
  --skip-xcode-select \
  --ui-only-testing "MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion" \
  --ui-derived-data-path "$TMP_DIR/ui-dd" \
  --ui-result-bundle-path "$TMP_DIR/ui.xcresult" \
  --live-derived-data-path "$TMP_DIR/live-dd" \
  --live-output-xctestrun "$TMP_DIR/live.xctestrun" \
  --destination "platform=iOS Simulator,name=iPhone 17")"

assert_contains "MingSi Alpha acceptance plan:" "$dry_output"
assert_contains "1. scripts/check_alpha_prerequisites.sh --skip-xcode-select" "$dry_output"
assert_contains "2. scripts/run_ui_automation.sh" "$dry_output"
assert_contains "--only-testing MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion" "$dry_output"
assert_contains "$TMP_DIR/ui-dd" "$dry_output"
assert_contains "$TMP_DIR/ui.xcresult" "$dry_output"
assert_contains "3. scripts/run_live_glm_acceptance.sh" "$dry_output"
assert_contains "$TMP_DIR/live-dd" "$dry_output"
assert_contains "$TMP_DIR/live.xctestrun" "$dry_output"
assert_contains "accepted_key_envs: MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY" "$dry_output"
assert_not_contains "** TEST SUCCEEDED **" "$dry_output"
assert_not_contains "secret-value" "$dry_output"

set +e
missing_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY "$SCRIPT" --skip-xcode-select --skip-ui 2>&1)"
missing_status=$?
set -e

[[ "$missing_status" == "3" ]] || fail "missing-key acceptance should exit 3, got $missing_status"
assert_contains "alpha_acceptance: blocked_missing_live_glm_key" "$missing_output"
assert_contains "ui_automation: skipped" "$missing_output"
assert_contains "next_step: provide a BYOK key and approved external network window, then run scripts/run_alpha_acceptance.sh" "$missing_output"

ready_output="$(MINGSI_GLM_API_KEY="secret-value" "$SCRIPT" --dry-run --skip-xcode-select --skip-ui)"
assert_contains "live_glm: ready" "$ready_output"
assert_contains "MINGSI_GLM_API_KEY=<provided>" "$ready_output"
assert_contains "skip_ui: true" "$ready_output"
assert_not_contains "secret-value" "$ready_output"

printf 'PASS: alpha acceptance script contract\n'
