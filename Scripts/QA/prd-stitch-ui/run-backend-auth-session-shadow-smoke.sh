#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="${AUTH_SESSION_SMOKE_OUTPUT_DIR:-$ROOT_DIR/tmp/visual-qa/prd-stitch-ui/backend-auth-session-shadow-smoke}"
mkdir -p "$OUTPUT_DIR"

BASE_URL="${DREAMJOURNEY_BACKEND_BASE_URL:-http://127.0.0.1:3100}"
python3 "$SCRIPT_DIR/backend-auth-session-shadow-smoke.py" \
  "$BASE_URL" \
  "${DREAMJOURNEY_BACKEND_API_TOKEN:-}" \
  | tee "$OUTPUT_DIR/report.json"

echo "Auth session shadow smoke report: $OUTPUT_DIR/report.json"
