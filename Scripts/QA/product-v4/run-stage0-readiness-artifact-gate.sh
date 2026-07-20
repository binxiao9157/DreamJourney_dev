#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUTPUT_ROOT="${OUTPUT_ROOT:-$ROOT_DIR/tmp/qa/stage0-readiness-artifact-gate}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUTPUT_DIR="$OUTPUT_ROOT/$RUN_ID"
INPUT_PATH="$OUTPUT_DIR/readiness-input.json"
REPORT_PATH="$OUTPUT_DIR/readiness-report.json"
AS_OF="${STAGE0_READINESS_AS_OF:-}"
BACKEND_READY_FILE="${STAGE0_BACKEND_READY_FILE:-}"
BACKEND_READY_URL="${STAGE0_BACKEND_READY_URL:-}"
ECHO_MANIFEST_PATH="${STAGE0_ECHO_MANIFEST_PATH:-}"
REQUIRE_BACKEND_READY="${REQUIRE_STAGE0_BACKEND_READY:-0}"
REQUIRE_ECHO_MANIFEST="${REQUIRE_STAGE0_ECHO_MANIFEST:-0}"
STRICT="${STAGE0_READINESS_STRICT:-0}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

args=(--output "$INPUT_PATH")
if [[ -n "$AS_OF" ]]; then
  args+=(--as-of "$AS_OF")
fi
if [[ -n "$BACKEND_READY_FILE" ]]; then
  args+=(--backend-ready-file "$BACKEND_READY_FILE")
fi
if [[ -n "$BACKEND_READY_URL" ]]; then
  args+=(--backend-ready-url "$BACKEND_READY_URL")
fi
if [[ -n "$ECHO_MANIFEST_PATH" ]]; then
  args+=(--echo-manifest "$ECHO_MANIFEST_PATH")
fi
if [[ "$REQUIRE_BACKEND_READY" == "1" ]]; then
  args+=(--require-backend-ready)
fi
if [[ "$REQUIRE_ECHO_MANIFEST" == "1" ]]; then
  args+=(--require-echo-manifest)
fi

python3 Scripts/QA/product-v4/stage0_readiness_artifact_adapter.py "${args[@]}"

evaluator_args=(--input "$INPUT_PATH" --output "$REPORT_PATH")
if [[ -n "$AS_OF" ]]; then
  evaluator_args+=(--as-of "$AS_OF")
fi
if [[ "$STRICT" == "1" ]]; then
  evaluator_args+=(--strict)
fi
python3 Scripts/QA/product-v4/stage0_strict_readiness.py "${evaluator_args[@]}"

echo "PASS: Stage 0 readiness artifact report written to $REPORT_PATH"
