#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/fixed_simulator_guard.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local haystack="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

mingsi_validate_simulator_destination "$MINGSI_FIXED_SIMULATOR_DESTINATION"
assert_contains "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4" "$(mingsi_fixed_simulator_usage)"

set +e
rejected_output="$(mingsi_validate_simulator_destination "platform=iOS Simulator,name=iPhone 17" 2>&1)"
rejected_status=$?
set -e
[[ "$rejected_status" == "2" ]] || fail "non-fixed destination should exit 2, got $rejected_status"
assert_contains "Refusing non-fixed simulator destination" "$rejected_output"

opt_out_output="$(MINGSI_ALLOW_NONFIXED_SIMULATOR=1 mingsi_validate_simulator_destination "platform=iOS Simulator,name=iPhone 17" 2>&1)"
assert_contains "WARNING: MINGSI_ALLOW_NONFIXED_SIMULATOR=1" "$opt_out_output"

xcrun() {
  [[ "$1" == "simctl" && "$2" == "list" && "$3" == "devices" && "$4" == "--json" ]] || return 1
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-5":[{"udid":"9F93EE80-68DF-4922-8A73-B0590F5143D4","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17","name":"iPhone 17","state":"Shutdown"}]}}
JSON
}

validation_output="$(mingsi_validate_fixed_simulator)"
assert_contains "Fixed simulator ready: iPhone 17" "$validation_output"

printf 'PASS: fixed simulator guard contract\n'
