#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_PATH="${OUTPUT_PATH:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/public-release-scope-model/result.json}"
EXECUTABLE_PATH="${EXECUTABLE_PATH:-${OUTPUT_PATH%.json}}"

mkdir -p "$(dirname "$OUTPUT_PATH")"
swiftc -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/FeatureFlagService.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/ReleasePolicyStore.swift" \
  "$SCRIPT_DIR/public-release-scope-model-smoke.swift" \
  -o "$EXECUTABLE_PATH"
"$EXECUTABLE_PATH" "$OUTPUT_PATH"
