#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <event-log-path> <event-name>" >&2
  exit 64
fi

event_log="$1"
event_name="$2"
timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"
cwd="$(pwd)"
payload_b64="$(base64 | tr -d '\n')"

mkdir -p "$(dirname "$event_log")"
printf '{"event":"%s","time":"%s","cwd":"%s","payload_b64":"%s"}\n' \
  "$event_name" \
  "$timestamp" \
  "$cwd" \
  "$payload_b64" >> "$event_log"
