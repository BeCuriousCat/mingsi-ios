#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MingSi"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/build/coach-quality-phone-trial"
PHONE_TRIAL_FILE="$ROOT_DIR/docs/mingsi-phone-acceptance.md"
APP_BUNDLE_ID="com.codex.mingsi"
DEVICE_ID=""
SIGNING_TEAM=""
SKIP_INSTALL=0
SKIP_LAUNCH_CHECK=0
LAUNCH_CHECK_ONLY=0
ALLOW_DIRTY=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/prepare_coach_quality_phone_trial.sh [options]

Build MingSi for a connected physical iPhone and install it for manual acceptance.
Installation and process launch do not establish usability or user benefit.

Options:
  --device-id VALUE          Physical iPhone/iPad identifier. Auto-detected when omitted.
  --scheme VALUE             Xcode scheme. Default: MingSi.
  --configuration VALUE      Xcode configuration. Default: Debug.
  --derived-data-path PATH   Build output directory.
  --phone-trial-file PATH    Phone trial evidence file.
  --app-bundle-id VALUE      App bundle id to launch-check. Default: com.codex.mingsi.
  --team VALUE               Local Apple signing Team ID; never stored in the project.
  --skip-install             Build only; never launch or validate an older installed app.
  --skip-launch-check        Install without checking process launch; manual launch remains unverified.
  --launch-check-only        Launch existing app only; installed code revision remains unknown.
  --allow-dirty              Allow a dirty worktree.
  --dry-run                  Print the planned commands without running them.
  -h, --help                 Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device-id)
      DEVICE_ID="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="${2:-}"
      shift 2
      ;;
    --derived-data-path)
      DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --phone-trial-file)
      PHONE_TRIAL_FILE="${2:-}"
      shift 2
      ;;
    --app-bundle-id)
      APP_BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --team)
      SIGNING_TEAM="${2:-}"
      [[ "$SIGNING_TEAM" =~ ^[A-Z0-9]{10}$ ]] || { printf 'Signing Team ID must contain 10 uppercase letters or digits.\n' >&2; exit 2; }
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --skip-launch-check)
      SKIP_LAUNCH_CHECK=1
      shift
      ;;
    --launch-check-only)
      LAUNCH_CHECK_ONLY=1
      SKIP_INSTALL=1
      shift
      ;;
    --allow-dirty)
      ALLOW_DIRTY=1
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

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

connected_ios_device_lines() {
  xcrun xctrace list devices 2>/dev/null | awk '
    /^== Devices ==/ { section = "devices"; next }
    /^== Devices Offline ==/ { section = "offline"; next }
    /^== Simulators ==/ { section = "simulators"; next }
    /^==/ { section = ""; next }
    section == "devices" && ($0 ~ /iPhone/ || $0 ~ /iPad/ || $0 ~ /iPod/) { print }
  '
}

extract_device_id() {
  sed -E 's/.*\(([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}|[0-9A-Fa-f-]{20,})\)[[:space:]]*$/\1/'
}

extract_device_name() {
  sed -E 's/[[:space:]]*\([0-9.]+\)[[:space:]]*\([0-9A-Fa-f-]{20,}\)[[:space:]]*$//'
}

