#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

python3 "$ROOT_DIR/Scripts/QA/product-v4/product-v4-ios-owner-media-candidate-handoff-check.py"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}" \
  OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/visual-qa/product-v4/owner-media-candidate-handoff-gate}" \
  bash "$ROOT_DIR/Scripts/QA/product-v4/run-ios-owner-media-task-status-uiqa-smoke.sh"
