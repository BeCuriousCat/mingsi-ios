#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_live_glm_acceptance.sh"
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

cat > "$TMP_DIR/fake.xctestrun" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>MingSiTests</key>
  <dict>
    <key>BlueprintName</key>
    <string>MingSiTests</string>
    <key>TestingEnvironmentVariables</key>
    <dict>
      <key>MINGSI_LIVE_GLM_API_KEY</key><string>stale-secret</string>
      <key>MINGSI_LIVE_GLM_BASE_URL</key><string>https://stale.example</string>
      <key>DYLD_FRAMEWORK_PATH</key><string>__TESTROOT__/Frameworks</string>
    </dict>
  </dict>
  <key>TestConfigurations</key>
  <array>
    <dict>
      <key>TestTargets</key>
      <array>
        <dict>
          <key>BlueprintName</key>
          <string>MingSiTests</string>
          <key>TestingEnvironmentVariables</key>
          <dict>
            <key>MINGSI_LIVE_MENTOR_ACCEPTANCE</key><string>1</string>
            <key>MINGSI_LIVE_GLM_MODEL</key><string>stale-model</string>
            <key>DYLD_FRAMEWORK_PATH</key><string>__TESTROOT__/Frameworks</string>
          </dict>
        </dict>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

dry_output="$("$SCRIPT" \
  --dry-run \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/live-flag.xctestrun" \
  --api-key "secret-value" \
  --base-url "https://example.test/api/paas/v4/" \
  --model "glm-test" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4")"

assert_contains "MINGSI_LIVE_GLM_ACCEPTANCE=1" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_API_KEY=<provided>" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_BASE_URL=https://example.test/api/paas/v4/" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_MODEL=glm-test" "$dry_output"
assert_contains "test-without-building" "$dry_output"
assert_not_contains "MINGSI_LIVE_GLM_CAREER_GOLDEN=1" "$dry_output"
assert_not_contains "secret-value" "$dry_output"
[[ ! -e "$TMP_DIR/live-flag.xctestrun" ]] || fail "dry-run should not create output xctestrun"

career_dry_output="$("$SCRIPT" \
  --dry-run \
  --career-golden \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/career-live-flag.xctestrun" \
  --api-key "secret-value" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4")"

assert_contains "MINGSI_LIVE_GLM_CAREER_GOLDEN=1" "$career_dry_output"
assert_contains "testLiveGLMCareerGoldenQuestionsWhenExplicitlyEnabled" "$career_dry_output"
assert_not_contains "secret-value" "$career_dry_output"
[[ ! -e "$TMP_DIR/career-live-flag.xctestrun" ]] || fail "career dry-run should not create output xctestrun"

mentor_dry_output="$($SCRIPT \
  --dry-run \
  --mentor-semantic \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/mentor-live-flag.xctestrun" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4")"

assert_contains "MINGSI_LIVE_MENTOR_ACCEPTANCE=1" "$mentor_dry_output"
assert_contains "testLiveMentorSemanticCasesWhenExplicitlyEnabled" "$mentor_dry_output"
assert_not_contains "MINGSI_LIVE_GLM_CAREER_GOLDEN=1" "$mentor_dry_output"
[[ ! -e "$TMP_DIR/mentor-live-flag.xctestrun" ]] || fail "mentor dry-run should not create output xctestrun"

"$SCRIPT" \
  --prepare-only \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/live-flag.xctestrun" \
  --api-key "secret-value" \
  --base-url "https://example.test/api/paas/v4/" \
  --model "glm-test" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4" >/tmp/mingsi-live-glm-script-test.out

[[ -f "$TMP_DIR/live-flag.xctestrun" ]] || fail "prepare-only should create output xctestrun"
assert_not_contains "secret-value" "$(cat /tmp/mingsi-live-glm-script-test.out)"

for dict_path in \
  ":TestConfigurations:0:TestTargets:0:EnvironmentVariables"
do
  acceptance="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_ACCEPTANCE" "$TMP_DIR/live-flag.xctestrun")"
  api_key="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_API_KEY" "$TMP_DIR/live-flag.xctestrun")"
  base_url="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_BASE_URL" "$TMP_DIR/live-flag.xctestrun")"
  model="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_MODEL" "$TMP_DIR/live-flag.xctestrun")"
  [[ "$acceptance" == "1" ]] || fail "missing acceptance flag at $dict_path"
  [[ "$api_key" == "secret-value" ]] || fail "missing API key at $dict_path"
  [[ "$base_url" == "https://example.test/api/paas/v4/" ]] || fail "missing base URL at $dict_path"
  [[ "$model" == "glm-test" ]] || fail "missing model at $dict_path"
done

for dict_path in \
  ":MingSiTests:EnvironmentVariables"
do
  acceptance="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_ACCEPTANCE" "$TMP_DIR/live-flag.xctestrun")"
  api_key="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_API_KEY" "$TMP_DIR/live-flag.xctestrun")"
  [[ "$acceptance" == "1" ]] || fail "missing top-level acceptance flag at $dict_path"
  [[ "$api_key" == "secret-value" ]] || fail "missing top-level API key at $dict_path"
