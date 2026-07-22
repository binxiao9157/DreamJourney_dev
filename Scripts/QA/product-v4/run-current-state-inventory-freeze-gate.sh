#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BACKEND_ROOT="${BACKEND_ROOT:-$(cd "$ROOT/.." && pwd)/DreamJourneyBackend}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)-current-state-inventory}"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT/tmp/visual-qa/product-v4/current-state-inventory}"
OUTPUT_PATH="$OUTPUT_ROOT/$RUN_ID/current-state-inventory.json"

python3 "$ROOT/Scripts/QA/product-v4/product-v4-current-state-inventory-check.py"
python3 "$ROOT/Scripts/QA/product-v4/current-state-inventory-freeze.py" \
  --backend-root "$BACKEND_ROOT" \
  --output "$OUTPUT_PATH"

echo "[current-state-inventory] Value-free report: $OUTPUT_PATH"
