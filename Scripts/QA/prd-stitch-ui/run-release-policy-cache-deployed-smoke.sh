#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/release-policy-cache-deployed-smoke}"
BACKEND_BASE_URL="${BACKEND_BASE_URL:-https://dreamjourney-api.liftora.cn}"
CLIENT_BUILD="${CLIENT_BUILD:-100}"
PAYLOAD_PATH="$OUTPUT_DIR/release-policy.json"
BIN_PATH="$OUTPUT_DIR/release-policy-cache-deployed-smoke"

mkdir -p "$OUTPUT_DIR"

curl --fail --silent --show-error --location --retry 2 \
  "$BACKEND_BASE_URL/v2/release-policy?audience=owner&cohort=closedPilotAdultSelf&clientBuild=$CLIENT_BUILD&knownPolicyRevision=0" \
  --output "$PAYLOAD_PATH"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/Services/ReleasePolicyStore.swift" \
  "$SCRIPT_DIR/release-policy-cache-deployed-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH" "$PAYLOAD_PATH" "$CLIENT_BUILD"
