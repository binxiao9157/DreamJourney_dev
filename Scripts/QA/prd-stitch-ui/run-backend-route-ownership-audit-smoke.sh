#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${ROUTE_OWNERSHIP_AUDIT_OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-route-ownership-audit-smoke}"
mkdir -p "$OUTPUT_DIR"

BASE_URL="${DREAMJOURNEY_BACKEND_BASE_URL:-http://127.0.0.1:3100}"
python3 "$SCRIPT_DIR/backend-route-ownership-audit-smoke.py" \
  "$BASE_URL" \
  "${DREAMJOURNEY_BACKEND_API_TOKEN:-}" \
  | tee "$OUTPUT_DIR/report.json"

echo "Route ownership audit smoke report: $OUTPUT_DIR/report.json"