done

"$SCRIPT" \
  --prepare-only \
  --career-golden \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/career-live-flag.xctestrun" \
  --api-key "secret-value" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4" >/tmp/mingsi-live-glm-career-script-test.out

for dict_path in \
  ":TestConfigurations:0:TestTargets:0:EnvironmentVariables"
do
  career_golden="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_GLM_CAREER_GOLDEN" "$TMP_DIR/career-live-flag.xctestrun")"
  [[ "$career_golden" == "1" ]] || fail "missing career golden flag at $dict_path"
done
assert_not_contains "secret-value" "$(cat /tmp/mingsi-live-glm-career-script-test.out)"

"$SCRIPT" \
  --prepare-only \
  --mentor-semantic \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/mentor-live-flag.xctestrun" \
  --api-key "secret-value" \
  --destination "platform=iOS Simulator,id=9F93EE80-68DF-4922-8A73-B0590F5143D4" >/tmp/mingsi-live-glm-mentor-script-test.out

for dict_path in \
  ":TestConfigurations:0:TestTargets:0:EnvironmentVariables"
do
  mentor_acceptance="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:MINGSI_LIVE_MENTOR_ACCEPTANCE" "$TMP_DIR/mentor-live-flag.xctestrun")"
  [[ "$mentor_acceptance" == "1" ]] || fail "missing mentor semantic flag at $dict_path"
done
assert_not_contains "secret-value" "$(cat /tmp/mingsi-live-glm-mentor-script-test.out)"

# TestingEnvironmentVariables must never receive URL/key custom values:
# xcodebuild converts its strings to paths and collapses https:// to https:/.
for output in live-flag career-live-flag mentor-live-flag; do
  for dict_path in \
    ":TestConfigurations:0:TestTargets:0:TestingEnvironmentVariables" \
    ":MingSiTests:TestingEnvironmentVariables"; do
    framework_path="$(/usr/libexec/PlistBuddy -c "Print ${dict_path}:DYLD_FRAMEWORK_PATH" "$TMP_DIR/${output}.xctestrun")"
    [[ "$framework_path" == "__TESTROOT__/Frameworks" ]] || fail "must preserve Xcode testing environment"
    for variable in MINGSI_LIVE_GLM_ACCEPTANCE MINGSI_LIVE_GLM_CAREER_GOLDEN \
      MINGSI_LIVE_MENTOR_ACCEPTANCE MINGSI_LIVE_GLM_API_KEY \
      MINGSI_LIVE_GLM_BASE_URL MINGSI_LIVE_GLM_MODEL; do
      if /usr/libexec/PlistBuddy -c "Print ${dict_path}:${variable}" "$TMP_DIR/${output}.xctestrun" >/dev/null 2>&1; then
        fail "custom variable $variable must not be injected into $dict_path"
      fi
    done
  done
done

mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/xcodebuild" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$TMP_DIR/bin/xcrun" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "simctl" ]]; then
  printf '%s\n' '{"devices":{"iOS":[{"udid":"9F93EE80-68DF-4922-8A73-B0590F5143D4","name":"iPhone 17","deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17","state":"Booted","isAvailable":true}]}}'
elif [[ "$1" == "xcresulttool" ]]; then
  printf '%s\n' "$FAKE_LIVE_RESULT_SUMMARY"
else
  exit 1
fi
SH
chmod +x "$TMP_DIR/bin/xcodebuild" "$TMP_DIR/bin/xcrun"

assert_result_status() {
  local summary="$1"
  local expected_status="$2"
  local output status
  set +e
  output="$(PATH="$TMP_DIR/bin:$PATH" FAKE_LIVE_RESULT_SUMMARY="$summary" "$SCRIPT" \
    --mentor-semantic \
    --source-xctestrun "$TMP_DIR/fake.xctestrun" \
    --output-xctestrun "$TMP_DIR/result-check.xctestrun" \
    --result-bundle-path "$TMP_DIR/result-check.xcresult" 2>&1)"
  status=$?
  set -e
  [[ "$status" == "$expected_status" ]] || fail "result gate expected exit $expected_status, got $status"
  if [[ "$expected_status" == "0" ]]; then
    assert_contains "live_glm: verified_execution" "$output"
  else
    assert_contains "live_glm: not_accepted" "$output"
    assert_not_contains "live_glm: verified_execution" "$output"
  fi
}

assert_result_status '{"totalTestCount":1,"passedTests":1,"skippedTests":0,"failedTests":0}' 0
assert_result_status '{"totalTestCount":1,"passedTests":0,"skippedTests":1,"failedTests":0}' 3
assert_result_status '{"totalTestCount":0,"passedTests":0,"skippedTests":0,"failedTests":0}' 3
assert_result_status '{"totalTestCount":1,"passedTests":0,"skippedTests":0,"failedTests":1}' 3
assert_result_status '{}' 3
assert_result_status 'invalid-json' 3

printf 'PASS: live GLM acceptance script contract\n'
