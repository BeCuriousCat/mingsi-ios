#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MingSi.xcodeproj"
SCHEME="MingSi"
DESTINATION="platform=iOS Simulator,name=iPhone 17"
DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-ui-automation-dd"
RESULT_BUNDLE_PATH="${TMPDIR:-/tmp}/mingsi-ui-automation.xcresult"
ONLY_TESTING="MingSiUITests"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/run_ui_automation.sh [options]

Run the MingSi rendered UI automation suite through XCTest accessibility identifiers.

Options:
  --destination VALUE          xcodebuild destination. Default: iPhone 17 simulator.
  --derived-data-path PATH     DerivedData path for this UI automation run.
  --result-bundle-path PATH    xcresult output path.
  --only-testing VALUE         XCTest only-testing selector. Default: MingSiUITests.
  --dry-run                    Print the xcodebuild command; do not run it.
  -h, --help                   Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --derived-data-path)
      DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --result-bundle-path)
      RESULT_BUNDLE_PATH="${2:-}"
      shift 2
      ;;
    --only-testing)
      ONLY_TESTING="${2:-}"
      shift 2
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

print_command() {
  printf 'MingSi UI automation runner:\n'
  printf 'Destination: %s\n' "$DESTINATION"
  printf 'DerivedData: %s\n' "$DERIVED_DATA_PATH"
  printf 'Result bundle: %s\n' "$RESULT_BUNDLE_PATH"
  printf 'Only testing: %s\n' "$ONLY_TESTING"
  printf '\n'
  printf 'xcodebuild test -project %q -scheme %q -destination %q -derivedDataPath %q -resultBundlePath %q -only-testing:%q\n' \
    "$PROJECT_PATH" "$SCHEME" "$DESTINATION" "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_PATH" "$ONLY_TESTING"
}

if [[ "$DRY_RUN" == "1" ]]; then
  print_command
  exit 0
fi

rm -rf "$RESULT_BUNDLE_PATH"

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -only-testing:"$ONLY_TESTING"
