#!/usr/bin/env bash

# Shared policy for MingSi verification runners. Sourcing scripts retain ownership
# of argument parsing and decide when a non-mutating dry-run should exit.
MINGSI_FIXED_SIMULATOR_UDID="9F93EE80-68DF-4922-8A73-B0590F5143D4"
MINGSI_FIXED_SIMULATOR_DESTINATION="platform=iOS Simulator,id=${MINGSI_FIXED_SIMULATOR_UDID}"

mingsi_fixed_simulator_usage() {
  cat <<USAGE
Simulator policy:
  Verification uses only the fixed iPhone 17 Simulator:
  ${MINGSI_FIXED_SIMULATOR_DESTINATION}
  --destination must use this exact destination. To intentionally use another
  destination, set MINGSI_ALLOW_NONFIXED_SIMULATOR=1 for that command; the
  runner will print a warning. It never boots, creates, deletes, or resets a device.
USAGE
}

mingsi_validate_simulator_destination() {
  local destination="$1"

  if [[ "$destination" == "$MINGSI_FIXED_SIMULATOR_DESTINATION" ]]; then
    return 0
  fi

  if [[ "${MINGSI_ALLOW_NONFIXED_SIMULATOR:-}" == "1" ]]; then
    printf 'WARNING: MINGSI_ALLOW_NONFIXED_SIMULATOR=1 permits non-fixed simulator destination: %s\n' "$destination" >&2
    return 0
  fi

  printf 'Refusing non-fixed simulator destination: %s\n' "$destination" >&2
  printf 'Use the fixed iPhone 17 destination: %s\n' "$MINGSI_FIXED_SIMULATOR_DESTINATION" >&2
  printf 'To intentionally opt out, set MINGSI_ALLOW_NONFIXED_SIMULATOR=1 for this command.\n' >&2
  return 2
}

mingsi_validate_fixed_simulator() {
  local device

  if ! command -v xcrun >/dev/null 2>&1; then
    printf 'xcrun is required to validate the fixed MingSi simulator.\n' >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'jq is required to validate the fixed MingSi simulator.\n' >&2
    return 1
  fi

  if ! device="$(xcrun simctl list devices --json 2>/dev/null | jq -er --arg udid "$MINGSI_FIXED_SIMULATOR_UDID" '
    [.devices[]?[]? | select(.udid == $udid)]
    | if length == 1 then .[0] else error("fixed simulator not found") end
    | select(.isAvailable != false)
    | select((.deviceTypeIdentifier // "") | test("iPhone"; "i"))
    | [.name, .deviceTypeIdentifier, .state] | @tsv
  ' 2>/dev/null)"; then
    printf 'Fixed simulator %s must exist, be available, and be an iPhone before verification starts.\n' "$MINGSI_FIXED_SIMULATOR_UDID" >&2
    return 1
  fi

  printf 'Fixed simulator ready: %s (%s)\n' "${device%%$'\t'*}" "$MINGSI_FIXED_SIMULATOR_UDID"
}
