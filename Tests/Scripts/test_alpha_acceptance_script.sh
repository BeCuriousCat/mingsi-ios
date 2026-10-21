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

dry_output="$(MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=missing "$SCRIPT" \
  --dry-run \
  --skip-xcode-select \
  --summary-json "$TMP_DIR/dry-summary.json" \
  --ui-only-testing "MingSiUITests/MingSiUITests/testTodayReviewCardsSeedCanDriveRenderedLoopToCompletion" \
  --ui-derived-data-path "$TMP_DIR/ui-dd" \
  --ui-result-bundle-path "$TMP_DIR/ui.xcresult" \
  --live-derived-data-path "$TMP_DIR/live-dd" \
  --live-output-xctestrun "$TMP_DIR/live.xctestrun" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4")"

assert_contains "MingSi Alpha acceptance plan:" "$dry_output"
assert_contains "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4" "$dry_output"
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
[[ -f "$TMP_DIR/dry-summary.json" ]] || fail "dry-run should write summary JSON when requested"
python3 - "$TMP_DIR/dry-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

assert summary["status"] == "dry_run", summary
assert summary["exit_code"] == 0, summary
assert summary["ui_automation"] == "planned", summary
assert summary["live_glm"] == "missing_key", summary
assert summary["provided_key_env"] == "", summary
assert summary["accepted_key_envs"] == ["MINGSI_LIVE_GLM_API_KEY", "MINGSI_GLM_API_KEY", "GLM_API_KEY"], summary
PY

set +e
missing_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=missing "$SCRIPT" --skip-xcode-select --skip-ui --summary-json "$TMP_DIR/missing-summary.json" 2>&1)"
missing_status=$?
set -e

[[ "$missing_status" == "3" ]] || fail "missing-key acceptance should exit 3, got $missing_status"
assert_contains "alpha_acceptance: blocked_missing_live_glm_key" "$missing_output"
assert_contains "ui_automation: skipped" "$missing_output"
assert_contains "next_step: provide a BYOK key and approved external network window, then run scripts/run_alpha_acceptance.sh" "$missing_output"
[[ -f "$TMP_DIR/missing-summary.json" ]] || fail "missing-key acceptance should write summary JSON"
python3 - "$TMP_DIR/missing-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

assert summary["status"] == "blocked_missing_live_glm_key", summary
assert summary["exit_code"] == 3, summary
assert summary["preflight"] == "missing_key", summary
assert summary["ui_automation"] == "skipped", summary
assert summary["live_glm"] == "missing_key", summary
assert summary["provided_key_env"] == "", summary
PY

ready_output="$(MINGSI_GLM_API_KEY="secret-value" "$SCRIPT" --dry-run --skip-xcode-select --skip-ui --summary-json "$TMP_DIR/ready-summary.json")"
assert_contains "live_glm: ready" "$ready_output"
assert_contains "MINGSI_GLM_API_KEY=<provided>" "$ready_output"
assert_contains "skip_ui: true" "$ready_output"
assert_not_contains "secret-value" "$ready_output"
[[ -f "$TMP_DIR/ready-summary.json" ]] || fail "ready dry-run should write summary JSON"
assert_not_contains "secret-value" "$(cat "$TMP_DIR/ready-summary.json")"
python3 - "$TMP_DIR/ready-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

assert summary["status"] == "dry_run", summary
assert summary["exit_code"] == 0, summary
assert summary["ui_automation"] == "skipped", summary
assert summary["live_glm"] == "ready", summary
assert summary["provided_key_env"] == "MINGSI_GLM_API_KEY", summary
PY

mentor_ready_output="$(MINGSI_GLM_API_KEY="secret-value" "$SCRIPT" --dry-run --skip-xcode-select --skip-ui --live-mentor-semantic --summary-json "$TMP_DIR/mentor-summary.json")"
assert_contains "3. scripts/run_live_glm_acceptance.sh --mentor-semantic" "$mentor_ready_output"
assert_not_contains "secret-value" "$mentor_ready_output"
python3 - "$TMP_DIR/mentor-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

