#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MingSi"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$ROOT_DIR/build/coach-quality-phone-trial"
PHONE_TRIAL_FILE="$ROOT_DIR/docs/coach-quality-phone-trial.md"
APP_BUNDLE_ID="com.codex.mingsi"
DEVICE_ID=""
SKIP_INSTALL=0
SKIP_LAUNCH_CHECK=0
ALLOW_DIRTY=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/prepare_coach_quality_phone_trial.sh [options]

Build MingSi for a connected physical iPhone and install it for the coach-quality
phone-day trial. The script also prints the evidence fields that must be filled
in docs/coach-quality-phone-trial.md after the real use day.

Options:
  --device-id VALUE          Physical iPhone/iPad identifier. Auto-detected when omitted.
  --scheme VALUE             Xcode scheme. Default: MingSi.
  --configuration VALUE      Xcode configuration. Default: Debug.
  --derived-data-path PATH   Build output directory.
  --phone-trial-file PATH    Phone trial evidence file.
  --app-bundle-id VALUE      App bundle id to launch-check. Default: com.codex.mingsi.
  --skip-install             Build only; do not install to the device.
  --skip-launch-check        Do not launch-check the installed app.
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
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    --skip-launch-check)
      SKIP_LAUNCH_CHECK=1
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

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<PLAN
Coach quality phone-trial preparation plan:
- scheme: $SCHEME
- configuration: $CONFIGURATION
- destination: $DESTINATION
- device: $DEVICE_NAME
- commit: $COMMIT
- derived data: $DERIVED_DATA_PATH
- phone trial file: $PHONE_TRIAL_FILE
- skip install: $SKIP_INSTALL
- launch check: $([[ "$SKIP_LAUNCH_CHECK" == "0" ]] && printf '%s' "$APP_BUNDLE_ID" || printf 'skipped')
PLAN
  exit 0
fi

printf 'Building %s for %s (%s)...\n' "$SCHEME" "$DEVICE_NAME" "$DEVICE_ID"
xcodebuild build \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -path "*-iphoneos/${SCHEME}.app" -type d -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  printf 'Built app was not found under %s/Build/Products.\n' "$DERIVED_DATA_PATH" >&2
  exit 1
fi

if [[ "$SKIP_INSTALL" == "0" ]]; then
  printf 'Installing %s to %s...\n' "$APP_PATH" "$DEVICE_NAME"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
else
  printf 'Install skipped. Built app: %s\n' "$APP_PATH"
fi

if [[ "$SKIP_LAUNCH_CHECK" == "0" ]]; then
  printf 'Launch-checking %s on %s...\n' "$APP_BUNDLE_ID" "$DEVICE_NAME"
  if ! xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$APP_BUNDLE_ID" --timeout 30; then
    cat >&2 <<'LAUNCH_HELP'

The app installed, but iOS refused to launch it.
On the iPhone, trust this developer profile before starting the trial:
Settings -> General -> VPN & Device Management -> Developer App -> Trust.
Then rerun this script, or use --skip-launch-check only after confirming the app launches manually.
LAUNCH_HELP
    exit 1
  fi
fi

cat <<EVIDENCE

Phone trial is ready to start.

After one real use day, update:
$PHONE_TRIAL_FILE

Evidence values to copy:
- Trial date: $TODAY
- Device: $DEVICE_NAME ($DEVICE_ID)
- Starting app commit: $COMMIT
- Ending app commit: $COMMIT

Keep Status: PENDING until the next-day result and judgment update are filled.
Change it to Status: PASSED only if the pass criteria are actually met.
EVIDENCE
