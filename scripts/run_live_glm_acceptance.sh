#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/MingSi.xcodeproj"
SCHEME="MingSi"
source "$ROOT_DIR/scripts/fixed_simulator_guard.sh"
DESTINATION="$MINGSI_FIXED_SIMULATOR_DESTINATION"
DERIVED_DATA_PATH="${TMPDIR:-/tmp}/mingsi-live-glm-acceptance-dd"
SOURCE_XCTESTRUN=""
OUTPUT_XCTESTRUN=""
API_KEY="${MINGSI_LIVE_GLM_API_KEY:-${MINGSI_GLM_API_KEY:-${GLM_API_KEY:-}}}"
BASE_URL="${MINGSI_LIVE_GLM_BASE_URL:-}"
MODEL="${MINGSI_LIVE_GLM_MODEL:-}"
DRY_RUN=0
PREPARE_ONLY=0
CAREER_GOLDEN=0
TEST_SELECTOR="MingSiTests/LiveGLMAcceptanceTests/testLiveGLMCompleteReturnsJSONWhenExplicitlyEnabled"

usage() {
  cat <<'USAGE'
Usage: scripts/run_live_glm_acceptance.sh [options]

Build and run the opt-in live BYOK GLM XCTest harness.

Options:
  --api-key VALUE             Live GLM API key. Prefer env vars for shell history safety.
  --base-url URL              Optional GLM base URL override.
  --model NAME                Optional GLM model override.
  --destination VALUE         xcodebuild destination. Default: fixed iPhone 17 UDID.
  --derived-data-path PATH    DerivedData path for build-for-testing.
  --source-xctestrun PATH     Existing .xctestrun to copy and inject.
  --output-xctestrun PATH     Output .xctestrun path after injection.
  --career-golden             Run the three live synthetic career golden scenarios.
  --prepare-only              Create injected .xctestrun, but do not run XCTest.
  --dry-run                   Print sanitized commands; do not write or run.
  -h, --help                  Show this help.

Accepted key env vars, in precedence order:
  MINGSI_LIVE_GLM_API_KEY, MINGSI_GLM_API_KEY, GLM_API_KEY
USAGE
  mingsi_fixed_simulator_usage
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --base-url)
      BASE_URL="${2:-}"
      shift 2
      ;;
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --destination)
      DESTINATION="${2:-}"
      shift 2
      ;;
    --derived-data-path)
      DERIVED_DATA_PATH="${2:-}"
      shift 2
      ;;
    --source-xctestrun)
      SOURCE_XCTESTRUN="${2:-}"
      shift 2
      ;;
    --output-xctestrun)
      OUTPUT_XCTESTRUN="${2:-}"
      shift 2
      ;;
    --career-golden)
      CAREER_GOLDEN=1
      TEST_SELECTOR="MingSiTests/LiveGLMAcceptanceTests/testLiveGLMCareerGoldenQuestionsWhenExplicitlyEnabled"
      shift
      ;;
    --prepare-only)
      PREPARE_ONLY=1
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

if [[ "$DESTINATION" != "$MINGSI_FIXED_SIMULATOR_DESTINATION" ]]; then
  printf 'Refusing non-fixed simulator destination: %s\n' "$DESTINATION" >&2
  printf 'Use the fixed iPhone 17 destination: %s\n' "$MINGSI_FIXED_SIMULATOR_DESTINATION" >&2
  exit 2
fi

if [[ -z "$OUTPUT_XCTESTRUN" ]]; then
  OUTPUT_XCTESTRUN="$DERIVED_DATA_PATH/Build/Products/MingSi_MingSi_live-glm.xctestrun"
fi

mask_value() {
  local name="$1"
  local value="$2"
  [[ -n "$value" ]] || return 0
  if [[ "$name" == "MINGSI_LIVE_GLM_API_KEY" ]]; then
    printf '%s=<provided>\n' "$name"
  else
    printf '%s=%s\n' "$name" "$value"
  fi
}

xctestrun_glob() {
  printf '%s/Build/Products/' "$DERIVED_DATA_PATH"
}

resolve_source_xctestrun() {
  if [[ -n "$SOURCE_XCTESTRUN" ]]; then
    printf '%s\n' "$SOURCE_XCTESTRUN"
    return 0
  fi

  local product_dir
  product_dir="$(xctestrun_glob)"
  local found
  found="$(find "$product_dir" -maxdepth 1 -name '*.xctestrun' -print 2>/dev/null | head -n 1 || true)"
  if [[ -z "$found" ]]; then
    printf 'No .xctestrun found under %s. Run without --source-xctestrun so build-for-testing can create one.\n' "$product_dir" >&2
    exit 1
  fi
  printf '%s\n' "$found"
}