assert summary["live_mentor_semantic"] is True, summary
PY

keychain_ready_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=present "$SCRIPT" --dry-run --skip-xcode-select --skip-ui --summary-json "$TMP_DIR/keychain-summary.json")"
assert_contains "live_glm: ready" "$keychain_ready_output"
assert_contains "Keychain=<provided>" "$keychain_ready_output"
[[ -f "$TMP_DIR/keychain-summary.json" ]] || fail "keychain dry-run should write summary JSON"
python3 - "$TMP_DIR/keychain-summary.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

assert summary["status"] == "dry_run", summary
assert summary["exit_code"] == 0, summary
assert summary["ui_automation"] == "skipped", summary
assert summary["live_glm"] == "ready", summary
assert summary["provided_key_env"] == "Keychain", summary
PY

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/live/Build/Products"
cat > "$TMP_DIR/live/Build/Products/fake.xctestrun" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>MingSiTests</key><dict/></dict></plist>
PLIST
cat > "$TMP_DIR/bin/xcodebuild" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TMP_DIR/bin/xcrun" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "simctl" ]]; then
  printf '%s\n' '{"devices":{"iOS":[{"udid":"9F93EE80-68DF-4922-8A73-B0590F5143D4","name":"iPhone 17","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17","state":"Booted","isAvailable":true}]}}'
elif [[ "$1" == "xcresulttool" ]]; then
  if [[ "${MINGSI_SCRIPT_TEST_XCRESULT_PASS:-0}" == "1" ]]; then
    printf '%s\n' '{"totalTestCount":1,"passedTests":1,"skippedTests":0,"failedTests":0}'
  else
    printf '%s\n' '{"totalTestCount":1,"passedTests":0,"skippedTests":1,"failedTests":0}'
  fi
else
  exit 1
fi
SH
chmod +x "$TMP_DIR/bin/xcodebuild" "$TMP_DIR/bin/xcrun"

set +e
skipped_live_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY \
  PATH="$TMP_DIR/bin:$PATH" MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=present "$SCRIPT" \
  --skip-xcode-select --skip-ui --live-mentor-semantic \
  --live-derived-data-path "$TMP_DIR/live" --summary-json "$TMP_DIR/ready-summary.json" 2>&1)"
skipped_live_status=$?
set -e
[[ "$skipped_live_status" == "3" ]] || fail "skipped live test must fail Alpha acceptance"
assert_contains "alpha_acceptance: failed_live_glm" "$skipped_live_output"
assert_not_contains "alpha_acceptance: accepted" "$skipped_live_output"
jq -e '.status == "failed_live_glm" and .exit_code == 3 and .live_glm == "not_accepted" and .ui_automation == "skipped"' \
  "$TMP_DIR/ready-summary.json" >/dev/null || fail "a skipped live test must replace the prior summary"

executed_live_output="$(env -u MINGSI_LIVE_GLM_API_KEY -u MINGSI_GLM_API_KEY -u GLM_API_KEY \
  PATH="$TMP_DIR/bin:$PATH" MINGSI_ALPHA_KEYCHAIN_TEST_OVERRIDE=present MINGSI_SCRIPT_TEST_XCRESULT_PASS=1 "$SCRIPT" \
  --skip-xcode-select --skip-ui --live-mentor-semantic \
  --live-derived-data-path "$TMP_DIR/live" --summary-json "$TMP_DIR/executed-summary.json" 2>&1)"
assert_contains "live_glm: verified_execution" "$executed_live_output"
assert_contains "alpha_acceptance: semantic_review_required" "$executed_live_output"
assert_not_contains "alpha_acceptance: accepted" "$executed_live_output"
jq -e '.status == "semantic_review_required" and .live_glm == "verified_execution"' \
  "$TMP_DIR/executed-summary.json" >/dev/null || fail "technical success must still require semantic review"

printf 'PASS: alpha acceptance script contract\n'
