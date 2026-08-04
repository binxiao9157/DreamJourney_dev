#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-media-stage2-uiqa-gate}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"

mkdir -p "$OUTPUT_DIR"

python3 "$ROOT_DIR/Scripts/QA/product-v4/product-v4-ios-owner-media-release-scope-check.py"

RUN_ID="$RUN_ID-creation" \
  OUTPUT_ROOT="$OUTPUT_DIR/creation" \
  bash "$ROOT_DIR/Scripts/QA/product-v4/run-ios-owner-media-unified-creation-uiqa-smoke.sh"

RUN_ID="$RUN_ID-status" \
  OUTPUT_ROOT="$OUTPUT_DIR/status" \
  bash "$ROOT_DIR/Scripts/QA/product-v4/run-owner-media-candidate-handoff-gate.sh"

RUN_ID="$RUN_ID-candidate" \
  OUTPUT_ROOT="$OUTPUT_DIR/candidate" \
  bash "$ROOT_DIR/Scripts/QA/prd-stitch-ui/run-owner-truth-candidate-inbox-smoke.sh"

printf '[owner-media-stage2-uiqa-gate] Output: %s\n' "$OUTPUT_DIR"