warm_coredevice_tunnels() {
  command -v jq >/dev/null 2>&1 || return 0

  local tmp id
  tmp="$(mktemp)"
  if ! xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 0
  fi

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    xcrun devicectl device info lockState --device "$id" --timeout 15 >/dev/null 2>&1 || true
  done < <(
    jq -r '
      .result.devices[]
      | select(.hardwareProperties.reality == "physical")
      | select((.hardwareProperties.deviceType // "") | test("iPhone|iPad|iPod"))
      | select((.connectionProperties.pairingState // "") == "paired")
      | .hardwareProperties.udid // .identifier
    ' "$tmp" 2>/dev/null
  )

  rm -f "$tmp"
}

print_device_diagnostics() {
  printf '== xctrace devices ==\n' >&2
  xcrun xctrace list devices >&2 || true

  printf '\n== CoreDevice physical iOS devices ==\n' >&2
  local tmp
  tmp="$(mktemp)"
  if xcrun devicectl list devices --json-output "$tmp" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    jq -r '
      .result.devices[]
      | select(.hardwareProperties.reality == "physical")
      | select((.hardwareProperties.deviceType // "") | test("iPhone|iPad|iPod"))
      | "- \(.deviceProperties.name) (\(.hardwareProperties.udid), CoreDevice \(.identifier)): pairing=\(.connectionProperties.pairingState // "unknown"), tunnel=\(.connectionProperties.tunnelState // "unknown"), transport=\(.connectionProperties.transportType // "unknown")"
    ' "$tmp" >&2 || true
    if jq -e '
      .result.devices[]
      | select(.hardwareProperties.reality == "physical")
      | select((.hardwareProperties.deviceType // "") | test("iPhone|iPad|iPod"))
      | select((.connectionProperties.tunnelState // "") != "connected")
    ' "$tmp" >/dev/null 2>&1; then
      printf '\nCoreDevice knows a paired iPhone/iPad, but its tunnel is not connected.\n' >&2
      printf 'Unlock the device, keep it awake, connect by USB if Wi-Fi pairing is stale, and trust this Mac if prompted.\n' >&2
    fi
  else
    xcrun devicectl list devices >&2 || true
  fi
  rm -f "$tmp"
}

launch_check_app() {
  printf 'Launch-checking %s on %s...\n' "$APP_BUNDLE_ID" "$DEVICE_NAME"
  if ! xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$APP_BUNDLE_ID" --timeout 30; then
    cat >&2 <<'LAUNCH_HELP'

The process launch check failed. This can reflect a locked device, pairing,
an unavailable installed app, signing, or profile trust; this message cannot
identify which one. Keep the raw tool error and inspect that cause first.
If iOS explicitly reports developer-profile trust, review the developer
identity on the iPhone in Settings -> General -> VPN & Device Management.
Do not mark launch or manual acceptance passed merely by skipping the check.
LAUNCH_HELP
    return 1
  fi
}

require_cmd git
require_cmd xcodebuild
require_cmd xcrun

cd "$ROOT_DIR"

if [[ "$ALLOW_DIRTY" == "0" ]] && [[ -n "$(git status --porcelain)" ]]; then
  printf 'Worktree is dirty. Commit or stash changes before preparing phone-trial evidence.\n' >&2
  printf 'Use --allow-dirty only for a local diagnostic install.\n' >&2
  exit 1
fi

warm_coredevice_tunnels

if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_LINE="$(connected_ios_device_lines | head -n 1 || true)"
  if [[ -n "$DEVICE_LINE" ]]; then
    DEVICE_ID="$(printf '%s\n' "$DEVICE_LINE" | extract_device_id)"
  fi
else
  DEVICE_LINE="$(connected_ios_device_lines | rg "$DEVICE_ID" | head -n 1 || true)"
  if [[ -z "$DEVICE_LINE" ]]; then
    printf 'Requested physical device is not connected or unlocked: %s\n' "$DEVICE_ID" >&2
    printf 'Connect and unlock the device, then trust this Mac if iOS asks.\n\n' >&2
    print_device_diagnostics
    exit 1
  fi
fi

if [[ -z "$DEVICE_ID" ]]; then
  printf 'No connected physical iPhone/iPad was found.\n' >&2
  printf 'Connect and unlock the device, then trust this Mac if iOS asks.\n\n' >&2
  print_device_diagnostics
  exit 1
fi

DEVICE_NAME="$DEVICE_ID"
if [[ -n "${DEVICE_LINE:-}" ]]; then
  DEVICE_NAME="$(printf '%s\n' "$DEVICE_LINE" | extract_device_name)"
fi

DESTINATION="platform=iOS,id=$DEVICE_ID"
COMMIT="$(git rev-parse --short HEAD)"
TODAY="$(date '+%Y-%m-%d')"

if [[ "$SKIP_INSTALL" == "1" && "$LAUNCH_CHECK_ONLY" == "0" ]]; then
  SKIP_LAUNCH_CHECK=1
fi

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<PLAN
Coach quality phone-trial preparation plan:
- scheme: $SCHEME
- configuration: $CONFIGURATION
- signing team override: ${SIGNING_TEAM:-not supplied}
- destination: $DESTINATION
- device: $DEVICE_NAME
- commit: $COMMIT
- derived data: $DERIVED_DATA_PATH
- phone trial file: $PHONE_TRIAL_FILE
- launch-check only: $LAUNCH_CHECK_ONLY
- skip install: $SKIP_INSTALL
- launch check: $([[ "$SKIP_LAUNCH_CHECK" == "0" ]] && printf '%s' "$APP_BUNDLE_ID" || printf 'skipped')
PLAN
  exit 0
fi

if [[ "$LAUNCH_CHECK_ONLY" == "1" ]]; then
  launch_check_app
  cat <<EVIDENCE

Existing app process launch-check passed.
No build or install occurred. Installed source revision is unverified;
do not associate this launch result with the current checkout's commit.
Manual acceptance remains pending in:
$PHONE_TRIAL_FILE
EVIDENCE
  exit 0
fi

printf 'Building %s for %s (%s)...\n' "$SCHEME" "$DEVICE_NAME" "$DEVICE_ID"
BUILD_ARGUMENTS=(build -project "$ROOT_DIR/MingSi.xcodeproj" -scheme "$SCHEME"
  -configuration "$CONFIGURATION" -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH")
if [[ -n "$SIGNING_TEAM" ]]; then
  BUILD_ARGUMENTS+=("DEVELOPMENT_TEAM=$SIGNING_TEAM" "CODE_SIGN_STYLE=Automatic")
fi
if ! xcodebuild "${BUILD_ARGUMENTS[@]}"; then
  cat >&2 <<'BUILD_HELP'

Candidate build failed; no installation or launch check was performed.
If Xcode reports No Accounts or No profiles, configure your own Apple account
in Xcode -> Settings -> Accounts, then select your Team locally or pass --team.
Do not uninstall the existing app or clear its data to fix a signing failure.
This script does not enable provisioning updates or register devices automatically.
BUILD_HELP
  exit 1
fi

APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos/${SCHEME}.app"
if [[ ! -d "$APP_PATH" ]]; then
  printf 'Candidate app for the requested configuration was not found. No older build will be substituted.\n' >&2
  exit 1
fi

if [[ "$SKIP_INSTALL" == "0" ]]; then
  printf 'Installing %s to %s...\n' "$APP_PATH" "$DEVICE_NAME"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
else
  printf 'Install skipped. Built app: %s\n' "$APP_PATH"
fi

if [[ "$SKIP_INSTALL" == "1" ]]; then
  cat <<BUILD_ONLY

Build completed; installation and launch were skipped.
The existing app on the iPhone was not verified and may be an older revision.
- Built source revision: $COMMIT
- Worktree diagnostic override: $ALLOW_DIRTY
- Candidate app: $APP_PATH
Manual acceptance and real use remain pending in:
$PHONE_TRIAL_FILE
BUILD_ONLY
  exit 0
fi

if [[ "$SKIP_LAUNCH_CHECK" == "0" ]]; then
  launch_check_app
fi

cat <<EVIDENCE

Candidate installation completed. This is not a manual acceptance pass.
Record the phone checks before starting the natural-use observation window:
$PHONE_TRIAL_FILE

Evidence values to copy:
- Trial date: $TODAY
- Device: $DEVICE_NAME ($DEVICE_ID)
- Installed candidate source revision: $COMMIT
- Worktree diagnostic override: $ALLOW_DIRTY
- Process launch checked: $([[ "$SKIP_LAUNCH_CHECK" == "0" ]] && printf 'yes' || printf 'no')

Dirty-worktree builds are diagnostic only; the revision alone cannot identify
their contents. Keep all manual and real-use results unverified until observed.
EVIDENCE
