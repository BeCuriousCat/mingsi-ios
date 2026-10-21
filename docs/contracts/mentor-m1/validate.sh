#!/usr/bin/env bash
set -euo pipefail

mentor_contract_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mentor_validator_directory="$(mktemp -d "${TMPDIR:-/tmp}/mingsi-mentor-m1-schema.XXXXXX")"
trap 'rm -rf "$mentor_validator_directory"' EXIT

npm install --prefix "$mentor_validator_directory" --ignore-scripts --no-audit --no-fund --package-lock=false ajv@8.17.1 ajv-formats@3.0.1
MENTOR_M1_VALIDATOR_ROOT="$mentor_validator_directory" node "$mentor_contract_directory/validate.mjs"