plist_set_string() {
  local plist="$1"
  local dict_path="$2"
  local key="$3"
  local value="$4"

  /usr/libexec/PlistBuddy -c "Add ${dict_path} dict" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Delete ${dict_path}:${key}" "$plist" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add ${dict_path}:${key} string ${value}" "$plist" >/dev/null
}

inject_environment() {
  local source="$1"
  local output="$2"

  [[ -f "$source" ]] || {
    printf 'Source .xctestrun not found: %s\n' "$source" >&2
    exit 1
  }

  mkdir -p "$(dirname "$output")"
  cp "$source" "$output"

  local dict_paths=(
    ":TestConfigurations:0:TestTargets:0:EnvironmentVariables"
    ":TestConfigurations:0:TestTargets:0:TestingEnvironmentVariables"
  )

  for dict_path in "${dict_paths[@]}"; do
    plist_set_string "$output" "$dict_path" "MINGSI_LIVE_GLM_ACCEPTANCE" "1"
    if [[ "$CAREER_GOLDEN" == "1" ]]; then
      plist_set_string "$output" "$dict_path" "MINGSI_LIVE_GLM_CAREER_GOLDEN" "1"
    fi
    if [[ -n "$API_KEY" ]]; then
      plist_set_string "$output" "$dict_path" "MINGSI_LIVE_GLM_API_KEY" "$API_KEY"
    fi
    if [[ -n "$BASE_URL" ]]; then
      plist_set_string "$output" "$dict_path" "MINGSI_LIVE_GLM_BASE_URL" "$BASE_URL"
    fi
    if [[ -n "$MODEL" ]]; then
      plist_set_string "$output" "$dict_path" "MINGSI_LIVE_GLM_MODEL" "$MODEL"
    fi
  done
}

print_plan() {
  printf 'Live GLM acceptance environment:\n'
  mask_value "MINGSI_LIVE_GLM_ACCEPTANCE" "1"
  if [[ "$CAREER_GOLDEN" == "1" ]]; then
    mask_value "MINGSI_LIVE_GLM_CAREER_GOLDEN" "1"
  fi
  if [[ -n "$API_KEY" ]]; then
    mask_value "MINGSI_LIVE_GLM_API_KEY" "$API_KEY"
  else
    printf 'MINGSI_LIVE_GLM_API_KEY=<missing; Keychain fallback may still be used>\n'
  fi
  mask_value "MINGSI_LIVE_GLM_BASE_URL" "$BASE_URL"
  mask_value "MINGSI_LIVE_GLM_MODEL" "$MODEL"
  printf '\n'
  if [[ -z "$SOURCE_XCTESTRUN" ]]; then
    printf 'Would run build-for-testing:\n'
    printf 'xcodebuild -project %q -scheme %q -destination %q -derivedDataPath %q -only-testing:%q build-for-testing\n' \
      "$PROJECT_PATH" "$SCHEME" "$DESTINATION" "$DERIVED_DATA_PATH" "$TEST_SELECTOR"
  else
    printf 'Would copy source .xctestrun: %s\n' "$SOURCE_XCTESTRUN"
  fi
  printf 'Would write injected .xctestrun: %s\n' "$OUTPUT_XCTESTRUN"
  printf 'Would run test-without-building:\n'
  printf 'xcodebuild -xctestrun %q -destination %q -derivedDataPath %q -only-testing:%q test-without-building\n' \
    "$OUTPUT_XCTESTRUN" "$DESTINATION" "$DERIVED_DATA_PATH" "$TEST_SELECTOR"
}

if [[ "$DRY_RUN" == "1" ]]; then
  print_plan
  exit 0
fi

mingsi_validate_fixed_simulator

if [[ -z "$SOURCE_XCTESTRUN" ]]; then
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -only-testing:"$TEST_SELECTOR" \
    build-for-testing
fi

SOURCE_XCTESTRUN="$(resolve_source_xctestrun)"
inject_environment "$SOURCE_XCTESTRUN" "$OUTPUT_XCTESTRUN"

printf 'Prepared live GLM .xctestrun: %s\n' "$OUTPUT_XCTESTRUN"
if [[ -n "$API_KEY" ]]; then
  printf 'MINGSI_LIVE_GLM_API_KEY=<provided>\n'
else
  printf 'MINGSI_LIVE_GLM_API_KEY=<missing; Keychain fallback may still be used>\n'
fi

if [[ "$PREPARE_ONLY" == "1" ]]; then
  exit 0
fi

xcodebuild \
  -xctestrun "$OUTPUT_XCTESTRUN" \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -only-testing:"$TEST_SELECTOR" \
  test-without-building
