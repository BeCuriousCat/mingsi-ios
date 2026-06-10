#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_ui_automation.sh"
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
  --destination "platform=iOS Simulator,name=iPhone 17" \
  --derived-data-path "$TMP_DIR/dd" \
  --result-bundle-path "$TMP_DIR/ui.xcresult" \
  --only-testing "MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion")"

assert_contains "MingSi UI automation runner:" "$dry_output"
assert_contains "xcodebuild test" "$dry_output"
assert_contains "-project" "$dry_output"
assert_contains "MingSi.xcodeproj" "$dry_output"
assert_contains "-scheme" "$dry_output"
assert_contains "MingSi" "$dry_output"
assert_contains "-destination" "$dry_output"
assert_contains "platform=iOS Simulator,name=iPhone 17" "$dry_output"
assert_contains "-derivedDataPath" "$dry_output"
assert_contains "$TMP_DIR/dd" "$dry_output"
assert_contains "-resultBundlePath" "$dry_output"
assert_contains "$TMP_DIR/ui.xcresult" "$dry_output"
assert_contains "-only-testing:MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion" "$dry_output"
assert_not_contains "** TEST SUCCEEDED **" "$dry_output"

[[ ! -e "$TMP_DIR/ui.xcresult" ]] || fail "dry-run should not create a result bundle"

default_output="$("$SCRIPT" --dry-run)"
assert_contains "-only-testing:MingSiUITests" "$default_output"
assert_contains "mingsi-ui-automation-dd" "$default_output"
assert_contains "mingsi-ui-automation.xcresult" "$default_output"

printf 'PASS: UI automation runner script contract\n'
