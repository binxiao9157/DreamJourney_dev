#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/feature-gate-evaluator-model-smoke}"
BIN_PATH="$OUTPUT_DIR/feature-gate-evaluator-model-smoke"

mkdir -p "$OUTPUT_DIR"

swiftc \
  -parse-as-library \
  "$ROOT_DIR/DreamJourney/Sources/App/FeatureFlagService.swift" \
  "$ROOT_DIR/DreamJourney/Sources/Services/ReleasePolicyStore.swift" \
  "$SCRIPT_DIR/feature-gate-evaluator-model-smoke.swift" \
  -o "$BIN_PATH"

"$BIN_PATH"
