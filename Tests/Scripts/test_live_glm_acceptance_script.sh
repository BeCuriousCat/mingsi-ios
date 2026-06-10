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
  <key>TestConfigurations</key>
  <array>
    <dict>
      <key>TestTargets</key>
      <array>
        <dict>
          <key>BlueprintName</key>
          <string>MingSiTests</string>
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
  --destination "platform=iOS Simulator,name=iPhone 17")"

assert_contains "MINGSI_LIVE_GLM_ACCEPTANCE=1" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_API_KEY=<provided>" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_BASE_URL=https://example.test/api/paas/v4/" "$dry_output"
assert_contains "MINGSI_LIVE_GLM_MODEL=glm-test" "$dry_output"
assert_contains "test-without-building" "$dry_output"
assert_not_contains "secret-value" "$dry_output"
[[ ! -e "$TMP_DIR/live-flag.xctestrun" ]] || fail "dry-run should not create output xctestrun"

"$SCRIPT" \
  --prepare-only \
  --source-xctestrun "$TMP_DIR/fake.xctestrun" \
  --output-xctestrun "$TMP_DIR/live-flag.xctestrun" \
  --api-key "secret-value" \
  --base-url "https://example.test/api/paas/v4/" \
  --model "glm-test" \
  --destination "platform=iOS Simulator,name=iPhone 17" >/tmp/mingsi-live-glm-script-test.out

[[ -f "$TMP_DIR/live-flag.xctestrun" ]] || fail "prepare-only should create output xctestrun"
assert_not_contains "secret-value" "$(cat /tmp/mingsi-live-glm-script-test.out)"

for dict_path in \
  ":TestConfigurations:0:TestTargets:0:EnvironmentVariables" \
  ":TestConfigurations:0:TestTargets:0:TestingEnvironmentVariables"
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

printf 'PASS: live GLM acceptance script contract\n'
